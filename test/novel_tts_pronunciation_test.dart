import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/er/prefer.dart';
import 'package:pixez/page/novel/tts/novel_tts_readings.dart';
import 'package:pixez/page/novel/tts/novel_tts_text.dart';
import 'package:pixez/page/novel/tts/pronunciation/diagnostics/pronunciation_preview.dart';
import 'package:pixez/page/novel/tts/pronunciation/matching/pronunciation_compiler.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_decision.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_rule.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_scope.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/resolved_pronunciation_text.dart';
import 'package:pixez/page/novel/tts/pronunciation/morphology/boundary_only_japanese_analyzer.dart';
import 'package:pixez/page/novel/tts/pronunciation/morphology/morphology_offset_mapper.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/morphology_token.dart';
import 'package:pixez/page/novel/tts/pronunciation/resolution/pronunciation_pipeline.dart';
import 'package:pixez/page/novel/tts/pronunciation/resolution/pronunciation_renderer.dart';
import 'package:pixez/page/novel/tts/pronunciation/resolution/source_aware_splitter.dart';
import 'package:pixez/page/novel/tts/pronunciation/storage/pronunciation_migration.dart';
import 'package:pixez/page/novel/tts/pronunciation/storage/pronunciation_repository.dart';
import 'package:pixez/page/novel/viewer/novel_ruby.dart';
import 'package:pixez/page/novel/viewer/novel_spans.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefer.init();
  });

  final compiler = PronunciationCompiler();
  final pipeline = PronunciationPipeline();
  final renderer = const PronunciationRenderer();

  PronunciationRule phrase(
    String id,
    String surface,
    String reading, {
    PronunciationScopeType scope = PronunciationScopeType.work,
    String? scopeId = 'work-1',
    PronunciationMatchMode mode = PronunciationMatchMode.exactPhrase,
  }) {
    return PronunciationRule(
      id: id,
      surface: surface,
      reading: reading,
      mode: mode,
      scope: PronunciationScope(type: scope, scopeId: scopeId),
      priority: 0,
      enabled: true,
      updatedAtEpochMs: 1,
    );
  }

  Future<String> spoken(
    String source, {
    PronunciationScopeType aliasScope = PronunciationScopeType.work,
  }) async {
    final snapshot = compiler.compile([
      phrase('full', '五条悟', 'ごじょうさとる'),
      phrase(
        'alias',
        '悟',
        'さとる',
        mode: PronunciationMatchMode.nameAlias,
        scope: aliasScope,
        scopeId: aliasScope == PronunciationScopeType.global ? null : 'work-1',
      ),
    ], workId: 'work-1');
    final resolved = await pipeline.resolve(
      document: NovelTtsTextDocument(displayText: source),
      snapshot: snapshot,
    );
    return renderer.renderAll(
      source: source,
      decisions: resolved.appliedDecisions,
    );
  }

  test('characterization: longest v1 replacement still works', () {
    expect(
      applyNovelTtsReadings('今日は銀行に行く。', const [
        NovelTtsReading(surface: '行', reading: 'こう'),
        NovelTtsReading(surface: '行く', reading: 'いく'),
        NovelTtsReading(surface: '銀行', reading: 'ぎんこう'),
        NovelTtsReading(surface: '今日', reading: 'きょう'),
      ]),
      'きょうはぎんこうにいく。',
    );
  });

  test('work-scoped alias accepts name uses and rejects verb forms', () async {
    expect(await spoken('悟は笑った。'), 'さとるは笑った。');
    expect(await spoken('真相を悟った。'), '真相を悟った。');
    expect(await spoken('彼は悟る。'), '彼は悟る。');
    expect(await spoken('悟りを開く。'), '悟りを開く。');
    expect(await spoken('悟れば分かる。'), '悟れば分かる。');
    expect(await spoken('悟れ。'), '悟れ。');
    expect(await spoken('悟ろうとした。'), '悟ろうとした。');
    expect(await spoken('悟らない。'), '悟らない。');
    expect(await spoken('五条悟は笑った。'), 'ごじょうさとるは笑った。');
    expect(await spoken('五条悟はすべてを悟った。'), 'ごじょうさとるはすべてを悟った。');
    expect(await spoken('孫悟空が来た。'), '孫悟空が来た。');
    expect(await spoken('悟空が来た。'), '悟空が来た。');
    expect(await spoken('「悟！」'), '「さとる！」');
    expect(await spoken('悟さん'), 'さとるさん');
    expect(await spoken('悟君'), 'さとる君');
    expect(await spoken('悟自身'), 'さとる自身');
    expect(await spoken('悟だけが知っている'), 'さとるだけが知っている');
    expect(await spoken('悟って誰？'), 'さとるって誰？');
    expect(await spoken('悟ってしまった。'), '悟ってしまった。');
  });

  test('global single-kanji alias does not accept a particle alone', () async {
    expect(
      await spoken('悟は笑った。', aliasScope: PronunciationScopeType.global),
      '悟は笑った。',
    );
    expect(
      await spoken('悟さん', aliasScope: PronunciationScopeType.global),
      'さとるさん',
    );
  });

  test('explicit ruby wins over the dictionary', () async {
    final snapshot = compiler.compile([
      phrase('full', '五条悟', 'ごじょうさとる'),
    ], workId: 'work-1');
    final document = novelTtsDocumentFromSpans([
      NovelSpansData(NovelSpansType.rb, parseNovelRubyMarkup('[[rb:五条悟＞ごじょう]]')!.encoded),
      NovelSpansData(NovelSpansType.normal, 'は笑った。'),
    ]);
    expect(document.displayText, '五条悟は笑った。');
    expect(document.rubyAnnotations, isNotEmpty);
    final resolved = await pipeline.resolve(
      document: document,
      snapshot: snapshot,
    );
    expect(
      renderer.renderAll(source: document.displayText, decisions: resolved.appliedDecisions),
      'ごじょうは笑った。',
    );
    expect(
      resolved.appliedDecisions.single.reason,
      PronunciationReason.explicitRuby,
    );
  });

  test('work scope beats global for the same surface', () async {
    final snapshot = compiler.compile([
      phrase(
        'global',
        '悟',
        'さとる-global',
        mode: PronunciationMatchMode.nameAlias,
        scope: PronunciationScopeType.global,
        scopeId: null,
      ),
      phrase(
        'work',
        '悟',
        'さとる',
        mode: PronunciationMatchMode.nameAlias,
      ),
    ], workId: 'work-1');
    final resolved = await pipeline.resolve(
      document: const NovelTtsTextDocument(displayText: '悟さん'),
      snapshot: snapshot,
    );
    expect(
      renderer.renderAll(
        source: '悟さん',
        decisions: resolved.appliedDecisions,
      ),
      'さとるさん',
    );
  });

  test('emoji before a candidate does not shift UTF-16 ranges', () async {
    const source = '😀悟は笑った。';
    expect(await spoken(source), '😀さとるは笑った。');
  });

  test('splitter does not cut an applied full name', () {
    const source = '五条悟は笑った。続き。';
    final ranges = const SourceAwareNovelTtsSplitter().split(
      displayText: source,
      appliedDecisions: [
        PronunciationDecision(
          start: 0,
          end: 3,
          surface: '五条悟',
          reading: 'ごじょうさとる',
          ruleId: 'full',
          status: PronunciationDecisionStatus.applied,
          reason: PronunciationReason.exactPhrase,
          locked: false,
        ),
      ],
      budget: const RuneTtsTextBudget(20),
    );
    expect(ranges, isNotEmpty);
    expect(ranges.any((range) => range.start > 0 && range.start < 3), isFalse);
    expect(source.substring(0, 3), '五条悟');
  });

  test('spoken budget splits again when readings expand', () {
    const source = 'AAAAABBBBBCCCCC';
    final ranges = const SourceAwareNovelTtsSplitter().split(
      displayText: source,
      appliedDecisions: [
        PronunciationDecision(
          start: 0,
          end: 5,
          surface: 'AAAAA',
          reading: 'aaaaaaaaaa',
          ruleId: 'a',
          status: PronunciationDecisionStatus.applied,
          reason: PronunciationReason.forcedRule,
          locked: false,
        ),
      ],
      budget: const RuneTtsTextBudget(12),
    );
    expect(ranges.length, greaterThan(1));
    expect(ranges.first.end, greaterThanOrEqualTo(5));
  });

  test('a single oversized reading is an explicit error', () {
    expect(
      () => const SourceAwareNovelTtsSplitter().split(
        displayText: '悟',
        appliedDecisions: [
          PronunciationDecision(
            start: 0,
            end: 1,
            surface: '悟',
            reading: 'さとるさとるさとるさとる',
            ruleId: 'a',
            status: PronunciationDecisionStatus.applied,
            reason: PronunciationReason.forcedRule,
            locked: false,
          ),
        ],
        budget: const RuneTtsTextBudget(4),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('v1 migration classifies kanji aliases and longer phrases', () {
    final rules = const PronunciationMigration().migrateV1(const [
      NovelTtsReading(surface: '五条悟', reading: 'ごじょうさとる'),
      NovelTtsReading(surface: '悟', reading: 'さとる'),
      NovelTtsReading(surface: 'あ', reading: 'ア'),
    ]);
    expect(rules[0].mode, PronunciationMatchMode.exactPhrase);
    expect(rules[0].needsReview, isFalse);
    expect(rules[1].mode, PronunciationMatchMode.nameAlias);
    expect(rules[1].needsReview, isTrue);
    expect(rules[2].mode, PronunciationMatchMode.force);
    expect(rules[2].enabled, isFalse);
  });

  test('repository migration is idempotent and keeps a v1 backup', () async {
    final repo = PronunciationRepository();
    final first = await repo.migrateFromSettingsIfNeeded(
      readings: const [NovelTtsReading(surface: '今日', reading: 'きょう')],
      nowMs: 10,
    );
    final second = await repo.migrateFromSettingsIfNeeded(
      readings: const [NovelTtsReading(surface: '別', reading: 'べつ')],
      nowMs: 20,
    );
    expect(first.rules, hasLength(1));
    expect(second.rules.single.surface, '今日');
    expect(Prefer.getString(PronunciationRepository.v1BackupKey), isNotEmpty);
  });

  test('preview explains applied and skipped decisions', () async {
    final snapshot = compiler.compile([
      phrase(
        'alias',
        '悟',
        'さとる',
        mode: PronunciationMatchMode.nameAlias,
      ),
    ], workId: 'work-1');
    final preview = await PronunciationPreview().preview(
      source: '悟は笑った。彼はすべてを悟った。',
      snapshot: snapshot,
    );
    expect(preview.spoken, 'さとるは笑った。彼はすべてを悟った。');
    expect(
      preview.resolved.allDecisions.any(
        (d) => d.status == PronunciationDecisionStatus.applied,
      ),
      isTrue,
    );
    expect(
      preview.resolved.allDecisions.any(
        (d) => d.reason == PronunciationReason.rejectedInflectionSuffix,
      ),
      isTrue,
    );
  });

  test('offset mapper rejects untrusted analyzer positions', () {
    const mapper = MorphologyOffsetMapper();
    final result = mapper.mapToRegion('悟は笑った。', const [
      MorphologyToken(start: 99, end: 100, surface: '悟'),
    ]);
    expect(result.valid, isTrue);
    expect(result.tokens.single.start, 0);
    final invalid = mapper.mapToRegion('真相を悟った。', const [
      MorphologyToken(start: 0, end: 1, surface: '悟'),
    ]);
    expect(invalid.valid, isFalse);
  });

  test('same snapshot yields the same decisions', () async {
    final snapshot = compiler.compile([
      phrase(
        'alias',
        '悟',
        'さとる',
        mode: PronunciationMatchMode.nameAlias,
      ),
    ], workId: 'work-1');
    const source = '悟は笑った。真相を悟った。';
    final first = await pipeline.resolve(
      document: const NovelTtsTextDocument(displayText: source),
      snapshot: snapshot,
    );
    final second = await pipeline.resolve(
      document: const NovelTtsTextDocument(displayText: source),
      snapshot: snapshot,
    );
    expect(
      first.appliedDecisions.map((d) => '${d.start}:${d.end}:${d.reading}'),
      second.appliedDecisions.map((d) => '${d.start}:${d.end}:${d.reading}'),
    );
    expect(first.displayText, source);
  });

  test('boundary analyzer keeps surrogate pairs intact', () {
    final tokens = tokenizeJapaneseBoundaries('😀悟');
    expect(tokens.first.surface, '😀');
    expect(tokens.last.surface, '悟');
    expect(tokens.first.end, 2);
  });
}
