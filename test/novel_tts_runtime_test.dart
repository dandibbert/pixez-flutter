import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pixez/er/prefer.dart';
import 'package:pixez/page/novel/tts/novel_tts_audio.dart';
import 'package:pixez/page/novel/tts/novel_tts_controller.dart';
import 'package:pixez/page/novel/tts/novel_tts_engine.dart';
import 'package:pixez/page/novel/tts/novel_tts_now_playing.dart';
import 'package:pixez/page/novel/tts/novel_tts_readings.dart';
import 'package:pixez/page/novel/tts/novel_tts_settings.dart';
import 'package:pixez/page/novel/tts/pronunciation/matching/pronunciation_compiler.dart';
import 'package:pixez/page/novel/tts/pronunciation/storage/pronunciation_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _settings = NovelTtsSettings(
  provider: NovelTtsProvider.custom,
  customUrl: 'https://example.test/a?text={text}&voice={voice}',
  customVoice: 'first',
  prefetchCount: 1,
  splitChars: 20,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefer.init();
    directory = await Directory.systemTemp.createTemp('tts_runtime');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  NovelTtsController controller({
    _Synth? synth,
    _Audio? audio,
    NovelTtsSettings Function()? settings,
    PronunciationRepository? repository,
    NovelTtsNowPlaying? nowPlaying,
  }) => NovelTtsController(
    synthesizer: synth ?? _Synth(),
    audio: audio ?? _Audio(),
    nowPlaying: nowPlaying ?? NovelTtsNowPlaying(),
    settingsLoader: settings ?? () => _settings,
    pronunciationRepository: repository,
    cacheDir: () async => directory,
  );

  Future<void> start(NovelTtsController reader, {int id = 1, int? next}) =>
      reader.start(
        novelId: id,
        title: 'Story $id',
        author: 'Author',
        page: 1,
        totalPages: 1,
        pageText: '第 $id 章。',
        nextSeriesId: next,
      );

  test(
    'real audio adapter prunes played sources without repeating indexes',
    () async {
      final native = _NativeAudio();
      final audio = JustAudioNovelTtsPlayer(player: native);
      final indexes = <int>[];
      final subscription = audio.onClipIndex.listen(indexes.add);
      addTearDown(subscription.cancel);
      addTearDown(audio.dispose);
      await audio.playFiles(['/0.mp3', '/1.mp3', '/2.mp3', '/3.mp3']);
      expect(native.source!.useLazyPreparation, isTrue);
      for (var tag = 1; tag <= 20; tag++) {
        native.advanceTo(tag);
        await _until(() => indexes.isNotEmpty && indexes.last == tag);
        await _until(
          () =>
              (native.source!.children.first as IndexedAudioSource).tag ==
              tag - 1,
        );
        expect(native.source!.children.length, lessThanOrEqualTo(5));
        // A sequence update caused by removing old sources retains its tag.
        native.advanceTo(tag);
        await audio.enqueue('/${tag + 3}.mp3');
      }
      expect(indexes, List.generate(20, (index) => index + 1));
      await audio.stop();
      expect(native.source!.children, isEmpty);
    },
  );

  test(
    'stop during source preparation cannot start playback afterwards',
    () async {
      final native = _NativeAudio()..prepare = Completer<void>();
      final audio = JustAudioNovelTtsPlayer(player: native);
      addTearDown(audio.dispose);
      final starting = audio.playFile('/waiting.mp3');
      await _until(() => native.source != null);
      final stopping = audio.stop();
      native.prepare!.complete();
      await starting;
      await stopping;
      expect(native.playCount, 0);
      expect(native.source!.children, isEmpty);
    },
  );

  test('stop invalidates a start waiting for pronunciation settings', () async {
    final repository = _DelayedRepository();
    final audio = _Audio();
    final reader = controller(repository: repository, audio: audio);
    addTearDown(reader.dispose);
    final starting = start(reader);
    await _until(() => repository.entered);
    await reader.stop();
    repository.release.complete();
    await starting;
    expect(reader.status, NovelTtsStatus.idle);
    expect(reader.session, isNull);
    expect(audio.playCount, 0);
  });

  test(
    'a stale series loader cannot append to a replacement session',
    () async {
      final reader = controller();
      addTearDown(reader.dispose);
      final chapter = Completer<NovelTtsChapter?>();
      var loading = false;
      reader.onLoadChapter = (_) {
        loading = true;
        return chapter.future;
      };
      final original = start(reader, next: 2);
      await _until(() => loading);
      await start(reader, id: 99);
      chapter.complete(
        const NovelTtsChapter(
          novelId: 2,
          title: 'Stale chapter',
          author: 'Author',
          pageTexts: ['过期的章节。'],
        ),
      );
      await original;
      expect(reader.session?.novelId, 99);
      expect(reader.clips.every((clip) => clip.novelId == 99), isTrue);
    },
  );

  test(
    'reattaching a page preserves the same page number in a prefetched chapter',
    () async {
      final reader = controller();
      addTearDown(reader.dispose);
      reader.onLoadChapter = (_) async => const NovelTtsChapter(
        novelId: 2,
        title: 'Second',
        author: 'Author',
        pageTexts: ['下一章的第一页。'],
      );
      await start(reader, next: 2);
      expect(reader.clips.map((clip) => clip.novelId), contains(2));
      await reader.attachPage(page: 1, totalPages: 1, pageText: '本章更新后的第一页。');
      expect(reader.currentClip?.novelId, 1);
      expect(reader.currentClip?.text, '本章更新后的第一页。');
      expect(
        reader.clips.where((clip) => clip.novelId == 2).single.text,
        '下一章的第一页。',
      );
    },
  );

  test('dispose during synthesis never revives the player', () async {
    final synth = _Synth()..gate = Completer<void>();
    final audio = _Audio();
    final reader = controller(synth: synth, audio: audio);
    final starting = start(reader);
    await _until(() => synth.requests.isNotEmpty);
    reader.dispose();
    synth.gate!.complete();
    await starting;
    expect(audio.playCount, 0);
    expect(reader.session, isNull);
    expect(reader.inflightAudioCount, 0);
  });

  test('one prefetched clip means only two synthesis requests', () async {
    final synth = _Synth();
    final reader = controller(synth: synth);
    addTearDown(reader.dispose);
    await reader.start(
      novelId: 1,
      title: 'Story',
      author: 'Author',
      page: 1,
      totalPages: 1,
      pageText: '这是第一句用来测试拆分的。这是第二句用来测试拆分的。这是第三句用来测试拆分的。',
    );
    expect(reader.clips.length, greaterThan(2));
    expect(synth.requests, hasLength(2));
  });

  test('endpoint changes cannot reuse another endpoint audio', () async {
    final synth = _Synth();
    var settings = _settings;
    final reader = controller(synth: synth, settings: () => settings);
    addTearDown(reader.dispose);
    await start(reader);
    settings = settings.copyWith(
      customUrl: 'https://example.test/b?text={text}',
    );
    await reader.applySettings();
    expect(synth.requests, hasLength(2));
    expect(synth.requests.last.customUrl, contains('/b?'));
    expect(reader.status, NovelTtsStatus.playing);
  });

  test(
    'changing a voice while paused replaces audio and stays paused',
    () async {
      final synth = _Synth();
      final audio = _Audio();
      var settings = _settings;
      final reader = controller(
        synth: synth,
        audio: audio,
        settings: () => settings,
      );
      addTearDown(reader.dispose);
      await start(reader);
      await reader.pause();
      settings = settings.copyWith(customVoice: 'second');
      await reader.applySettings();
      expect(synth.requests.last.customVoice, 'second');
      expect(audio.playCount, 2);
      expect(reader.status, NovelTtsStatus.paused);
    },
  );

  test(
    'a seek index event arriving before seek returns advances once',
    () async {
      final audio = _Audio()..emitOnSeek = true;
      final reader = controller(audio: audio);
      addTearDown(reader.dispose);
      await reader.start(
        novelId: 1,
        title: 'Story',
        author: 'Author',
        page: 1,
        totalPages: 1,
        pageText: '这是第一句用来测试拆分的。这是第二句用来测试拆分的。这是第三句用来测试拆分的。',
      );
      await reader.skip(direction: 'next');
      expect(reader.clipIndex, 1);
    },
  );

  test(
    'continuous series retains only previous/current/prefetched chapters',
    () async {
      final audio = _Audio()..emitOnSeek = true;
      final reader = controller(audio: audio);
      addTearDown(reader.dispose);
      reader.onLoadChapter = (id) async => NovelTtsChapter(
        novelId: id,
        title: 'Story $id',
        author: 'Author',
        pageTexts: ['第 $id 章。'],
        prevSeriesId: id - 1,
        nextSeriesId: id < 20 ? id + 1 : null,
      );
      await start(reader, next: 2);
      for (var id = 2; id <= 20; id++) {
        await _until(() => reader.clips.any((clip) => clip.novelId == id));
        await reader.skip(direction: 'next');
        await _until(() => reader.session?.novelId == id);
        expect(
          reader.clips.map((clip) => clip.novelId).toSet().length,
          lessThanOrEqualTo(3),
        );
      }
      expect(reader.session?.novelId, 20);
      await reader.stop();
    },
  );

  test('gap keepalive ends when audio is ready and when paused', () async {
    final nowPlaying = _NowPlaying();
    final reader = controller(nowPlaying: nowPlaying);
    addTearDown(reader.dispose);
    await start(reader);
    expect(nowPlaying.keepAliveStates, contains(true));
    expect(nowPlaying.keepAliveStates.last, isFalse);
    await reader.pause();
    expect(nowPlaying.keepAliveStates.last, isFalse);
  });

  test(
    'platform interruptions update state and preserve automatic resume',
    () async {
      final audio = _Audio();
      final reader = controller(audio: audio);
      addTearDown(reader.dispose);
      await start(reader);
      audio.playing.add(false);
      expect(reader.status, NovelTtsStatus.paused);
      audio.playing.add(true);
      expect(reader.status, NovelTtsStatus.playing);
      await reader.pause();
      audio.playing.add(true);
      expect(
        reader.status,
        NovelTtsStatus.paused,
        reason: 'A user pause must not be undone by a late platform event',
      );
    },
  );

  test(
    'asynchronous playback errors leave a recoverable error state',
    () async {
      final audio = _Audio();
      final nowPlaying = _NowPlaying();
      final reader = controller(audio: audio, nowPlaying: nowPlaying);
      addTearDown(reader.dispose);
      await start(reader);
      audio.errors.add(StateError('decoder failed'));
      await _until(() => reader.status == NovelTtsStatus.error);
      expect(reader.errorMessage, contains('decoder failed'));
      await _until(() => nowPlaying.keepAliveStates.last == false);
      await start(reader);
      expect(reader.status, NovelTtsStatus.playing);
    },
  );

  test(
    'applying readings rebuilds spoken clips at the current position',
    () async {
      var settings = _settings;
      final reader = controller(settings: () => settings);
      addTearDown(reader.dispose);
      await start(reader);
      await reader.pause();
      settings = settings.copyWith(
        readings: const [NovelTtsReading(surface: '第 1 章', reading: '第一章')],
      );
      await reader.applySettings();
      expect(reader.currentClip?.spokenText, '第一章。');
      expect(reader.status, NovelTtsStatus.paused);
    },
  );

  test('custom JSON bodies escape text without expanding its placeholders', () {
    final request = buildNovelTtsRequest(
      _settings.copyWith(
        customMethod: 'POST',
        customUrl: 'https://example.test/tts',
        customContentType: 'application/json',
        customBody: '{"text":"{text}","voice":"{voice}"}',
      ),
      'He said "{voice}".\nNext line',
    );
    final body = jsonDecode(utf8.decode(request.body!));
    expect(body['text'], 'He said "{voice}".\nNext line');
    expect(body['voice'], 'first');
  });

  test('GET cannot rely on a text placeholder in an unsent body', () {
    expect(
      () => buildNovelTtsRequest(
        _settings.copyWith(
          customUrl: 'https://example.test/tts',
          customBody: '{text}',
        ),
        'Hello',
      ),
      throwsA(isA<NovelTtsConfigException>()),
    );
    expect(
      () => buildNovelTtsRequest(
        _settings.copyWith(customUrl: 'file:///tmp/{text}'),
        'Hello',
      ),
      throwsA(isA<NovelTtsConfigException>()),
    );
  });

  test('a response that stops producing bytes times out', () async {
    final stream = StreamController<List<int>>();
    final reading = consolidateHttpClientResponseBytes(
      _Response(stream.stream),
      idleTimeout: const Duration(milliseconds: 20),
    );
    stream.add([1, 2]);
    await expectLater(reading, throwsA(isA<TimeoutException>()));
    await stream.close();
  });
}

