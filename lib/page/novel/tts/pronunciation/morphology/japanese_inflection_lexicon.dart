import 'package:pixez/page/novel/tts/pronunciation/morphology/japanese_lexicon_data.dart';

/// One IPADIC conjugation class: the stems that inflect with it and the
/// endings those stems accept.
class JapaneseInflectionClass {
  const JapaneseInflectionClass(
    this.id,
    this.partOfSpeech,
    this.baseEnding,
    this.packedEndings,
    this.packedStems,
  );

  /// IPADIC 活用型, for example `五段・ラ行`.
  final String id;

  /// IPADIC 品詞, either `動詞` or `形容詞`.
  final String partOfSpeech;

  /// Ending of the dictionary form, used to rebuild 原形 from a stem.
  final String baseEnding;

  /// `ending:policy` pairs joined by `;`, longest ending first.
  final String packedEndings;

  /// Newline separated stems.
  final String packedStems;
}

/// Words that never inflect but mix kanji and kana, so a bare kanji run cannot
/// describe them (`実に`, `再び`, `明け方`).
class JapaneseFixedWordGroup {
  const JapaneseFixedWordGroup(this.partOfSpeech, this.packedWords);

  final String partOfSpeech;
  final String packedWords;
}

/// What has to follow an inflected form for the verb reading to hold.
///
/// `悟さ` is only a verb in `悟さない`; without a negative auxiliary the text is
/// far more likely to be a name. Checking the follow-up keeps the analyzer from
/// rejecting `直さん` while still rejecting `直さない`.
enum JapaneseInflectionFollow { free, negative, volitional, past, conditional, polite }

const _followByCode = {
  'f': JapaneseInflectionFollow.free,
  'n': JapaneseInflectionFollow.negative,
  'u': JapaneseInflectionFollow.volitional,
  't': JapaneseInflectionFollow.past,
  'b': JapaneseInflectionFollow.conditional,
  'g': JapaneseInflectionFollow.polite,
};

const _followHeads = {
  JapaneseInflectionFollow.negative: {'な', 'ぬ', 'ん', 'ず', 'れ', 'せ', 'ざ'},
  JapaneseInflectionFollow.volitional: {'う'},
  JapaneseInflectionFollow.past: {'た', 'て', 'だ', 'で', 'ち', 'ぢ'},
  JapaneseInflectionFollow.conditional: {'ば'},
  JapaneseInflectionFollow.polite: {'ご'},
};

class JapaneseInflectionEnding {
  const JapaneseInflectionEnding(this.text, this.follow);

  final String text;
  final JapaneseInflectionFollow follow;

  bool accepts(String source, int index) {
    final heads = _followHeads[follow];
    if (heads == null) {
      return true;
    }
    if (index >= source.length) {
      return false;
    }
    return heads.contains(source[index]);
  }
}

/// A dictionary hit at a source offset.
class JapaneseLexiconMatch {
  const JapaneseLexiconMatch({
    required this.start,
    required this.end,
    required this.surface,
    required this.basicForm,
    required this.partOfSpeech,
    this.conjugationType,
    this.conjugationEnding,
  });

  final int start;
  final int end;
  final String surface;
  final String basicForm;
  final String partOfSpeech;
  final String? conjugationType;
  final String? conjugationEnding;

  bool get isInflected => conjugationType != null;
}

class _StemNode {
  Map<int, _StemNode>? children;
  List<int>? classes;
  List<String>? fixedPartsOfSpeech;
}

/// Longest-match index over the generated inflection lexicon.
///
/// The index is built once, lazily, and then only walked, so a novel page costs
/// a trie descent per character instead of a dictionary load.
class JapaneseInflectionLexicon {
  JapaneseInflectionLexicon._(
    this._root,
    this._endings,
    this._classes,
    this.stemCount,
    this.fixedWordCount,
  );

  static JapaneseInflectionLexicon? _shared;

  static JapaneseInflectionLexicon get shared => _shared ??= build();

  static JapaneseInflectionLexicon build({
    List<JapaneseInflectionClass> classes = japaneseInflectionClasses,
    List<JapaneseFixedWordGroup> fixedWords = japaneseFixedWords,
  }) {
    final root = _StemNode();
    final endings = <List<JapaneseInflectionEnding>>[];
    var stemCount = 0;
    for (var i = 0; i < classes.length; i++) {
      final group = classes[i];
      endings.add(_parseEndings(group.packedEndings));
      for (final stem in group.packedStems.split('\n')) {
        if (stem.isEmpty) {
          continue;
        }
        final node = _descend(root, stem);
        (node.classes ??= <int>[]).add(i);
        stemCount++;
      }
    }
    var fixedWordCount = 0;
    for (final group in fixedWords) {
      for (final word in group.packedWords.split('\n')) {
        if (word.isEmpty) {
          continue;
        }
        final node = _descend(root, word);
        (node.fixedPartsOfSpeech ??= <String>[]).add(group.partOfSpeech);
        fixedWordCount++;
      }
    }
    return JapaneseInflectionLexicon._(
      root,
      endings,
      classes,
      stemCount,
      fixedWordCount,
    );
  }

