import 'package:pixez/page/novel/tts/pronunciation/models/morphology_token.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_decision.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_rule.dart';

/// Titles that only ever attach to a person, so they outrank a verb reading:
/// `直さん` is a name even though `直さ` is a real 未然形 of `直す`.
const japaneseHonorifics = <String>[
  'ちゃん先輩',
  'さん',
  'ちゃん',
  'くん',
  'たん',
  'せんぱい',
  '君',
  '様',
  'さま',
  '氏',
  '先生',
  '先輩',
  '殿',
];

/// Suffixes that keep a name a name inside a longer kanji token (`悟自身`).
const japanesePersonSuffixes = <String>[
  ...japaneseHonorifics,
  '自身',
  '達',
  'たち',
  '兄',
  '姉',
];

/// Particles that mark a preceding noun phrase. Only used when morphology is
/// unavailable, where they are the single piece of positive evidence left.
const japaneseNameParticles = <String>[
  'は',
  'が',
  'を',
  'に',
  'へ',
  'と',
  'も',
  'の',
  'から',
  'まで',
  'だけ',
  'なら',
  'だ',
  'です',
  '自身',
];

/// Okurigana that starts a verb or adjective inflection. The lexicon analyzer
/// makes this list redundant; it is the fallback used when the analyzer is
/// unavailable and only boundaries are known.
const japaneseInflectionSuffixes = <String>[
  'ってしま',
  'らせる',
  'られる',
  'らない',
  'らず',
  'らせ',
  'られ',
  'った',
  'って',
  'れば',
  'ろう',
  'ます',
  'ました',
  'り',
  'れ',
  'る',
];

const japanesePersonQuestions = <String>['誰', 'どんな人', '何者', 'どの人'];

/// Decides whether a `nameAlias` hit really is the character's name.
///
/// The rule is deliberately "apply unless the text says otherwise": the user
/// typed the alias for their own library, so a hit is honoured unless the
/// analyzer shows the characters belong to a verb, an adjective, or a longer
/// word. Requiring positive proof instead made aliases almost never fire.
class JapaneseNameDisambiguator {
  const JapaneseNameDisambiguator();

  PronunciationDecision decide({
    required String source,
    required PronunciationCandidate candidate,
    required MorphologyResult? morphology,
    required bool analyzerAvailable,
  }) {
    final surface = source.substring(candidate.start, candidate.end);
    if (surface != candidate.rule.surface) {
      return _skip(candidate, surface, PronunciationReason.invalidSourceRange);
    }
    if (candidate.rule.mode == PronunciationMatchMode.force) {
      return _apply(candidate, surface, PronunciationReason.forcedRule);
    }
    if (candidate.rule.mode == PronunciationMatchMode.exactPhrase) {
      return _apply(candidate, surface, PronunciationReason.exactPhrase);
    }

    final after = source.substring(candidate.end);
    if (morphology == null || !morphology.valid || !analyzerAvailable) {
      return _decideWithoutMorphology(
        source: source,
        candidate: candidate,
        surface: surface,
        after: after,
        reason: morphology?.reason == 'analyzerTimeout'
            ? PronunciationReason.analyzerTimeout
            : PronunciationReason.analyzerUnavailable,
      );
    }

    final token = _coveringToken(morphology.tokens, candidate);
    final atTokenStart = token == null || token.start == candidate.start;

    // An honorific or a quoted call cannot follow a conjugated verb, so this
    // evidence is checked before the verb rejection below.
    if (atTokenStart && _startsWithAny(after, japaneseHonorifics)) {
      return _apply(candidate, surface, PronunciationReason.morphologyProperName);
    }
    if (atTokenStart && _isQuotedVocative(source, candidate)) {
      return _apply(candidate, surface, PronunciationReason.morphologyProperName);
    }
    if (atTokenStart && _isQuotativeWho(after)) {
      return _apply(candidate, surface, PronunciationReason.quotativeNameContext);
    }

    if (token == null) {
      return _skip(candidate, surface, PronunciationReason.rejectedLowConfidence);
    }
    if (_looksLikeVerbOrAdjective(token)) {
      return _skip(
        candidate,
        surface,
        token.end > candidate.end || token.start < candidate.start
            ? PronunciationReason.rejectedInflectionSuffix
            : PronunciationReason.rejectedVerbOrAdjective,
      );
    }
    if (token.start < candidate.start || token.end > candidate.end) {
      if (atTokenStart &&
          _startsWithAny(
            source.substring(candidate.end, token.end),
            japanesePersonSuffixes,
          )) {
        return _apply(
          candidate,
          surface,
          PronunciationReason.morphologyProperName,
        );
      }
      return _skip(
        candidate,
        surface,
        PronunciationReason.rejectedInsideLargerToken,
      );
    }
    if (_startsWithAny(after, japaneseNameParticles)) {
      return _apply(candidate, surface, PronunciationReason.workScopedNameContext);
    }
    return _apply(candidate, surface, PronunciationReason.aliasWithoutConflict);
  }

