import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/page/novel/search/novel_search_filter_sheet.dart';
import 'package:pixez/page/novel/search/novel_search_query.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';

void main() {
  const phoneSize = Size(390, 844);

  Future<void> pumpSheet(
    WidgetTester tester, {
    required Locale locale,
    required NovelSearchQuery initial,
    ValueChanged<NovelSearchQuery>? onApply,
    bool Function()? canUsePopular,
    bool openAsModal = false,
  }) async {
    tester.view.physicalSize = phoneSize;
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: openAsModal
            ? Builder(
                builder: (context) {
                  return Scaffold(
                    body: Center(
                      child: TextButton(
                        onPressed: () {
                          NovelSearchFilterSheet.show(
                            context: context,
                            initial: initial,
                            onApply: onApply ?? (_) {},
                            canUsePopular: canUsePopular,
                          );
                        },
                        child: const Text('open-filters'),
                      ),
                    ),
                  );
                },
              )
            : Scaffold(
                body: NovelSearchFilterSheet(
                  initial: initial,
                  onApply: onApply ?? (_) {},
                  canUsePopular: canUsePopular,
                ),
              ),
      ),
    );
    if (openAsModal) {
      await tester.tap(find.text('open-filters'));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('keeps apply on a phone screen without scrolling', (
    tester,
  ) async {
    var applied = false;
    await pumpSheet(
      tester,
      locale: const Locale('ja'),
      initial: const NovelSearchQuery(word: '猫'),
      onApply: (_) => applied = true,
      openAsModal: true,
    );

    final apply = tester.getRect(find.byKey(novelSearchFilterApplyKey));
    expect(apply.top, greaterThanOrEqualTo(0));
    expect(apply.bottom, lessThanOrEqualTo(phoneSize.height));
    expect(find.text('フィルター'), findsOneWidget);
    expect(tester.getTopLeft(find.text('フィルター')).dy, greaterThanOrEqualTo(47));

    await tester.tap(find.byKey(novelSearchFilterApplyKey));
    await tester.pumpAndSettle();
    expect(applied, isTrue);
  });

  testWidgets('uses Japanese copy instead of hardcoded English', (tester) async {
    await pumpSheet(
      tester,
      locale: const Locale('ja'),
      initial: const NovelSearchQuery(word: '猫'),
    );

    expect(find.text('Publish date'), findsNothing);
    expect(find.text('Bookmarks'), findsNothing);
    expect(find.text('Exclude AI'), findsNothing);
    expect(find.text('投稿日時'), findsOneWidget);
    expect(find.text('ブックマーク数'), findsOneWidget);
    expect(find.text('AI 作品を除外'), findsOneWidget);
    expect(find.text('タグ（部分一致）'), findsOneWidget);
    expect(find.text('タグの完全一致'), findsOneWidget);
    expect(find.text('適用'), findsOneWidget);
    expect(find.text('リセット'), findsOneWidget);
  });

  testWidgets('rejects a bookmark minimum above the maximum', (tester) async {
    NovelSearchQuery? applied;
    await pumpSheet(
      tester,
      locale: const Locale('en', 'US'),
      initial: const NovelSearchQuery(word: 'cat'),
      onApply: (query) => applied = query,
    );

    await tester.enterText(find.widgetWithText(TextField, 'Minimum'), '500');
    await tester.enterText(find.widgetWithText(TextField, 'Maximum'), '100');
    await tester.tap(find.byKey(novelSearchFilterApplyKey));
    await tester.pump();

    expect(applied, isNull);
    expect(
      find.text('Bookmark minimum cannot be greater than maximum'),
      findsOneWidget,
    );
    expect(find.byKey(novelSearchFilterSheetKey), findsOneWidget);
  });

  testWidgets('captures the Japanese phone layout', (tester) async {
    await pumpSheet(
      tester,
      locale: const Locale('ja'),
      initial: const NovelSearchQuery(
        word: '猫',
        searchTarget: 'keyword',
        sort: 'popular_desc',
        bookmarkNumMin: 1000,
        searchAiType: 1,
      ),
      openAsModal: true,
    );

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(MaterialApp),
    );
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('/opt/cursor/artifacts/novel_filter_sheet_ja_phone.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    expect(file.existsSync(), isTrue);
  });
}
