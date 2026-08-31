import 'package:pixez/page/novel/tts/novel_tts_readings.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_rule.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_scope.dart';

class PronunciationMigration {
  const PronunciationMigration();

  static final _han = RegExp(r'^[\u3400-\u9FFF\uF900-\uFAFF]+$');
  static final _kana = RegExp(
    r'^[\u3040-\u309F\u30A0-\u30FFー]+$',
  );

  List<PronunciationRule> migrateV1(
    Iterable<NovelTtsReading> readings, {
    int nowMs = 0,
  }) {
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
          id: 'migrated-v1-$index',
          surface: trimmed.surface,
          reading: trimmed.reading,
          mode: mode,
          scope: const PronunciationScope(type: PronunciationScopeType.global),
          priority: 0,
          enabled: trimmed.mode == PronunciationMatchMode.force
              ? true
              : classified.enabled,
          updatedAtEpochMs: nowMs,
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
