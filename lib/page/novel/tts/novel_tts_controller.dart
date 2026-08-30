import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pixez/page/novel/tts/novel_tts_advance.dart';
import 'package:pixez/page/novel/tts/novel_tts_audio.dart';
import 'package:pixez/page/novel/tts/novel_tts_engine.dart';
import 'package:pixez/page/novel/tts/novel_tts_now_playing.dart';
import 'package:pixez/page/novel/tts/novel_tts_settings.dart';
import 'package:pixez/page/novel/tts/novel_tts_splitter.dart';

enum NovelTtsStatus { idle, synthesizing, playing, paused, error }

enum NovelTtsNavigateKind { page, series }

class NovelTtsNavigate {
  const NovelTtsNavigate({
    required this.kind,
    this.page,
    this.seriesNovelId,
    this.fromEnd = false,
  });

  final NovelTtsNavigateKind kind;
  final int? page;
  final int? seriesNovelId;
  final bool fromEnd;
}

class NovelTtsSession {
  const NovelTtsSession({
    required this.novelId,
    required this.title,
    required this.author,
    required this.page,
    required this.totalPages,
    required this.chunks,
    this.coverUrl,
    this.prevSeriesId,
    this.nextSeriesId,
  });

  final int novelId;
  final String title;
  final String author;
  final String? coverUrl;
  final int page;
  final int totalPages;
  final List<String> chunks;
  final int? prevSeriesId;
  final int? nextSeriesId;

  NovelTtsSession copyWith({
    int? page,
    int? totalPages,
    List<String>? chunks,
    int? prevSeriesId,
    int? nextSeriesId,
  }) {
    return NovelTtsSession(
      novelId: novelId,
      title: title,
      author: author,
      coverUrl: coverUrl,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      chunks: chunks ?? this.chunks,
      prevSeriesId: prevSeriesId ?? this.prevSeriesId,
      nextSeriesId: nextSeriesId ?? this.nextSeriesId,
    );
  }
}

class NovelTtsController extends ChangeNotifier {
  NovelTtsController({
    NovelTtsSynthesizer? synthesizer,
    NovelTtsAudioPlayer? audio,
    NovelTtsNowPlaying? nowPlaying,
    NovelTtsSettings Function()? settingsLoader,
    Future<Directory> Function()? cacheDir,
  }) : _synthesizer = synthesizer ?? NovelTtsHttpSynthesizer(),
       _audio = audio ?? JustAudioNovelTtsPlayer(),
       _nowPlaying = nowPlaying ?? NovelTtsNowPlaying(),
       _settingsLoader = settingsLoader ?? NovelTtsSettings.load,
       _cacheDir = cacheDir {
    _audio.listen();
    _completionSub = _audio.onComplete.listen((_) {
      unawaited(_onChunkComplete());
    });
    _nowPlaying.onRemote = _onRemote;
    _nowPlaying.bind();
  }

  static NovelTtsController? _instance;

  static NovelTtsController get instance {
    return _instance ??= NovelTtsController();
  }

  @visibleForTesting
  static set debugInstance(NovelTtsController? value) {
    _instance = value;
  }

  final NovelTtsSynthesizer _synthesizer;
  final NovelTtsAudioPlayer _audio;
  final NovelTtsNowPlaying _nowPlaying;
  final NovelTtsSettings Function() _settingsLoader;
  final Future<Directory> Function()? _cacheDir;

  StreamSubscription<void>? _completionSub;
  final Map<String, Future<Uint8List>> _inflight = {};
  int _generation = 0;
  Timer? _nowPlayingTimer;

  NovelTtsStatus status = NovelTtsStatus.idle;
  String? errorMessage;
  NovelTtsSession? session;
  int chunkIndex = 0;
  int? pendingResumeNovelId;
  bool pendingResumeFromEnd = false;
  void Function(NovelTtsNavigate navigate)? onNavigate;

  bool get isActive =>
      status == NovelTtsStatus.playing ||
      status == NovelTtsStatus.paused ||
      status == NovelTtsStatus.synthesizing;

  String get subtitle {
    final chunks = session?.chunks;
    if (chunks == null || chunks.isEmpty) {
      return '';
    }
    return chunks[chunkIndex.clamp(0, chunks.length - 1)];
  }

  NovelTtsSettings get settings => _settingsLoader();

