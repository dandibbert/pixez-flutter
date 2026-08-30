import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/er/prefer.dart';
import 'package:pixez/page/novel/tts/novel_tts_advance.dart';
import 'package:pixez/page/novel/tts/novel_tts_audio.dart';
import 'package:pixez/page/novel/tts/novel_tts_bar.dart';
import 'package:pixez/page/novel/tts/novel_tts_controller.dart';
import 'package:pixez/page/novel/tts/novel_tts_engine.dart';
import 'package:pixez/page/novel/tts/novel_tts_follow.dart';
import 'package:pixez/page/novel/tts/novel_tts_now_playing.dart';
import 'package:pixez/page/novel/tts/novel_tts_page.dart';
import 'package:pixez/page/novel/tts/novel_tts_readings.dart';
import 'package:pixez/page/novel/tts/novel_tts_settings.dart';
import 'package:pixez/page/novel/tts/novel_tts_splitter.dart';
import 'package:pixez/page/novel/tts/novel_tts_template.dart';
import 'package:pixez/page/novel/tts/novel_tts_text.dart';
import 'package:pixez/page/novel/viewer/novel_pages.dart';
import 'package:pixez/page/novel/viewer/novel_ruby.dart';
import 'package:pixez/page/novel/viewer/novel_spans.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefer.init();
  });

  test('keeps sentence endings when packing to a character budget', () {
    final chunks = splitNovelTtsText(
      '第一句。第二句！第三句？第四句。',
      maxChars: 8,
    );
    expect(chunks, ['第一句。第二句！', '第三句？第四句。']);
    expect(chunks.every((chunk) => chunk.contains(RegExp(r'[。！？]'))), isTrue);
  });

  test('does not leave a tiny leftover sentence as its own clip', () {
    final chunks = splitNovelTtsText(
      '这是一段刚好接近上限的句子。短。',
      maxChars: 16,
    );
    expect(chunks, hasLength(1));
    expect(chunks.single, contains('短。'));
  });

  test('splits an overlong sentence at a comma instead of mid-word', () {
    final chunks = splitNovelTtsText(
      '这是一段非常非常非常非常非常非常长，而且中间有逗号的句子。',
      maxChars: 20,
    );
    expect(chunks.length, greaterThan(1));
    expect(chunks.first.endsWith('，') || chunks.first.endsWith('长'), isTrue);
  });

  test('fills named and sequential custom URL placeholders', () {
    const vars = NovelTtsTemplateVars(
      text: '你好 世界',
      voice: 'zh-CN-XiaoxiaoNeural',
    );
    expect(
      applyNovelTtsTemplate(
        'https://tts.773421.xyz/tts?t=%@&v=%@voiceName&',
        vars,
        encodeValues: true,
      ),
      'https://tts.773421.xyz/tts?t=${Uri.encodeComponent('你好 世界')}&v=${Uri.encodeComponent('zh-CN-XiaoxiaoNeural')}&',
    );
    expect(
      applyNovelTtsTemplate(
        'https://host/tts?t={text}&v={voice}',
        vars,
        encodeValues: true,
      ),
      'https://host/tts?t=${Uri.encodeComponent('你好 世界')}&v=${Uri.encodeComponent('zh-CN-XiaoxiaoNeural')}',
    );
  });

  test('builds Microsoft, OpenAI, and custom TTS requests', () {
    final microsoft = buildNovelTtsRequest(
      const NovelTtsSettings(
        provider: NovelTtsProvider.microsoft,
        microsoftKey: 'key',
        microsoftRegion: 'eastasia',
        microsoftVoice: 'zh-CN-XiaoxiaoNeural',
      ),
      '你好<script>',
    );
    expect(microsoft.method, 'POST');
    expect(
      microsoft.uri.host,
      'eastasia.tts.speech.microsoft.com',
    );
    expect(utf8.decode(microsoft.body!), contains('&lt;script&gt;'));
    expect(utf8.decode(microsoft.body!), isNot(contains('<script>')));

    final openai = buildNovelTtsRequest(
      const NovelTtsSettings(
        provider: NovelTtsProvider.openai,
        openaiBaseUrl: 'https://example.com/v1',
        openaiApiKey: 'sk-test',
        openaiVoice: 'alloy',
      ),
      'hello',
    );
    expect(openai.uri.path, '/v1/audio/speech');
    expect(openai.headers['Authorization'], 'Bearer sk-test');
    expect(jsonDecode(utf8.decode(openai.body!))['input'], 'hello');

    final custom = buildNovelTtsRequest(
      const NovelTtsSettings(
        provider: NovelTtsProvider.custom,
        customUrl: 'https://tts.773421.xyz/tts?t=%@&v=%@voiceName&',
        customVoice: 'xiaoxiao',
      ),
      '朗读文本',
    );
    expect(custom.method, 'GET');
    expect(custom.uri.queryParameters['t'], '朗读文本');
    expect(custom.uri.queryParameters['v'], 'xiaoxiao');
  });

  test('advances through chunks, pages, then a series chapter', () {
    final nextChunk = resolveNovelTtsAdvance(
      direction: 'next',
      chunkIndex: 0,
      chunkCount: 3,
      currentPage: 1,
      totalPages: 2,
      nextSeriesId: 99,
    );
    expect(nextChunk.kind, NovelTtsAdvanceKind.chunk);

    final nextPage = resolveNovelTtsAdvance(
      direction: 'next',
      chunkIndex: 2,
      chunkCount: 3,
      currentPage: 1,
      totalPages: 2,
      nextSeriesId: 99,
    );
    expect(nextPage.kind, NovelTtsAdvanceKind.page);
    expect(nextPage.page, 2);

    final nextSeries = resolveNovelTtsAdvance(
      direction: 'next',
      chunkIndex: 0,
      chunkCount: 1,
      currentPage: 2,
      totalPages: 2,
      nextSeriesId: 99,
    );
    expect(nextSeries.kind, NovelTtsAdvanceKind.series);
    expect(nextSeries.seriesNovelId, 99);

    final stop = resolveNovelTtsAdvance(
      direction: 'next',
      chunkIndex: 0,
      chunkCount: 1,
      currentPage: 1,
      totalPages: 1,
      autoContinue: false,
      nextSeriesId: 99,
    );
    expect(stop.kind, NovelTtsAdvanceKind.stop);
  });

  test('reads ruby base text and skips images', () {
    final text = novelTtsTextFromSpans([
      NovelSpansData(NovelSpansType.chapter, '序章'),
      NovelSpansData(NovelSpansType.normal, '他走了。'),
      NovelSpansData(
        NovelSpansType.rb,
        parseNovelRubyMarkup('[[rb:漢字＞かんじ]]')!.encoded,
      ),
      NovelSpansData(NovelSpansType.pixivImage, '[pixivimage:1]'),
    ]);
    expect(text, contains('序章'));
    expect(text, contains('他走了。'));
    expect(text, contains('漢字'));
    expect(text, isNot(contains('かんじ')));
    expect(text, isNot(contains('pixivimage')));
  });

  test('controller prefetches the next chunk and can skip to a series', () async {
    final synth = _FakeSynth();
    final audio = _FakeAudio();
    final dir = await Directory.systemTemp.createTemp('novel_tts_test');
    final controller = NovelTtsController(
      synthesizer: synth,
      audio: audio,
      nowPlaying: NovelTtsNowPlaying(),
      settingsLoader: () => const NovelTtsSettings(
        provider: NovelTtsProvider.custom,
        customUrl: 'https://example/tts?t={text}',
        splitChars: 20,
        prefetchCount: 1,
      ),
      cacheDir: () async => dir,
    );
    NovelTtsNavigate? navigate;
    controller.onNavigate = (value) => navigate = value;

    await controller.start(
      novelId: 1,
      title: 'Title',
      author: 'Author',
      page: 1,
      totalPages: 1,
      pageText: '这是第一句用来测试拆分的。这是第二句用来测试拆分的。',
      nextSeriesId: 22,
    );
    expect(controller.status, NovelTtsStatus.playing);
    expect(controller.subtitle, '这是第一句用来测试拆分的。');
    expect(synth.texts, contains('这是第一句用来测试拆分的。'));
    expect(synth.texts, contains('这是第二句用来测试拆分的。'));

    await controller.skip(direction: 'next');
    expect(controller.subtitle, '这是第二句用来测试拆分的。');

    await controller.skip(direction: 'next');
    expect(navigate?.kind, NovelTtsNavigateKind.series);
    expect(navigate?.seriesNovelId, 22);
    expect(controller.takePendingResume(22), isTrue);

    controller.dispose();
    await dir.delete(recursive: true);
  });

  test('keeps synthesizing later pages while the current clip plays', () async {
    final synth = _FakeSynth();
    final audio = _FakeAudio();
    final dir = await Directory.systemTemp.createTemp('novel_tts_pages');
    final navigated = <NovelTtsNavigate>[];
    final controller = NovelTtsController(
      synthesizer: synth,
      audio: audio,
      nowPlaying: NovelTtsNowPlaying(),
      settingsLoader: () => const NovelTtsSettings(
        provider: NovelTtsProvider.custom,
        customUrl: 'https://example/tts?t={text}',
        splitChars: 20,
        prefetchCount: 4,
      ),
      cacheDir: () async => dir,
    );
    controller.onNavigate = navigated.add;

    await controller.start(
      novelId: 1,
      title: 'Title',
      author: 'Author',
      page: 1,
      totalPages: 2,
      pageText: '这是第一页用来测试拆分的。',
      pageTexts: const ['这是第一页用来测试拆分的。', '这是第二页用来测试拆分的。'],
    );
    expect(controller.subtitle, '这是第一页用来测试拆分的。');
    expect(synth.texts, contains('这是第二页用来测试拆分的。'));
    expect(audio.files, hasLength(2));

    await controller.skip(direction: 'next');
    expect(controller.session?.page, 2);
    expect(controller.subtitle, '这是第二页用来测试拆分的。');
    expect(navigated.single.kind, NovelTtsNavigateKind.page);
    expect(navigated.single.keepPlaying, isTrue);

    controller.dispose();
    await dir.delete(recursive: true);
  });

  test('prefetches the next series chapter while the current clip plays', () async {
    final synth = _FakeSynth();
    final audio = _FakeAudio();
    final dir = await Directory.systemTemp.createTemp('novel_tts_series');
    final navigated = <NovelTtsNavigate>[];
    final controller = NovelTtsController(
      synthesizer: synth,
      audio: audio,
      nowPlaying: NovelTtsNowPlaying(),
      settingsLoader: () => const NovelTtsSettings(
        provider: NovelTtsProvider.custom,
        customUrl: 'https://example/tts?t={text}',
        splitChars: 20,
        prefetchCount: 4,
      ),
      cacheDir: () async => dir,
    );
    controller.onNavigate = navigated.add;
    controller.onLoadChapter = (id) async {
      expect(id, 22);
      return const NovelTtsChapter(
        novelId: 22,
        title: 'Next chapter',
        author: 'Author',
        pageTexts: ['下一章第一句用来测试拆分的。'],
        nextSeriesId: 33,
      );
    };

    await controller.start(
      novelId: 1,
      title: 'Title',
      author: 'Author',
      page: 1,
      totalPages: 1,
      pageText: '这是第一句用来测试拆分的。',
      nextSeriesId: 22,
    );
    expect(controller.status, NovelTtsStatus.playing);
    expect(synth.texts, contains('这是第一句用来测试拆分的。'));
    expect(synth.texts, contains('下一章第一句用来测试拆分的。'));
    expect(audio.files, hasLength(2));

    await controller.skip(direction: 'next');
    expect(controller.session?.novelId, 22);
    expect(controller.session?.title, 'Next chapter');
    expect(controller.subtitle, '下一章第一句用来测试拆分的。');
    expect(navigated.single.kind, NovelTtsNavigateKind.series);
    expect(navigated.single.seriesNovelId, 22);
    expect(navigated.single.keepPlaying, isTrue);

    controller.dispose();
    await dir.delete(recursive: true);
  });

  testWidgets('settings page switches the three voice libraries', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NovelTtsPage(initial: const NovelTtsSettings()),
      ),
    );

    expect(find.byKey(novelTtsSettingsPageKey), findsOneWidget);
    expect(find.byKey(novelTtsReadingsSectionKey), findsOneWidget);
    expect(find.byKey(novelTtsCustomUrlFieldKey), findsOneWidget);

    await tester.tap(find.byKey(novelTtsProviderMicrosoftKey));
    await tester.pumpAndSettle();
    expect(find.text('Subscription key'), findsOneWidget);

    await tester.tap(find.byKey(novelTtsProviderOpenaiKey));
    await tester.pumpAndSettle();
    expect(find.text('API base URL'), findsOneWidget);

    await tester.enterText(find.byKey(novelTtsSplitCharsFieldKey), '160');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(NovelTtsSettings.load().splitChars, 160);
    expect(NovelTtsSettings.load().provider, NovelTtsProvider.openai);
  });

  test('applies longer pronunciation marks before shorter ones', () {
    const readings = [
      NovelTtsReading(surface: '行', reading: 'こう'),
      NovelTtsReading(surface: '行く', reading: 'いく'),
      NovelTtsReading(surface: '銀行', reading: 'ぎんこう'),
      NovelTtsReading(surface: '今日', reading: 'きょう'),
    ];
    expect(
      applyNovelTtsReadings('今日は銀行に行く。', readings),
      'きょうはぎんこうにいく。',
    );
    expect(
      parseNovelTtsReadingLines('今日=きょう\n# skip\n行先/ゆきさき'),
      [
        const NovelTtsReading(surface: '今日', reading: 'きょう'),
        const NovelTtsReading(surface: '行先', reading: 'ゆきさき'),
      ],
    );
  });

  test('controller synthesizes the marked reading, not the written form', () async {
    final synth = _FakeSynth();
    final audio = _FakeAudio();
    final dir = await Directory.systemTemp.createTemp('novel_tts_yomi');
    final controller = NovelTtsController(
      synthesizer: synth,
      audio: audio,
      nowPlaying: NovelTtsNowPlaying(),
      settingsLoader: () => const NovelTtsSettings(
        provider: NovelTtsProvider.custom,
        customUrl: 'https://example/tts?t={text}',
        splitChars: 40,
        readings: [NovelTtsReading(surface: '今日', reading: 'きょう')],
      ),
      cacheDir: () async => dir,
    );

    await controller.start(
      novelId: 1,
      title: 'Title',
      author: 'Author',
      page: 1,
      totalPages: 1,
      pageText: '今日は雨です。',
    );
    expect(controller.subtitle, '今日は雨です。');
    expect(synth.texts, ['きょうは雨です。']);

    controller.dispose();
    await dir.delete(recursive: true);
  });

  test('maps a spoken clip to the matching reader block', () {
    final blocks = [
      NovelReaderBlock.spans([
        NovelSpansData(NovelSpansType.normal, '第一段先写在这里。'),
      ]),
      NovelReaderBlock.spans([
        NovelSpansData(NovelSpansType.normal, '第二段才是当前朗读。'),
      ]),
    ];
    expect(
      novelTtsBlockIndexForClip(blocks: blocks, clipText: '第二段才是当前朗读。'),
      1,
    );
    expect(
      novelTtsBlockIndexForClip(blocks: blocks, clipText: '第一段先写在这里。'),
      0,
    );
    final spoken = [
      NovelReaderBlock.spans([
        NovelSpansData(NovelSpansType.normal, '这是第一句用来测试拆分的。'),
      ]),
      NovelReaderBlock.spans([
        NovelSpansData(NovelSpansType.normal, '这是第二句用来测试拆分的。'),
      ]),
    ];
    expect(
      novelTtsChunkIndexForBlock(
        blocks: spoken,
        blockIndex: 1,
        splitChars: 20,
      ),
      1,
    );
    expect(
      novelTtsBlockIndexForChunk(
        blocks: spoken,
        chunkIndex: 1,
        splitChars: 20,
      ),
      1,
    );
  });

  test('can pause while synthesizing and resume afterwards', () async {
    final gate = Completer<void>();
    final synth = _GatedSynth(gate.future);
    final audio = _FakeAudio();
    final dir = await Directory.systemTemp.createTemp('novel_tts_pause');
    final controller = NovelTtsController(
      synthesizer: synth,
      audio: audio,
      nowPlaying: NovelTtsNowPlaying(),
      settingsLoader: () => const NovelTtsSettings(
        provider: NovelTtsProvider.custom,
        customUrl: 'https://example/tts?t={text}',
        splitChars: 40,
      ),
      cacheDir: () async => dir,
    );

    final started = controller.start(
      novelId: 1,
      title: 'Title',
      author: 'Author',
      page: 1,
      totalPages: 1,
      pageText: '暂停测试用的句子。',
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.status, NovelTtsStatus.synthesizing);
    await controller.pause();
    expect(controller.status, NovelTtsStatus.paused);
    gate.complete();
    await started;
    expect(controller.status, NovelTtsStatus.paused);
    expect(audio.paused, greaterThanOrEqualTo(1));
    await controller.resume();
    expect(controller.status, NovelTtsStatus.playing);
    expect(audio.resumed, 1);

    controller.dispose();
    await dir.delete(recursive: true);
  });

  test('stop then play again resumes the same page clip', () async {
    final synth = _FakeSynth();
    final audio = _FakeAudio();
    final dir = await Directory.systemTemp.createTemp('novel_tts_bookmark');
    final controller = NovelTtsController(
      synthesizer: synth,
      audio: audio,
      nowPlaying: NovelTtsNowPlaying(),
      settingsLoader: () => const NovelTtsSettings(
        provider: NovelTtsProvider.custom,
        customUrl: 'https://example/tts?t={text}',
        splitChars: 20,
      ),
      cacheDir: () async => dir,
    );

    await controller.start(
      novelId: 7,
      title: 'Title',
      author: 'Author',
      page: 1,
      totalPages: 1,
      pageText: '这是第一句用来测试拆分的。这是第二句用来测试拆分的。',
    );
    expect(controller.clips, hasLength(2));
    await controller.skip(direction: 'next');
    expect(controller.clipIndex, 1);
    await controller.stop();
    expect(controller.status, NovelTtsStatus.idle);
    expect(controller.bookmark?.chunkIndex, 1);

    await controller.start(
      novelId: 7,
      title: 'Title',
      author: 'Author',
      page: 1,
      totalPages: 1,
      pageText: '这是第一句用来测试拆分的。这是第二句用来测试拆分的。',
    );
    expect(controller.clipIndex, 1);
    expect(controller.subtitle, '这是第二句用来测试拆分的。');

    await controller.start(
      novelId: 7,
      title: 'Title',
      author: 'Author',
      page: 1,
      totalPages: 1,
      pageText: '这是第一句用来测试拆分的。这是第二句用来测试拆分的。',
      startChunk: 0,
    );
    expect(controller.clipIndex, 0);
    expect(controller.subtitle, '这是第一句用来测试拆分的。');

    await controller.start(
      novelId: 7,
      title: 'Title',
      author: 'Author',
      page: 2,
      totalPages: 2,
      pageText: '下一页第一句用来测试拆分的。',
      pageTexts: [
        '这是第一句用来测试拆分的。这是第二句用来测试拆分的。',
        '下一页第一句用来测试拆分的。',
      ],
    );
    expect(controller.subtitle, '下一页第一句用来测试拆分的。');

    controller.dispose();
    await dir.delete(recursive: true);
  });

  test('replacing a finished clip does not skip the next one', () async {
    final audio = _ReenteringAudio();
    final dir = await Directory.systemTemp.createTemp('novel_tts_reenter');
    final controller = NovelTtsController(
      synthesizer: _FakeSynth(),
      audio: audio,
      nowPlaying: NovelTtsNowPlaying(),
      settingsLoader: () => const NovelTtsSettings(
        provider: NovelTtsProvider.custom,
        customUrl: 'https://example/tts?t={text}',
        splitChars: 20,
      ),
      cacheDir: () async => dir,
    );

    await controller.start(
      novelId: 3,
      title: 'Title',
      author: 'Author',
      page: 1,
      totalPages: 1,
      pageText: '这是第一句用来测试拆分的。这是第二句用来测试拆分的。这是第三句用来测试拆分的。',
    );
    expect(controller.clips.length, greaterThanOrEqualTo(3));
    expect(controller.clipIndex, 0);
    expect(audio.playCount, 1);

    audio.emitComplete();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(controller.clipIndex, 1);
    expect(audio.playCount, 2);
    expect(controller.subtitle, '这是第二句用来测试拆分的。');

    controller.dispose();
    await dir.delete(recursive: true);
  });

  test('TTS strings are translated instead of leftover English', () {
    final ja = lookupAppLocalizations(const Locale('ja'));
    expect(ja.novel_tts_settings, '小説の読み上げ');
    expect(ja.novel_tts_section_readings, '読み仮名');
    expect(ja.novel_tts_reading_add, '読みを追加');
    expect(ja.novel_tts_readings_hint, contains('今日'));

    final zh = lookupAppLocalizations(const Locale('zh'));
    expect(zh.novel_tts_settings, '小说朗读');
    expect(zh.novel_tts_section_readings, '读音标记');
    expect(zh.novel_tts_lock_screen_hint, isNot(contains('Locking the screen')));

    final de = lookupAppLocalizations(const Locale('de'));
    expect(de.novel_tts_settings, 'Roman vorlesen');
    expect(de.novel_tts_section_readings, 'Aussprache');
    expect(de.novel_tts_empty, isNot(contains('Nothing to read')));

    final es = lookupAppLocalizations(const Locale('es'));
    expect(es.novel_tts_settings_subtitle, isNot(contains('Voice libraries')));
    expect(es.novel_tts_not_configured, isNot(contains('Configure a voice')));

    final ko = lookupAppLocalizations(const Locale('ko'));
    expect(ko.novel_tts_custom_body, 'POST 본문 템플릿');
    expect(ko.novel_tts_section_readings, '발음 표기');
  });

  testWidgets('settings page can add a pronunciation mark', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NovelTtsPage(initial: const NovelTtsSettings()),
      ),
    );

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(novelTtsAddReadingKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(novelTtsReadingSurfaceFieldKey), '今日');
    await tester.enterText(find.byKey(novelTtsReadingValueFieldKey), 'きょう');
    await tester.tap(find.byKey(novelTtsReadingSaveKey));
    await tester.pumpAndSettle();
    expect(find.text('今日  →  きょう'), findsOneWidget);
    expect(NovelTtsSettings.load().readings, [
      const NovelTtsReading(surface: '今日', reading: 'きょう'),
    ]);
  });

  testWidgets('player bar shows the current subtitle', (tester) async {
    final controller = NovelTtsController(
      synthesizer: _FakeSynth(),
      audio: _FakeAudio(),
      nowPlaying: NovelTtsNowPlaying(),
      settingsLoader: () => const NovelTtsSettings(
        provider: NovelTtsProvider.custom,
        customUrl: 'https://example/tts?t={text}',
      ),
      cacheDir: () async => Directory.systemTemp,
    );
    controller.session = const NovelTtsSession(
      novelId: 1,
      title: 'Story',
      author: 'A',
      page: 1,
      totalPages: 2,
      chunks: ['当前字幕'],
    );
    controller.clips = const [
      NovelTtsClip(novelId: 1, page: 1, chunkIndex: 0, text: '当前字幕'),
    ];
    controller.status = NovelTtsStatus.synthesizing;
    controller.clipIndex = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: NovelTtsBar(
            controller: controller,
            onOpenSettings: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(novelTtsBarKey), findsOneWidget);
    expect(find.byKey(novelTtsPauseButtonKey), findsOneWidget);
    expect(find.text('当前字幕'), findsOneWidget);
    controller.dispose();
  });
}

