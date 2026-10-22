import 'package:pixez/page/novel/tts/pronunciation/models/morphology_token.dart';

abstract interface class JapaneseMorphologyAnalyzer {
  String get analyzerId;
  String get analyzerVersion;
  bool get supportsPartOfSpeech;
  String get capability;

  Future<void> warmUp();

  /// [userWords] are written forms the caller wants the analyzer to consider
  /// as words, such as the user's name aliases. Analyzers without a lexicon
  /// to extend ignore them.
  Future<MorphologyResult> analyze(
    String text, {
    required String requestId,
    Iterable<String> userWords = const [],
  });

  Future<void> dispose();
}
