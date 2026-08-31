import 'package:pixez/page/novel/tts/pronunciation/models/morphology_token.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_decision.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_rule.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_scope.dart';

const japaneseHonorifics = <String>[
  'さん',
  'ちゃん先輩',
  'ちゃん',
  'くん',
  '君',
  '様',
  'さま',
  '氏',
  '先生',
  '先輩',
  '殿',
];

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
  '自身',
];

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
      return _skip(
        candidate,
        surface,
        PronunciationReason.invalidSourceRange,
      );
    }
    if (candidate.rule.mode == PronunciationMatchMode.force) {
      return _apply(candidate, surface, PronunciationReason.forcedRule);
    }
    if (candidate.rule.mode == PronunciationMatchMode.exactPhrase) {
      return _apply(candidate, surface, PronunciationReason.exactPhrase);
    }

    if (morphology != null && !morphology.valid) {
      return _skip(
        candidate,
        surface,
        morphology.reason == 'analyzerTimeout'
            ? PronunciationReason.analyzerTimeout
            : PronunciationReason.invalidAnalyzerOffsets,
      );
    }
    if (!analyzerAvailable || morphology == null) {
      return _skip(candidate, surface, PronunciationReason.analyzerUnavailable);
    }

    final token = _coveringToken(morphology.tokens, candidate);
    if (token == null) {
      return _skip(candidate, surface, PronunciationReason.rejectedLowConfidence);
    }
    if (token.start < candidate.start || token.end > candidate.end) {
      final trailing = source.substring(candidate.end, token.end);
      if (token.start == candidate.start &&
          _startsWithAny(trailing, japaneseHonorifics)) {
        return _apply(
          candidate,
          surface,
          PronunciationReason.morphologyProperName,
        );
      }
      if (token.start == candidate.start &&
          _isWorkOrSeries(candidate.rule.scope) &&
          _startsWithAny(trailing, japaneseNameParticles)) {
        return _apply(
          candidate,
          surface,
          PronunciationReason.workScopedNameContext,
        );
      }
      return _skip(
        candidate,
        surface,
        PronunciationReason.rejectedInsideLargerToken,
      );
    }
    if (_looksLikeVerbOrAdjective(token)) {
      return _skip(
        candidate,
        surface,
        PronunciationReason.rejectedVerbOrAdjective,
      );
    }

    final after = source.substring(candidate.end);
    if (_startsWithAny(after, japaneseInflectionSuffixes) &&
        !_isQuotativeWho(after, candidate.rule.scope)) {
      return _skip(
        candidate,
        surface,
        PronunciationReason.rejectedInflectionSuffix,
      );
    }
    if (_isQuotativeWho(after, candidate.rule.scope)) {
      return _apply(
        candidate,
        surface,
        PronunciationReason.quotativeNameContext,
      );
    }
    if (_isQuotedVocative(source, candidate) ||
        _startsWithAny(after, japaneseHonorifics)) {
      return _apply(
        candidate,
        surface,
        PronunciationReason.morphologyProperName,
      );
    }
    if (_hasNameParticleContext(source, candidate) &&
        (_isWorkOrSeries(candidate.rule.scope) ||
            candidate.rule.surface.runes.length >= 2)) {
      return _apply(
        candidate,
        surface,
        PronunciationReason.workScopedNameContext,
      );
    }
    return _skip(candidate, surface, PronunciationReason.rejectedLowConfidence);
  }

  bool _hasNameParticleContext(
    String source,
    PronunciationCandidate candidate,
  ) {
    final after = source.substring(candidate.end);
    if (_startsWithAny(after, japaneseNameParticles)) {
      return true;
    }
    return _precededByNameParticle(source, candidate.start);
  }

  bool _precededByNameParticle(String source, int start) {
    for (final particle in japaneseNameParticles) {
      if (start >= particle.length &&
          source.substring(start - particle.length, start) == particle) {
        return true;
      }
    }
    return false;
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
    if (token.partOfSpeech.any((pos) {
      final lower = pos.toLowerCase();
      return pos.contains('動詞') ||
          pos.contains('形容') ||
          lower.contains('verb') ||
          lower.contains('adjective');
    })) {
      return true;
    }
    final basic = token.basicForm;
    return basic.isNotEmpty &&
        basic != token.surface &&
        (basic.endsWith('る') || basic.endsWith('だ') || basic.endsWith('い'));
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

  bool _isQuotativeWho(String after, PronunciationScope scope) {
    if (!_isWorkOrSeries(scope) || !after.startsWith('って')) {
      return false;
    }
    final rest = after.substring('って'.length);
    return _startsWithAny(rest, japanesePersonQuestions);
  }

  bool _isWorkOrSeries(PronunciationScope scope) {
    return scope.type == PronunciationScopeType.work ||
        scope.type == PronunciationScopeType.series;
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
