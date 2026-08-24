import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/models/illust.dart';
import 'package:pixez/page/picture/illust_detail_content.dart';

void main() {
  testWidgets('recommendations load once when their region approaches', (
    tester,
  ) async {
    var calls = 0;
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 300,
            child: CustomScrollView(
              controller: controller,
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 1000)),
                SliverToBoxAdapter(
                  child: IllustRecommendationLoadTrigger(
                    preloadExtent: 0,
                    onApproach: () => calls++,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 400)),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(calls, 0);

    controller.jumpTo(750);
    await tester.pump();
    await tester.pump();
    expect(calls, 1);

    controller.jumpTo(0);
    await tester.pump();
    controller.jumpTo(750);
    await tester.pump();
    await tester.pump();
    expect(calls, 1);
  });

  testWidgets('recommendations load when their region is initially visible', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: IllustRecommendationLoadTrigger(onApproach: () => calls++),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(calls, 1);

    await tester.pump();
    expect(calls, 1);
  });

  test('recommendation stores are reused across the same growing batch', () {
    final cache = IllustRecommendationStoreCache();
    final first = _illust(1);
    final second = _illust(2);

    cache.sync([first]);
    final firstStore = cache.stores.single;
    cache.sync([first]);
    expect(identical(cache.stores.single, firstStore), isTrue);

    cache.sync([first, second]);
    expect(cache.stores.length, 2);
    expect(identical(cache.stores.first, firstStore), isTrue);
    expect(cache.stores.last.id, 2);

    cache.clear();
    expect(cache.stores, isEmpty);
  });
}

Illusts _illust(int id) {
  return Illusts(
    id: id,
    title: 'title $id',
    type: 'illust',
    imageUrls: ImageUrls(squareMedium: '', medium: '', large: ''),
    caption: '',
    restrict: 0,
    user: User(
      id: 1,
      name: 'user',
      account: 'account',
      profileImageUrls: ProfileImageUrls(medium: ''),
    ),
    tags: [],
    tools: [],
    createDate: '2026-01-01T00:00:00+09:00',
    pageCount: 1,
    width: 100,
    height: 100,
    sanityLevel: 2,
    xRestrict: 0,
    metaPages: [],
    totalView: 0,
    totalBookmarks: 0,
    isBookmarked: false,
    visible: true,
    isMuted: false,
    illustAIType: 0,
    totalComments: 0,
  );
}
