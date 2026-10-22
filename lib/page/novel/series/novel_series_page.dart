import 'package:easy_refresh/easy_refresh.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pixez/component/painter_avatar.dart';
import 'package:pixez/component/selected_text.dart';
import 'package:pixez/component/pixiv_image.dart';
import 'package:pixez/er/leader.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/models/novel_recom_response.dart';
import 'package:pixez/models/novel_series_detail.dart';
import 'package:pixez/network/api_client.dart';
import 'package:pixez/page/novel/component/novel_bookmark_button.dart';
import 'package:pixez/page/novel/new/novel_watch_list_notifier.dart';
import 'package:pixez/page/novel/user/novel_users_page.dart';
import 'package:pixez/page/novel/viewer/novel_store.dart';
import 'package:pixez/page/novel/viewer/novel_viewer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pixez/watercolor/mingcute.dart';
import 'package:pixez/watercolor/watercolor_tokens.dart';
import 'package:pixez/watercolor/watercolor_widgets.dart';
import 'package:pixez/watercolor/watercolor_motion.dart';

final novelSeriesProvider =
    NotifierProvider<NovelSeriesNotifier, NovelSeriesState?>(() {
      return NovelSeriesNotifier();
    });

class NovelSeriesState {
  final NovelSeriesDetail novelSeriesDetail;
  final List<Novel> novels;
  final List<NovelStore> novelStores;
  final String? nextUrl;

  NovelSeriesState(
    this.novelSeriesDetail,
    this.novels,
    this.novelStores,
    this.nextUrl,
  );
}

class NovelSeriesNotifier extends Notifier<NovelSeriesState?> {
  final EasyRefreshController refreshController = EasyRefreshController(
    controlFinishLoad: true,
    controlFinishRefresh: true,
  );

  Future<void> fetch(int id) async {
    try {
      final response = await apiClient.novelSeries(id);
      final detail = NovelSeriesResponse.fromJson(response.data);
      final list = detail.novels.map((e) => NovelStore(e.id, e)).toList();
      final result = NovelSeriesState(
        detail.novelSeriesDetail,
        detail.novels,
        list,
        detail.nextUrl,
      );
      state = result;
      refreshController.finishRefresh();
    } catch (e) {
      print(e);
      refreshController.finishRefresh(IndicatorResult.fail);
    }
  }

  Future<void> onLoadNext() async {
    if (state?.nextUrl != null) {
      try {
        final response = await apiClient.getNext(state!.nextUrl!);
        final detail = NovelSeriesResponse.fromJson(response.data);
        final list = detail.novels.map((e) => NovelStore(e.id, e)).toList();
        final result = NovelSeriesState(
          detail.novelSeriesDetail,
          state!.novels + detail.novels,
          state!.novelStores + list,
          detail.nextUrl,
        );
        state = result;
        refreshController.finishLoad(
          IndicatorResult.success,
          detail.nextUrl == null,
        );
      } catch (e) {
        print(e);
        refreshController.finishLoad(IndicatorResult.fail);
      }
    } else {
      refreshController.finishLoad(IndicatorResult.success, true);
    }
  }

  Future<void> addWatchlist() async {
    try {
      await apiClient.watchListNovelAdd(state!.novelSeriesDetail.id.toString());
      final updatedDetail = state!.novelSeriesDetail;
      updatedDetail.watchlistAdded = true;
      final result = NovelSeriesState(
        updatedDetail,
        state!.novels,
        state!.novelStores,
        state!.nextUrl,
      );
      state = result;
    } catch (e) {
      print(e);
    }
  }

  Future<void> removeWatchlist() async {
    try {
      await apiClient.watchListNovelDelete(
        state!.novelSeriesDetail.id.toString(),
      );
      final updatedDetail = state!.novelSeriesDetail;
      updatedDetail.watchlistAdded = false;
      final result = NovelSeriesState(
        updatedDetail,
        state!.novels,
        state!.novelStores,
        state!.nextUrl,
      );
      state = result;
    } catch (e) {
      print(e);
    }
  }

