import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_decision.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_rule.dart';

class _TrieNode {
  final children = <int, _TrieNode>{};
  final rules = <PronunciationRule>[];
}

class PhraseTrie {
  PhraseTrie(Iterable<PronunciationRule> rules) {
    for (final rule in rules) {
      if (!rule.enabled || rule.surface.isEmpty) {
        continue;
      }
      var node = _root;
      for (final rune in rule.surface.runes) {
        node = node.children.putIfAbsent(rune, _TrieNode.new);
      }
      node.rules.add(rule);
      if (rule.surface.length > maxSurfaceUtf16) {
        maxSurfaceUtf16 = rule.surface.length;
      }
      _firstRunes.add(rule.surface.runes.first);
    }
  }

  final _root = _TrieNode();
  final _firstRunes = <int>{};
  var maxSurfaceUtf16 = 0;

  bool get isEmpty => _firstRunes.isEmpty;

  List<PronunciationCandidate> scan(String text) {
    if (isEmpty || text.isEmpty) {
      return const [];
    }
    final hits = <PronunciationCandidate>[];
    var index = 0;
    while (index < text.length) {
      if (!isUtf16ScalarStart(text, index)) {
        index++;
        continue;
      }
      if (!_firstRunes.contains(_runeAt(text, index))) {
        index += _utf16LengthAt(text, index);
        continue;
      }
      var node = _root;
      var cursor = index;
      while (cursor < text.length) {
        if (!isUtf16ScalarStart(text, cursor)) {
          break;
        }
        final rune = _runeAt(text, cursor);
        final next = node.children[rune];
        if (next == null) {
          break;
        }
        node = next;
        cursor += _utf16LengthAt(text, cursor);
        for (final rule in node.rules) {
          hits.add(PronunciationCandidate(start: index, end: cursor, rule: rule));
        }
      }
      index += _utf16LengthAt(text, index);
    }
    return hits;
  }
}

bool isUtf16ScalarStart(String text, int index) {
  if (index < 0 || index >= text.length) {
    return false;
  }
  final unit = text.codeUnitAt(index);
  return unit < 0xDC00 || unit > 0xDFFF;
}

int _runeAt(String text, int index) {
  final unit = text.codeUnitAt(index);
  if (unit >= 0xD800 && unit <= 0xDBFF && index + 1 < text.length) {
    final low = text.codeUnitAt(index + 1);
    if (low >= 0xDC00 && low <= 0xDFFF) {
      return 0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00);
    }
  }
  return unit;
}

int _utf16LengthAt(String text, int index) {
  final unit = text.codeUnitAt(index);
  if (unit >= 0xD800 && unit <= 0xDBFF && index + 1 < text.length) {
    final low = text.codeUnitAt(index + 1);
    if (low >= 0xDC00 && low <= 0xDFFF) {
      return 2;
    }
  }
  return 1;
}
