import 'package:pixez/page/novel/tts/pronunciation/models/morphology_token.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_rule.dart';
import 'package:pixez/page/novel/tts/pronunciation/morphology/ipadic_japanese_analyzer.dart';
import 'package:pixez/page/novel/tts/pronunciation/morphology/japanese_morphology_analyzer.dart';
import 'package:pixez/page/novel/tts/pronunciation/morphology/lexicon_japanese_analyzer.dart';
import 'package:pixez/page/novel/tts/pronunciation/morphology/morphology_offset_mapper.dart';

class PronunciationWorker {
  /// [analyzer] is tried first; when it cannot start (the dictionary asset is
  /// missing or fails to load) [fallback] takes over for the rest of the
  /// process, so a broken asset degrades accuracy instead of turning name
  /// aliases off.
  PronunciationWorker({
    JapaneseMorphologyAnalyzer? analyzer,
    JapaneseMorphologyAnalyzer? fallback,
    MorphologyOffsetMapper mapper = const MorphologyOffsetMapper(),
  }) : _primary = analyzer ?? IpadicJapaneseAnalyzer(),
       _fallback =
           fallback ?? (analyzer == null ? LexiconJapaneseAnalyzer() : null),
       _mapper = mapper;

  final JapaneseMorphologyAnalyzer _primary;
  final JapaneseMorphologyAnalyzer? _fallback;
  final MorphologyOffsetMapper _mapper;
  JapaneseMorphologyAnalyzer? _active;
  Future<void>? _primaryLoad;
  var _primaryReady = false;
  var _primaryFailed = false;
  var _fallbackReady = false;
  var _failed = false;
  var sessionGeneration = 0;

  String get capability =>
      _failed ? 'unavailable' : (_active ?? _primary).capability;

  JapaneseMorphologyAnalyzer get analyzer => _active ?? _primary;

  /// Waits a bounded time for the primary analyzer. A slow first load (the
  /// dictionary is inflated once per process) is served by the fallback in the
  /// meantime and keeps loading, so the next region uses the full analyzer.
  Future<bool> warmUp() async {
    if (_primaryReady) {
      _active = _primary;
      return true;
    }
    if (!_primaryFailed) {
      _primaryLoad ??= _primary.warmUp().then(
        (_) => _primaryReady = true,
        onError: (Object _) => _primaryFailed = true,
      );
      try {
        await _primaryLoad!.timeout(PronunciationLimits.warmUpTimeout);
      } catch (_) {}
      if (_primaryReady) {
        _active = _primary;
        return true;
      }
    }
    final fallback = _fallback;
    if (fallback != null) {
      if (!_fallbackReady) {
        try {
          await fallback.warmUp().timeout(PronunciationLimits.warmUpTimeout);
          _fallbackReady = true;
        } catch (_) {}
      }
      if (_fallbackReady) {
        _active = fallback;
        return true;
      }
    }
    if (_primaryFailed) {
      _failed = true;
    }
    return false;
  }

  Future<MorphologyResult?> analyzeRegion({
    required String text,
    required String requestId,
    required int generation,
    Iterable<String> userWords = const [],
  }) async {
    if (generation != sessionGeneration) {
      return null;
    }
    final ready = await warmUp();
    if (!ready) {
      return const MorphologyResult(
        tokens: [],
        valid: false,
        reason: 'analyzerUnavailable',
      );
    }
    try {
      final raw = await _active!
          .analyze(text, requestId: requestId, userWords: userWords)
          .timeout(PronunciationLimits.regionTimeout);
      if (generation != sessionGeneration) {
        return null;
      }
      return _mapper.mapToRegion(
        text,
        raw.tokens,
        exactBoundaries: raw.exactBoundaries,
      );
    } catch (_) {
      return const MorphologyResult(
        tokens: [],
        valid: false,
        reason: 'analyzerTimeout',
      );
    }
  }

  Future<void> dispose() async {
    sessionGeneration++;
    await _primary.dispose();
    await _fallback?.dispose();
  }
}
