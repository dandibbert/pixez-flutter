import 'package:pixez/page/novel/tts/novel_tts_readings.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_rule.dart';

class PronunciationMigration {
  const PronunciationMigration();

  static final _han = RegExp(r'^[\u3400-\u9FFF\uF900-\uFAFF]+$');
  static final _kana = RegExp(r'^[\u3040-\u309F\u30A0-\u30FFー]+$');

  List<PronunciationRule> migrateV1(Iterable<NovelTtsReading> readings) {
    final rules = <PronunciationRule>[];
    var index = 0;
    for (final reading in readings) {
      if (!reading.isValid) {
        continue;
      }
      final trimmed = reading.trimmed();
      final classified = classifyV1Surface(trimmed.surface);
      final mode = trimmed.mode ?? classified.mode;
      rules.add(
        PronunciationRule(
          id: trimmed.id ?? 'migrated-v1-$index',
          surface: trimmed.surface,
          reading: trimmed.reading,
          mode: mode,
          scope: trimmed.scope,
          priority: 0,
          // Only the guessed classification may leave a rule off; a mode the
          // user picked is a mode the user wants applied.
          enabled: trimmed.isActive,
          // Entries without an edit time fall back to their position, which
          // keeps "later in the list wins" for them and loses to any entry
          // edited since.
          updatedAtEpochMs: trimmed.updatedAt > 0 ? trimmed.updatedAt : index,
          needsReview: trimmed.mode == null && classified.needsReview,
        ),
      );
      index++;
    }
    return rules;
  }

  ({PronunciationMatchMode mode, bool enabled, bool needsReview})
  classifyV1Surface(String surface) {
    if (surface.runes.length >= 2) {
      return (
        mode: PronunciationMatchMode.exactPhrase,
        enabled: true,
        needsReview: false,
      );
    }
    if (_han.hasMatch(surface)) {
      return (
        mode: PronunciationMatchMode.nameAlias,
        enabled: true,
        needsReview: true,
      );
    }
    if (_kana.hasMatch(surface) || _isDigitOrSymbol(surface)) {
      return (
        mode: PronunciationMatchMode.force,
        enabled: false,
        needsReview: true,
      );
    }
    return (
      mode: PronunciationMatchMode.nameAlias,
      enabled: true,
      needsReview: true,
    );
  }

  bool _isDigitOrSymbol(String surface) {
    if (surface.isEmpty) {
      return false;
    }
    final rune = surface.runes.first;
    return rune < 0x80;
  }
}
