import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_decision.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/resolved_pronunciation_text.dart';

class PronunciationRenderer {
  const PronunciationRenderer();

  String renderRange({
    required String source,
    required NovelTtsSourceRange range,
    required Iterable<PronunciationDecision> decisions,
  }) {
    final applied = [
      for (final decision in decisions)
        if (decision.isApplied &&
            decision.start >= range.start &&
            decision.end <= range.end)
          decision,
    ]..sort((a, b) => a.start.compareTo(b.start));
    if (applied.isEmpty) {
      return source.substring(range.start, range.end);
    }
    final buffer = StringBuffer();
    var cursor = range.start;
    for (final decision in applied) {
      if (source.substring(decision.start, decision.end) != decision.surface) {
        continue;
      }
      if (decision.start > cursor) {
        buffer.write(source.substring(cursor, decision.start));
      }
      buffer.write(decision.reading);
      cursor = decision.end;
    }
    if (cursor < range.end) {
      buffer.write(source.substring(cursor, range.end));
    }
    return buffer.toString();
  }

  String renderAll({
    required String source,
    required Iterable<PronunciationDecision> decisions,
  }) {
    return renderRange(
      source: source,
      range: NovelTtsSourceRange(0, source.length),
      decisions: decisions,
    );
  }
}