  /// Degraded path: no part of speech, so only boundaries and the honorific and
  /// particle lists are available. Anything that looks like okurigana is left
  /// alone.
  PronunciationDecision _decideWithoutMorphology({
    required String source,
    required PronunciationCandidate candidate,
    required String surface,
    required String after,
    required PronunciationReason reason,
  }) {
    if (_startsWithAny(after, japaneseHonorifics) ||
        _isQuotedVocative(source, candidate)) {
      return _apply(candidate, surface, PronunciationReason.morphologyProperName);
    }
    if (_isKanjiAt(source, candidate.start - 1) ||
        _isKanjiAt(source, candidate.end)) {
      return _skip(candidate, surface, PronunciationReason.rejectedInsideLargerToken);
    }
    if (_startsWithAny(after, japaneseInflectionSuffixes)) {
      return _skip(candidate, surface, PronunciationReason.rejectedInflectionSuffix);
    }
    if (_startsWithAny(after, japaneseNameParticles)) {
      return _apply(candidate, surface, PronunciationReason.workScopedNameContext);
    }
    return _skip(candidate, surface, reason);
  }

  MorphologyToken? _coveringToken(
    List<MorphologyToken> tokens,
    PronunciationCandidate candidate,
  ) {
    for (final token in tokens) {
      if (token.start <= candidate.start && candidate.end <= token.end) {
        return token;
      }
    }
    return null;
  }

  bool _looksLikeVerbOrAdjective(MorphologyToken token) {
    for (final pos in token.partOfSpeech) {
      final lower = pos.toLowerCase();
      if (pos.contains('動詞') ||
          pos.contains('形容') ||
          lower.contains('verb') ||
          lower.contains('adjective')) {
        return true;
      }
    }
    return false;
  }

  bool _isQuotedVocative(String source, PronunciationCandidate candidate) {
    if (candidate.start <= 0 || candidate.end >= source.length) {
      return false;
    }
    final before = source.substring(candidate.start - 1, candidate.start);
    final after = source.substring(candidate.end, candidate.end + 1);
    const opens = {'「', '『', '"', '“'};
    const closes = {'」', '』', '"', '”', '！', '!'};
    return opens.contains(before) && closes.contains(after);
  }

  bool _isQuotativeWho(String after) {
    if (!after.startsWith('って')) {
      return false;
    }
    return _startsWithAny(after.substring('って'.length), japanesePersonQuestions);
  }

  bool _isKanjiAt(String source, int index) {
    if (index < 0 || index >= source.length) {
      return false;
    }
    final rune = source.codeUnitAt(index);
    return (rune >= 0x4E00 && rune <= 0x9FFF) ||
        (rune >= 0x3400 && rune <= 0x4DBF) ||
        (rune >= 0xF900 && rune <= 0xFAFF) ||
        rune == 0x3005;
  }

  bool _startsWithAny(String text, List<String> prefixes) {
    for (final prefix in prefixes) {
      if (text.startsWith(prefix)) {
        return true;
      }
    }
    return false;
  }

  PronunciationDecision _apply(
    PronunciationCandidate candidate,
    String surface,
    PronunciationReason reason,
  ) {
    return PronunciationDecision(
      start: candidate.start,
      end: candidate.end,
      surface: surface,
      reading: candidate.rule.reading,
      ruleId: candidate.rule.id,
      status: PronunciationDecisionStatus.applied,
      reason: reason,
      locked: false,
    );
  }

  PronunciationDecision _skip(
    PronunciationCandidate candidate,
    String surface,
    PronunciationReason reason,
  ) {
    return PronunciationDecision(
      start: candidate.start,
      end: candidate.end,
      surface: surface,
      reading: candidate.rule.reading,
      ruleId: candidate.rule.id,
      status: PronunciationDecisionStatus.skipped,
      reason: reason,
      locked: false,
    );
  }
}
