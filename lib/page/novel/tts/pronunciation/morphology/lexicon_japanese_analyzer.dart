import 'package:pixez/page/novel/tts/pronunciation/matching/phrase_trie.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/morphology_token.dart';
import 'package:pixez/page/novel/tts/pronunciation/morphology/japanese_inflection_lexicon.dart';
import 'package:pixez/page/novel/tts/pronunciation/morphology/japanese_lexicon_data.dart';
import 'package:pixez/page/novel/tts/pronunciation/morphology/japanese_morphology_analyzer.dart';

/// Japanese analyzer backed by the generated IPADIC inflection lexicon.
///
/// It reports part of speech, dictionary form, and conjugation type for verbs
/// and adjectives, which is what name disambiguation needs to tell `悟った`
/// apart from `悟は`. Text the lexicon does not cover falls back to script
/// runs, so a kanji compound such as `孫悟空` still forms a single token and a
/// one-kanji alias inside it stays untouched.
class LexiconJapaneseAnalyzer implements JapaneseMorphologyAnalyzer {
  LexiconJapaneseAnalyzer({JapaneseInflectionLexicon? lexicon})
    : _lexicon = lexicon;

  JapaneseInflectionLexicon? _lexicon;

  @override
  String get analyzerId => 'lexicon-ja';

  @override
  String get analyzerVersion => japaneseLexiconSource;

  @override
  bool get supportsPartOfSpeech => true;

  @override
  String get capability => 'lexicon-pos';

  @override
  Future<void> warmUp() async {
    _lexicon ??= JapaneseInflectionLexicon.shared;
  }

  @override
  Future<MorphologyResult> analyze(
    String text, {
    required String requestId,
  }) async {
    await warmUp();
    return MorphologyResult(tokens: tokenize(text));
  }

  @override
  Future<void> dispose() async {}

  List<MorphologyToken> tokenize(String text) {
    return tokenizeWithJapaneseLexicon(
      text,
      _lexicon ??= JapaneseInflectionLexicon.shared,
    );
  }
}

enum JapaneseScript { kanji, hiragana, katakana, other }

/// Splits [text] into tokens, preferring the longest dictionary word and
/// falling back to script runs.
List<MorphologyToken> tokenizeWithJapaneseLexicon(
  String text,
  JapaneseInflectionLexicon lexicon,
) {
  if (text.isEmpty) {
    return const [];
  }
  final tokens = <MorphologyToken>[];
  var index = 0;
  while (index < text.length) {
    if (!isUtf16ScalarStart(text, index)) {
      index++;
      continue;
    }
    final match = lexicon.matchAt(text, index);
    if (match != null) {
      tokens.add(
        MorphologyToken(
          start: match.start,
          end: match.end,
          surface: match.surface,
          basicForm: match.basicForm,
          partOfSpeech: [match.partOfSpeech],
          conjugationType: match.conjugationType,
          conjugationForm: match.conjugationEnding,
        ),
      );
      index = match.end;
      continue;
    }
    final script = japaneseScriptAt(text, index);
    final start = index;
    index += utf16ScalarLengthAt(text, index);
    while (index < text.length &&
        isUtf16ScalarStart(text, index) &&
        japaneseScriptAt(text, index) == script &&
        lexicon.matchAt(text, index) == null) {
      index += utf16ScalarLengthAt(text, index);
    }
    final surface = text.substring(start, index);
    tokens.add(
      MorphologyToken(
        start: start,
        end: index,
        surface: surface,
        basicForm: surface,
        partOfSpeech: script == JapaneseScript.kanji ? const ['名詞'] : const [],
      ),
    );
  }
  return tokens;
}

JapaneseScript japaneseScriptAt(String text, int index) {
  final rune = utf16ScalarAt(text, index);
  if (rune >= 0x3040 && rune <= 0x309F) {
    return JapaneseScript.hiragana;
  }
  if ((rune >= 0x30A0 && rune <= 0x30FF) || rune == 0xFF70) {
    return JapaneseScript.katakana;
  }
  if ((rune >= 0x4E00 && rune <= 0x9FFF) ||
      (rune >= 0x3400 && rune <= 0x4DBF) ||
      (rune >= 0xF900 && rune <= 0xFAFF) ||
      rune == 0x3005 ||
      (rune >= 0x20000 && rune <= 0x2FA1F)) {
    return JapaneseScript.kanji;
  }
  return JapaneseScript.other;
}

int utf16ScalarAt(String text, int index) {
  final unit = text.codeUnitAt(index);
  if (unit >= 0xD800 && unit <= 0xDBFF && index + 1 < text.length) {
    final low = text.codeUnitAt(index + 1);
    if (low >= 0xDC00 && low <= 0xDFFF) {
      return 0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00);
    }
  }
  return unit;
}

int utf16ScalarLengthAt(String text, int index) {
  final unit = text.codeUnitAt(index);
  if (unit >= 0xD800 && unit <= 0xDBFF && index + 1 < text.length) {
    final low = text.codeUnitAt(index + 1);
    if (low >= 0xDC00 && low <= 0xDFFF) {
      return 2;
    }
  }
  return 1;
}
