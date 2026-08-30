import 'package:pixez/page/novel/tts/pronunciation/matching/pronunciation_compiler.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/resolved_pronunciation_text.dart';
import 'package:pixez/page/novel/tts/pronunciation/resolution/pronunciation_pipeline.dart';
import 'package:pixez/page/novel/tts/pronunciation/resolution/pronunciation_renderer.dart';

class PronunciationPreviewResult {
  const PronunciationPreviewResult({
    required this.source,
    required this.spoken,
    required this.resolved,
  });

  final String source;
  final String spoken;
  final ResolvedPronunciationText resolved;
}

class PronunciationPreview {
  PronunciationPreview({
    PronunciationPipeline? pipeline,
    this.renderer = const PronunciationRenderer(),
  }) : _pipeline = pipeline ?? PronunciationPipeline();

  final PronunciationPipeline _pipeline;
  final PronunciationRenderer renderer;

  Future<PronunciationPreviewResult> preview({
    required String source,
    required PronunciationSnapshot snapshot,
  }) async {
    final resolved = await _pipeline.resolve(
      document: NovelTtsTextDocument(displayText: source, sourceHash: ''),
      snapshot: snapshot,
      sessionId: 'preview',
    );
    return PronunciationPreviewResult(
      source: source,
      spoken: renderer.renderAll(
        source: source,
        decisions: resolved.appliedDecisions,
      ),
      resolved: resolved,
    );
  }
}
