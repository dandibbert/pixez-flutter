import 'package:pixez/page/novel/tts/playback/novel_tts_playback_controller.dart';
import 'package:pixez/page/novel/tts/queue/tts_queue_policy.dart';
import 'package:pixez/page/novel/tts/synthesis/novel_tts_synthesis_engine.dart';

class NovelTtsBufferedSession {
  NovelTtsBufferedSession({
    required this.audio,
    this.policy = const TtsBufferPolicy(),
  });
  final NovelTtsAudioPort audio;
  final TtsBufferPolicy policy;
  final TtsGenerationGuard _guard = TtsGenerationGuard();
  Duration bufferedDuration = Duration.zero;
  bool _loaded = false;
  bool _started = false;

  Future<void> consume(
    Stream<NovelTtsSynthesisItem> source, {
    bool autoPlay = true,
  }) async {
    final token = _guard.begin();
    bufferedDuration = Duration.zero;
    _loaded = false;
    _started = false;
    await for (final synthesized in source) {
      if (!_guard.accepts(token)) return;
      final item = _playbackItem(synthesized);
      if (!_loaded) {
        await audio.load([item]);
        _loaded = true;
      } else {
        await audio.append(item);
      }
      if (!_guard.accepts(token)) return;
      bufferedDuration += item.duration;
      final decision = policy.evaluate(bufferedDuration, starting: true);
      if (autoPlay && !_started && decision.canStart) {
        await audio.play();
        _started = true;
      }
    }
    if (_guard.accepts(token) && autoPlay && _loaded && !_started) {
      await audio.play();
      _started = true;
    }
  }

  void noteConsumed(Duration duration) {
    bufferedDuration = bufferedDuration - duration;
    if (bufferedDuration < Duration.zero) bufferedDuration = Duration.zero;
  }

  TtsBufferDecision get decision => policy.evaluate(bufferedDuration);
  Future<void> cancel() async {
    _guard.cancel();
    bufferedDuration = Duration.zero;
    _loaded = false;
    _started = false;
    await audio.stop();
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
