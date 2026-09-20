import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pixez/page/novel/tts/novel_tts_advance.dart';
import 'package:pixez/page/novel/tts/novel_tts_audio.dart';
import 'package:pixez/page/novel/tts/novel_tts_engine.dart';
import 'package:pixez/page/novel/tts/novel_tts_follow.dart';
import 'package:pixez/page/novel/tts/novel_tts_now_playing.dart';
import 'package:pixez/page/novel/tts/novel_tts_settings.dart';
import 'package:pixez/page/novel/tts/novel_tts_text.dart';
import 'package:pixez/page/novel/tts/pronunciation/matching/pronunciation_compiler.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_decision.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/resolved_pronunciation_text.dart';
import 'package:pixez/page/novel/tts/pronunciation/resolution/pronunciation_pipeline.dart';
import 'package:pixez/page/novel/tts/pronunciation/resolution/pronunciation_renderer.dart';
import 'package:pixez/page/novel/tts/pronunciation/resolution/source_aware_splitter.dart';
import 'package:pixez/page/novel/tts/pronunciation/storage/pronunciation_repository.dart';

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
    required this.novelId,
    required this.page,
    required this.chunkIndex,
    required this.text,
    String? spokenText,
    this.sourceStart = 0,
    this.sourceEnd = 0,
    this.pronunciationFingerprint = '',
  }) : spokenText = spokenText ?? text;

  final int novelId;
  final int page;
  final int chunkIndex;
  final String text;
  final String spokenText;
  final int sourceStart;
  final int sourceEnd;
  final String pronunciationFingerprint;

  String get spokenTextHash =>
      sha1.convert(utf8.encode(spokenText)).toString();
}

class NovelTtsChapter {
  const NovelTtsChapter({
    required this.novelId,
    required this.title,
    required this.author,
    required this.pageTexts,
    this.coverUrl,
    this.prevSeriesId,
    this.nextSeriesId,
  });

  final int novelId;
  final String title;
  final String author;
  final String? coverUrl;
  final List<String> pageTexts;
  final int? prevSeriesId;
  final int? nextSeriesId;
}

class NovelTtsBookmark {
  const NovelTtsBookmark({
    required this.novelId,
    required this.page,
    required this.chunkIndex,
  });

