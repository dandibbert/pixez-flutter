import 'package:pixez/page/novel/tts/novel_tts_readings.dart';
import 'package:pixez/page/novel/tts/novel_tts_settings.dart';
import 'package:pixez/page/novel/tts/pronunciation/matching/pronunciation_compiler.dart';
import 'package:pixez/page/novel/tts/pronunciation/storage/pronunciation_migration.dart';

/// Compiles the user dictionary kept in the TTS settings.
///
/// The settings list is the single source of truth; nothing is copied into a
/// second store that could fall out of step with what the editor shows.
class PronunciationRepository {
  PronunciationRepository({
    PronunciationCompiler? compiler,
    PronunciationMigration migration = const PronunciationMigration(),
  }) : _compiler = compiler ?? PronunciationCompiler(),
       _migration = migration;

  final PronunciationCompiler _compiler;
  final PronunciationMigration _migration;

  Future<PronunciationSnapshot> snapshotFor({
    required String? workId,
    required String? seriesId,
    List<NovelTtsReading>? settingsReadings,
  }) async {
    final readings = settingsReadings ?? NovelTtsSettings.load().readings;
    return _compiler.compile(
      _migration.migrateV1(readings),
      workId: workId,
      seriesId: seriesId,
    );
  }
}