class _FakeSynth implements NovelTtsSynthesizer {
  final texts = <String>[];

  @override
  Future<Uint8List> synthesize(NovelTtsSettings settings, String text) async {
    texts.add(text);
    return Uint8List.fromList(const [1, 2, 3, 4]);
  }
}

class _GatedSynth implements NovelTtsSynthesizer {
  _GatedSynth(this._gate);

  final Future<void> _gate;

  @override
  Future<Uint8List> synthesize(NovelTtsSettings settings, String text) async {
    await _gate;
    return Uint8List.fromList(const [1, 2, 3, 4]);
  }
}

class _ReenteringAudio implements NovelTtsAudioPlayer {
  var playCount = 0;
  final _completed = StreamController<void>.broadcast();
  final _clipIndex = StreamController<int>.broadcast();

  void emitComplete() => _completed.add(null);

  @override
  Stream<void> get onComplete => _completed.stream;

  @override
  Stream<int> get onClipIndex => _clipIndex.stream;

  @override
  void listen() {}

  @override
  Future<void> playFile(String path) => playFiles([path]);

  @override
  Future<void> playFiles(List<String> paths) async {
    playCount++;
    if (playCount > 1) {
      _completed.add(null);
    }
  }

  @override
  Future<void> enqueue(String path) async {}

