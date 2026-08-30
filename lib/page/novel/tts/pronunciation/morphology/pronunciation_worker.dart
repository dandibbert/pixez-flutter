import 'package:pixez/page/novel/tts/pronunciation/models/morphology_token.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_rule.dart';
import 'package:pixez/page/novel/tts/pronunciation/morphology/boundary_only_japanese_analyzer.dart';
import 'package:pixez/page/novel/tts/pronunciation/morphology/japanese_morphology_analyzer.dart';
import 'package:pixez/page/novel/tts/pronunciation/morphology/morphology_offset_mapper.dart';

class PronunciationWorker {
  PronunciationWorker({
    JapaneseMorphologyAnalyzer? analyzer,
    MorphologyOffsetMapper mapper = const MorphologyOffsetMapper(),
  }) : _analyzer = analyzer ?? BoundaryOnlyJapaneseAnalyzer(),
       _mapper = mapper;

  final JapaneseMorphologyAnalyzer _analyzer;
  final MorphologyOffsetMapper _mapper;
  var _warmed = false;
  var _failed = false;
  var sessionGeneration = 0;

  String get capability => _failed ? 'unavailable' : _analyzer.capability;

  JapaneseMorphologyAnalyzer get analyzer => _analyzer;

  Future<bool> warmUp() async {
    if (_failed) {
      return false;
    }
    if (_warmed) {
      return true;
    }
    try {
      await _analyzer.warmUp().timeout(PronunciationLimits.warmUpTimeout);
      _warmed = true;
      return true;
    } catch (_) {
      _failed = true;
      return false;
    }
  }

  Future<MorphologyResult?> analyzeRegion({
    required String text,
    required String requestId,
    required int generation,
  }) async {
    if (generation != sessionGeneration) {
      return null;
    }
    if (_failed) {
      return const MorphologyResult(
        tokens: [],
        valid: false,
        reason: 'analyzerUnavailable',
      );
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
      final raw = await _analyzer
          .analyze(text, requestId: requestId)
          .timeout(PronunciationLimits.regionTimeout);
      if (generation != sessionGeneration) {
        return null;
      }
      return _mapper.mapToRegion(text, raw.tokens);
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
    await _analyzer.dispose();
  }
}
