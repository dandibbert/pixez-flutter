import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/er/prefer.dart';
import 'package:pixez/page/novel/tts/novel_tts_readings.dart';
import 'package:pixez/page/novel/tts/novel_tts_settings.dart';
import 'package:pixez/page/novel/tts/novel_tts_text.dart';
import 'package:pixez/page/novel/tts/pronunciation/diagnostics/pronunciation_preview.dart';
import 'package:pixez/page/novel/tts/pronunciation/matching/pronunciation_compiler.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_decision.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_rule.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_scope.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/resolved_pronunciation_text.dart';
import 'package:pixez/page/novel/tts/pronunciation/morphology/boundary_only_japanese_analyzer.dart';
import 'package:pixez/page/novel/tts/pronunciation/morphology/japanese_morphology_analyzer.dart';
import 'package:pixez/page/novel/tts/pronunciation/morphology/lexicon_japanese_analyzer.dart';
import 'package:pixez/page/novel/tts/pronunciation/morphology/morphology_offset_mapper.dart';
import 'package:pixez/page/novel/tts/pronunciation/morphology/pronunciation_worker.dart';
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

  test('a global single-kanji alias behaves like a work-scoped one', () async {
    const global = PronunciationScopeType.global;
    expect(await spoken('悟は笑った。', aliasScope: global), 'さとるは笑った。');
    expect(await spoken('悟さん', aliasScope: global), 'さとるさん');
    expect(await spoken('悟と話した。', aliasScope: global), 'さとると話した。');
    expect(await spoken('真相を悟った。', aliasScope: global), '真相を悟った。');
    expect(await spoken('孫悟空が来た。', aliasScope: global), '孫悟空が来た。');
    expect(await spoken('覚悟を決めた。', aliasScope: global), '覚悟を決めた。');
  });

  test('the analyzer reports part of speech and dictionary forms', () async {
    final analyzer = LexiconJapaneseAnalyzer();
    await analyzer.warmUp();
    expect(analyzer.supportsPartOfSpeech, isTrue);
    expect(analyzer.capability, 'lexicon-pos');

    MorphologyToken tokenFor(String text, String surface) {
      return analyzer
          .tokenize(text)
          .firstWhere((token) => token.surface == surface);
    }

    final verb = tokenFor('真相を悟った。', '悟っ');
    expect(verb.partOfSpeech, contains('動詞'));
    expect(verb.basicForm, '悟る');
    expect(verb.conjugationType, '五段・ラ行');

    final noun = tokenFor('悟は笑った。', '悟');
    expect(noun.partOfSpeech, contains('名詞'));
    expect(noun.conjugationType, isNull);

    final adjective = tokenFor('彼は優しい。', '優しい');
    expect(adjective.partOfSpeech, contains('形容詞'));
    expect(adjective.basicForm, '優しい');

    expect(tokenFor('孫悟空が来た。', '孫悟空').start, 0);
    expect(tokenFor('実に美しい。', '実に').partOfSpeech, contains('副詞'));
  });

  test('an inflection only counts when the auxiliary that needs it follows', () {
    final analyzer = LexiconJapaneseAnalyzer();
    List<String> surfaces(String text) =>
        [for (final token in analyzer.tokenize(text)) token.surface];

    // 直さ is a real 未然形 of 直す, but only in front of a negative.
    expect(surfaces('直さない。'), contains('直さ'));
    expect(surfaces('直そう。'), contains('直そ'));
    expect(surfaces('直せば'), contains('直せ'));
    // A verb spelled without okurigana is indistinguishable from a name.
    expect(surfaces('悟は'), contains('悟'));
  });

  test('homograph aliases apply as names and stay out of other words', () async {
    Future<String> render(String surface, String reading, String source) async {
      final snapshot = compiler.compile([
        phrase(
          'alias',
          surface,
          reading,
          mode: PronunciationMatchMode.nameAlias,
          scope: PronunciationScopeType.global,
          scopeId: null,
        ),
      ]);
      final resolved = await pipeline.resolve(
        document: NovelTtsTextDocument(displayText: source),
        snapshot: snapshot,
      );
      return renderer.renderAll(
        source: source,
        decisions: resolved.appliedDecisions,
      );
    }

    expect(await render('恵', 'めぐみ', '恵は笑った。'), 'めぐみは笑った。');
    expect(await render('恵', 'めぐみ', '恵まれた子だ。'), '恵まれた子だ。');
    expect(await render('恵', 'めぐみ', '知恵を使う。'), '知恵を使う。');
    expect(await render('恵', 'めぐみ', '恵みの雨。'), '恵みの雨。');

    expect(await render('愛', 'まなみ', '愛さんが来た。'), 'まなみさんが来た。');
    expect(await render('愛', 'まなみ', '彼を愛している。'), '彼を愛している。');
    expect(await render('愛', 'まなみ', '愛らしい笑顔。'), '愛らしい笑顔。');
    expect(await render('愛', 'まなみ', '恋愛の話。'), '恋愛の話。');

    expect(await render('光', 'ひかる', '光と話した。'), 'ひかると話した。');
    expect(await render('光', 'ひかる', '目が光った。'), '目が光った。');
    expect(await render('光', 'ひかる', '観光に行く。'), '観光に行く。');

    expect(await render('望', 'のぞむ', '望は帰った。'), 'のぞむは帰った。');
    expect(await render('望', 'のぞむ', '平和を望む。'), '平和を望む。');
    expect(await render('望', 'のぞむ', '望みを託す。'), '望みを託す。');
    expect(await render('望', 'のぞむ', '希望がある。'), '希望がある。');

    expect(await render('歩', 'あゆむ', '歩くん、行こう。'), 'あゆむくん、行こう。');
    expect(await render('歩', 'あゆむ', '道を歩いた。'), '道を歩いた。');
    expect(await render('歩', 'あゆむ', '散歩に出る。'), '散歩に出る。');

    expect(await render('司', 'つかさ', '司の番だ。'), 'つかさの番だ。');
    expect(await render('司', 'つかさ', '国を司る。'), '国を司る。');
    expect(await render('司', 'つかさ', '司会を務める。'), '司会を務める。');

    expect(await render('静', 'しずか', '静も来た。'), 'しずかも来た。');
    expect(await render('静', 'しずか', '静かな夜。'), '静かな夜。');
    expect(await render('静', 'しずか', '嵐が静まる。'), '嵐が静まる。');

    expect(await render('実', 'みのり', '実さんが来た。'), 'みのりさんが来た。');
    expect(await render('実', 'みのり', '実に美しい。'), '実に美しい。');
    expect(await render('実', 'みのり', '実った稲。'), '実った稲。');
    expect(await render('実', 'みのり', '事実を知る。'), '事実を知る。');

    expect(await render('優', 'ゆう', '優と会った。'), 'ゆうと会った。');
    expect(await render('優', 'ゆう', '彼は優しい。'), '彼は優しい。');
    expect(await render('優', 'ゆう', '優れた才能。'), '優れた才能。');
    expect(await render('優', 'ゆう', '優勝した。'), '優勝した。');

    expect(await render('薫', 'かおる', '薫が笑う。'), 'かおるが笑う。');
    expect(await render('薫', 'かおる', '風が薫る。'), '風が薫る。');

    expect(await render('誠', 'まこと', '誠が来た。'), 'まことが来た。');
    expect(await render('誠', 'まこと', '誠実な人。'), '誠実な人。');

    expect(await render('翼', 'つばさ', '翼が呼んだ。'), 'つばさが呼んだ。');
    expect(await render('楓', 'かえで', '楓と歩く。'), 'かえでと歩く。');
    expect(await render('葵', 'あおい', '葵は強い。'), 'あおいは強い。');
  });

  test('a cast of aliases reads a whole excerpt', () async {
    PronunciationRule alias(String id, String surface, String reading) =>
        phrase(
          id,
          surface,
          reading,
          mode: PronunciationMatchMode.nameAlias,
        );
    final snapshot = compiler.compile([
      phrase('full', '五条悟', 'ごじょうさとる'),
      alias('satoru', '悟', 'さとる'),
      alias('megumi', '恵', 'めぐみ'),
      alias('suguru', '傑', 'すぐる'),
      alias('nobara', '棘', 'のばら'),
    ], workId: 'work-1');
    const source =
        '悟は教室の窓際に座っていた。恵が入ってくると、悟は顔を上げて笑った。\n'
        '「悟、また遅刻か」と恵が言う。悟は肩をすくめただけだった。\n'
        'やがて彼は事の重大さを悟った。悟りを開くにはまだ早い。\n'
        '恵まれた環境で育った恵は、知恵を働かせて話を逸らした。\n'
        '「傑！」棘が叫んだ。傑は振り返らなかった。棘の声は震えていた。\n'
        '悟さんと恵さんは幼馴染で、傑くんはその後輩だ。\n'
        '悟って誰？と棘が聞いた。恵は答えなかった。\n'
        '彼女は自分の過ちを悟らないままだった。悟れば話は変わる。';

    final resolved = await pipeline.resolve(
      document: NovelTtsTextDocument(displayText: source),
      snapshot: snapshot,
    );

    expect(
      renderer.renderAll(
        source: source,
        decisions: resolved.appliedDecisions,
      ),
      'さとるは教室の窓際に座っていた。めぐみが入ってくると、さとるは顔を上げて笑った。\n'
      '「さとる、また遅刻か」とめぐみが言う。さとるは肩をすくめただけだった。\n'
      'やがて彼は事の重大さを悟った。悟りを開くにはまだ早い。\n'
      '恵まれた環境で育っためぐみは、知恵を働かせて話を逸らした。\n'
      '「すぐる！」のばらが叫んだ。すぐるは振り返らなかった。のばらの声は震えていた。\n'
      'さとるさんとめぐみさんは幼馴染で、すぐるくんはその後輩だ。\n'
      'さとるって誰？とのばらが聞いた。めぐみは答えなかった。\n'
      '彼女は自分の過ちを悟らないままだった。悟れば話は変わる。',
    );
    // 17 of the 23 written名 land as names; the six left alone are all verb or
    // compound uses. That ratio is the whole point of the feature: the reader
    // configures 悟 once and does not hear さとる in 悟った.
    expect(resolved.appliedDecisions, hasLength(17));
    expect(resolved.allDecisions, hasLength(23));
    expect(resolved.analyzerCapability, 'lexicon-pos');
  });

  test('aliases degrade to boundaries when the analyzer fails', () async {
    final pipeline = PronunciationPipeline(
      worker: PronunciationWorker(analyzer: _BrokenAnalyzer()),
    );
    final snapshot = compiler.compile([
      phrase('full', '五条悟', 'ごじょうさとる'),
      phrase(
        'alias',
        '悟',
        'さとる',
        mode: PronunciationMatchMode.nameAlias,
        scope: PronunciationScopeType.global,
        scopeId: null,
      ),
    ], workId: 'work-1');
    Future<String> render(String source) async {
      final resolved = await pipeline.resolve(
        document: NovelTtsTextDocument(displayText: source),
        snapshot: snapshot,
      );
      return renderer.renderAll(
        source: source,
        decisions: resolved.appliedDecisions,
      );
    }

    // Exact phrases keep working, and the safe alias contexts survive.
    expect(await render('五条悟は笑った。'), 'ごじょうさとるは笑った。');
    expect(await render('悟さん'), 'さとるさん');
    expect(await render('悟は笑った。'), 'さとるは笑った。');
    // Anything that could be okurigana or a compound is left alone.
    expect(await render('真相を悟った。'), '真相を悟った。');
    expect(await render('悟りを開く。'), '悟りを開く。');
    expect(await render('孫悟空が来た。'), '孫悟空が来た。');
    expect(pipeline.worker.capability, 'unavailable');
  });

  test('explicit ruby wins over a name alias', () async {
    final snapshot = compiler.compile([
      phrase(
        'alias',
        '五条悟',
        'ごじょうさとる',
        mode: PronunciationMatchMode.nameAlias,
      ),
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

  test('exact and force marks override author ruby', () async {
    final document = novelTtsDocumentFromSpans([
      NovelSpansData(NovelSpansType.rb, parseNovelRubyMarkup('[[rb:悠仁＞なるひと]]')!.encoded),
      NovelSpansData(NovelSpansType.normal, 'が来た。'),
    ]);
    final exact = compiler.compile([
      phrase('exact', '悠仁', 'ゆうじ'),
    ], workId: 'work-1');
    final exactResolved = await pipeline.resolve(
      document: document,
      snapshot: exact,
    );
    expect(
      renderer.renderAll(
        source: document.displayText,
        decisions: exactResolved.appliedDecisions,
      ),
      'ゆうじが来た。',
    );

    final forced = compiler.compile([
      phrase(
        'force',
        '悠仁',
        'ゆうじ',
        mode: PronunciationMatchMode.force,
      ),
    ], workId: 'work-1');
    final forceResolved = await pipeline.resolve(
      document: document,
      snapshot: forced,
    );
    expect(
      renderer.renderAll(
        source: document.displayText,
        decisions: forceResolved.appliedDecisions,
      ),
      'ゆうじが来た。',
    );
  });

  test('みんなの悠仁 is a name even as a global alias', () async {
    final snapshot = compiler.compile([
      phrase(
        'yuji',
        '悠仁',
        'ゆうじ',
        mode: PronunciationMatchMode.nameAlias,
        scope: PronunciationScopeType.global,
        scopeId: null,
      ),
    ]);
    final resolved = await pipeline.resolve(
      document: const NovelTtsTextDocument(displayText: 'みんなの悠仁が来た。'),
      snapshot: snapshot,
    );
    expect(
      renderer.renderAll(
        source: 'みんなの悠仁が来た。',
        decisions: resolved.appliedDecisions,
      ),
      'みんなのゆうじが来た。',
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

  test('spoken overflow splits at punctuation instead of mid-sentence', () {
    const source = 'あ。BBBBBBBB。CCCCCCCC。';
    final ranges = const SourceAwareNovelTtsSplitter().split(
      displayText: source,
      appliedDecisions: [
        PronunciationDecision(
          start: 0,
          end: 1,
          surface: 'あ',
          reading: 'ああああああああああ',
          ruleId: 'a',
          status: PronunciationDecisionStatus.applied,
          reason: PronunciationReason.forcedRule,
          locked: false,
        ),
      ],
      budget: const RuneTtsTextBudget(16),
    );
    expect(
      [
        for (final range in ranges) source.substring(range.start, range.end),
      ],
      ['あ。', 'BBBBBBBB。', 'CCCCCCCC。'],
    );
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

  test('a single oversized reading is spoken, not dropped', () {
    // One scalar cannot be split, so the budget has to give. Throwing here
    // used to take the whole chapter down from the settings screen.
    final ranges = const SourceAwareNovelTtsSplitter().split(
      displayText: '悟',
      appliedDecisions: [
        const PronunciationDecision(
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
    );
    expect(ranges, hasLength(1));
    expect(ranges.single.start, 0);
    expect(ranges.single.end, 1);
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

  test('a mode the user picked is never disabled by the guesser', () {
    final rules = const PronunciationMigration().migrateV1(const [
      // The guesser turns a lone kana off, because it cannot tell `あ` in a
      // name from `あ` in every other word. An explicit mode overrules it.
      NovelTtsReading(
        surface: 'あ',
        reading: 'ア',
        mode: PronunciationMatchMode.exactPhrase,
      ),
      NovelTtsReading(
        surface: '悟',
        reading: 'さとる',
        mode: PronunciationMatchMode.nameAlias,
      ),
    ]);
    expect(rules[0].enabled, isTrue);
    expect(rules[0].needsReview, isFalse);
    expect(rules[1].enabled, isTrue);
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

    final live = await repo.snapshotFor(
      workId: '1',
      seriesId: null,
      settingsReadings: const [
        NovelTtsReading(
          surface: '悠仁',
          reading: 'ゆうじ',
          mode: PronunciationMatchMode.exactPhrase,
        ),
      ],
    );
    expect(live.activeRules.single.surface, '悠仁');
    expect(live.activeRules.single.reading, 'ゆうじ');
    expect(live.activeRules.single.mode, PronunciationMatchMode.exactPhrase);
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

  test('lexicon analyzer keeps surrogate pairs intact', () {
    final tokens = LexiconJapaneseAnalyzer().tokenize('😀悟った');
    expect(tokens.first.surface, '😀');
    expect(tokens.first.end, 2);
    expect(tokens[1].surface, '悟っ');
    expect(tokens[1].start, 2);
  });

  test('the pipeline survives hostile text and reports honest spans', () async {
    // Astral plane, lone combining marks, zero width spaces, half-width kana,
    // control characters: whatever a Pixiv novel throws at the reader, the
    // pipeline has to answer with spans that really index the source.
    const alphabet = [
      '悟', '恵', '愛', '静', '実', '五', '条', 'は', 'が', 'った', 'り', 'る',
      'さん', '「', '」', '。', '！', '？', '\n', ' ', '　', 'ア', 'ｱ', 'ー',
      '𠮷', '👨‍👩‍👧‍👦', '🎉', '\u{1F600}', '\uFE0F', '\u0301', '\u200B',
      '\t', 'a', '1', '…', '—', '﷽', '\u3005', '々', 'ゔ', 'ヷ',
    ];
    const surfaces = [
      '悟', '恵', '愛', '静', '実', '五条悟', '𠮷', '👨‍👩‍👧‍👦', 'ア',
      '\u{1F600}', '\uFE0F', '々', 'は', '。', 'a',
    ];
    final random = Random(20260909);
    final modes = PronunciationMatchMode.values;
    final scopes = PronunciationScopeType.values;

    String randomText(int units) {
      final buffer = StringBuffer();
      while (buffer.length < units) {
        buffer.write(alphabet[random.nextInt(alphabet.length)]);
      }
      return buffer.toString();
    }

    for (var i = 0; i < 300; i++) {
      final rules = [
        for (var r = 0; r < 1 + random.nextInt(4); r++)
          PronunciationRule(
            id: 'r$i-$r',
            surface: surfaces[random.nextInt(surfaces.length)],
            reading: randomText(1 + random.nextInt(12)),
            mode: modes[random.nextInt(modes.length)],
            scope: PronunciationScope(
              type: scopes[random.nextInt(scopes.length)],
              scopeId: random.nextBool() ? 'work-1' : null,
            ),
            priority: random.nextInt(3),
            enabled: true,
            updatedAtEpochMs: i,
          ),
      ];
      final snapshot = compiler.compile(rules, workId: 'work-1', seriesId: 's1');
      final source = randomText(random.nextInt(400));
      final resolved = await pipeline.resolve(
        document: NovelTtsTextDocument(displayText: source),
        snapshot: snapshot,
      );
      renderer.renderAll(
        source: source,
        decisions: resolved.appliedDecisions,
      );
      const SourceAwareNovelTtsSplitter().split(
        displayText: source,
        appliedDecisions: resolved.appliedDecisions,
        budget: RuneTtsTextBudget(
          NovelTtsSettings.minSplitChars +
              random.nextInt(
                NovelTtsSettings.maxSplitChars -
                    NovelTtsSettings.minSplitChars,
              ),
        ),
      );
      for (final decision in resolved.appliedDecisions) {
        expect(decision.start, inInclusiveRange(0, source.length));
        expect(decision.end, inInclusiveRange(decision.start, source.length));
        expect(source.substring(decision.start, decision.end), decision.surface);
      }
    }
  });
}

class _BrokenAnalyzer implements JapaneseMorphologyAnalyzer {
  @override
  String get analyzerId => 'broken';

  @override
  String get analyzerVersion => '0';

  @override
  bool get supportsPartOfSpeech => false;

  @override
  String get capability => 'broken';

  @override
  Future<void> warmUp() async => throw StateError('no analyzer');

  @override
  Future<MorphologyResult> analyze(String text, {required String requestId}) {
    throw StateError('no analyzer');
  }

  @override
  Future<void> dispose() async {}
}
