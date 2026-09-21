import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pixez/page/novel/tts/novel_tts_preview.dart';
import 'package:pixez/page/novel/tts/novel_tts_settings.dart';

// These bytes travel through a real HTTP response and a real temporary file.
// The fake player verifies transport/storage; it does not validate MP3 decoding.
const _audioBytes = <int>[0x49, 0x44, 0x33, 4, 0, 0, 0, 0, 0, 0, 1, 2, 3];
const _deadline = Duration(seconds: 5);

void main() {
  late HttpServer server;
  late StreamSubscription<HttpRequest> serverSubscription;
  late Directory temporary;
  late List<_Request> requests;
  late Completer<_Request> firstRequest;
  late Future<void> Function(HttpRequest) respond;
  late _PreviewAudio audio;
  late NovelTtsPreview preview;
  late int playerCreations;
  late bool shuttingDown;
  late List<Object> serverErrors;

  NovelTtsSettings settings({String? template}) => NovelTtsSettings(
    provider: NovelTtsProvider.custom,
    customUrl:
        template ??
        'http://127.0.0.1:${server.port}/tts?voice={voice}&text={text}',
    customVoice: '声线 A & B',
  );

  Future<void> play(NovelTtsSettings settings, [String text = '试听文本']) =>
      HttpOverrides.runWithHttpOverrides(
        () => preview.play(settings, text),
        _RealHttp(),
      );

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('pixez_preview_test_');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    requests = [];
    serverErrors = [];
    shuttingDown = false;
    firstRequest = Completer<_Request>();
    respond = (request) async {
      request.response.headers.contentType = ContentType('audio', 'mpeg');
      request.response.add(_audioBytes);
      await request.response.close();
    };
    serverSubscription = server.listen((request) {
      unawaited(() async {
        try {
          final captured = _Request(
            method: request.method,
            uri: request.uri,
            body: await utf8.decoder.bind(request).join(),
          );
          requests.add(captured);
          if (!firstRequest.isCompleted) firstRequest.complete(captured);
          await respond(request);
        } catch (error) {
          // Closing a client during the cancellation tests can close its
          // response socket. Unexpected server errors remain test failures.
          if (!shuttingDown) serverErrors.add(error);
        }
      }());
    });
    audio = _PreviewAudio();
    playerCreations = 0;
    preview = NovelTtsPreview(
      temporaryDirectory: () async => temporary,
      audioPlayerFactory: () {
        playerCreations++;
        return audio;
      },
    );
  });

  tearDown(() async {
    shuttingDown = true;
    // Release test-controlled waits before cleanup, even after an assertion
    // failure, so a failing test cannot hang the entire CI job.
    audio.releaseLoad();
    audio.releasePlayback();
    try {
      await preview.dispose().timeout(_deadline);
    } catch (_) {
      // Tests for cleanup failures inspect the original play() exception.
    }
    await server.close(force: true);
    await serverSubscription.cancel();
    if (await temporary.exists()) await temporary.delete(recursive: true);
    expect(serverErrors, isEmpty);
  });

  test(
    'voice/text GET preserves exact parameters and plays the saved response',
    () async {
      const text = '你好，A&B + {voice}\n下一行';
      await play(settings(), text).timeout(_deadline);

      final request = requests.single;
      expect(request.method, 'GET');
      expect(request.uri.path, '/tts');
      expect(request.uri.queryParametersAll, {
        'voice': ['声线 A & B'],
        'text': [text],
      });
      expect(request.body, isEmpty);
      expect(playerCreations, 1);
      expect(audio.bytesReadFromFile, _audioBytes);
      expect(
        audio.loadedPath,
        startsWith('${temporary.path}${Platform.pathSeparator}'),
      );
      expect(
        audio.loadedPath,
        endsWith('${Platform.pathSeparator}preview.mp3'),
      );
      expect(audio.playCount, 1);
      expect(audio.disposeCount, 1);
      expect(await File(audio.loadedPath!).exists(), isFalse);
      expect(await temporary.list().toList(), isEmpty);
    },
  );

  test(
    'arbitrary custom variables reach the server without injected fields',
    () async {
      final custom =
          settings(
            template:
                'http://127.0.0.1:${server.port}/tts'
                '?speaker_id={speaker_id}&style={style_name}&text={text}',
          ).copyWith(
            customVariables: {
              'speaker_id': '428',
              'style_name': '落ち着いた声 & slow',
            },
          );
      const text = 'Read {speaker_id} literally.';
      await play(custom, text).timeout(_deadline);

      expect(requests.single.uri.queryParametersAll, {
        'speaker_id': ['428'],
        'style': ['落ち着いた声 & slow'],
        'text': [text],
      });
      expect(audio.bytesReadFromFile, _audioBytes);
      expect(audio.playCount, 1);
      expect(await temporary.list().toList(), isEmpty);
    },
  );

  for (final status in [401, 500]) {
    test(
      'HTTP $status retains status and response details as a synthesis error',
      () async {
        final body = status == 401
            ? 'Missing speech API key'
            : 'Speech worker unavailable';
        respond = (request) async {
          request.response.statusCode = status;
          request.response.write(body);
          await request.response.close();
        };

        await expectLater(
          play(settings()).timeout(_deadline),
          throwsA(
            isA<NovelTtsPreviewException>()
                .having(
                  (error) => error.stage,
                  'stage',
                  NovelTtsPreviewStage.synthesis,
                )
                .having(
                  (error) => error.cause.toString(),
                  'HTTP status',
                  contains('HTTP $status'),
                )
                .having(
                  (error) => error.cause.toString(),
                  'response body',
                  contains(body),
                ),
          ),
        );
        expect(requests, hasLength(1));
        expect(playerCreations, 0);
        expect(await temporary.list().toList(), isEmpty);
      },
    );
  }

  test('an unusable temporary directory is reported at savingAudio', () async {
    final obstruction = await File(
      '${temporary.path}/not_a_directory',
    ).writeAsString('existing file');
    preview = NovelTtsPreview(
      temporaryDirectory: () async => Directory(obstruction.path),
      audioPlayerFactory: () {
        playerCreations++;
        return audio;
      },
    );

    await expectLater(
      play(settings()).timeout(_deadline),
      throwsA(
        isA<NovelTtsPreviewException>()
            .having(
              (error) => error.stage,
              'stage',
              NovelTtsPreviewStage.savingAudio,
            )
            .having(
              (error) => error.cause,
              'filesystem cause',
              isA<FileSystemException>(),
            ),
      ),
    );
    expect(
      requests,
      hasLength(1),
      reason: 'The API succeeds before saving fails',
    );
    expect(playerCreations, 0);
    expect(await obstruction.readAsString(), 'existing file');
  });

  test(
    'a decoder failure is reported at loadingAudio and removes the saved file',
    () async {
      final failure = StateError('Unsupported audio encoding');
      audio.loadError = failure;

      await expectLater(
        play(settings()).timeout(_deadline),
        throwsA(
          isA<NovelTtsPreviewException>()
              .having(
                (error) => error.stage,
                'stage',
                NovelTtsPreviewStage.loadingAudio,
              )
              .having(
                (error) => error.cause,
                'original decoder failure',
                same(failure),
              ),
        ),
      );
      expect(audio.bytesReadFromFile, _audioBytes);
      expect(audio.playCount, 0);
      expect(audio.disposeCount, 1);
      expect(await temporary.list().toList(), isEmpty);
    },
  );

  test(
    'a playback failure keeps its stage and removes temporary audio',
    () async {
      final failure = StateError('Audio output unavailable');
      audio.playError = failure;

      await expectLater(
        play(settings()).timeout(_deadline),
        throwsA(
          isA<NovelTtsPreviewException>()
              .having(
                (error) => error.stage,
                'stage',
                NovelTtsPreviewStage.playback,
              )
              .having(
                (error) => error.cause,
                'original playback failure',
                same(failure),
              ),
        ),
      );
      expect(audio.playCount, 1);
      expect(audio.disposeCount, 1);
      expect(await temporary.list().toList(), isEmpty);
    },
  );

  test(
    'stop aborts an outstanding real HTTP request before creating a player',
    () async {
      // Leave the response open: only cancelling the actual client connection
      // can settle synthesis before the normal request timeout.
      respond = (_) async {};
      final playing = play(settings());
      await firstRequest.future.timeout(_deadline);

      await preview.stop().timeout(_deadline);
      await playing.timeout(_deadline);
      expect(playerCreations, 0);
      expect(audio.playCount, 0);
      expect(await temporary.list().toList(), isEmpty);
    },
  );

  test(
    'stop while loading audio prevents playback and cleans the saved file',
    () async {
      audio.loadGate = Completer<void>();
      final playing = play(settings());
      await audio.loadEntered.future.timeout(_deadline);
      final path = audio.loadedPath!;
      expect(await File(path).readAsBytes(), _audioBytes);

      final stopping = preview.stop();
      audio.releaseLoad();
      await stopping.timeout(_deadline);
      await playing.timeout(_deadline);
      expect(audio.playCount, 0);
      expect(audio.disposeCount, 1);
      expect(await File(path).exists(), isFalse);
      expect(await temporary.list().toList(), isEmpty);
    },
  );

  test(
    'dispose during playback stops the player and removes temporary audio',
    () async {
      audio.playGate = Completer<void>();
      final playing = play(settings());
      await audio.playEntered.future.timeout(_deadline);
      expect(await File(audio.loadedPath!).exists(), isTrue);

      await preview.dispose().timeout(_deadline);
      await playing.timeout(_deadline);
      expect(audio.stopCount, greaterThanOrEqualTo(1));
      expect(audio.disposeCount, 1);
      expect(await temporary.list().toList(), isEmpty);

      await play(settings()).timeout(_deadline);
      expect(
        requests,
        hasLength(1),
        reason: 'Disposed previews cannot restart',
      );
    },
  );

  test(
    'a cleanup failure does not replace the original decoder error',
    () async {
      final original = StateError('Original decoder failure');
      audio.loadError = original;
      audio.disposeError = StateError('Secondary disposal failure');

      await expectLater(
        play(settings()).timeout(_deadline),
        throwsA(
          isA<NovelTtsPreviewException>()
              .having(
                (error) => error.stage,
                'stage',
                NovelTtsPreviewStage.loadingAudio,
              )
              .having((error) => error.cause, 'first failure', same(original)),
        ),
      );
      expect(audio.disposeCount, 1);
      expect(
        await temporary.list().toList(),
        isEmpty,
        reason: 'File cleanup still runs after player disposal fails',
      );
    },
  );

  test('a standalone cleanup failure is reported as cleanup', () async {
    final failure = StateError('Disposal failure');
    audio.disposeError = failure;

    await expectLater(
      play(settings()).timeout(_deadline),
      throwsA(
        isA<NovelTtsPreviewException>()
            .having(
              (error) => error.stage,
              'stage',
              NovelTtsPreviewStage.cleanup,
            )
            .having((error) => error.cause, 'cleanup failure', same(failure)),
      ),
    );
    expect(audio.playCount, 1);
    expect(await temporary.list().toList(), isEmpty);
  });
}

