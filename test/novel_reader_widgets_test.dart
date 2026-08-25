import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/page/novel/viewer/installed_fonts.dart';
import 'package:pixez/page/novel/viewer/novel_custom_font.dart';
import 'package:pixez/page/novel/viewer/novel_font_picker.dart';
import 'package:pixez/page/novel/viewer/novel_pages.dart';
import 'package:pixez/page/novel/viewer/novel_reader_style.dart';
import 'package:pixez/page/novel/viewer/novel_reader_widgets.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';

void main() {
  test('custom installed font names are not remapped to serif/sans', () {
    expect(NovelReaderStyle.isDefaultFamily(''), isTrue);
    expect(NovelReaderStyle.isDefaultFamily('serif'), isTrue);
    expect(NovelReaderStyle.isDefaultFamily('LXGW WenKai'), isFalse);

    final custom = NovelReaderStyle.resolve(
      color: const Color(0xFF111111),
      fontSize: 16,
      lineHeight: 1.8,
      fontFamily: 'LXGW WenKai',
    );
    expect(custom.fontFamily, 'LXGW WenKai');
    expect(custom.height, 1.8);
    expect(custom.fontFamilyFallback, isNot(contains('serif')));
    expect(custom.fontFamilyFallback, isNot(contains('sans-serif')));

    final imported = NovelReaderStyle.resolve(
      color: const Color(0xFF111111),
      fontSize: 18,
      lineHeight: 2.0,
      fontFamily: 'pixez__SourceHanSerif',
    );
    expect(imported.fontFamily, 'pixez__SourceHanSerif');
  });

  test('font search matches installed family names', () {
    final families = InstalledFonts.normalizeFamilies(const [
      ' Noto Sans CJK JP ',
      'Source Han Serif CN',
      'LXGW WenKai',
      '@MingLiU',
      'LXGW WenKai',
    ]);
    expect(families, containsAll(['Noto Sans CJK JP', 'Source Han Serif CN', 'LXGW WenKai']));
    expect(families, isNot(contains('@MingLiU')));
    expect(InstalledFonts.filterFamilies(families, 'wenkai'), ['LXGW WenKai']);
  });

  test('imported font files get a stable family name', () {
    expect(
      NovelCustomFont.familyFromFileName('LXGWWenKai-Regular.ttf'),
      'pixez__LXGWWenKai-Regular',
    );
    expect(NovelCustomFont.isImportedFamily('pixez__LXGWWenKai-Regular'), isTrue);
    expect(NovelCustomFont.isImportedFamily('Noto Sans'), isFalse);
    expect(
      NovelCustomFont.displayName('pixez__LXGWWenKai-Regular'),
      'LXGWWenKai-Regular',
    );
  });

  test('selected custom family stays in the picker list', () {
    expect(
      InstalledFonts.mergeSelected(['Noto Sans'], 'LXGW WenKai'),
      ['LXGW WenKai', 'Noto Sans'],
    );
    expect(
      InstalledFonts.mergeSelected(['LXGW WenKai'], 'LXGW WenKai'),
      ['LXGW WenKai'],
    );
  });

  testWidgets('reader chrome shows title and page controls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: NovelReaderScaffold(
            header: NovelReaderHeader(
              title: 'Winter Story',
              author: 'Author A',
              onBack: () {},
              onTitleTap: () {},
              onAuthorTap: () {},
            ),
            article: const NovelReaderArticle(
              child: Text('The snow kept falling.'),
            ),
            pageNav: NovelReaderPageNav(
              currentPage: 2,
              totalPages: 5,
              navState: const NovelPageNavState(
                isOnFirstPage: false,
                isOnLastPage: false,
                canJumpPrevSeries: false,
                canJumpNextSeries: false,
                isPrevDisabled: false,
                isNextDisabled: false,
              ),
              onPrev: () {},
              onNext: () {},
              onPickPage: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Winter Story'), findsOneWidget);
    expect(find.text('Author A'), findsOneWidget);
    expect(find.text('The snow kept falling.'), findsOneWidget);
    expect(find.text('2 / 5'), findsOneWidget);
    expect(find.byKey(novelReaderHeaderKey), findsOneWidget);
    expect(find.byKey(novelReaderArticleKey), findsOneWidget);
    expect(find.byKey(novelReaderPageNavKey), findsOneWidget);
  });

  testWidgets('article list only builds visible paragraph blocks', (
    tester,
  ) async {
    var built = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NovelReaderArticle(
            itemCount: 400,
            itemBuilder: (context, index) {
              built++;
              return Text('paragraph $index');
            },
          ),
        ),
      ),
    );

    expect(find.text('paragraph 0'), findsOneWidget);
    expect(find.text('paragraph 399'), findsNothing);
    expect(built, lessThan(80));
    expect(built, lessThan(400));
  });

  testWidgets('font settings keep size and line height controls', (
    tester,
  ) async {
    var fontSize = 16.0;
    var lineHeight = 1.8;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: NovelReaderSettingsSheet(
            fontSize: fontSize,
            lineHeight: lineHeight,
            fontFamily: '',
            onFontSizeChanged: (value) => fontSize = value,
            onLineHeightChanged: (value) => lineHeight = value,
            onFontFamilyChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.byKey(novelReaderSettingsKey), findsOneWidget);
    expect(find.byKey(novelFontPickerButtonKey), findsOneWidget);
    expect(find.text('Default'), findsOneWidget);
    expect(find.text('Search installed fonts'), findsOneWidget);

    await tester.drag(find.byKey(novelFontSizeSliderKey), const Offset(80, 0));
    await tester.pump();
    expect(fontSize, greaterThan(16));

    await tester.drag(
      find.byKey(novelLineHeightSliderKey),
      const Offset(80, 0),
    );
    await tester.pump();
    expect(lineHeight, greaterThan(1.8));
  });

  testWidgets('font picker lists installed families and can search', (
    tester,
  ) async {
    NovelFontChoice? selected;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                selected = await Navigator.of(context).push<NovelFontChoice>(
                  MaterialPageRoute(
                    builder: (_) => const NovelFontPickerPage(
                      selectedFamily: '',
                      families: [
                        'Noto Sans CJK JP',
                        'Source Han Serif CN',
                        'LXGW WenKai',
                      ],
                    ),
                  ),
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(novelFontPickerKey), findsOneWidget);
    expect(find.text('LXGW WenKai'), findsOneWidget);

    await tester.enterText(find.byKey(novelFontSearchKey), 'wenkai');
    await tester.pump();
    expect(find.text('Noto Sans CJK JP'), findsNothing);
    expect(find.text('LXGW WenKai'), findsOneWidget);

    await tester.tap(find.text('LXGW WenKai'));
    await tester.pump();
    await tester.pump();
    expect(selected?.family, 'LXGW WenKai');
    expect(selected?.filePath, isNull);
  });

  testWidgets('font picker keeps an imported family and its file path', (
    tester,
  ) async {
    NovelFontChoice? selected;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                selected = await Navigator.of(context).push<NovelFontChoice>(
                  MaterialPageRoute(
                    builder: (_) => const NovelFontPickerPage(
                      selectedFamily: 'pixez__LXGWWenKai',
                      selectedFilePath: '/tmp/lxgw.ttf',
                      families: ['Noto Sans CJK JP'],
                    ),
                  ),
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump();

    expect(find.text('LXGWWenKai'), findsOneWidget);
    expect(find.text('Imported'), findsOneWidget);

    await tester.tap(find.text('LXGWWenKai'));
    await tester.pump();
    await tester.pump();
    expect(selected?.family, 'pixez__LXGWWenKai');
    expect(selected?.filePath, '/tmp/lxgw.ttf');
  });

  testWidgets('font picker import returns the chosen file family', (
    tester,
  ) async {
    NovelFontChoice? selected;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                selected = await Navigator.of(context).push<NovelFontChoice>(
                  MaterialPageRoute(
                    builder: (_) => NovelFontPickerPage(
                      selectedFamily: '',
                      families: const ['Noto Sans CJK JP'],
                      importFont: () async => const NovelImportedFont(
                        family: 'pixez__SourceHanSerif',
                        filePath: '/tmp/source-han.otf',
                      ),
                    ),
                  ),
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(novelFontImportKey));
    await tester.pump();
    await tester.pump();
    expect(selected?.family, 'pixez__SourceHanSerif');
    expect(selected?.filePath, '/tmp/source-han.otf');
  });

  testWidgets('settings tile opens the installed-font picker', (tester) async {
    NovelFontChoice? selected;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: NovelReaderSettingsSheet(
            fontSize: 16,
            lineHeight: 1.8,
            fontFamily: '',
            fontFamilies: const ['LXGW WenKai', 'Source Han Serif CN'],
            onFontSizeChanged: (_) {},
            onLineHeightChanged: (_) {},
            onFontFamilyChanged: (choice) => selected = choice,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(novelFontPickerButtonKey));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(novelFontPickerKey), findsOneWidget);
    expect(find.text('Source Han Serif CN'), findsOneWidget);

    await tester.tap(find.text('Source Han Serif CN'));
    await tester.pump();
    await tester.pump();
    expect(selected?.family, 'Source Han Serif CN');
    expect(find.text('Source Han Serif CN'), findsOneWidget);
  });
}
