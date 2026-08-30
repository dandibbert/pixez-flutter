enum TtsBufferState { underrun, critical, low, healthy }

class TtsBufferDecision {
  const TtsBufferDecision({
    required this.state,
    required this.canStart,
    required this.prioritizeSuccessor,
    required this.rescueOnly,
  });
  final TtsBufferState state;
  final bool canStart;
  final bool prioritizeSuccessor;
  final bool rescueOnly;
}

class TtsBufferPolicy {
  const TtsBufferPolicy({
    this.startup = const Duration(seconds: 90),
    this.target = const Duration(seconds: 180),
    this.low = const Duration(seconds: 90),
    this.critical = const Duration(seconds: 30),
  });
  final Duration startup;
  final Duration target;
  final Duration low;
  final Duration critical;

  TtsBufferDecision evaluate(Duration playable, {bool starting = false}) {
    final state = playable <= Duration.zero
        ? TtsBufferState.underrun
        : playable < critical
        ? TtsBufferState.critical
        : playable < low
        ? TtsBufferState.low
        : TtsBufferState.healthy;
    return TtsBufferDecision(
      state: state,
      canStart: !starting || playable >= startup,
      prioritizeSuccessor: playable < low,
      rescueOnly: playable < critical,
    );
  }
}

class TtsGenerationToken {
  const TtsGenerationToken(this.value);
  final int value;
}

class TtsGenerationGuard {
  int _generation = 0;
  bool _cancelled = true;
  TtsGenerationToken begin() {
    _cancelled = false;
    return TtsGenerationToken(++_generation);
  }

  void cancel() {
    _cancelled = true;
    _generation++;
  }

  bool accepts(TtsGenerationToken token) =>
      !_cancelled && token.value == _generation;
}

class TtsNextNovel {
  const TtsNextNovel({required this.id, required this.viewable});
  final String id;
  final bool viewable;
}

class TtsContinuationPlanner {
  TtsContinuationPlanner(String initialNovelId) : _visited = {initialNovelId};
  final Set<String> _visited;
  int visiblePage = 1;
  int queueStartPage = 1;
  Set<String> get visited => Set.unmodifiable(_visited);
  bool acceptNext(TtsNextNovel? next) {
    if (next == null || !next.viewable || _visited.contains(next.id))
      return false;
    _visited.add(next.id);
    return true;
  }

  void noteVisiblePage(int page) {
    visiblePage = page;
  }

  void restartFromPage(int page) {
    visiblePage = page;
    queueStartPage = page;
  }
}
