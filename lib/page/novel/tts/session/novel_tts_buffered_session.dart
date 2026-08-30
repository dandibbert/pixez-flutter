import 'dart:async';

import 'package:pixez/page/novel/tts/playback/novel_tts_playback_controller.dart';
import 'package:pixez/page/novel/tts/queue/tts_queue_policy.dart';
import 'package:pixez/page/novel/tts/synthesis/novel_tts_synthesis_engine.dart';

class NovelTtsBufferedSession {
  NovelTtsBufferedSession({
    required this.audio,
    this.playbackController,
    this.policy = const TtsBufferPolicy(),
  }) {
    playbackController?.addListener(_syncPlayableDuration);
  }
  final NovelTtsAudioPort audio;
  final NovelTtsPlaybackController? playbackController;
  final TtsBufferPolicy policy;
  final TtsGenerationGuard _guard = TtsGenerationGuard();
  Duration bufferedDuration = Duration.zero;
  bool _loaded = false;
  bool _started = false;
  bool _disposed = false;
  Completer<void>? _belowTarget;

  Future<void> consume(
    Stream<NovelTtsSynthesisItem> source, {
    bool autoPlay = true,
  }) {
    final token = _guard.begin();
    return _consume(source, token: token, autoPlay: autoPlay);
  }

  Future<void> consumeGenerated(
    Stream<NovelTtsSynthesisItem> Function(
      TtsGenerationGuard guard,
      TtsGenerationToken token,
    )
    source, {
    bool autoPlay = true,
  }) {
    final token = _guard.begin();
    return _consume(source(_guard, token), token: token, autoPlay: autoPlay);
  }

  Future<void> _consume(
    Stream<NovelTtsSynthesisItem> source, {
    required TtsGenerationToken token,
    required bool autoPlay,
  }) async {
    bufferedDuration = Duration.zero;
    _loaded = false;
    _started = false;
    await for (final synthesized in source) {
      if (!_guard.accepts(token)) return;
      final item = _playbackItem(synthesized);
      if (!_loaded) {
        if (playbackController != null) {
          await playbackController!.load([item]);
        } else {
          await audio.load([item]);
        }
        _loaded = true;
      } else {
        if (playbackController != null) {
          await playbackController!.append(item);
        } else {
          await audio.append(item);
        }
      }
      if (!_guard.accepts(token)) return;
      if (playbackController == null) {
        bufferedDuration += item.duration;
      } else {
        _syncPlayableDuration();
      }
      playbackController?.updateBufferedDuration(bufferedDuration);
      final decision = policy.evaluate(bufferedDuration, starting: true);
      if (autoPlay && !_started && decision.canStart) {
        await (playbackController?.play() ?? audio.play());
        _started = true;
      }
      await _waitUntilRefillNeeded(token);
    }
    if (_guard.accepts(token) && autoPlay && _loaded && !_started) {
      await (playbackController?.play() ?? audio.play());
      _started = true;
    }
  }

  Future<void> _waitUntilRefillNeeded(TtsGenerationToken token) async {
    if (playbackController == null || bufferedDuration < policy.target) return;
    _belowTarget ??= Completer<void>();
    await _belowTarget!.future;
    if (!_guard.accepts(token)) return;
  }

  void _resumeGenerationIfNeeded() {
    if (bufferedDuration >= policy.low) return;
    final waiting = _belowTarget;
    _belowTarget = null;
    if (waiting != null && !waiting.isCompleted) waiting.complete();
  }

  void _syncPlayableDuration() {
    final snapshot = playbackController?.snapshot;
    if (snapshot == null || snapshot.items.isEmpty) return;
    final index = snapshot.currentIndex ?? 0;
    var remaining = Duration.zero;
    for (
      var itemIndex = index;
      itemIndex < snapshot.items.length;
      itemIndex++
    ) {
      final item = snapshot.items[itemIndex];
      remaining += itemIndex == index
          ? item.duration - snapshot.position
          : item.duration;
    }
    if (remaining < Duration.zero) remaining = Duration.zero;
    bufferedDuration = remaining;
    if (snapshot.bufferedDuration != remaining) {
      playbackController?.updateBufferedDuration(remaining);
    }
    _resumeGenerationIfNeeded();
  }

  void noteConsumed(Duration duration) {
    bufferedDuration = bufferedDuration - duration;
    if (bufferedDuration < Duration.zero) bufferedDuration = Duration.zero;
    playbackController?.updateBufferedDuration(bufferedDuration);
    _resumeGenerationIfNeeded();
  }

  TtsBufferDecision get decision => policy.evaluate(bufferedDuration);
  Future<void> cancel() async {
    _guard.cancel();
    bufferedDuration = Duration.zero;
    _loaded = false;
    _started = false;
    final waiting = _belowTarget;
    _belowTarget = null;
    if (waiting != null && !waiting.isCompleted) waiting.complete();
    playbackController?.updateBufferedDuration(Duration.zero);
    await (playbackController?.stop() ?? audio.stop());
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    playbackController?.removeListener(_syncPlayableDuration);
    await cancel();
  }

  NovelTtsPlaybackItem _playbackItem(NovelTtsSynthesisItem item) =>
      NovelTtsPlaybackItem(
        id: item.id,
        filePath: item.filePath,
        title: item.title,
        author: item.author,
        displayText: item.displayText,
        pageNumber: item.pageNumber,
        chunkIndex: item.chunkIndex,
        chunkCount: item.chunkCount,
        duration: item.duration,
      );
}
