import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pixez/page/novel/tts/data/tts_settings_repository.dart';
import 'package:pixez/page/novel/tts/ui/novel_tts_settings_page.dart';
import 'package:pixez/page/novel/tts/ui/pronunciation_dictionary_page.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';

class UiSecrets implements TtsSecretStore {
  @override
  Future<void> delete(String namespace, String name) async {}
  @override
  Future<String?> read(String namespace, String name) async => null;
  @override
  Future<void> write(String namespace, String name, String value) async {}
}

class RecordingSettingsRepository extends TtsSettingsRepository {
  RecordingSettingsRepository() : super(secretStore: UiSecrets());

  final saves = <TtsSettingsSnapshot>[];

  @override
  Future<TtsSettingsSnapshot> load() async => const TtsSettingsSnapshot();

  @override
  Future<void> save(TtsSettingsSnapshot snapshot) async {
    saves.add(snapshot);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgets('settings exposes profiles dictionary and duration controls', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NovelTtsSettingsPage(
          repository: TtsSettingsRepository(secretStore: UiSecrets()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Provider profiles'), findsOneWidget);
    expect(find.text('Pronunciation dictionary'), findsOneWidget);
    expect(find.text('Startup buffer seconds'), findsOneWidget);
    expect(find.text('Maximum cache MB'), findsOneWidget);
  });
  testWidgets('profile editor offers Azure OpenAI and custom HTTP methods', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NovelTtsSettingsPage(
          repository: TtsSettingsRepository(secretStore: UiSecrets()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tts-add-profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Microsoft Azure'));
    await tester.pumpAndSettle();
    expect(find.text('OpenAI-compatible'), findsOneWidget);
    await tester.tap(find.text('Custom HTTP'));
    await tester.pumpAndSettle();
    expect(find.text('HTTP method'), findsOneWidget);
    await tester.tap(find.text('POST'));
    await tester.pumpAndSettle();
    expect(find.text('GET'), findsOneWidget);
    expect(find.text('PUT'), findsOneWidget);
    await tester.tap(find.text('POST').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Validate body as JSON'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Validate body as JSON'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Named secret keys'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Named secret keys'), findsOneWidget);
  });

  testWidgets('rapid setting changes merge against optimistic state', (
    tester,
  ) async {
    final repository = RecordingSettingsRepository();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NovelTtsSettingsPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    Finder incrementFor(String label) => find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(ListTile)),
      matching: find.byIcon(Icons.add),
    );

    await tester.tap(incrementFor('Target graphemes'));
    await tester.tap(incrementFor('Target graphemes'));
    await tester.tap(incrementFor('Maximum graphemes'));
    await tester.pumpAndSettle();

    expect(repository.saves.last.targetLength, 240);
    expect(repository.saves.last.maxLength, 370);
  });

  testWidgets('settings use consistent Traditional Chinese terminology', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'TW'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NovelTtsSettingsPage(
          repository: TtsSettingsRepository(secretStore: UiSecrets()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('語音服務設定'), findsOneWidget);
    expect(find.text('分段與緩衝'), findsOneWidget);
    expect(find.textContaining('服务'), findsNothing);
    expect(find.textContaining('目标'), findsNothing);
    expect(find.textContaining('朗读'), findsNothing);
  });

  testWidgets('settings are usable and localized on a narrow Chinese phone', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NovelTtsSettingsPage(
          repository: TtsSettingsRepository(secretStore: UiSecrets()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('语音服务配置'), findsOneWidget);
    expect(find.text('分段与缓冲'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('tts-add-profile')));
    await tester.pumpAndSettle();

    expect(find.text('添加 TTS 配置'), findsOneWidget);
    expect(find.byKey(const Key('tts-profile-name')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('tts-profile-save')));
    await tester.pump();
    expect(find.text('请填写此项'), findsOneWidget);
    expect(find.text('添加 TTS 配置'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('tts-profile-name')),
      '我的 Azure',
    );
    await tester.tap(find.byKey(const Key('tts-profile-save')));
    await tester.pumpAndSettle();

    expect(find.text('我的 Azure'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pronunciation editor previews stable display and spoken text', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh', 'CN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: PronunciationRuleEditor(initialSurface: '行方')),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('pronunciation-reading')),
      'ゆくえ',
    );
    await tester.pump();
    expect(find.text('显示文本: 行方'), findsOneWidget);
    expect(find.text('朗读文本: ゆくえ'), findsOneWidget);
    expect(find.textContaining('<sub alias="ゆくえ">行方</sub>'), findsOneWidget);
  });
}
