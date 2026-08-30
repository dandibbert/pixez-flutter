import 'package:pixez/page/novel/tts/novel_tts_follow.dart';
import 'package:pixez/page/novel/tts/novel_tts_splitter.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_decision.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/resolved_pronunciation_text.dart';
import 'package:pixez/page/novel/tts/pronunciation/resolution/pronunciation_renderer.dart';

class SourceAwareNovelTtsSplitter {
  const SourceAwareNovelTtsSplitter({
    this.renderer = const PronunciationRenderer(),
  });

  final PronunciationRenderer renderer;

  List<NovelTtsSourceRange> split({
    required String displayText,
    required List<PronunciationDecision> appliedDecisions,
    required TtsTextBudget budget,
  }) {
    if (displayText.isEmpty) {
      return const [];
    }
    final protected = [
      for (final decision in appliedDecisions)
        if (decision.isApplied) (decision.start, decision.end),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final chunks = splitNovelTtsText(displayText, maxChars: budget.maxUnits);
    var ranges = novelTtsAlignChunks(displayText, chunks)
        .where((range) => range.end > range.start)
        .map((range) => NovelTtsSourceRange(range.start, range.end))
        .toList();
    ranges = _expandProtected(ranges, protected);
    ranges = _mergeOverlaps(ranges);
    ranges = [
      for (final range in ranges) _trimRange(displayText, range),
    ].where((range) => range.end > range.start).toList();

    final out = <NovelTtsSourceRange>[];
    for (final range in ranges) {
      out.addAll(
        _fitBudget(
          displayText: displayText,
          range: range,
          applied: appliedDecisions,
          budget: budget,
          protected: protected,
        ),
      );
    }
    return out;
  }

  List<NovelTtsSourceRange> _expandProtected(
    List<NovelTtsSourceRange> ranges,
    List<(int, int)> protected,
  ) {
    return [
      for (final range in ranges)
        _coverProtected(range, protected),
    ];
  }

  NovelTtsSourceRange _coverProtected(
    NovelTtsSourceRange range,
    List<(int, int)> protected,
  ) {
    var start = range.start;
    var end = range.end;
    for (final span in protected) {
      if (start < span.$2 && span.$1 < end) {
        if (span.$1 < start) {
          start = span.$1;
        }
        if (span.$2 > end) {
          end = span.$2;
        }
      }
    }
    return NovelTtsSourceRange(start, end);
  }

  List<NovelTtsSourceRange> _mergeOverlaps(List<NovelTtsSourceRange> ranges) {
    if (ranges.isEmpty) {
      return ranges;
    }
    final sorted = [...ranges]..sort((a, b) => a.start.compareTo(b.start));
    final merged = <NovelTtsSourceRange>[sorted.first];
    for (var i = 1; i < sorted.length; i++) {
      final last = merged.last;
      final next = sorted[i];
      if (next.start < last.end) {
        merged[merged.length - 1] = NovelTtsSourceRange(
          last.start,
          next.end > last.end ? next.end : last.end,
        );
      } else {
        merged.add(next);
      }
    }
    return merged;
  }

  NovelTtsSourceRange _trimRange(String text, NovelTtsSourceRange range) {
    var start = range.start;
    var end = range.end;
    while (start < end && _isTrimSpace(text[start])) {
      start++;
    }
    while (end > start && _isTrimSpace(text[end - 1])) {
      end--;
    }
    return NovelTtsSourceRange(start, end);
  }

  bool _isTrimSpace(String char) {
    return char == ' ' ||
        char == '\n' ||
        char == '\r' ||
        char == '\t' ||
        char == '　';
  }

  List<NovelTtsSourceRange> _fitBudget({
    required String displayText,
    required NovelTtsSourceRange range,
    required List<PronunciationDecision> applied,
    required TtsTextBudget budget,
    required List<(int, int)> protected,
  }) {
    final spoken = renderer.renderRange(
      source: displayText,
      range: range,
      decisions: applied,
    );
    if (budget.measure(spoken) <= budget.maxUnits) {
      return [range];
    }
    final mid = _safeMid(range, protected);
    if (mid == null) {
      throw StateError('pronunciation_reading_exceeds_budget');
    }
    return [
      ..._fitBudget(
        displayText: displayText,
        range: NovelTtsSourceRange(range.start, mid),
        applied: applied,
        budget: budget,
        protected: protected,
      ),
      ..._fitBudget(
        displayText: displayText,
        range: NovelTtsSourceRange(mid, range.end),
        applied: applied,
        budget: budget,
        protected: protected,
      ),
    ];
  }

  int? _safeMid(NovelTtsSourceRange range, List<(int, int)> protected) {
    if (range.length < 2) {
      return null;
    }
    var mid = range.start + range.length ~/ 2;
    for (final span in protected) {
      if (mid > span.$1 && mid < span.$2) {
        mid = span.$2;
        break;
      }
    }
    if (mid <= range.start || mid >= range.end) {
      return null;
    }
    return mid;
  }
}
