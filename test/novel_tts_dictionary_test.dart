import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/page/novel/tts/novel_tts_readings.dart';
import 'package:pixez/page/novel/tts/pronunciation/diagnostics/pronunciation_preview.dart';
import 'package:pixez/page/novel/tts/pronunciation/matching/pronunciation_compiler.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_rule.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_scope.dart';
import 'package:pixez/page/novel/tts/pronunciation/storage/pronunciation_migration.dart';

const _work = PronunciationScope(
  type: PronunciationScopeType.work,
  scopeId: '7',
);

Future<String> _speak(String source, List<NovelTtsReading> readings) async {
  final snapshot = PronunciationCompiler().compile(
    const PronunciationMigration().migrateV1(readings),
    workId: '7',
  );
  final preview = await PronunciationPreview().preview(
    source: source,
    snapshot: snapshot,
  );
  return preview.spoken;
}

void main() {
  test(
    'the later of two legacy duplicates wins, whatever their index',
    () async {
      // Ids used to break the tie as strings, so entry 10 beat entry 2 but
      // entry 3 lost to entry 1.
      final readings = [
        for (var i = 0; i < 11; i++)
          NovelTtsReading(surface: '今日$i', reading: 'x$i'),
      ];
      readings[2] = const NovelTtsReading(surface: '明日', reading: 'あした');
      readings[10] = const NovelTtsReading(surface: '明日', reading: 'あす');
      readings[1] = const NovelTtsReading(surface: '昨日', reading: 'さくじつ');
      readings[3] = const NovelTtsReading(surface: '昨日', reading: 'きのう');
      final stored = readingsFromJson([
        for (final reading in readings) reading.toJson(),
      ]);
      expect(await _speak('明日と昨日', stored), 'あすときのう');
    },
  );

  test(
    'an edited entry beats an older one for the same written form',
    () async {
      final readings = [
        const NovelTtsReading(
          id: 'new',
          surface: '明日',
          reading: 'あした',
          updatedAt: 2000,
        ),
        const NovelTtsReading(
          id: 'old',
          surface: '明日',
          reading: 'あす',
          updatedAt: 1000,
        ),
      ];
      expect(await _speak('明日', readings), 'あした');
    },
  );

  test('saving replaces the entry for the same written form and scope', () {
    const global = NovelTtsReading(id: 'a', surface: '悟', reading: 'さとる');
    const scoped = NovelTtsReading(
      id: 'b',
      surface: '悟',
      reading: 'さとし',
      scope: _work,
    );
    const other = NovelTtsReading(id: 'c', surface: '今日', reading: 'きょう');
    final list = [global, scoped, other];

    final replaced = upsertNovelTtsReading(
      list,
      const NovelTtsReading(id: 'd', surface: '悟', reading: 'ご'),
    );
    expect(replaced.map((r) => (r.id, r.reading)), [
      ('d', 'ご'),
      ('b', 'さとし'),
      ('c', 'きょう'),
    ]);
    expect(
      conflictingNovelTtsReading(
        list,
        const NovelTtsReading(surface: '悟', reading: 'ご'),
      )?.id,
      'a',
    );

    final edited = upsertNovelTtsReading(list, other.copyWith(reading: 'こんにち'));
    expect(edited.map((r) => r.reading), ['さとる', 'さとし', 'こんにち']);
  });

  test('pasting a list updates existing entries and reports counts', () {
    final existing = [
      const NovelTtsReading(
        id: 'a',
        surface: '今日',
        reading: 'こんにち',
        mode: PronunciationMatchMode.exactPhrase,
      ),
      const NovelTtsReading(
        id: 'b',
        surface: '明日',
        reading: 'あす',
        mode: PronunciationMatchMode.exactPhrase,
      ),
    ];
    final parsed = parseNovelTtsReadingImport(
      '今日=きょう\n明日=あす\nは=わ\n悟=さとる|exact\nbroken line\n# note',
    );
    expect(parsed.skipped, ['broken line']);
    final merged = mergeNovelTtsReadings(existing, parsed.readings, nowMs: 5);
    expect(merged.added, 2);
    expect(merged.updated, 1);
    expect(merged.unchanged, 1);
    expect(merged.readings.first.id, 'a');
    expect(merged.readings.first.reading, 'きょう');
    final kana = merged.readings.firstWhere((r) => r.surface == 'は');
    // Same as the add dialog: the mode is written down and the entry is on.
    expect(kana.mode, PronunciationMatchMode.force);
    expect(kana.isActive, isTrue);
    final named = merged.readings.firstWhere((r) => r.surface == '悟');
    expect(named.mode, PronunciationMatchMode.exactPhrase);
  });

  test('a legacy lone kana is visibly off until turned on', () {
    final stored = readingsFromJson([
      {'surface': 'は', 'reading': 'わ'},
    ]).single;
    expect(stored.enabled, isTrue);
    expect(stored.isActive, isFalse);
    expect(stored.effectiveMode, PronunciationMatchMode.force);
    final confirmed = stored.copyWith(mode: stored.effectiveMode);
    expect(confirmed.isActive, isTrue);
    expect(
      const PronunciationMigration().migrateV1([confirmed]).single.enabled,
      isTrue,
    );
  });

  test('stored entries keep ids, scope and switches across a round trip', () {
    final first = readingsFromJson([
      {'surface': '今日', 'reading': 'きょう'},
      {'surface': '明日', 'reading': 'あした'},
    ]);
    expect(first.map((r) => r.id), ['legacy-0', 'legacy-1']);
    final edited = [
      first[1].copyWith(enabled: false),
      first[0].copyWith(scope: _work, scopeLabel: 'Story'),
    ];
    final again = readingsFromJson([for (final r in edited) r.toJson()]);
    expect(again.map((r) => r.id), ['legacy-1', 'legacy-0']);
    expect(again[0].enabled, isFalse);
    expect(again[1].scope, _work);
    expect(again[1].scopeLabel, 'Story');
  });

  test('export writes every mode so a paste restores the same entries', () {
    const readings = [
      NovelTtsReading(surface: '悟', reading: 'さとる'),
      NovelTtsReading(
        surface: '今日',
        reading: 'きょう',
        mode: PronunciationMatchMode.force,
      ),
    ];
    final text = formatNovelTtsReadingLines(readings);
    expect(text, '悟=さとる|alias\n今日=きょう|force');
    final back = parseNovelTtsReadingLines(text);
    expect(back.map((r) => r.mode), [
      PronunciationMatchMode.nameAlias,
      PronunciationMatchMode.force,
    ]);
  });

  test('matching ignores letter case and full-width forms', () async {
    const readings = [
      NovelTtsReading(
        surface: 'ABC',
        reading: 'エービーシー',
        mode: PronunciationMatchMode.exactPhrase,
      ),
    ];
    expect(await _speak('ＡＢＣとabcとAbc', readings), 'エービーシーとエービーシーとエービーシー');
  });

  test('validation names the field that is wrong', () {
    expect(
      const NovelTtsReading(surface: ' ', reading: 'a').validationError,
      'empty_surface',
    );
    expect(
      const NovelTtsReading(surface: 'a', reading: '').validationError,
      'empty_reading',
    );
    expect(
      NovelTtsReading(surface: 'a' * 129, reading: 'b').validationError,
      'surface_too_long',
    );
  });
}
