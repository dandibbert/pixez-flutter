import 'package:easy_refresh/easy_refresh.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pixez/component/pixez_default_header.dart';
import 'package:pixez/component/pixiv_image.dart';
import 'package:pixez/er/leader.dart';
import 'package:pixez/exts.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/models/novel_watch_list_model.dart';
import 'package:pixez/page/novel/new/novel_watch_list_notifier.dart';
import 'package:pixez/page/novel/series/novel_series_page.dart';
import 'package:pixez/page/novel/viewer/novel_viewer.dart';
import 'package:pixez/watercolor/watercolor_tokens.dart';
import 'package:pixez/watercolor/watercolor_widgets.dart';

class NovelWatchList extends StatefulHookConsumerWidget {
  const NovelWatchList({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _State();
}

class _State extends ConsumerState<NovelWatchList> {
  @override
  Widget build(BuildContext context) {
    final controller = ref
        .watch(novelWatchListStoreProvider.notifier)
        .controller;
    final series = ref.watch(
      novelWatchListStoreProvider.select((e) => e.series),
    );
    useEffect(() {
      Future.delayed(Duration.zero, () {
        ref.read(novelWatchListStoreProvider.notifier).fetch();
      });
      return null;
    }, []);
    return EasyRefresh.builder(
      controller: controller,
      header: PixezDefault.header(context),
      footer: PixezDefault.footer(context),
      onRefresh: () async {
        ref.read(novelWatchListStoreProvider.notifier).fetch();
      },
      onLoad: () async {
        ref.read(novelWatchListStoreProvider.notifier).loadMore();
      },
      childBuilder: (context, physics) {
        return CustomScrollView(
          physics: physics,
          slivers: [
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                return NovelSeriesItem(data: series[index]);
              }, childCount: series.length),
            ),
          ],
        );
      },
    );
  }
}

class NovelSeriesItem extends StatelessWidget {
  final NovelSeriesModel data;
  const NovelSeriesItem({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final tokens = WatercolorTokens.of(context);
    if (tokens != null) return _buildWatercolor(context, tokens);
    return GestureDetector(
      onTap: () {
        Leader.push(context, NovelSeriesPage(data.id));
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  constraints: BoxConstraints(minHeight: 120),
                  child: Stack(
                    children: [
                      PixivImage(
                        data.url ?? '',
                        width: 120,
                        fit: BoxFit.fitWidth,
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          margin: EdgeInsets.only(top: 4, right: 4),
                          padding: EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          child: Text(
                            '${data.publishedContentCount}',
                            style: Theme.of(context).textTheme.bodySmall!
                                .copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Row(
                      children: [
                        Text(
                          data.user?.name ?? '',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      data.lastPublishedContentDatetime.toShortTime(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: InkWell(
                        onTap: () {
                          Leader.push(
                            context,
                            NovelViewerPage(id: data.latestContentId),
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          child: Text(
                            I18n.of(context).view_latest,
                            style: Theme.of(context).textTheme.bodyMedium!
                                .copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Divider(),
        ],
      ),
    );
  }

  /// A paper card per series, with a pigment pill to open the latest episode.
  Widget _buildWatercolor(BuildContext context, WatercolorTokens tokens) {
    final pigment = tokens.pigment(data.id);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: GestureDetector(
        onTap: () {
          Leader.push(context, NovelSeriesPage(data.id));
        },
        behavior: HitTestBehavior.opaque,
        child: WcPanel(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(
                  WatercolorTokens.radiusSmall,
                ),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 120),
                  child: Stack(
                    children: [
                      PixivImage(
                        data.url ?? '',
                        width: 96,
                        fit: BoxFit.fitWidth,
                      ),
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.ink.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${data.publishedContentCount}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: tokens.card,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: tokens.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.user?.name ?? '',
                      style: TextStyle(fontSize: 13, color: tokens.accent),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.lastPublishedContentDatetime.toShortTime(),
                      style: TextStyle(fontSize: 12, color: tokens.sub),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        Leader.push(
                          context,
                          NovelViewerPage(id: data.latestContentId),
                        );
                      },
                      child: SizedBox(
                        height: 32,
                        child: PigmentBackdrop(
                          color: pigment,
                          bleed: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 2,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              I18n.of(context).view_latest,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: tokens.onPigment,
                              ),
                            ),
                          ),
                        ),
                      ),
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
