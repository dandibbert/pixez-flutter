import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/er/prefer.dart';
import 'package:pixez/page/novel/tts/novel_tts_page.dart';
import 'package:pixez/page/novel/tts/novel_tts_reading_editor.dart';
import 'package:pixez/page/novel/tts/novel_tts_readings.dart';
import 'package:pixez/page/novel/tts/pronunciation/morphology/ipadic_japanese_analyzer.dart';
import 'package:pixez/page/novel/tts/novel_tts_settings.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_rule.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_scope.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('en', 'US'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

Future<void> _pumpPage(WidgetTester tester, List<NovelTtsReading> readings) {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  return tester.pumpWidget(
    _app(NovelTtsPage(initial: NovelTtsSettings(readings: readings))),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Widget tests run on a fake clock, where the background isolate that
  // inflates the dictionary never finishes. Load it once for real up front.
  setUpAll(() => IpadicJapaneseAnalyzer().warmUp());
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefer.init();
    // Drop any write a previous test left pending.
    await const NovelTtsSettings().save();
  });

  testWidgets('deleting an entry can be undone', (tester) async {
    await _pumpPage(tester, const [
      NovelTtsReading(id: 'a', surface: '今日', reading: 'きょう'),
      NovelTtsReading(id: 'b', surface: '明日', reading: 'あした'),
    ]);
    await tester.ensureVisible(find.byKey(novelTtsReadingDeleteKey('a')));
    await tester.tap(find.byKey(novelTtsReadingDeleteKey('a')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('今日 → きょう'), findsNothing);
    expect(NovelTtsSettings.load().readings.map((r) => r.id), ['b']);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(NovelTtsSettings.load().readings.map((r) => r.id), ['a', 'b']);
  });

  testWidgets('the switch turns an entry off and a guessed one on', (
    tester,
  ) async {
    await _pumpPage(tester, const [
      NovelTtsReading(id: 'a', surface: '今日', reading: 'きょう'),
      // A lone kana from the first format: the guesser leaves it off.
      NovelTtsReading(id: 'b', surface: 'は', reading: 'わ'),
    ]);
    expect(find.textContaining('Off: a single kana'), findsOneWidget);

    await tester.ensureVisible(find.byKey(novelTtsReadingSwitchKey('a')));
    await tester.tap(find.byKey(novelTtsReadingSwitchKey('a')));
    await tester.pump();
    await tester.tap(find.byKey(novelTtsReadingSwitchKey('b')));
    await tester.pump();
    final saved = NovelTtsSettings.load().readings;
    expect(saved[0].isActive, isFalse);
    expect(saved[1].isActive, isTrue);
    expect(saved[1].mode, PronunciationMatchMode.force);
    expect(find.text('Fixed phrase · All works · Off'), findsOneWidget);
  });

  testWidgets('pasting a list merges and reports what happened', (
    tester,
  ) async {
    await _pumpPage(tester, const [
      NovelTtsReading(
        id: 'a',
        surface: '今日',
        reading: 'こんにち',
        mode: PronunciationMatchMode.exactPhrase,
      ),
    ]);
    await tester.ensureVisible(find.byKey(novelTtsBulkReadingKey));
    await tester.tap(find.byKey(novelTtsBulkReadingKey));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(novelTtsBulkReadingFieldKey),
      '今日=きょう\n明日=あした\nnot a pair',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(
      find.text('Added 1, updated 1, unchanged 0, skipped 1 lines'),
      findsOneWidget,
    );
    final saved = NovelTtsSettings.load().readings;
    expect(saved.map((r) => (r.surface, r.reading)), [
      ('今日', 'きょう'),
      ('明日', 'あした'),
    ]);
    expect(saved.first.id, 'a');
  });

  testWidgets('copy all puts the list on the clipboard', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _pumpPage(tester, const [
      NovelTtsReading(id: 'a', surface: '悟', reading: 'さとる'),
    ]);
    await tester.ensureVisible(find.byKey(novelTtsExportReadingKey));
    await tester.tap(find.byKey(novelTtsExportReadingKey));
    await tester.pumpAndSettle();
    expect(copied, '悟=さとる|alias');
    expect(find.text('Copied 1 entries'), findsOneWidget);
  });

  testWidgets('the dialog explains an empty save and a replaced entry', (
    tester,
  ) async {
    await _pumpPage(tester, const [
      NovelTtsReading(id: 'a', surface: '今日', reading: 'こんにち'),
    ]);
    await tester.ensureVisible(find.byKey(novelTtsAddReadingKey));
    await tester.tap(find.byKey(novelTtsAddReadingKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(novelTtsReadingSaveKey));
    await tester.pump();
    expect(find.text('Enter the written form'), findsOneWidget);

    await tester.enterText(find.byKey(novelTtsReadingSurfaceFieldKey), '今日');
    await tester.enterText(find.byKey(novelTtsReadingValueFieldKey), 'きょう');
    await tester.pump();
    expect(find.text('Replaces the existing entry 今日 → こんにち'), findsOneWidget);
    await tester.tap(find.byKey(novelTtsReadingSaveKey));
    await tester.pumpAndSettle();
    final saved = NovelTtsSettings.load().readings;
    expect(saved, hasLength(1));
    expect(saved.single.reading, 'きょう');
  });

  testWidgets('adding from the reader defaults to the work being read', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => addNovelTtsReadingFromReader(
                context,
                surface: '悟',
                previewText: '悟は笑った。',
                readingContext: const NovelTtsReadingContext(
                  workId: '42',
                  workTitle: 'Story',
                  seriesId: '9',
                  seriesTitle: 'Saga',
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('This work: Story'), findsOneWidget);
    await tester.enterText(find.byKey(novelTtsReadingValueFieldKey), 'さとる');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Spoken: さとるは笑った。'), findsOneWidget);
    await tester.tap(find.byKey(novelTtsReadingSaveKey));
    await tester.pumpAndSettle();
    final saved = NovelTtsSettings.load().readings.single;
    expect(saved.surface, '悟');
    expect(
      saved.scope,
      const PronunciationScope(
        type: PronunciationScopeType.work,
        scopeId: '42',
      ),
    );
    expect(saved.scopeLabel, 'Story');
    expect(find.text('Saved 悟 → さとる'), findsOneWidget);
  });
}
