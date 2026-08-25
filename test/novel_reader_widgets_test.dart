import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/page/novel/viewer/novel_pages.dart';
import 'package:pixez/page/novel/viewer/novel_reader_style.dart';
import 'package:pixez/page/novel/viewer/novel_reader_widgets.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';

void main() {
  test('serif is the default novel font and line height matches pixvel', () {
    expect(NovelFontFamily.normalize(null), NovelFontFamily.serif);
    expect(NovelFontFamily.normalize('unknown'), NovelFontFamily.serif);
    expect(NovelReaderStyle.defaultLineHeight, 1.8);

    final serif = NovelReaderStyle.resolve(
      color: const Color(0xFF111111),
      fontSize: 16,
      lineHeight: 1.8,
      fontFamily: NovelFontFamily.serif,
    );
    expect(serif.height, 1.8);
    expect(serif.fontFamily, isNotNull);
    expect(serif.fontFamily, isNot(NovelReaderStyle.sansFamily));

    final system = NovelReaderStyle.resolve(
      color: const Color(0xFF111111),
      fontSize: 18,
      lineHeight: 2.0,
      fontFamily: NovelFontFamily.system,
    );
    expect(system.fontFamily, isNull);
    expect(system.fontSize, 18);
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

  testWidgets('font settings can switch family, size, and line height', (
    tester,
  ) async {
    var family = NovelFontFamily.serif;
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
            fontFamily: family,
            onFontSizeChanged: (value) => fontSize = value,
            onLineHeightChanged: (value) => lineHeight = value,
            onFontFamilyChanged: (value) => family = value,
          ),
        ),
      ),
    );

    expect(find.byKey(novelReaderSettingsKey), findsOneWidget);
    await tester.tap(find.byKey(novelFontFamilySansKey));
    await tester.pump();
    expect(family, NovelFontFamily.sans);

    await tester.tap(find.byKey(novelFontFamilySystemKey));
    await tester.pump();
    expect(family, NovelFontFamily.system);

    await tester.drag(find.byKey(novelFontSizeSliderKey), const Offset(80, 0));
    await tester.pump();
    expect(fontSize, greaterThan(16));

    await tester.drag(
      find.byKey(novelLineHeightSliderKey),
      const Offset(80, 0),
    );
    await tester.pump();
    expect(lineHeight, greaterThan(1.8));

    final preview = tester.widget<Text>(find.byKey(novelReaderPreviewKey));
    expect(preview.style?.fontFamily, isNull);
  });
}
