import 'dart:async';

import 'package:flutter/foundation.dart';

enum NovelTtsAudioProcessingState { idle, loading, buffering, ready, completed }

enum NovelTtsPlaybackState {
  idle,
  preparing,
  buffering,
  playing,
  paused,
  completed,
  failed,
}

class NovelTtsPlaybackItem {
  const NovelTtsPlaybackItem({
    required this.id,
    required this.filePath,
    required this.title,
    required this.author,
    required this.displayText,
    required this.pageNumber,
    required this.chunkIndex,
    required this.chunkCount,
    required this.duration,
  });

  final String id;
  final String filePath;
  final String title;
  final String author;
  final String displayText;
  final int pageNumber;
  final int chunkIndex;
  final int chunkCount;
  final Duration duration;
}

class NovelTtsAudioEvent {
  const NovelTtsAudioEvent({
    required this.currentIndex,
    required this.position,
    required this.processingState,
    required this.playing,
  });

  final int? currentIndex;
  final Duration position;
  final NovelTtsAudioProcessingState processingState;
  final bool playing;
}

abstract interface class NovelTtsAudioPort {
  Stream<NovelTtsAudioEvent> get events;

  Future<void> load(List<NovelTtsPlaybackItem> items);
  Future<void> append(NovelTtsPlaybackItem item);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> skipTo(int index);
  Future<void> dispose();
}

class NovelTtsPlaybackSnapshot {
  const NovelTtsPlaybackSnapshot({
    this.state = NovelTtsPlaybackState.idle,
    this.items = const <NovelTtsPlaybackItem>[],
    this.currentIndex,
    this.position = Duration.zero,
    this.bufferedDuration = Duration.zero,
    this.visiblePage,
    this.error,
  });

  final NovelTtsPlaybackState state;
  final List<NovelTtsPlaybackItem> items;
  final int? currentIndex;
  final Duration position;
  final Duration bufferedDuration;
  final int? visiblePage;
  final Object? error;

  NovelTtsPlaybackItem? get currentItem {
    final index = currentIndex;
    if (index == null || index < 0 || index >= items.length) return null;
    return items[index];
  }

  bool get playing => state == NovelTtsPlaybackState.playing;

  double get progress {
    final duration = currentItem?.duration ?? Duration.zero;
    if (duration <= Duration.zero) return 0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0, 1);
  }

  NovelTtsPlaybackSnapshot copyWith({
    NovelTtsPlaybackState? state,
    List<NovelTtsPlaybackItem>? items,
    int? currentIndex,
    bool clearCurrentIndex = false,
    Duration? position,
    Duration? bufferedDuration,
    int? visiblePage,
    Object? error,
    bool clearError = false,
  }) {
    return NovelTtsPlaybackSnapshot(
      state: state ?? this.state,
      items: items ?? this.items,
      currentIndex: clearCurrentIndex ? null : currentIndex ?? this.currentIndex,
      position: position ?? this.position,
      bufferedDuration: bufferedDuration ?? this.bufferedDuration,
      visiblePage: visiblePage ?? this.visiblePage,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class NovelTtsPlaybackController extends ChangeNotifier {
  NovelTtsPlaybackController(this._audioPort) {
    _subscription = _audioPort.events.listen(
      _onAudioEvent,
      onError: _onAudioError,
    );
  }

  final NovelTtsAudioPort _audioPort;
  late final StreamSubscription<NovelTtsAudioEvent> _subscription;
  NovelTtsPlaybackSnapshot _snapshot = const NovelTtsPlaybackSnapshot();

  NovelTtsPlaybackSnapshot get snapshot => _snapshot;

  Future<void> load(List<NovelTtsPlaybackItem> items) async {
    _snapshot = NovelTtsPlaybackSnapshot(
      state: NovelTtsPlaybackState.preparing,
      items: List<NovelTtsPlaybackItem>.unmodifiable(items),
      currentIndex: items.isEmpty ? null : 0,
      visiblePage: _snapshot.visiblePage,
    );
    notifyListeners();
    try {
      await _audioPort.load(items);
      if (items.isEmpty) {
        _snapshot = _snapshot.copyWith(
          state: NovelTtsPlaybackState.idle,
          clearCurrentIndex: true,
        );
        notifyListeners();
      }
    } catch (error) {
      _onAudioError(error);
      rethrow;
    }
  }

  Future<void> append(NovelTtsPlaybackItem item) async {
    await _audioPort.append(item);
    _snapshot = _snapshot.copyWith(
      items: List<NovelTtsPlaybackItem>.unmodifiable([..._snapshot.items, item]),
    );
    notifyListeners();
  }

  Future<void> play() => _audioPort.play();
  Future<void> pause() => _audioPort.pause();
  Future<void> stop() => _audioPort.stop();
  Future<void> seek(Duration position) => _audioPort.seek(position);
  Future<void> skipTo(int index) => _audioPort.skipTo(index);

  void updateBufferedDuration(Duration duration) {
    _snapshot = _snapshot.copyWith(bufferedDuration: duration);
    notifyListeners();
  }

  void noteVisiblePageChanged(int page) {
    _snapshot = _snapshot.copyWith(visiblePage: page);
    notifyListeners();
  }

  void _onAudioEvent(NovelTtsAudioEvent event) {
    final state = switch (event.processingState) {
      NovelTtsAudioProcessingState.loading ||
      NovelTtsAudioProcessingState.buffering => NovelTtsPlaybackState.buffering,
      NovelTtsAudioProcessingState.completed => NovelTtsPlaybackState.completed,
      NovelTtsAudioProcessingState.ready => event.playing
          ? NovelTtsPlaybackState.playing
          : NovelTtsPlaybackState.paused,
      NovelTtsAudioProcessingState.idle => NovelTtsPlaybackState.idle,
    };
    _snapshot = _snapshot.copyWith(
      state: state,
      currentIndex: event.currentIndex,
      position: event.position,
      clearError: true,
    );
    notifyListeners();
  }

  void _onAudioError(Object error) {
    _snapshot = _snapshot.copyWith(
      state: NovelTtsPlaybackState.failed,
      error: error,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    unawaited(_audioPort.dispose());
    super.dispose();
  }
}