  final _StemNode _root;
  final List<List<JapaneseInflectionEnding>> _endings;
  final List<JapaneseInflectionClass> _classes;
  final int stemCount;
  final int fixedWordCount;

  /// Longest dictionary word starting at [index], or null when the lexicon has
  /// nothing to say about that offset.
  JapaneseLexiconMatch? matchAt(String source, int index) {
    if (index < 0 || index >= source.length) {
      return null;
    }
    JapaneseLexiconMatch? best;
    var node = _root;
    var cursor = index;
    while (cursor < source.length) {
      final step = _scalarLengthAt(source, cursor);
      final next = node.children?[_scalarAt(source, cursor)];
      if (next == null) {
        break;
      }
      node = next;
      cursor += step;
      final fixed = node.fixedPartsOfSpeech;
      if (fixed != null && (best == null || cursor > best.end)) {
        best = JapaneseLexiconMatch(
          start: index,
          end: cursor,
          surface: source.substring(index, cursor),
          basicForm: source.substring(index, cursor),
          partOfSpeech: fixed.first,
        );
      }
      final classes = node.classes;
      if (classes == null) {
        continue;
      }
      final stem = source.substring(index, cursor);
      for (final classIndex in classes) {
        for (final ending in _endings[classIndex]) {
          final end = cursor + ending.text.length;
          if (end > source.length) {
            continue;
          }
          if (best != null && end <= best.end) {
            continue;
          }
          if (ending.text.isNotEmpty &&
              !source.startsWith(ending.text, cursor)) {
            continue;
          }
          final surface = stem + ending.text;
          if (!_hasKana(surface)) {
            // A verb written without okurigana (IPADIC's 体言接続特殊２ and the
            // bare 連用形 of kanji-only stems) is indistinguishable from a
            // name, so it is not evidence of anything.
            continue;
          }
          if (!ending.accepts(source, end)) {
            continue;
          }
          final group = _classes[classIndex];
          best = JapaneseLexiconMatch(
            start: index,
            end: end,
            surface: surface,
            basicForm: stem + group.baseEnding,
            partOfSpeech: group.partOfSpeech,
            conjugationType: group.id,
            conjugationEnding: ending.text,
          );
          break;
        }
      }
    }
    return best;
  }

  static List<JapaneseInflectionEnding> _parseEndings(String packed) {
    final result = <JapaneseInflectionEnding>[];
    for (final part in packed.split(';')) {
      if (part.isEmpty) {
        continue;
      }
      final split = part.lastIndexOf(':');
      if (split < 0) {
        continue;
      }
      final follow = _followByCode[part.substring(split + 1)];
      if (follow == null) {
        continue;
      }
      result.add(
        JapaneseInflectionEnding(part.substring(0, split), follow),
      );
    }
    result.sort((a, b) => b.text.length.compareTo(a.text.length));
    return result;
  }

  static _StemNode _descend(_StemNode root, String word) {
    var node = root;
    for (final rune in word.runes) {
      node = (node.children ??= <int, _StemNode>{}).putIfAbsent(
        rune,
        _StemNode.new,
      );
    }
    return node;
  }
}

bool _hasKana(String value) {
  for (final rune in value.runes) {
    if ((rune >= 0x3041 && rune <= 0x309F) ||
        (rune >= 0x30A0 && rune <= 0x30FF)) {
      return true;
    }
  }
  return false;
}

int _scalarAt(String text, int index) {
  final unit = text.codeUnitAt(index);
  if (unit >= 0xD800 && unit <= 0xDBFF && index + 1 < text.length) {
    final low = text.codeUnitAt(index + 1);
    if (low >= 0xDC00 && low <= 0xDFFF) {
      return 0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00);
    }
  }
  return unit;
}

int _scalarLengthAt(String text, int index) {
  final unit = text.codeUnitAt(index);
  if (unit >= 0xD800 && unit <= 0xDBFF && index + 1 < text.length) {
    final low = text.codeUnitAt(index + 1);
    if (low >= 0xDC00 && low <= 0xDFFF) {
      return 2;
    }
  }
  return 1;
}
