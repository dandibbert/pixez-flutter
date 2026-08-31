import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_rule.dart';

enum PronunciationDecisionStatus { applied, skipped }

enum PronunciationReason {
  explicitRuby,
  exactPhrase,
  forcedRule,
  morphologyProperName,
  workScopedNameContext,
  quotativeNameContext,
  rejectedInsideLargerToken,
  rejectedVerbOrAdjective,
  rejectedInflectionSuffix,
  rejectedOverlap,
  rejectedLowConfidence,
  analyzerUnavailable,
  analyzerTimeout,
  invalidAnalyzerOffsets,
  invalidSourceRange,
  staleSession,
}

class PronunciationCandidate {
  const PronunciationCandidate({
    required this.start,
    required this.end,
    required this.rule,
  });

  final int start;
  final int end;
  final PronunciationRule rule;

  String surfaceOf(String source) => source.substring(start, end);
}

class PronunciationDecision {
  const PronunciationDecision({
    required this.start,
    required this.end,
    required this.surface,
    required this.reading,
    required this.ruleId,
    required this.status,
    required this.reason,
    required this.locked,
  });

  final int start;
  final int end;
  final String surface;
  final String reading;
  final String ruleId;
  final PronunciationDecisionStatus status;
  final PronunciationReason reason;
  final bool locked;

  bool get isApplied => status == PronunciationDecisionStatus.applied;

  bool overlaps(int otherStart, int otherEnd) {
    return start < otherEnd && otherStart < end;
  }
}
