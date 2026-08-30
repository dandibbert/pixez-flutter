import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pixez/page/novel/tts/data/tts_settings_repository.dart';
import 'package:pixez/page/novel/tts/ui/novel_tts_settings_page.dart';
import 'package:pixez/page/novel/tts/ui/pronunciation_dictionary_page.dart';

class UiSecrets implements TtsSecretStore {
  @override
  Future<void> delete(String namespace, String name) async {}
  @override
  Future<String?> read(String namespace, String name) async => null;
  @override
  Future<void> write(String namespace, String name, String value) async {}
}

void main() {
  testWidgets('settings exposes profiles dictionary and duration controls', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
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
        home: NovelTtsSettingsPage(
          repository: TtsSettingsRepository(secretStore: UiSecrets()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tts-add-profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('microsoftAzure'));
    await tester.pumpAndSettle();
    expect(find.text('openAiCompatible'), findsOneWidget);
    await tester.tap(find.text('customHttp'));
    await tester.pumpAndSettle();
    expect(find.text('HTTP method'), findsOneWidget);
    expect(find.text('Named secret keys'), findsOneWidget);
    expect(find.text('New named secret values'), findsOneWidget);
    await tester.tap(find.text('POST'));
    await tester.pumpAndSettle();
    expect(find.text('GET'), findsOneWidget);
    expect(find.text('PUT'), findsOneWidget);
  });

  testWidgets('pronunciation editor previews stable display and spoken text', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PronunciationRuleEditor(initialSurface: '行方')),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('pronunciation-reading')),
      'ゆくえ',
    );
    await tester.pump();
    expect(find.text('Display: 行方'), findsOneWidget);
    expect(find.text('Spoken: ゆくえ'), findsOneWidget);
    expect(find.textContaining('<sub alias="ゆくえ">行方</sub>'), findsOneWidget);
  });
}
