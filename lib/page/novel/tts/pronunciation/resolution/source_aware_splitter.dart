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
    final units = budget.measure(spoken);
    if (units <= budget.maxUnits || units <= budget.maxUnits + _grace(budget)) {
      return [range];
    }
    final cut = _bestBudgetCut(
      displayText: displayText,
      range: range,
      applied: applied,
      budget: budget,
      protected: protected,
    );
    if (cut == null) {
      throw StateError('pronunciation_reading_exceeds_budget');
    }
    return [
      ..._fitBudget(
        displayText: displayText,
        range: NovelTtsSourceRange(range.start, cut),
        applied: applied,
        budget: budget,
        protected: protected,
      ),
      ..._fitBudget(
        displayText: displayText,
        range: NovelTtsSourceRange(cut, range.end),
        applied: applied,
        budget: budget,
        protected: protected,
      ),
    ];
  }

  int _grace(TtsTextBudget budget) {
    final extra = (budget.maxUnits * 0.2).round();
    return extra > 24 ? 24 : extra;
  }

  int? _bestBudgetCut({
    required String displayText,
    required NovelTtsSourceRange range,
    required List<PronunciationDecision> applied,
    required TtsTextBudget budget,
    required List<(int, int)> protected,
  }) {
    var sentenceCut = -1;
    var lineCut = -1;
    var softCut = -1;
    var anyCut = -1;
    for (var cut = range.start + 1; cut < range.end; cut++) {
      if (_isInsideProtected(cut, protected)) {
        continue;
      }
      final spoken = renderer.renderRange(
        source: displayText,
        range: NovelTtsSourceRange(range.start, cut),
        decisions: applied,
      );
      if (budget.measure(spoken) > budget.maxUnits) {
        continue;
      }
      anyCut = cut;
      final prev = displayText[cut - 1];
      if (_isSentenceEnder(prev) ||
          (cut >= range.start + 2 &&
              _isCloser(prev) &&
              _isSentenceEnder(displayText[cut - 2]))) {
        sentenceCut = cut;
      } else if (prev == '\n') {
        lineCut = cut;
      } else if (_isSoftBreak(prev)) {
        softCut = cut;
      }
    }
    if (sentenceCut > range.start) {
      return sentenceCut;
    }
    if (lineCut > range.start) {
      return lineCut;
    }
    if (softCut > range.start) {
      return softCut;
    }
    if (anyCut > range.start) {
      return anyCut;
    }
    return _safeMid(range, protected);
  }

  bool _isInsideProtected(int cut, List<(int, int)> protected) {
    for (final span in protected) {
      if (cut > span.$1 && cut < span.$2) {
        return true;
      }
    }
    return false;
  }

  bool _isSentenceEnder(String char) {
    return char == '。' ||
        char == '！' ||
        char == '？' ||
        char == '!' ||
        char == '?' ||
        char == '…' ||
        char == '．';
  }

  bool _isCloser(String char) {
    return char == '」' ||
        char == '』' ||
        char == '"' ||
        char == '”' ||
        char == '’' ||
        char == ')' ||
        char == '）' ||
        char == ']' ||
        char == '】';
  }

  bool _isSoftBreak(String char) {
    return char == '；' ||
        char == ';' ||
        char == '，' ||
        char == ',' ||
        char == '、' ||
        char == '：' ||
        char == ':' ||
        char == '—' ||
        char == '–' ||
        char == ' ';
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