  final int novelId;
  final int page;
  final int chunkIndex;
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
    PronunciationRepository? pronunciationRepository,
    PronunciationPipeline? pronunciationPipeline,
    SourceAwareNovelTtsSplitter? splitter,
  }) : _synthesizer = synthesizer ?? NovelTtsHttpSynthesizer(),
       _audio = audio ?? JustAudioNovelTtsPlayer(),
       _nowPlaying = nowPlaying ?? NovelTtsNowPlaying(),
       _settingsLoader = settingsLoader ?? NovelTtsSettings.load,
       _cacheDir = cacheDir,
       _pronunciationRepository =
           pronunciationRepository ?? PronunciationRepository(),
       _pronunciationPipeline = pronunciationPipeline ?? PronunciationPipeline(),
       _splitter = splitter ?? const SourceAwareNovelTtsSplitter(),
       _renderer = const PronunciationRenderer() {
    _audio.listen();
    _completionSub = _audio.onComplete.listen((_) {
      unawaited(_onQueueComplete());
    });
    _clipSub = _audio.onClipIndex.listen(_onQueuedClip);
    final events = _audio;
    if (events is NovelTtsAudioEvents) {
      final audioEvents = events as NovelTtsAudioEvents;
      _playingSub = audioEvents.onPlaying.listen(_onPlatformPlaying);
      _errorSub = audioEvents.onError.listen(_onAudioError);
    }
    _nowPlaying.onRemote = _onRemote;
    _nowPlaying.bind();
    WidgetsBinding.instance.addObserver(this);
  }

  static NovelTtsController? _instance;

  static NovelTtsController? get maybeInstance => _instance;

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
  final PronunciationRepository _pronunciationRepository;
  final PronunciationPipeline _pronunciationPipeline;
  final SourceAwareNovelTtsSplitter _splitter;
  final PronunciationRenderer _renderer;
  PronunciationSnapshot? _sessionSnapshot;
  final Map<String, List<PronunciationDecision>> _pageDecisions = {};

  StreamSubscription<void>? _completionSub;
  StreamSubscription<int>? _clipSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Object>? _errorSub;
  final Map<String, Future<File>> _inflight = {};
  final Set<String> _protectedCachePaths = {};
  NovelTtsSettings? _playbackSettings;
  int _sessionGeneration = 0;
  final Map<int, NovelTtsChapter> _chapters = {};
  final Map<int, List<NovelTtsTextDocument>> _chapterDocuments = {};
  String? _seriesId;
  final Set<int> _queuedClips = {};
  final Set<int> _loadedSeriesIds = {};
  int _generation = 0;
  int _queueStartClip = 0;
  int _clipBase = 0;
  int? _prefetchingSeriesId;
  var _fillingQueue = false;
  var _fillAgain = false;
  var _holdAfterReady = false;
  var _userPaused = false;
  var _audioReady = false;
  var _advanceDepth = 0;
  var _cacheWrite = 0;
  var _disposed = false;
  int? _pendingCompletion;
  Future<void> _nowPlayingWrite = Future<void>.value();
  var _backgroundWork = 0;
  Future<void>? _cacheCleanup;

  NovelTtsStatus status = NovelTtsStatus.idle;
  String? errorMessage;
  NovelTtsSession? session;
  List<NovelTtsClip> clips = const [];
  int clipIndex = 0;
  NovelTtsBookmark? bookmark;
  int? pendingResumeNovelId;
  bool pendingResumeFromEnd = false;
  void Function(NovelTtsNavigate navigate)? onNavigate;
  Future<NovelTtsChapter?> Function(int novelId)? onLoadChapter;

  NovelTtsClip? get currentClip {
    if (clips.isEmpty) {
      return null;
    }
    return clips[clipIndex.clamp(0, clips.length - 1)];
  }

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
      !_disposed && (status == NovelTtsStatus.playing ||
      status == NovelTtsStatus.paused ||
      status == NovelTtsStatus.synthesizing);

  String get subtitle {
    if (clips.isEmpty) {
      return '';
    }
    return clips[clipIndex.clamp(0, clips.length - 1)].text;
  }

  NovelTtsSettings get settings => _settingsLoader();

  bool _isSession(int generation) =>
      !_disposed && generation == _sessionGeneration;

  bool _isPlayback(int generation) =>
      !_disposed && generation == _generation;

  void _cancelSynthesis() {
    final synth = _synthesizer;
    if (synth is NovelTtsCancellableSynthesizer) {
      (synth as NovelTtsCancellableSynthesizer).cancelPending();
    }
    _inflight.clear();
  }

  void _invalidateSession() {
    _sessionGeneration++;
    _generation++;
    _pronunciationPipeline.worker.sessionGeneration = _sessionGeneration;
    _pendingCompletion = null;
    _backgroundWork = 0;
    _cancelSynthesis();
  }

  /// Apply a saved voice/endpoint without leaving old audio in the queue.
  Future<void> applySettings() async {
    if (!isActive || clips.isEmpty) return;
    final loaded = settings;
    if (!loaded.isConfigured) {
      await stop();
      if (_disposed) return;
      status = NovelTtsStatus.error;
      errorMessage = 'not_configured';
      notifyListeners();
      return;
    }
    final paused = status == NovelTtsStatus.paused;
    final previous = _playbackSettings;
    final current = currentClip;
    final chapter = current == null ? null : _chapters[current.novelId];
    if (previous != null && current != null && chapter != null &&
        (previous.splitChars != loaded.splitChars ||
         jsonEncode(previous.readings.map((item) => item.toJson()).toList()) !=
             jsonEncode(loaded.readings.map((item) => item.toJson()).toList()))) {
      final restarting = start(
        novelId: chapter.novelId,
        title: chapter.title,
        author: chapter.author,
        page: current.page,
        totalPages: chapter.pageTexts.length,
        pageText: chapter.pageTexts[current.page - 1],
        pageTexts: chapter.pageTexts,
        pageDocuments: _chapterDocuments[chapter.novelId],
        coverUrl: chapter.coverUrl,
        prevSeriesId: chapter.prevSeriesId,
        nextSeriesId: chapter.nextSeriesId,
        seriesId: _seriesId,
        startOffset: current.sourceStart,
      );
      if (paused) await pause();
      await restarting;
      return;
    }
    _playbackSettings = loaded;
    _cancelSynthesis();
    _userPaused = paused;
    _holdAfterReady = paused;
    await _playFrom(clipIndex);
  }

  Future<void> start({
    required int novelId,
    required String title,
    required String author,
    required int page,
    required int totalPages,
    required String pageText,
    List<String>? pageTexts,
    List<NovelTtsTextDocument>? pageDocuments,
    String? coverUrl,
    int? prevSeriesId,
    int? nextSeriesId,
    String? seriesId,
    int? startChunk,
    String? startNeedle,
    int? startOffset,
  }) async {
    if (_disposed) return;
    final loaded = settings;
    _rememberBookmark();
    _invalidateSession();
    final generation = _sessionGeneration;
    _playbackSettings = loaded;
    _seriesId = seriesId;
    _pageDecisions.clear();
    _sessionSnapshot = null;
    _chapters.clear();
    _chapterDocuments.clear();
    _loadedSeriesIds.clear();
    _queuedClips.clear();
    _protectedCachePaths.clear();
    _prefetchingSeriesId = null;
    _audioReady = false;
    _holdAfterReady = false;
    _userPaused = false;
    session = null;
    clips = const [];
    _clipBase = 0;
    status = NovelTtsStatus.synthesizing;
    errorMessage = null;
    notifyListeners();
    await _audio.stop();
    if (!_isSession(generation)) return;
    await _nowPlaying.keepAlive(false);
    if (!_isSession(generation)) return;
    await _nowPlaying.stop();
    if (!_isSession(generation)) return;
    if (!loaded.isConfigured) {
      status = NovelTtsStatus.error;
      errorMessage = 'not_configured';
      notifyListeners();
      return;
    }
    final texts = pageTexts == null || pageTexts.isEmpty
        ? [pageText]
        : pageTexts;
    final documents = pageDocuments == null || pageDocuments.isEmpty
        ? [for (final text in texts) novelTtsDocumentFromText(text)]
        : pageDocuments;
    List<NovelTtsClip> built;
    try {
      final snapshot = await _pronunciationRepository.snapshotFor(
        workId: '$novelId',
        seriesId: seriesId,
        settingsReadings: loaded.readings,
      );
      if (!_isSession(generation)) return;
      _sessionSnapshot = snapshot;
      built = await _clipsFromDocuments(
        documents,
        loaded.clampedSplitChars,
        novelId: novelId,
      );
    } catch (_) {
      built = const [];
    }
    if (!_isSession(generation)) return;
    if (built.isEmpty) {
      status = NovelTtsStatus.error;
      errorMessage = 'empty';
      notifyListeners();
      return;
    }
    pendingResumeNovelId = null;
    _chapters
      ..clear()
      ..[novelId] = NovelTtsChapter(
        novelId: novelId,
        title: title,
        author: author,
        pageTexts: texts,
        coverUrl: coverUrl,
        prevSeriesId: prevSeriesId,
        nextSeriesId: nextSeriesId,
      );
    _loadedSeriesIds
      ..clear()
      ..add(novelId);
    _prefetchingSeriesId = null;
    _chapterDocuments[novelId] = documents;
    clips = built;
    status = NovelTtsStatus.synthesizing;
    errorMessage = null;
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
    clipIndex = _indexForStart(
      page: page,
      novelId: novelId,
      startChunk: startChunk,
      startNeedle: startNeedle,
      startOffset: startOffset,
      pageDisplayText: documents[page.clamp(1, documents.length) - 1].displayText,
    );
    session = session!.copyWith(
      chunks: [
        for (final clip in clips)
          if (clip.page == page) clip.text,
      ],
    );
    errorMessage = null;
    _audioReady = false;
    await _ensureAudioSession();
    if (!_isSession(generation)) return;
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
      unawaited(_publishNowPlaying());
    }
  }

  Future<void> _ensureAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
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
    final generation = _sessionGeneration;
    List<NovelTtsClip> pageClips;
    try {
      pageClips = await _clipsFromDocuments(
        [novelTtsDocumentFromText(pageText)],
        settings.clampedSplitChars,
        novelId: current.novelId,
        pageOffset: page,
      );
    } catch (_) {
      pageClips = const [];
    }
    if (!_isSession(generation)) return;
    if (pageClips.isEmpty) {
      await skip(direction: fromEnd ? 'prev' : 'next');
      return;
    }
    session = current.copyWith(
      page: page,
      totalPages: totalPages,
      chunks: [for (final clip in pageClips) clip.text],
      prevSeriesId: prevSeriesId,
      nextSeriesId: nextSeriesId,
    );
    final firstCurrent = clips.indexWhere((clip) => clip.novelId == current.novelId);
    final lastCurrent = clips.lastIndexWhere((clip) => clip.novelId == current.novelId);
    if (firstCurrent < 0) return;
    final chapterClips = clips.sublist(firstCurrent, lastCurrent + 1);
    clips = [
      ...clips.take(firstCurrent),
      for (final clip in chapterClips)
        if (clip.page < page) clip,
      ...pageClips,
      for (final clip in chapterClips)
        if (clip.page > page) clip,
      ...clips.skip(lastCurrent + 1),
    ];
    final chapter = _chapters[current.novelId];
    if (chapter != null) {
      final texts = List<String>.generate(
        totalPages,
        (index) => index < chapter.pageTexts.length ? chapter.pageTexts[index] : '',
      );
      if (page > 0 && page <= texts.length) texts[page - 1] = pageText;
      _chapters[current.novelId] = NovelTtsChapter(
        novelId: chapter.novelId,
        title: chapter.title,
        author: chapter.author,
        pageTexts: texts,
        coverUrl: chapter.coverUrl,
        prevSeriesId: prevSeriesId ?? chapter.prevSeriesId,
        nextSeriesId: nextSeriesId ?? chapter.nextSeriesId,
      );
      final oldDocuments = _chapterDocuments[current.novelId] ?? const [];
      _chapterDocuments[current.novelId] = [
        for (var index = 0; index < texts.length; index++)
          if (index != page - 1 && index < oldDocuments.length)
            oldDocuments[index]
          else
            novelTtsDocumentFromText(texts[index]),
      ];
    }
    clipIndex = _indexOf(
      page: page,
      chunkIndex: fromEnd ? pageClips.length - 1 : 0,
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
    if (status == NovelTtsStatus.playing ||
        status == NovelTtsStatus.synthesizing) {
      await pause();
      return;
    }
    if (status == NovelTtsStatus.paused) {
      await resume();
    }
  }

  Future<void> pause() async {
    if (status != NovelTtsStatus.playing &&
        status != NovelTtsStatus.synthesizing) return;
    final generation = _generation;
    _userPaused = true;
    _holdAfterReady = true;
    status = NovelTtsStatus.paused;
    _rememberBookmark();
    notifyListeners();
    await _nowPlaying.keepAlive(false);
    if (!_isPlayback(generation)) return;
    await _audio.pause();
    if (!_isPlayback(generation)) return;
    await _publishNowPlaying();
  }

  Future<void> resume() async {
    if (_disposed || status != NovelTtsStatus.paused) return;
    final generation = _generation;
    _userPaused = false;
    _holdAfterReady = false;
    if (!_audioReady) {
      status = NovelTtsStatus.synthesizing;
      await _nowPlaying.keepAlive(true);
    } else {
      await _audio.resume();
      if (!_isPlayback(generation)) return;
      status = NovelTtsStatus.playing;
    }
    if (!_isPlayback(generation)) return;
    await _publishNowPlaying();
    notifyListeners();
  }

  Future<void> stop() async {
    if (_disposed) return;
    _rememberBookmark();
    _invalidateSession();
    final generation = _sessionGeneration;
    pendingResumeNovelId = null;
    _prefetchingSeriesId = null;
    _holdAfterReady = false;
    _userPaused = false;
    _audioReady = false;
    _chapters.clear();
    _chapterDocuments.clear();
    _loadedSeriesIds.clear();
    _pageDecisions.clear();
    _sessionSnapshot = null;
    _playbackSettings = null;
    status = NovelTtsStatus.idle;
    errorMessage = null;
    session = null;
    clips = const [];
    _clipBase = 0;
    clipIndex = 0;
    _queuedClips.clear();
    _protectedCachePaths.clear();
    notifyListeners();
    await _audio.stop();
    if (!_isSession(generation)) return;
    await _nowPlaying.keepAlive(false);
    if (!_isSession(generation)) return;
    await _nowPlaying.endBackgroundTask();
    if (!_isSession(generation)) return;
    await _nowPlaying.stop();
  }

  Future<void> skip({required String direction}) async {
    final current = session;
    if (current == null) {
      return;
    }
    final generation = _generation;
    final previousIndex = clipIndex + _clipBase;
    _userPaused = false;
    _holdAfterReady = false;
    if (direction == 'next' && await _audio.seekNext()) {
      if (!_isPlayback(generation)) return;
      final next = previousIndex + 1 - _clipBase;
      if (next < clips.length && clipIndex < next) {
        _applyClip(next, keepPlaying: true);
        unawaited(_fillQueue());
        notifyListeners();
      }
      return;
    }
    if (!_isPlayback(generation)) return;
    if (direction == 'prev' && await _audio.seekPrevious()) {
      if (!_isPlayback(generation)) return;
      final previous = previousIndex - 1 - _clipBase;
      if (previous >= 0 && clipIndex > previous) {
        _applyClip(previous, keepPlaying: true);
        notifyListeners();
      }
      return;
    }
    if (!_isPlayback(generation)) return;
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
        // `clamp` throws when the upper bound falls below the lower one, and
        // the argument is evaluated before `_playFrom` can turn an empty clip
        // list away. `session.chunks` outliving `clips` is enough to get here.
        if (clips.isEmpty) {
          return;
        }
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
    if (!isActive || status == NovelTtsStatus.paused || _userPaused) {
      return;
    }
    if (_advanceDepth > 0) {
      // A clip ran out while an advance was still in flight. Dropping the
      // event is what parked readers on the opening clip of a chapter: that
      // clip is usually a short title line, so it ends while `_playFrom` is
      // still publishing now-playing state, and nothing ever moved on.
      //
      // Only a clip that had actually started counts. Before `_audioReady` the
      // advance in flight has not replaced the player yet, so the event
      // belongs to the clip being navigated away from and replaying it would
      // skip the clip we are on our way to.
      if (_audioReady) {
        _pendingCompletion = _generation;
      }
      return;
    }
    _advanceDepth++;
    try {
      if (clipIndex + 1 < clips.length) {
        await _playFrom(clipIndex + 1, reusePrefetch: true);
      } else {
        final generation = _sessionGeneration;
        await _maybePrefetchSeries();
        if (!_isSession(generation)) return;
        if (clipIndex + 1 < clips.length) {
          await _playFrom(clipIndex + 1, reusePrefetch: true);
        } else {
          await skip(direction: 'next');
        }
      }
    } finally {
      _advanceDepth--;
    }
    await _drainPendingCompletion();
  }

  /// Replays a clip-finished event that arrived while an advance was running.
  Future<void> _drainPendingCompletion() async {
    if (_advanceDepth > 0) return;
    final pending = _pendingCompletion;
    _pendingCompletion = null;
    if (pending == null || pending != _generation) {
      return;
    }
    await _onQueueComplete();
  }

  void _onQueuedClip(int queueIndex) {
    if (!_audioReady || !isActive) return;
    final next = _queueStartClip + queueIndex - _clipBase;
    if (next < 0 || next >= clips.length) {
      return;
    }
    _applyClip(next, keepPlaying: true);
    _queuedClips.removeWhere((index) => index < clipIndex - 1);
    final loaded = _playbackSettings ?? settings;
    final queuedNames = {
      for (final index in _queuedClips)
        '${_cacheKey(clips[index].spokenText, loaded)}.mp3',
    };
    _protectedCachePaths.removeWhere((path) => !queuedNames.contains(p.basename(path)));
    unawaited(_fillQueue());
    unawaited(_publishNowPlaying());
    notifyListeners();
  }

  void _onPlatformPlaying(bool playing) {
    if (!_audioReady || !isActive) return;
    if (!playing && status == NovelTtsStatus.playing) {
      // Do not call pause() here: just_audio preserves whether a phone-call
      // interruption should resume. A user pause separately sets _userPaused.
      status = NovelTtsStatus.paused;
      unawaited(_nowPlaying.keepAlive(false));
    } else if (playing && status == NovelTtsStatus.paused && !_userPaused) {
      status = NovelTtsStatus.playing;
    } else {
      return;
    }
    unawaited(_publishNowPlaying());
    notifyListeners();
  }

  void _onAudioError(Object error) {
    if (_disposed || !isActive) return;
    final generation = ++_generation;
    _audioReady = false;
    _pendingCompletion = null;
    _cancelSynthesis();
    status = NovelTtsStatus.error;
    errorMessage = error.toString();
    notifyListeners();
    unawaited(() async {
      await _audio.stop();
      if (!_isPlayback(generation)) return;
      await _nowPlaying.keepAlive(false);
      if (!_isPlayback(generation)) return;
      await _nowPlaying.stop();
    }());
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

  Future<void> _playFrom(int index, {bool reusePrefetch = false}) async {
    if (_disposed || clips.isEmpty) {
      return;
    }
    _advanceDepth++;
    if (!reusePrefetch) _cancelSynthesis();
    final generation = ++_generation;
    _queuedClips.clear();
    _protectedCachePaths.clear();
    // The player still holds the clip we are leaving. Until `playFiles` lands,
    // a clip-finished event belongs to that clip, not to this one.
    _audioReady = false;
    _applyClip(index.clamp(0, clips.length - 1));
    status = NovelTtsStatus.synthesizing;
    errorMessage = null;
    notifyListeners();
    var playing = false;
    try {
      await _audio.stop();
      if (!_isPlayback(generation)) return;
      if (_userPaused) {
        await _audio.pause();
      } else {
        await _nowPlaying.keepAlive(true);
      }
      if (!_isPlayback(generation)) return;
      final first = await _fileForClip(clipIndex);
      if (!_isPlayback(generation)) {
        return;
      }
      _queueStartClip = clipIndex + _clipBase;
      _queuedClips.add(clipIndex);
      await _audio.playFiles([first.path]);
      if (!_isPlayback(generation)) {
        return;
      }
      _audioReady = true;
      await _nowPlaying.keepAlive(false);
      if (!_isPlayback(generation)) return;
      if (_userPaused || _holdAfterReady) {
        await _audio.pause();
        if (!_isPlayback(generation)) return;
        _holdAfterReady = false;
        status = NovelTtsStatus.paused;
      } else {
        status = NovelTtsStatus.playing;
      }
      await _publishNowPlaying();
      notifyListeners();
      playing = true;
    } catch (error) {
      if (!_isPlayback(generation)) {
        return;
      }
      _audioReady = false;
      await _nowPlaying.keepAlive(false);
      if (!_isPlayback(generation)) return;
      status = NovelTtsStatus.error;
      errorMessage = error.toString();
      notifyListeners();
      await _nowPlaying.stop();
    } finally {
      _advanceDepth--;
    }
    // Filling the queue is one network round trip per clip ahead. Holding the
    // advance guard across it makes `_onQueueComplete` a no-op for that whole
    // window, and the clip that opens a chapter is usually a title line short
    // enough to run out inside it -- the reader then sits on clip one forever.
    if (!playing) {
      return;
    }
    await _drainPendingCompletion();
    if (!_isPlayback(generation)) {
      return;
    }
    await _fillQueue();
  }

  Future<void> _fillQueue() async {
    if (_fillingQueue) {
      _fillAgain = true;
      return;
    }
    _fillingQueue = true;
    try {
      do {
        _fillAgain = false;
        await _enqueueAhead();
        if (await _maybePrefetchSeries()) {
          await _enqueueAhead();
        }
      } while (_fillAgain && isActive);
    } finally {
      _fillingQueue = false;
    }
  }

  Future<void> _enqueueAhead() async {
    if (clips.isEmpty || !isActive) {
      return;
    }
    // The fill now runs alongside a possible advance, so every clip it lines up
    // belongs to the playlist that was current when it started. Appending them
    // to a playlist a newer `_playFrom` has since installed would read the
    // wrong part of the chapter.
    final generation = _generation;
    final ahead = settings.prefetchCount.clamp(1, 4);
    final needed = <int>[];
    for (var i = 1; i <= ahead; i++) {
      final next = clipIndex + i;
      if (next >= clips.length) {
        break;
      }
      if (!_queuedClips.contains(next)) {
        needed.add(next + _clipBase);
      }
    }
    if (needed.isEmpty) {
      return;
    }
    for (final index in needed) {
      if (!isActive || !_isPlayback(generation)) return;
      final localIndex = index - _clipBase;
      if (localIndex < 0 || localIndex >= clips.length) continue;
      final file = await _tryFileForClip(localIndex);
      if (file == null || !isActive || !_isPlayback(generation)) return;
      if (_queuedClips.contains(index - _clipBase)) continue;
      try {
        await _audio.enqueue(file.path);
      } catch (_) {
        // Playback can still request this clip if speculative enqueue fails.
        return;
      }
      if (!_isPlayback(generation)) return;
      _queuedClips.add(index - _clipBase);
    }
  }

  Future<bool> _maybePrefetchSeries() async {
    if (!settings.autoContinue || !isActive) {
      return false;
    }
    final ahead = settings.prefetchCount.clamp(1, 4);
    if (clips.isEmpty || clips.length - clipIndex > ahead) {
      return false;
    }
    final last = clips.last;
    final chapter = _chapters[last.novelId];
    final nextId = chapter?.nextSeriesId ?? session?.nextSeriesId;
    if (nextId == null ||
        _loadedSeriesIds.contains(nextId) ||
        _prefetchingSeriesId == nextId) {
      return false;
    }
    final loader = onLoadChapter;
    if (loader == null) {
      return false;
    }
    final generation = _sessionGeneration;
    _prefetchingSeriesId = nextId;
    await _beginBackgroundWork(generation);
    try {
      final loaded = await loader(nextId);
      if (loaded == null || !isActive || !_isSession(generation)) {
        return false;
      }
      final documents = [
        for (final text in loaded.pageTexts) novelTtsDocumentFromText(text),
      ];
      final extra = await _clipsFromDocuments(
        documents,
        settings.clampedSplitChars,
        novelId: loaded.novelId,
      );
      if (extra.isEmpty || !_isSession(generation)) {
        return false;
      }
      _chapters[loaded.novelId] = loaded;
      _chapterDocuments[loaded.novelId] = documents;
      _loadedSeriesIds.add(loaded.novelId);
      clips = [...clips, ...extra];
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    } finally {
      if (_isSession(generation) && _prefetchingSeriesId == nextId) {
        _prefetchingSeriesId = null;
      }
      await _endBackgroundWork(generation);
    }
  }

  void _rememberBookmark() {
    if (session == null || clips.isEmpty) {
      return;
    }
    final clip = clips[clipIndex.clamp(0, clips.length - 1)];
    bookmark = NovelTtsBookmark(
      novelId: clip.novelId,
      page: clip.page,
      chunkIndex: clip.chunkIndex,
    );
  }

  int? _bookmarkChunk({required int novelId, required int page}) {
    final mark = bookmark;
    if (mark != null && mark.novelId == novelId && mark.page == page) {
      return mark.chunkIndex;
    }
    return null;
  }

  void _applyClip(int index, {bool keepPlaying = false}) {
    clipIndex = index;
    _rememberBookmark();
    final clip = clips[index];
    final current = session;
    if (current == null) {
      return;
    }
    if (clip.novelId != current.novelId) {
      final chapter = _chapters[clip.novelId];
      session = NovelTtsSession(
        novelId: clip.novelId,
        title: chapter?.title ?? current.title,
        author: chapter?.author ?? current.author,
        coverUrl: chapter?.coverUrl ?? current.coverUrl,
        page: clip.page,
        totalPages: chapter?.pageTexts.length ?? current.totalPages,
        chunks: [
          for (final item in clips)
            if (item.novelId == clip.novelId && item.page == clip.page)
              item.text,
        ],
        prevSeriesId: chapter?.prevSeriesId,
        nextSeriesId: chapter?.nextSeriesId,
      );
      _trimPastChapters();
      onNavigate?.call(
        NovelTtsNavigate(
          kind: NovelTtsNavigateKind.series,
          seriesNovelId: clip.novelId,
          page: clip.page,
          keepPlaying: keepPlaying,
        ),
      );
      return;
    }
    if (clip.page == current.page) {
      return;
    }
    session = current.copyWith(
      page: clip.page,
      chunks: [
        for (final item in clips)
          if (item.novelId == clip.novelId && item.page == clip.page) item.text,
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

  void _trimPastChapters() {
    // Retain the previous chapter for back navigation, the current chapter,
    // and any prefetched chapter. Absolute queue positions survive the trim.
    var firstCurrent = clipIndex;
    final currentId = clips[clipIndex].novelId;
    while (firstCurrent > 0 && clips[firstCurrent - 1].novelId == currentId) {
      firstCurrent--;
    }
    if (firstCurrent == 0) return;
    final previousId = clips[firstCurrent - 1].novelId;
    var remove = firstCurrent - 1;
    while (remove > 0 && clips[remove - 1].novelId == previousId) {
      remove--;
    }
    if (remove == 0) return;
    clips = clips.sublist(remove);
    clipIndex -= remove;
    _clipBase += remove;
    final queued = [for (final index in _queuedClips) index - remove];
    _queuedClips
      ..clear()
      ..addAll(queued.where((index) => index >= 0));
    final retained = {for (final clip in clips) clip.novelId};
    _chapters.removeWhere((id, _) => !retained.contains(id));
    _chapterDocuments.removeWhere((id, _) => !retained.contains(id));
    _pageDecisions.removeWhere(
      (key, _) => !retained.contains(int.tryParse(key.split(':').first)),
    );
  }

  Future<List<NovelTtsClip>> _clipsFromDocuments(
    List<NovelTtsTextDocument> pages,
    int splitChars, {
    int? novelId,
    int pageOffset = 1,
  }) async {
    final id = novelId ?? session?.novelId ?? 0;
    final snapshot = _sessionSnapshot;
    final generation = _sessionGeneration;
    final result = <NovelTtsClip>[];
    for (var page = 0; page < pages.length; page++) {
      if (!_isSession(generation)) return const [];
      final document = pages[page];
      if (document.displayText.trim().isEmpty) {
        continue;
      }
      final resolved = snapshot == null
          ? null
          : await _pronunciationPipeline.resolve(
              document: document,
              snapshot: snapshot,
              sessionId: '$id:${page + pageOffset}',
              generation: generation,
            );
      if (!_isSession(generation)) return const [];
      if (snapshot != null &&
          resolved != null &&
          resolved.snapshotFingerprint != snapshot.fingerprint) {
        continue;
      }
      final applied = resolved?.appliedDecisions ?? const [];
      _pageDecisions['$id:${page + pageOffset}'] = applied;
      final ranges = _splitter.split(
        displayText: document.displayText,
        appliedDecisions: applied,
        budget: RuneTtsTextBudget(splitChars),
      );
      for (var i = 0; i < ranges.length; i++) {
        final range = ranges[i];
        final display = document.displayText.substring(range.start, range.end);
        final spoken = resolved == null
            ? display
            : _renderer.renderRange(
                source: document.displayText,
                range: range,
                decisions: applied,
              );
        result.add(
          NovelTtsClip(
            novelId: id,
            page: page + pageOffset,
            chunkIndex: i,
            text: display,
            spokenText: spoken,
            sourceStart: range.start,
            sourceEnd: range.end,
            pronunciationFingerprint: snapshot?.fingerprint ?? '',
          ),
        );
      }
    }
    return result;
  }

  int _indexForStart({
    required int page,
    required int novelId,
    int? startChunk,
    String? startNeedle,
    int? startOffset,
    String? pageDisplayText,
  }) {
    var offset = startOffset;
    if ((offset == null || offset < 0) &&
        startNeedle != null &&
        startNeedle.trim().isNotEmpty &&
        pageDisplayText != null &&
        pageDisplayText.isNotEmpty) {
      offset = novelTtsAlignFlexible(pageDisplayText, startNeedle)?.start;
    }
    if (offset != null && offset >= 0) {
      var cut = offset;
      if (pageDisplayText != null && cut < pageDisplayText.length) {
        while (cut < pageDisplayText.length &&
            _isSpeakableSpace(pageDisplayText[cut])) {
          cut++;
        }
      }
      final index = _clipIndexContaining(page: page, sourceOffset: cut);
      if (index >= 0) {
        _trimClipToSourceOffset(
          clipIndex: index,
          sourceOffset: cut,
          pageDisplayText: pageDisplayText,
        );
        return index;
      }
    }
    if (startNeedle != null && startNeedle.trim().isNotEmpty) {
      final pageTexts = [
        for (final clip in clips)
          if (clip.page == page) clip.text,
      ];
      final local = novelTtsIndexOfNeedle(pageTexts, startNeedle);
      if (local >= 0) {
        var seen = 0;
        for (var i = 0; i < clips.length; i++) {
          if (clips[i].page != page) {
            continue;
          }
          if (seen == local) {
            return i;
          }
          seen++;
        }
      }
    }
    return _indexOf(
      page: page,
      chunkIndex: startChunk ??
          _bookmarkChunk(novelId: novelId, page: page) ??
          0,
    );
  }

  int _clipIndexContaining({required int page, required int sourceOffset}) {
    var fallback = -1;
    for (var i = 0; i < clips.length; i++) {
      final clip = clips[i];
      if (clip.page != page) {
        continue;
      }
      fallback = fallback < 0 ? i : fallback;
      if (sourceOffset >= clip.sourceStart && sourceOffset < clip.sourceEnd) {
        return i;
      }
    }
    return fallback;
  }

  void _trimClipToSourceOffset({
    required int clipIndex,
    required int sourceOffset,
    String? pageDisplayText,
  }) {
    if (clipIndex < 0 || clipIndex >= clips.length) {
      return;
    }
    final clip = clips[clipIndex];
    var cut = sourceOffset;
    if (pageDisplayText != null) {
      while (cut < clip.sourceEnd &&
          cut < pageDisplayText.length &&
          _isSpeakableSpace(pageDisplayText[cut])) {
        cut++;
      }
    }
    if (cut <= clip.sourceStart || cut >= clip.sourceEnd) {
      return;
    }
    final local = (cut - clip.sourceStart).clamp(0, clip.text.length);
    final text = clip.text.substring(local);
    final spoken = pageDisplayText == null
        ? clip.spokenText.substring(
            local.clamp(0, clip.spokenText.length),
          )
        : _renderer.renderRange(
            source: pageDisplayText,
            range: NovelTtsSourceRange(cut, clip.sourceEnd),
            decisions: _pageDecisions['${clip.novelId}:${clip.page}'] ?? const [],
          );
    final next = [...clips];
    next[clipIndex] = NovelTtsClip(
      novelId: clip.novelId,
      page: clip.page,
      chunkIndex: clip.chunkIndex,
      text: text,
      spokenText: spoken,
      sourceStart: cut,
      sourceEnd: clip.sourceEnd,
      pronunciationFingerprint: clip.pronunciationFingerprint,
    );
    clips = next;
  }

  bool _isSpeakableSpace(String char) {
    return char == ' ' ||
        char == '\n' ||
        char == '\r' ||
        char == '\t' ||
        char == '　';
  }

  int _indexOf({required int page, required int chunkIndex}) {
    bool matchesPage(NovelTtsClip clip) =>
        clip.novelId == session?.novelId && clip.page == page;
    final exact = clips.indexWhere(
      (clip) => matchesPage(clip) && clip.chunkIndex == chunkIndex,
    );
    if (exact >= 0) return exact;
    final firstOnPage = clips.indexWhere(matchesPage);
    if (firstOnPage >= 0) {
      final pageClips = clips.where(matchesPage).length;
      return firstOnPage + chunkIndex.clamp(0, pageClips - 1);
    }
    return 0;
  }

  Future<File?> _tryFileForClip(int index) async {
    try {
      return await _fileForClip(index);
    } catch (_) {
      return null;
    }
  }

  Future<File> _fileForClip(int index) {
    final clip = clips[index];
    // Freeze the complete request before any I/O. Settings can change while a
    // response is in flight; that response must keep its original cache key.
    final loaded = _playbackSettings ?? settings;
    final key = _cacheKey(clip.spokenText, loaded);
    final pending = _inflight[key];
    if (pending != null) return pending;
    final generation = _sessionGeneration;
    final started = _loadClipFile(clip.spokenText, loaded, key, generation);
    _inflight[key] = started;
    started.whenComplete(() {
      if (identical(_inflight[key], started)) _inflight.remove(key);
    }).ignore();
    return started;
  }

  Future<File> _loadClipFile(
    String text,
    NovelTtsSettings loaded,
    String key,
    int generation,
  ) async {
    final file = await _cacheFile(key);
    if (!_isSession(generation)) {
      throw const NovelTtsSynthException('TTS request cancelled');
    }
    _protectedCachePaths.add(file.path);
    if (await file.exists() && await file.length() > 0) return file;
    await _beginBackgroundWork(generation);
    try {
      if (!_isSession(generation)) {
        throw const NovelTtsSynthException('TTS request cancelled');
      }
      final bytes = await _synthesizer.synthesize(loaded, text);
      if (!_isSession(generation)) {
        throw const NovelTtsSynthException('TTS request cancelled');
      }
      final temp = File('${file.path}.${_cacheWrite++}.part');
      try {
        await temp.writeAsBytes(bytes);
        await temp.rename(file.path);
      } finally {
        if (await temp.exists()) await temp.delete();
      }
      if (_cacheWrite == 1 || _cacheWrite % 32 == 0) {
        _scheduleCacheCleanup(file.parent);
      }
      return file;
    } finally {
      await _endBackgroundWork(generation);
    }
  }

  /// Only outstanding file loads are retained, never completed audio bytes.
  int get inflightAudioCount => _inflight.length;

  Future<void> _beginBackgroundWork(int generation) async {
    if (!_isSession(generation)) return;
    if (_backgroundWork++ == 0) await _nowPlaying.beginBackgroundTask();
  }

  Future<void> _endBackgroundWork(int generation) async {
    if (!_isSession(generation)) return;
    if (_backgroundWork > 0 && --_backgroundWork == 0) {
      await _nowPlaying.endBackgroundTask();
    }
  }

  String _cacheKey(String text, NovelTtsSettings loaded) {
    final request = buildNovelTtsRequest(loaded, text);
    final headers = request.headers.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return sha256.convert(utf8.encode(jsonEncode([
      request.method,
      request.uri.toString(),
      [for (final header in headers) [header.key, header.value]],
      request.body == null ? null : base64Encode(request.body!),
    ]))).toString();
  }

  Future<File> _cacheFile(String key) async {
    final dir = await (_cacheDir?.call() ?? getTemporaryDirectory());
    final ttsDir = Directory(p.join(dir.path, 'novel_tts'));
    await ttsDir.create(recursive: true);
    return File(p.join(ttsDir.path, '$key.mp3'));
  }

  void _scheduleCacheCleanup(Directory directory) {
    if (_cacheCleanup != null) return;
    final cleanup = _trimCache(directory);
    _cacheCleanup = cleanup;
    cleanup.whenComplete(() => _cacheCleanup = null).ignore();
  }

  Future<void> _trimCache(Directory directory) async {
    try {
      final entries = <({File file, FileStat stat})>[];
      await for (final entity in directory.list()) {
        if (entity is! File || !entity.path.endsWith('.mp3')) continue;
        entries.add((file: entity, stat: await entity.stat()));
      }
      entries.sort((a, b) => a.stat.modified.compareTo(b.stat.modified));
      var bytes = entries.fold<int>(0, (sum, entry) => sum + entry.stat.size);
      var count = entries.length;
      for (final entry in entries) {
        if (bytes <= 128 * 1024 * 1024 && count <= 256) break;
        if (_protectedCachePaths.contains(entry.file.path)) continue;
        await entry.file.delete();
        bytes -= entry.stat.size;
        count--;
      }
    } catch (_) {
      // Cache eviction must not interrupt playback (the OS can evict too).
    }
  }

  Future<void> _publishNowPlaying() {
    final generation = _generation;
    final current = session;
    final spoken = subtitle;
    final playing = status == NovelTtsStatus.playing;
    final active = playing || status == NovelTtsStatus.paused;
    final result = _nowPlayingWrite.then((_) async {
      if (current == null || !_isPlayback(generation)) return;
      final duration = await _audio.duration;
      final position = await _audio.position;
      if (!_isPlayback(generation) || !identical(current, session)) return;
      final info = NovelTtsNowPlayingInfo(
        title: current.title,
        artist: current.author,
        subtitle: spoken,
        isPlaying: playing,
        durationMs: duration?.inMilliseconds ?? 0,
        positionMs: position?.inMilliseconds ?? 0,
      );
      if (active) {
        await _nowPlaying.start(info);
      } else {
        await _nowPlaying.update(info);
      }
    });
    _nowPlayingWrite = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    // Native now-playing extrapolates elapsed time from playbackRate. Sending
    // the same metadata every second causes unnecessary platform/UI work.
    return _nowPlayingWrite;
  }

  @override
  void notifyListeners() {
    // Playback outlives dispose by whatever async step it was in, and
    // ChangeNotifier throws when notified after disposal. That throw lands in
    // the middle of `_playFrom`, not at a call site anyone can guard.
    if (_disposed) {
      return;
    }
    super.notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _invalidateSession();
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _completionSub?.cancel();
    _clipSub?.cancel();
    _playingSub?.cancel();
    _errorSub?.cancel();
    _nowPlaying.onRemote = null;
    _pageDecisions.clear();
    _chapters.clear();
    _chapterDocuments.clear();
    _loadedSeriesIds.clear();
    _queuedClips.clear();
    _protectedCachePaths.clear();
    _sessionSnapshot = null;
    clips = const [];
    session = null;
    final synth = _synthesizer;
    if (synth is NovelTtsCancellableSynthesizer) {
      (synth as NovelTtsCancellableSynthesizer).dispose();
    }
    unawaited(_nowPlaying.keepAlive(false));
    unawaited(_nowPlaying.endBackgroundTask());
    unawaited(_nowPlaying.stop());
    unawaited(_audio.dispose());
    unawaited(_pronunciationPipeline.worker.dispose().catchError((Object _) {}));
    super.dispose();
  }
}
