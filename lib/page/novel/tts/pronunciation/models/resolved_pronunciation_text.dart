import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_decision.dart';

class NovelTtsRubyAnnotation {
  const NovelTtsRubyAnnotation({
    required this.start,
    required this.end,
    required this.surface,
    required this.reading,
  });

  final int start;
  final int end;
  final String surface;
  final String reading;
}

class NovelTtsTextDocument {
  const NovelTtsTextDocument({
    required this.displayText,
    this.rubyAnnotations = const [],
    this.sourceHash = '',
  });

  final String displayText;
  final List<NovelTtsRubyAnnotation> rubyAnnotations;
  final String sourceHash;
}

class NovelTtsSourceRange {
  const NovelTtsSourceRange(this.start, this.end);

  final int start;
  final int end;

  int get length => end - start;
}

class ResolvedPronunciationText {
  const ResolvedPronunciationText({
    required this.displayText,
    required this.appliedDecisions,
    required this.allDecisions,
    required this.snapshotFingerprint,
    required this.analyzerCapability,
  });

  final String displayText;
  final List<PronunciationDecision> appliedDecisions;
  final List<PronunciationDecision> allDecisions;
  final String snapshotFingerprint;
  final String analyzerCapability;
}

abstract interface class TtsTextBudget {
  int measure(String text);
  int get maxUnits;
}

class RuneTtsTextBudget implements TtsTextBudget {
  const RuneTtsTextBudget(this.maxUnits);

  @override
  final int maxUnits;

  @override
  int measure(String text) => text.runes.length;
}