// Override any Flutter test HTTP stub with dart:io's default implementation.
// All tests above still use real loopback sockets; no HTTP response is mocked.
class _RealHttp extends HttpOverrides {}

class _Request {
  const _Request({required this.method, required this.uri, required this.body});
  final String method;
  final Uri uri;
  final String body;
}

class _PreviewAudio extends Fake implements AudioPlayer {
  String? loadedPath;
  List<int>? bytesReadFromFile;
  Object? loadError;
  Object? playError;
  Object? disposeError;
  Completer<void>? loadGate;
  Completer<void>? playGate;
  final loadEntered = Completer<void>();
  final playEntered = Completer<void>();
  var playCount = 0;
  var stopCount = 0;
  var disposeCount = 0;

  void releaseLoad() {
    final gate = loadGate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  void releasePlayback() {
    final gate = playGate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<Duration?> setFilePath(
    String filePath, {
    Duration? initialPosition,
    bool preload = true,
    dynamic tag,
  }) async {
    loadedPath = filePath;
    bytesReadFromFile = await File(filePath).readAsBytes();
    if (!loadEntered.isCompleted) loadEntered.complete();
    await loadGate?.future;
    final failure = loadError;
    if (failure != null) throw failure;
    return const Duration(milliseconds: 100);
  }

  @override
  Future<void> play() async {
    playCount++;
    if (!playEntered.isCompleted) playEntered.complete();
    final failure = playError;
    if (failure != null) throw failure;
    await playGate?.future;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    releasePlayback();
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    releasePlayback();
    final failure = disposeError;
    if (failure != null) throw failure;
  }
}
