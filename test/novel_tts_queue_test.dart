import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/page/novel/tts/queue/tts_queue_policy.dart';

void main() {
  test('buffer policy transitions by playable duration', () {
    const policy = TtsBufferPolicy();
    expect(policy.evaluate(Duration.zero).state, TtsBufferState.underrun);
    expect(
      policy.evaluate(const Duration(seconds: 20)).state,
      TtsBufferState.critical,
    );
    expect(
      policy.evaluate(const Duration(seconds: 60)).state,
      TtsBufferState.low,
    );
    expect(
      policy.evaluate(const Duration(seconds: 120), starting: true).canStart,
      isTrue,
    );
    expect(
      policy.evaluate(const Duration(seconds: 200)).state,
      TtsBufferState.healthy,
    );
  });
  test('generation guard rejects cancelled queue results', () {
    final guard = TtsGenerationGuard();
    final first = guard.begin();
    final second = guard.begin();
    expect(guard.accepts(first), isFalse);
    expect(guard.accepts(second), isTrue);
    guard.cancel();
    expect(guard.accepts(second), isFalse);
  });
  test('series continuation visits each viewable novel once', () {
    final planner = TtsContinuationPlanner('1');
    expect(
      planner.acceptNext(const TtsNextNovel(id: '2', viewable: true)),
      isTrue,
    );
    expect(
      planner.acceptNext(const TtsNextNovel(id: '1', viewable: true)),
      isFalse,
    );
    expect(
      planner.acceptNext(const TtsNextNovel(id: '3', viewable: false)),
      isFalse,
    );
    expect(planner.visited, {'1', '2'});
  });
  test('manual page changes require an explicit restart action', () {
    final planner = TtsContinuationPlanner('1');
    planner.noteVisiblePage(4);
    expect(planner.queueStartPage, 1);
    planner.restartFromPage(4);
    expect(planner.queueStartPage, 4);
  });
}