Future<void> _until(bool Function() ready) async {
  final end = DateTime.now().add(const Duration(seconds: 5));
  while (!ready() && DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(ready(), isTrue, reason: 'Timed out waiting for asynchronous work');
}

class _Synth implements NovelTtsSynthesizer {
  final requests = <NovelTtsSettings>[];
  Completer<void>? gate;

  @override
  Future<Uint8List> synthesize(NovelTtsSettings settings, String text) async {
    requests.add(settings);
    await gate?.future;
    return Uint8List.fromList([1, 2, 3, 4]);
  }
}

class _Audio implements NovelTtsAudioPlayer, NovelTtsAudioEvents {
  final _indexes = StreamController<int>.broadcast(sync: true);
  final playing = StreamController<bool>.broadcast(sync: true);
  final errors = StreamController<Object>.broadcast(sync: true);
  @override
  Stream<bool> get onPlaying => playing.stream;
  @override
  Stream<Object> get onError => errors.stream;
  var playCount = 0;
  var index = 0;
  var count = 0;
  var emitOnSeek = false;

  @override
  Stream<void> get onComplete => const Stream.empty();
  @override
  Stream<int> get onClipIndex => _indexes.stream;
  @override
  void listen() {}
  @override
  Future<void> playFile(String path) => playFiles([path]);
  @override
  Future<void> playFiles(List<String> paths) async {
    playCount++;
    count = paths.length;
    index = 0;
  }

  @override
  Future<void> enqueue(String path) async {
    count++;
  }

  @override
  Future<bool> seekNext() async {
    if (index + 1 >= count) return false;
    index++;
    if (emitOnSeek) _indexes.add(index);
    return true;
  }

  @override
  Future<bool> seekPrevious() async => false;
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stop() async {
    count = 0;
    index = 0;
  }

  @override
  Future<Duration?> get duration async => const Duration(seconds: 1);
  @override
  Future<Duration?> get position async => Duration.zero;
  @override
  Future<void> dispose() async {
    await _indexes.close();
    await playing.close();
    await errors.close();
  }
}

class _DelayedRepository extends PronunciationRepository {
  var entered = false;
  final release = Completer<void>();

  @override
  Future<PronunciationSnapshot> snapshotFor({
    required String? workId,
    required String? seriesId,
    List<NovelTtsReading>? settingsReadings,
  }) async {
    entered = true;
    await release.future;
    return super.snapshotFor(
      workId: workId,
      seriesId: seriesId,
      settingsReadings: settingsReadings,
    );
  }
}

class _NowPlaying extends NovelTtsNowPlaying {
  final keepAliveStates = <bool>[];
  @override
  Future<void> keepAlive(bool enabled) async {
    keepAliveStates.add(enabled);
  }
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.body);
  final Stream<List<int>> body;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => body.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Uses the production adapter/playlist with a platform-free AudioPlayer.
class _NativeAudio extends Fake implements AudioPlayer {
  final states = StreamController<PlayerState>.broadcast(sync: true);
  final sequences = StreamController<SequenceState>.broadcast(sync: true);
  final errors = StreamController<PlayerException>.broadcast(sync: true);
  ConcatenatingAudioSource? source;
  Completer<void>? prepare;
  int? currentTag;
  var playCount = 0;

  @override
  Stream<PlayerState> get playerStateStream => states.stream;
  @override
  Stream<SequenceState> get sequenceStateStream => sequences.stream;
  @override
  Stream<PlayerException> get errorStream => errors.stream;
  @override
  int? get currentIndex {
    final children = source?.children ?? [];
    final found = children.indexWhere(
      (item) => (item as IndexedAudioSource).tag == currentTag,
    );
    return found < 0 ? null : found;
  }

  void advanceTo(int tag) {
    currentTag = tag;
    final children = source!.children.cast<IndexedAudioSource>();
    sequences.add(
      SequenceState(
        sequence: List.of(children),
        currentIndex: currentIndex,
        shuffleIndices: List.generate(children.length, (index) => index),
        shuffleModeEnabled: false,
        loopMode: LoopMode.off,
      ),
    );
  }

  @override
  Future<Duration?> setAudioSource(
    AudioSource audioSource, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    source = audioSource as ConcatenatingAudioSource;
    currentTag = source!.children.isEmpty
        ? null
        : (source!.children.first as IndexedAudioSource).tag as int;
    if (preload) await prepare?.future;
    return const Duration(seconds: 1);
  }

  @override
  Future<void> play() async {
    playCount++;
  }

  @override
  Future<void> pause() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {
    await states.close();
    await sequences.close();
    await errors.close();
  }
}
