import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
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
    this.keepPlaying = false,
  });

  final NovelTtsNavigateKind kind;
  final int? page;
  final int? seriesNovelId;
  final bool fromEnd;
  final bool keepPlaying;
}

class NovelTtsClip {
  const NovelTtsClip({
    required this.page,
    required this.chunkIndex,
    required this.text,
  });

  final int page;
  final int chunkIndex;
  final String text;
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

class NovelTtsController extends ChangeNotifier with WidgetsBindingObserver {
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
      unawaited(_onQueueComplete());
    });
    _clipSub = _audio.onClipIndex.listen(_onQueuedClip);
    _nowPlaying.onRemote = _onRemote;
    _nowPlaying.bind();
    WidgetsBinding.instance.addObserver(this);
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
  StreamSubscription<int>? _clipSub;
  final Map<String, Future<Uint8List>> _inflight = {};
  final Set<int> _queuedClips = {};
  int _generation = 0;
  int _queueStartClip = 0;
  Timer? _nowPlayingTimer;

  NovelTtsStatus status = NovelTtsStatus.idle;
  String? errorMessage;
  NovelTtsSession? session;
  List<NovelTtsClip> clips = const [];
  int clipIndex = 0;
  int? pendingResumeNovelId;
  bool pendingResumeFromEnd = false;
  void Function(NovelTtsNavigate navigate)? onNavigate;

  int get chunkIndex {
    if (clips.isEmpty) {
      return 0;
    }
    return clips[clipIndex.clamp(0, clips.length - 1)].chunkIndex;
  }

  set chunkIndex(int value) {
    if (clips.isEmpty) {
      return;
    }
    final page = session?.page ?? 1;
    final index = clips.indexWhere(
      (clip) => clip.page == page && clip.chunkIndex == value,
    );
    if (index >= 0) {
      clipIndex = index;
    }
  }

  bool get isActive =>
      status == NovelTtsStatus.playing ||
      status == NovelTtsStatus.paused ||
      status == NovelTtsStatus.synthesizing;

  String get subtitle {
    if (clips.isEmpty) {
      return '';
    }
    return clips[clipIndex.clamp(0, clips.length - 1)].text;
  }

  NovelTtsSettings get settings => _settingsLoader();

  Future<void> start({
    required int novelId,
    required String title,
    required String author,
    required int page,
    required int totalPages,
    required String pageText,
    List<String>? pageTexts,
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
    final texts = pageTexts == null || pageTexts.isEmpty
        ? [pageText]
        : pageTexts;
    final built = _clipsFromPages(texts, loaded.clampedSplitChars);
    if (built.isEmpty) {
      status = NovelTtsStatus.error;
      errorMessage = 'empty';
      notifyListeners();
      return;
    }
    _generation++;
    pendingResumeNovelId = null;
    clips = built;
    session = NovelTtsSession(
      novelId: novelId,
      title: title,
      author: author,
      coverUrl: coverUrl,
      page: page,
      totalPages: texts.length,
      chunks: [
        for (final clip in built)
          if (clip.page == page) clip.text,
      ],
      prevSeriesId: prevSeriesId,
      nextSeriesId: nextSeriesId,
    );
    clipIndex = _indexOf(page: page, chunkIndex: startChunk);
    errorMessage = null;
    await _ensureAudioSession();
    await _playFrom(clipIndex);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!isActive) {
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      unawaited(_ensureAudioSession());
      unawaited(_publishNowPlaying());
      unawaited(_fillQueue());
    }
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
    final pageClips = [
      for (var i = 0; i < chunks.length; i++)
        NovelTtsClip(page: page, chunkIndex: i, text: chunks[i]),
    ];
    clips = [
      for (final clip in clips)
        if (clip.page < page) clip,
      ...pageClips,
      for (final clip in clips)
        if (clip.page > page) clip,
    ];
    if (clips.isEmpty) {
      clips = pageClips;
    }
    clipIndex = _indexOf(
      page: page,
      chunkIndex: fromEnd ? chunks.length - 1 : 0,
    );
    await _playFrom(clipIndex);
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
    clips = const [];
    clipIndex = 0;
    _queuedClips.clear();
    notifyListeners();
  }

  Future<void> skip({required String direction}) async {
    final current = session;
    if (current == null) {
      return;
    }
    if (direction == 'next' && await _audio.seekNext()) {
      final next = clipIndex + 1;
      if (next < clips.length && clipIndex < next) {
        _applyClip(next, keepPlaying: true);
        unawaited(_fillQueue());
        notifyListeners();
      }
      return;
    }
    if (direction == 'prev' && await _audio.seekPrevious()) {
      final previous = clipIndex - 1;
      if (previous >= 0 && clipIndex > previous) {
        _applyClip(previous, keepPlaying: true);
        notifyListeners();
      }
      return;
    }
    final nextIndex = clipIndex + (direction == 'prev' ? -1 : 1);
    if (nextIndex >= 0 && nextIndex < clips.length) {
      await _playFrom(nextIndex);
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
        await _playFrom(nextIndex.clamp(0, clips.length - 1));
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

  Future<void> _onQueueComplete() async {
    if (status == NovelTtsStatus.idle) {
      return;
    }
    if (clipIndex + 1 < clips.length) {
      await _playFrom(clipIndex + 1);
      return;
    }
    await skip(direction: 'next');
  }

  void _onQueuedClip(int queueIndex) {
    final next = _queueStartClip + queueIndex;
    if (next < 0 || next >= clips.length) {
      return;
    }
    _applyClip(next, keepPlaying: true);
    unawaited(_fillQueue());
    unawaited(_publishNowPlaying());
    notifyListeners();
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

  Future<void> _playFrom(int index) async {
    if (clips.isEmpty) {
      return;
    }
    final generation = ++_generation;
    _queuedClips.clear();
    _applyClip(index.clamp(0, clips.length - 1));
    status = NovelTtsStatus.synthesizing;
    errorMessage = null;
    notifyListeners();
    try {
      final first = await _fileForClip(clipIndex);
      if (generation != _generation) {
        return;
      }
      _queueStartClip = clipIndex;
      _queuedClips.add(clipIndex);
      await _audio.playFiles([first.path]);
      if (generation != _generation) {
        return;
      }
      status = NovelTtsStatus.playing;
      await _publishNowPlaying();
      notifyListeners();
      await _fillQueue();
    } catch (error) {
      if (generation != _generation) {
        return;
      }
      status = NovelTtsStatus.error;
      errorMessage = error.toString();
      notifyListeners();
    }
  }

  Future<void> _fillQueue() async {
    if (clips.isEmpty || !isActive) {
      return;
    }
    final ahead = settings.prefetchCount.clamp(2, 8);
    for (var i = 1; i <= ahead; i++) {
      final next = clipIndex + i;
      if (next >= clips.length || _queuedClips.contains(next)) {
        continue;
      }
      try {
        final file = await _fileForClip(next);
        if (!isActive || _queuedClips.contains(next)) {
          return;
        }
        _queuedClips.add(next);
        await _audio.enqueue(file.path);
      } catch (_) {
        return;
      }
    }
  }

  void _applyClip(int index, {bool keepPlaying = false}) {
    clipIndex = index;
    final clip = clips[index];
    final current = session;
    if (current == null) {
      return;
    }
    if (clip.page == current.page) {
      return;
    }
    session = current.copyWith(
      page: clip.page,
      chunks: [
        for (final item in clips)
          if (item.page == clip.page) item.text,
      ],
    );
    onNavigate?.call(
      NovelTtsNavigate(
        kind: NovelTtsNavigateKind.page,
        page: clip.page,
        keepPlaying: keepPlaying,
      ),
    );
  }

  List<NovelTtsClip> _clipsFromPages(List<String> pages, int splitChars) {
    final result = <NovelTtsClip>[];
    for (var page = 0; page < pages.length; page++) {
      final chunks = splitNovelTtsText(pages[page], maxChars: splitChars);
      for (var i = 0; i < chunks.length; i++) {
        result.add(
          NovelTtsClip(page: page + 1, chunkIndex: i, text: chunks[i]),
        );
      }
    }
    return result;
  }

  int _indexOf({required int page, required int chunkIndex}) {
    final exact = clips.indexWhere(
      (clip) => clip.page == page && clip.chunkIndex == chunkIndex,
    );
    if (exact >= 0) {
      return exact;
    }
    final firstOnPage = clips.indexWhere((clip) => clip.page == page);
    if (firstOnPage >= 0) {
      final pageClips = clips.where((clip) => clip.page == page).length;
      return firstOnPage + chunkIndex.clamp(0, pageClips - 1);
    }
    return 0;
  }

  Future<File> _fileForClip(int index) async {
    final text = clips[index].text;
    final bytes = await _audioBytes(text);
    return _writeCache(text, bytes);
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
    WidgetsBinding.instance.removeObserver(this);
    _completionSub?.cancel();
    _clipSub?.cancel();
    _nowPlayingTimer?.cancel();
    unawaited(_audio.dispose());
    super.dispose();
  }
}
