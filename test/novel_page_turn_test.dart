import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/main.dart';
import 'package:pixez/page/novel/viewer/image_text.dart';
import 'package:pixez/page/novel/viewer/novel_reader_widgets.dart';
import 'package:pixez/page/novel/viewer/novel_store.dart';
import 'package:pixez/page/novel/viewer/novel_viewer.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'novel_reader_background_test.dart' show buildNovel, buildWebResponse;

/// A page of [count] paragraphs whose lengths follow [stride], so two pages
/// built with different strides have blocks of different heights at the
/// same index.
String _page(int count, String tag, int stride) => List.generate(
  count,
  (i) => '$tag 静かな夜だった。$i 行目の文章はここまで続いていく。' * (1 + (i * stride) % 5),
).join('\n');

void main() {
  testWidgets('the next page starts at its top after reading to the end', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    userSetting.prefs = await SharedPreferences.getInstance();
    final store = NovelStore(1, buildNovel());
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NovelViewerPage(id: 1, novelStore: store),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    // A short page followed by a longer one with differently sized blocks:
    // laying the new blocks out from the old blocks' positions used to leave
    // the next page scrolled part-way down.
    store.novelTextResponse = buildWebResponse(
      '${_page(45, 'A', 1)}\n[newpage]\n${_page(150, 'B', 3)}',
    );
    store.spans = NovelSpansGenerator().buildSpans(store.novelTextResponse!);
    store.errorMessage = null;
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final article = find.descendant(
      of: find.byKey(novelReaderArticleKey),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(article.first).position;
    for (var i = 0; i < 30 && position.pixels < position.maxScrollExtent; i++) {
      await tester.fling(article.first, const Offset(0, -900), 4000);
      await tester.pumpAndSettle();
    }
    expect(position.pixels, position.maxScrollExtent);

    final nav = tester.getRect(find.byKey(novelReaderPageNavKey));
    await tester.tapAt(Offset(nav.right - 30, nav.center.dy));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('2 / 2'), findsOneWidget);
    expect(position.pixels, 0);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
