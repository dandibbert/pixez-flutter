import 'dart:convert';

import 'package:pixez/er/prefer.dart';
import 'package:pixez/page/novel/tts/novel_tts_readings.dart';
import 'package:pixez/page/novel/tts/novel_tts_settings.dart';
import 'package:pixez/page/novel/tts/pronunciation/matching/pronunciation_compiler.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_entity.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_rule.dart';
import 'package:pixez/page/novel/tts/pronunciation/storage/pronunciation_migration.dart';

class PronunciationStore {
  const PronunciationStore({
    this.schemaVersion = PronunciationLimits.schemaVersion,
    this.entities = const [],
    this.rules = const [],
    this.v1Completed = false,
    this.completedAt = 0,
  });

  final int schemaVersion;
  final List<PronunciationEntity> entities;
  final List<PronunciationRule> rules;
  final bool v1Completed;
  final int completedAt;

  PronunciationStore copyWith({
    List<PronunciationEntity>? entities,
    List<PronunciationRule>? rules,
    bool? v1Completed,
    int? completedAt,
  }) {
    return PronunciationStore(
      schemaVersion: schemaVersion,
      entities: entities ?? this.entities,
      rules: rules ?? this.rules,
      v1Completed: v1Completed ?? this.v1Completed,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': schemaVersion,
      'entities': [for (final entity in entities) entity.toJson()],
      'rules': [for (final rule in rules) rule.toJson()],
      'migration': {
        'v1Completed': v1Completed,
        'completedAt': completedAt,
      },
    };
  }

  factory PronunciationStore.fromJson(Map<String, dynamic> json) {
    final migration = json['migration'] as Map? ?? const {};
    return PronunciationStore(
      schemaVersion:
          (json['schemaVersion'] as num?)?.toInt() ??
          PronunciationLimits.schemaVersion,
      entities: [
        for (final item in json['entities'] as List? ?? const [])
          if (item is Map)
            PronunciationEntity.fromJson(Map<String, dynamic>.from(item)),
      ],
      rules: [
        for (final item in json['rules'] as List? ?? const [])
          if (item is Map)
            PronunciationRule.fromJson(Map<String, dynamic>.from(item)),
      ],
      v1Completed: migration['v1Completed'] as bool? ?? false,
      completedAt: (migration['completedAt'] as num?)?.toInt() ?? 0,
    );
  }
}

class PronunciationRepository {
  PronunciationRepository({
    this.storeKey = prefKey,
    this.backupKey = v1BackupKey,
    PronunciationCompiler? compiler,
    PronunciationMigration migration = const PronunciationMigration(),
  }) : _compiler = compiler ?? PronunciationCompiler(),
       _migration = migration;

  static const prefKey = 'novel_tts_pronunciation_v2';
  static const v1BackupKey = 'novel_tts_readings_v1_backup';

  final String storeKey;
  final String backupKey;
  final PronunciationCompiler _compiler;
  final PronunciationMigration _migration;

  Future<PronunciationStore> load() async {
    final raw = Prefer.getString(storeKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return PronunciationStore.fromJson(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {}
    }
    return const PronunciationStore();
  }

  Future<void> save(PronunciationStore store) {
    return Prefer.setString(storeKey, jsonEncode(store.toJson()));
  }

  Future<PronunciationStore> migrateFromSettingsIfNeeded({
    List<NovelTtsReading>? readings,
    int? nowMs,
  }) async {
    final current = await load();
    if (current.v1Completed) {
      return current;
    }
    final source = readings ?? NovelTtsSettings.load().readings;
    final existingBackup = Prefer.getString(backupKey);
    if (existingBackup == null || existingBackup.isEmpty) {
      await Prefer.setString(
        backupKey,
        jsonEncode([for (final reading in source) reading.toJson()]),
      );
    }
    final migrated = _migration.migrateV1(
      source,
      nowMs: nowMs ?? DateTime.now().millisecondsSinceEpoch,
    );
    final next = current.copyWith(
      rules: migrated,
      v1Completed: true,
      completedAt: nowMs ?? DateTime.now().millisecondsSinceEpoch,
    );
    await save(next);
    return next;
  }

  Future<PronunciationSnapshot> snapshotFor({
    required String? workId,
    required String? seriesId,
    List<NovelTtsReading>? settingsReadings,
  }) async {
    var store = await load();
    if (!store.v1Completed &&
        (settingsReadings != null && settingsReadings.isNotEmpty ||
            (NovelTtsSettings.load().readings.isNotEmpty))) {
      store = await migrateFromSettingsIfNeeded(readings: settingsReadings);
    }
    final rules = store.rules;
    if (rules.isEmpty &&
        settingsReadings != null &&
        settingsReadings.isNotEmpty) {
      return _compiler.compile(
        _migration.migrateV1(settingsReadings),
        workId: workId,
        seriesId: seriesId,
      );
    }
    return _compiler.compile(rules, workId: workId, seriesId: seriesId);
  }

  List<NovelTtsReading> asLegacyReadings(PronunciationStore store) {
    return [
      for (final rule in store.rules)
        if (rule.enabled)
          NovelTtsReading(surface: rule.surface, reading: rule.reading),
    ];
  }
}
