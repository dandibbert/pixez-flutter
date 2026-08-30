import 'package:pixez/page/novel/tts/pronunciation/matching/pronunciation_compiler.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_decision.dart';

int _reasonRank(PronunciationReason reason) {
  switch (reason) {
    case PronunciationReason.explicitRuby:
      return 5;
    case PronunciationReason.exactPhrase:
      return 4;
    case PronunciationReason.forcedRule:
      return 3;
    case PronunciationReason.morphologyProperName:
    case PronunciationReason.workScopedNameContext:
    case PronunciationReason.quotativeNameContext:
      return 2;
    default:
      return 0;
  }
}

int compareAppliedDecisions(PronunciationDecision a, PronunciationDecision b) {
  final locked = (b.locked ? 1 : 0).compareTo(a.locked ? 1 : 0);
  if (locked != 0) {
    return locked;
  }
  final reason = _reasonRank(b.reason).compareTo(_reasonRank(a.reason));
  if (reason != 0) {
    return reason;
  }
  final length = (b.end - b.start).compareTo(a.end - a.start);
  if (length != 0) {
    return length;
  }
  final start = a.start.compareTo(b.start);
  if (start != 0) {
    return start;
  }
  return a.ruleId.compareTo(b.ruleId);
}

int compareCandidates(PronunciationCandidate a, PronunciationCandidate b) {
  return comparePronunciationPriority(a.rule, b.rule);
}

List<PronunciationDecision> resolvePronunciationOverlaps(
  Iterable<PronunciationDecision> incoming,
) {
  final applied = [
    for (final decision in incoming)
      if (decision.isApplied) decision,
  ]..sort(compareAppliedDecisions);
  final kept = <PronunciationDecision>[];
  final rejected = <PronunciationDecision>[];
  for (final decision in applied) {
    final hits = kept.any((other) => other.overlaps(decision.start, decision.end));
    if (hits) {
      rejected.add(
        PronunciationDecision(
          start: decision.start,
          end: decision.end,
          surface: decision.surface,
          reading: decision.reading,
          ruleId: decision.ruleId,
          status: PronunciationDecisionStatus.skipped,
          reason: PronunciationReason.rejectedOverlap,
          locked: false,
        ),
      );
      continue;
    }
    kept.add(decision);
  }
  kept.sort((a, b) => a.start.compareTo(b.start));
  return [
    ...kept,
    ...rejected,
    for (final decision in incoming)
      if (!decision.isApplied) decision,
  ];
}

PronunciationCandidate? pickPreferredCandidate(
  Iterable<PronunciationCandidate> candidates,
) {
  PronunciationCandidate? best;
  for (final candidate in candidates) {
    if (best == null || compareCandidates(candidate, best) < 0) {
      best = candidate;
    }
  }
  return best;
}
