import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/page/novel/component/novel_intro.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';

void main() {
  test('strips novel caption markup into readable text', () {
    expect(
      novelCaptionPlainText('<p>Hello<br>world &amp; cats</p>'),
      'Hello\nworld & cats',
    );
    expect(novelCaptionPlainText('   '), isEmpty);
  });

  testWidgets('preview shows two lines of the synopsis', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NovelIntroPreview(
            caption: '<b>A quiet town</b> waits under snow.',
          ),
        ),
      ),
    );

    expect(find.byKey(novelIntroCaptionKey), findsOneWidget);
    expect(find.textContaining('A quiet town'), findsOneWidget);
  });

  testWidgets('details dialog shows the full synopsis', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  showNovelIntroDialog(
                    context: context,
                    title: 'Winter Story',
                    caption: 'The snow kept falling.',
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Winter Story'), findsOneWidget);
    expect(find.text('The snow kept falling.'), findsOneWidget);
  });
}
