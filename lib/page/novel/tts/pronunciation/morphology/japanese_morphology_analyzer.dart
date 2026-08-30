import 'package:pixez/page/novel/tts/pronunciation/models/morphology_token.dart';

abstract interface class JapaneseMorphologyAnalyzer {
  String get analyzerId;
  String get analyzerVersion;
  bool get supportsPartOfSpeech;
  String get capability;

  Future<void> warmUp();

  Future<MorphologyResult> analyze(
    String text, {
    required String requestId,
  });

  Future<void> dispose();
}