  @override
  NovelSeriesState? build() {
    return null;
  }
}

class NovelSeriesPage extends HookConsumerWidget {
  final int id;
  const NovelSeriesPage(this.id, {Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(novelSeriesProvider);
    final refreshState = useState(0);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (data != null) ...[
              PainterAvatar(
                url: data.novelSeriesDetail.user.profileImageUrls.medium,
                id: data.novelSeriesDetail.user.id,
                size: Size(30, 30),
                onTap: () {
                  Leader.push(
                    context,
                    NovelUsersPage(id: data.novelSeriesDetail.user.id),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text(
                  "${data.novelSeriesDetail.user.name}",
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ],
        ),
        actions: [
          Builder(
            builder: (context) {
              return IconButton(
                onPressed: () {
                  final box = context.findRenderObject() as RenderBox?;
                  final pos = box != null
                      ? box.localToGlobal(Offset.zero) & box.size
                      : null;
                  final link = "https://www.pixiv.net/novel/series/$id";
                  SharePlus.instance.share(
                    ShareParams(text: link, sharePositionOrigin: pos),
                  );
                },
                icon: WcIcon(Icons.share),
              );
            },
          ),
        ],
      ),
      body: EasyRefresh(
        refreshOnStart: true,
        controller: ref.read(novelSeriesProvider.notifier).refreshController,
        onLoad: () async {
          await ref.read(novelSeriesProvider.notifier).onLoadNext();
        },
        child: Builder(
          builder: (context) {
            if (data != null)
              return Container(
                child: CustomScrollView(
                  slivers: [
                    if (WatercolorTokens.of(context) != null)
                      SliverToBoxAdapter(
                        child: _buildWatercolorHeader(context, ref, data),
                      )
                    else ...[
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            Container(height: 60),
                            ShortcutSelectionArea(
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 16.0),
                                child: Text(
                                  "${data.novelSeriesDetail.title}",
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                            ),
                            ShortcutSelectionArea(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  "${data.novelSeriesDetail.caption ?? ""}",
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ),
                            SizedBox(height: 12),
                            GestureDetector(
                              onTap: () {
                                if (data.novelSeriesDetail.watchlistAdded ==
                                    true) {
                                  ref
                                      .read(novelSeriesProvider.notifier)
                                      .removeWatchlist();
                                  ref
                                      .read(
                                        novelWatchListStoreProvider.notifier,
                                      )
                                      .fetch();
                                } else {
                                  ref
                                      .read(novelSeriesProvider.notifier)
                                      .addWatchlist();
                                  ref
                                      .read(
                                        novelWatchListStoreProvider.notifier,
                                      )
                                      .fetch();
                                }
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                decoration:
                                    data.novelSeriesDetail.watchlistAdded ==
                                        true
                                    ? BoxDecoration(
                                        border: Border.all(
                                          color: Colors.black,
                                          width: 1,
                                        ),
                                        borderRadius: BorderRadius.circular(21),
                                      )
                                    : BoxDecoration(
                                        color: Colors.blue,
                                        borderRadius: BorderRadius.circular(21),
                                      ),
                                padding: EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 12,
                                ),
                                child: Text(
                                  data.novelSeriesDetail.watchlistAdded == true
                                      ? I18n.of(context).watchlist_added
                                      : I18n.of(context).add_to_watchlist,
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color:
                                            data
                                                    .novelSeriesDetail
                                                    .watchlistAdded ==
                                                true
                                            ? Colors.black
                                            : Colors.white,
                                      ),
                                ),
                              ),
                            ),
                            SizedBox(height: 12),
                          ],
                          crossAxisAlignment: CrossAxisAlignment.center,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0),
                              child: SizedBox(
                                width: double.infinity,
                                child: FilledButton.tonal(
                                  onPressed: () {
                                    Leader.push(
                                      context,
                                      NovelViewerPage(id: data.novels.last.id),
                                    );
                                  },
                                  child: Text(I18n.of(context).view_the_latest),
                                ),
                              ),
                            ),
                            Divider(),
                          ],
                        ),
                      ),
                    ],
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final novel = data.novels[index];
                        return _buildItem(
                          context,
                          novel,
                          data.novelStores[index],
                          index,
                          refreshState,
                        );
                      }, childCount: data.novels.length),
                    ),
                  ],
                ),
              );
            return CustomScrollView(slivers: []);
          },
        ),
        onRefresh: () async {
          await ref.read(novelSeriesProvider.notifier).fetch(id);
        },
      ),
    );
  }

  void _toggleWatchlist(WidgetRef ref, NovelSeriesState data) {
    if (data.novelSeriesDetail.watchlistAdded == true) {
      ref.read(novelSeriesProvider.notifier).removeWatchlist();
    } else {
      ref.read(novelSeriesProvider.notifier).addWatchlist();
    }
    ref.read(novelWatchListStoreProvider.notifier).fetch();
  }

  /// Title, caption, then the watchlist pigment pill beside an outlined
  /// button for the latest episode.
  Widget _buildWatercolorHeader(
    BuildContext context,
    WidgetRef ref,
    NovelSeriesState data,
  ) {
    final tokens = WatercolorTokens.of(context)!;
    final added = data.novelSeriesDetail.watchlistAdded == true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShortcutSelectionArea(
            child: Text(
              "${data.novelSeriesDetail.title}",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: tokens.ink,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ShortcutSelectionArea(
            child: Text(
              "${data.novelSeriesDetail.caption ?? ""}",
              style: TextStyle(fontSize: 13, height: 1.6, color: tokens.body),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _toggleWatchlist(ref, data),
                  behavior: HitTestBehavior.opaque,
                  child: PressScale(
                    child: SizedBox(
                      height: 44,
                      child: PigmentBackdrop(
                        color: tokens.pigment(0),
                        visible: !added,
                        bleed: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 3,
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: added ? tokens.line : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            added
                                ? I18n.of(context).watchlist_added
                                : I18n.of(context).add_to_watchlist,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: added ? tokens.sub : tokens.onPigment,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () {
                      Leader.push(
                        context,
                        NovelViewerPage(id: data.novels.last.id),
                      );
                    },
                    child: Text(
                      I18n.of(context).view_the_latest,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    Novel novel,
    NovelStore novelStore,
    int index,
    ValueNotifier<int> refreshState,
  ) {
    final tokens = WatercolorTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Card(
        child: InkWell(
          onTap: () async {
            await Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (BuildContext context) =>
                    NovelViewerPage(id: novel.id, novelStore: novelStore),
              ),
            );
            refreshState.value = refreshState.value + 1;
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: 5,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: tokens == null
                          ? const EdgeInsets.symmetric(vertical: 8.0)
                          : const EdgeInsets.fromLTRB(10, 10, 2, 10),
                      child: tokens == null
                          ? PixivImage(novel.imageUrls.medium, width: 80)
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: PixivImage(
                                novel.imageUrls.medium,
                                width: 64,
                              ),
                            ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0, left: 8.0),
                            child: tokens == null
                                ? Text(
                                    "#${index + 1} ${novel.title}",
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge,
                                    maxLines: 3,
                                  )
                                : Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: "#${index + 1} ",
                                          style: TextStyle(
                                            color: tokens.accent,
                                          ),
                                        ),
                                        TextSpan(text: novel.title),
                                      ],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 3,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: tokens.ink,
                                    ),
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                            ),
                            child: Text(
                              novel.user.name,
                              maxLines: 1,
                              style: Theme.of(context).textTheme.bodySmall!
                                  .copyWith(
                                    color:
                                        tokens?.sub ??
                                        Theme.of(context).colorScheme.secondary,
                                  ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                            ),
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 2, // gap between adjacent chips
                              runSpacing: 0,
                              children: [
                                for (var f in novel.tags)
                                  Text(
                                    f.name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                          Container(height: 8.0),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    NovelBookmarkButton(novel: novelStore.novel!),
                    Text(
                      '${novel.totalBookmarks}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