  @override
  Future<bool> seekNext() async => false;

  @override
  Future<bool> seekPrevious() async => false;

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<Duration?> get duration async => const Duration(seconds: 1);

  @override
  Future<Duration?> get position async => Duration.zero;

  @override
  Future<void> dispose() async {
    await _completed.close();
    await _clipIndex.close();
  }
}

class _FakeAudio implements NovelTtsAudioPlayer {
  final files = <String>[];
  var index = 0;
  var paused = 0;
  var resumed = 0;
  final _clipIndex = StreamController<int>.broadcast();

  @override
  final Stream<void> onComplete = const Stream.empty();

  @override
  Stream<int> get onClipIndex => _clipIndex.stream;

  @override
  void listen() {}

  @override
  Future<void> playFile(String path) => playFiles([path]);

  @override
  Future<void> playFiles(List<String> paths) async {
    files
      ..clear()
      ..addAll(paths);
    index = 0;
  }

  @override
  Future<void> enqueue(String path) async {
    files.add(path);
  }

  @override
  Future<bool> seekNext() async {
    if (index + 1 >= files.length) {
      return false;
    }
    index++;
    return true;
  }

  @override
  Future<bool> seekPrevious() async {
    if (index <= 0) {
      return false;
    }
    index--;
    return true;
  }

  @override
  Future<void> pause() async {
    paused++;
  }

  @override
  Future<void> resume() async {
    resumed++;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<Duration?> get duration async => const Duration(seconds: 1);

  @override
  Future<Duration?> get position async => Duration.zero;

  @override
  Future<void> dispose() async {
    await _clipIndex.close();
  }
}
