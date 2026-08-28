import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/page/novel/search/novel_search_pager.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';

void main() {
  testWidgets('search pager exposes previous next and the current page', (
    tester,
  ) async {
    var page = 3;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: NovelSearchPagerBar(
            currentPage: page,
            loading: false,
            hasPrevious: true,
            hasNext: true,
            onPrevious: () => page -= 1,
            onNext: () => page += 1,
            onPickPage: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(novelSearchPagerKey), findsOneWidget);
    expect(find.text('Page 3'), findsOneWidget);
    expect(find.text('Pre'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    await tester.tap(find.text('Next'));
    expect(page, 4);
  });
}
