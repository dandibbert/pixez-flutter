import 'package:pixez/page/novel/tts/pronunciation/matching/phrase_trie.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/morphology_token.dart';
import 'package:pixez/page/novel/tts/pronunciation/morphology/japanese_morphology_analyzer.dart';

enum _CharClass { kanji, hiragana, katakana, other }

class BoundaryOnlyJapaneseAnalyzer implements JapaneseMorphologyAnalyzer {
  @override
  String get analyzerId => 'boundary-only';

  @override
  String get analyzerVersion => '1';

  @override
  bool get supportsPartOfSpeech => false;

  @override
  String get capability => 'boundary-only';

  @override
  Future<void> warmUp() async {}

  @override
  Future<MorphologyResult> analyze(
    String text, {
    required String requestId,
  }) async {
    return MorphologyResult(tokens: tokenizeJapaneseBoundaries(text));
  }

  @override
  Future<void> dispose() async {}
}

List<MorphologyToken> tokenizeJapaneseBoundaries(String text) {
  if (text.isEmpty) {
    return const [];
  }
  final tokens = <MorphologyToken>[];
  var start = 0;
  var current = _classOfRune(_runeAtSafe(text, 0));
  var index = _utf16Advance(text, 0);
  while (index <= text.length) {
    final atEnd = index >= text.length;
    final next = atEnd ? null : _classOfRune(_runeAtSafe(text, index));
    if (atEnd || next != current) {
      final surface = text.substring(start, index);
      tokens.add(
        MorphologyToken(
          start: start,
          end: index,
          surface: surface,
          basicForm: surface,
        ),
      );
      if (atEnd) {
        break;
      }
      start = index;
      current = next!;
    }
    index = _utf16Advance(text, index);
  }
  return tokens;
}

_CharClass _classOfRune(int rune) {
  if (rune >= 0x3040 && rune <= 0x309F) {
    return _CharClass.hiragana;
  }
  if (rune >= 0x30A0 && rune <= 0x30FF) {
    return _CharClass.katakana;
  }
  if ((rune >= 0x4E00 && rune <= 0x9FFF) ||
      (rune >= 0x3400 && rune <= 0x4DBF) ||
      (rune >= 0xF900 && rune <= 0xFAFF)) {
    return _CharClass.kanji;
  }
  return _CharClass.other;
}

int _runeAtSafe(String text, int index) {
  if (!isUtf16ScalarStart(text, index)) {
    return text.codeUnitAt(index);
  }
  final unit = text.codeUnitAt(index);
  if (unit >= 0xD800 && unit <= 0xDBFF && index + 1 < text.length) {
    final low = text.codeUnitAt(index + 1);
    if (low >= 0xDC00 && low <= 0xDFFF) {
      return 0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00);
    }
  }
  return unit;
}

int _utf16Advance(String text, int index) {
  if (index >= text.length) {
    return index;
  }
  final unit = text.codeUnitAt(index);
  if (unit >= 0xD800 && unit <= 0xDBFF && index + 1 < text.length) {
    final low = text.codeUnitAt(index + 1);
    if (low >= 0xDC00 && low <= 0xDFFF) {
      return index + 2;
    }
  }
  return index + 1;
}