  Future<void> start({
    required int novelId,
    required String title,
    required String author,
    required int page,
    required int totalPages,
    required String pageText,
    String? coverUrl,
    int? prevSeriesId,
    int? nextSeriesId,
    int startChunk = 0,
  }) async {
    final loaded = settings;
    if (!loaded.isConfigured) {
      status = NovelTtsStatus.error;
      errorMessage = 'not_configured';
      notifyListeners();
      return;
    }
    final chunks = splitNovelTtsText(
      pageText,
      maxChars: loaded.clampedSplitChars,
    );
    if (chunks.isEmpty) {
      status = NovelTtsStatus.error;
      errorMessage = 'empty';
      notifyListeners();
      return;
    }
    _generation++;
    pendingResumeNovelId = null;
    session = NovelTtsSession(
      novelId: novelId,
      title: title,
      author: author,
      coverUrl: coverUrl,
      page: page,
      totalPages: totalPages,
      chunks: chunks,
      prevSeriesId: prevSeriesId,
      nextSeriesId: nextSeriesId,
    );
    chunkIndex = startChunk.clamp(0, chunks.length - 1);
    errorMessage = null;
    await _ensureAudioSession();
    await _playCurrent();
  }

  Future<void> _ensureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      await session.setActive(true);
    } catch (_) {}
  }

  Future<void> attachPage({
    required int page,
    required int totalPages,
    required String pageText,
    int? prevSeriesId,
    int? nextSeriesId,
    bool fromEnd = false,
  }) async {
    final current = session;
    if (current == null) {
      return;
    }
    final chunks = splitNovelTtsText(
      pageText,
      maxChars: settings.clampedSplitChars,
    );
    if (chunks.isEmpty) {
      await skip(direction: fromEnd ? 'prev' : 'next');
      return;
    }
    session = current.copyWith(
      page: page,
      totalPages: totalPages,
      chunks: chunks,
      prevSeriesId: prevSeriesId,
      nextSeriesId: nextSeriesId,
    );
    chunkIndex = fromEnd ? chunks.length - 1 : 0;
    await _playCurrent();
  }

  bool takePendingResume(int novelId) {
    if (pendingResumeNovelId != novelId) {
      return false;
    }
    pendingResumeNovelId = null;
    return true;
  }

  Future<void> toggle() async {
    if (status == NovelTtsStatus.playing) {
      await pause();
      return;
    }
    if (status == NovelTtsStatus.paused) {
      await resume();
    }
  }

  Future<void> pause() async {
    if (status != NovelTtsStatus.playing) {
      return;
    }
    await _audio.pause();
    status = NovelTtsStatus.paused;
    await _publishNowPlaying();
    notifyListeners();
  }

  Future<void> resume() async {
    if (status != NovelTtsStatus.paused) {
      return;
    }
    await _audio.resume();
    status = NovelTtsStatus.playing;
    await _publishNowPlaying();
    notifyListeners();
  }

  Future<void> stop() async {
    _generation++;
    pendingResumeNovelId = null;
    await _audio.stop();
    await _nowPlaying.stop();
    _nowPlayingTimer?.cancel();
    status = NovelTtsStatus.idle;
    errorMessage = null;
    session = null;
    chunkIndex = 0;
    notifyListeners();
  }

  Future<void> skip({required String direction}) async {
    final current = session;
    if (current == null) {
      return;
    }
    final advance = resolveNovelTtsAdvance(
      direction: direction,
      chunkIndex: chunkIndex,
      chunkCount: current.chunks.length,
      currentPage: current.page,
      totalPages: current.totalPages,
      prevSeriesId: current.prevSeriesId,
      nextSeriesId: current.nextSeriesId,
      autoContinue: settings.autoContinue,
    );
    switch (advance.kind) {
      case NovelTtsAdvanceKind.chunk:
        chunkIndex += direction == 'prev' ? -1 : 1;
        await _playCurrent();
      case NovelTtsAdvanceKind.page:
        onNavigate?.call(
          NovelTtsNavigate(
            kind: NovelTtsNavigateKind.page,
            page: advance.page,
            fromEnd: direction == 'prev',
          ),
        );
      case NovelTtsAdvanceKind.series:
        pendingResumeNovelId = advance.seriesNovelId;
        pendingResumeFromEnd = direction == 'prev';
        onNavigate?.call(
          NovelTtsNavigate(
            kind: NovelTtsNavigateKind.series,
            seriesNovelId: advance.seriesNovelId,
            fromEnd: direction == 'prev',
          ),
        );
      case NovelTtsAdvanceKind.stop:
        await stop();
    }
  }

  Future<void> _onChunkComplete() async {
    if (status == NovelTtsStatus.idle) {
      return;
    }
    await skip(direction: 'next');
  }

  void _onRemote(String action) {
    switch (action) {
      case 'play':
        unawaited(resume());
      case 'pause':
        unawaited(pause());
      case 'toggle':
        unawaited(toggle());
      case 'next':
        unawaited(skip(direction: 'next'));
      case 'previous':
        unawaited(skip(direction: 'prev'));
      case 'stop':
        unawaited(stop());
    }
  }

  Future<void> _playCurrent() async {
    final current = session;
    if (current == null || current.chunks.isEmpty) {
      return;
    }
    final generation = ++_generation;
    final index = chunkIndex.clamp(0, current.chunks.length - 1);
    chunkIndex = index;
    status = NovelTtsStatus.synthesizing;
    errorMessage = null;
    notifyListeners();
    _prefetch(current, index);
    try {
      final bytes = await _audioBytes(current.chunks[index]);
      if (generation != _generation) {
        return;
      }
      final file = await _writeCache(current.chunks[index], bytes);
      if (generation != _generation) {
        return;
      }
      await _audio.playFile(file.path);
      if (generation != _generation) {
        return;
      }
      status = NovelTtsStatus.playing;
      await _publishNowPlaying();
      notifyListeners();
    } catch (error) {
      if (generation != _generation) {
        return;
      }
      status = NovelTtsStatus.error;
      errorMessage = error.toString();
      notifyListeners();
    }
  }

  void _prefetch(NovelTtsSession current, int index) {
    final ahead = settings.prefetchCount.clamp(0, 4);
    for (var i = 1; i <= ahead; i++) {
      final next = index + i;
      if (next >= current.chunks.length) {
        break;
      }
      unawaited(_audioBytes(current.chunks[next]));
    }
  }

  Future<Uint8List> _audioBytes(String text) {
    final key = _cacheKey(text);
    return _inflight.putIfAbsent(key, () async {
      return _synthesizer.synthesize(settings, text);
    });
  }

  String _cacheKey(String text) {
    final loaded = settings;
    final material =
        '${loaded.provider.name}|${loaded.activeVoice}|${loaded.openaiModel}|$text';
    return sha1.convert(material.codeUnits).toString();
  }

  Future<File> _writeCache(String text, Uint8List bytes) async {
    final dir = await (_cacheDir?.call() ?? getTemporaryDirectory());
    final ttsDir = Directory(p.join(dir.path, 'novel_tts'));
    if (!ttsDir.existsSync()) {
      ttsDir.createSync(recursive: true);
    }
    final file = File(p.join(ttsDir.path, '${_cacheKey(text)}.mp3'));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _publishNowPlaying() async {
    final current = session;
    if (current == null) {
      return;
    }
    final info = NovelTtsNowPlayingInfo(
      title: current.title,
      artist: current.author,
      subtitle: subtitle,
      isPlaying: status == NovelTtsStatus.playing,
      durationMs: (await _audio.duration)?.inMilliseconds ?? 0,
      positionMs: (await _audio.position)?.inMilliseconds ?? 0,
    );
    if (status == NovelTtsStatus.playing || status == NovelTtsStatus.paused) {
      await _nowPlaying.start(info);
    } else {
      await _nowPlaying.update(info);
    }
    if (status == NovelTtsStatus.playing) {
      _nowPlayingTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        unawaited(_tickNowPlaying());
      });
    } else {
      _nowPlayingTimer?.cancel();
      _nowPlayingTimer = null;
    }
  }

  Future<void> _tickNowPlaying() async {
    if (status != NovelTtsStatus.playing || session == null) {
      return;
    }
    await _nowPlaying.update(
      NovelTtsNowPlayingInfo(
        title: session!.title,
        artist: session!.author,
        subtitle: subtitle,
        isPlaying: true,
        durationMs: (await _audio.duration)?.inMilliseconds ?? 0,
        positionMs: (await _audio.position)?.inMilliseconds ?? 0,
      ),
    );
  }

  @override
  void dispose() {
    _completionSub?.cancel();
    _nowPlayingTimer?.cancel();
    unawaited(_audio.dispose());
    super.dispose();
  }
}
