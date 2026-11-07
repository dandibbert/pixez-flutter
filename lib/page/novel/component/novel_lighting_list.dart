/*
 * Copyright (C) 2020. by perol_notsf, All rights reserved
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program. If not, see <http://www.gnu.org/licenses/>.
 *
 */

import 'package:easy_refresh/easy_refresh.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:pixez/component/pixez_default_header.dart';
import 'package:pixez/component/pixiv_image.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/lighting/lighting_store.dart';
import 'package:pixez/models/novel_recom_response.dart';
import 'package:pixez/page/novel/component/novel_bookmark_button.dart';
import 'package:pixez/page/novel/component/novel_intro.dart';
import 'package:pixez/page/novel/component/novel_lighting_store.dart';
import 'package:pixez/page/novel/search/novel_search_pager.dart';
import 'package:pixez/page/novel/search/novel_seen_store.dart';
import 'package:pixez/page/novel/user/novel_users_page.dart';
import 'package:pixez/page/novel/viewer/novel_viewer.dart';
import 'package:pixez/exts.dart';
import 'package:pixez/main.dart';
import 'package:pixez/watercolor/mingcute.dart';
import 'package:pixez/watercolor/watercolor_motion.dart';
import 'package:pixez/watercolor/watercolor_tokens.dart';
import 'package:pixez/watercolor/watercolor_routes.dart';
import 'package:pixez/watercolor/watercolor_effects.dart';

class NovelLightingList extends StatefulWidget {
  final FutureGet? futureGet;
  final LightSource? source;
  final bool? isNested;
  final ValueChanged<int>? onPageChanged;

  /// Marks novels already opened or seen here, and records what is shown.
  final bool trackSeen;

  /// With [trackSeen], leaves out what was opened or seen before this page
  /// loaded.
  final bool hideSeen;

  const NovelLightingList({
    Key? key,
    this.futureGet,
    this.source,
    this.isNested,
    this.onPageChanged,
    this.trackSeen = false,
    this.hideSeen = false,
  }) : assert(futureGet != null || source != null),
       super(key: key);

  @override
  _NovelLightingListState createState() => _NovelLightingListState();
}

class _NovelLightingListState extends State<NovelLightingList> {
  late EasyRefreshController _easyRefreshController;
  late NovelLightingStore _store;
  late bool _isNested;
  late ScrollController _scrollController;

  // What was seen or opened when the current page loaded. Marks and hiding
  // use this snapshot, so cards do not fade or vanish while being read.
  String? _snapshotKey;
  Set<int> _seenAtLoad = const {};
  Set<int> _readAtLoad = const {};
  final Map<int, GlobalKey> _itemKeys = {};
  final GlobalKey _viewportKey = GlobalKey();

  bool get _isPaged => widget.source is ApiPagedSource;

  FutureGet get _legacySource {
    final futureGet = widget.futureGet;
    if (futureGet != null) return futureGet;
    return () {
      final source = widget.source;
      if (source is ApiForceSource) return source.fetch(false);
      if (source is ApiSource) return source.fetch();
      if (source is ApiPagedSource) {
        return source.fetch(source.initialPage, false);
      }
      throw StateError('NovelLightingList needs a source');
    };
  }

  @override
  void initState() {
    _isNested = widget.isNested ?? false;
    _scrollController = ScrollController();
    _easyRefreshController = EasyRefreshController(
      controlFinishLoad: true,
      controlFinishRefresh: true,
    );
    _store = NovelLightingStore(
      _legacySource,
      _easyRefreshController,
      lightSource: widget.source,
    );
    super.initState();
    if (_isNested || _isPaged) {
      _store.fetch().then(_notifyPage);
    }
    if (widget.trackSeen) {
      if (novelHistoryStore.data.isEmpty) novelHistoryStore.fetch();
      novelSeenStore.load().then((_) {
        // Take the snapshot again now that the stored marks are in.
        if (mounted) setState(() => _snapshotKey = null);
      });
    }
  }

  /// Records the novels that are fully on screen, or fill most of it.
  void _markVisible() {
    if (!widget.trackSeen || !mounted) return;
    final viewport =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.attached) return;
    final height = viewport.size.height;
    final visible = <int>[];
    _itemKeys.forEach((id, key) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) return;
      final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
      final bottom = top + box.size.height;
      final shown = (bottom.clamp(0, height) - top.clamp(0, height));
      if ((top >= -1 && bottom <= height + 1) || shown >= height * 0.6) {
        visible.add(id);
      }
    });
    if (visible.isNotEmpty) novelSeenStore.markSeen(visible);
  }

  void _notifyPage([void _]) {
    if (mounted && _isPaged) {
      widget.onPageChanged?.call(_store.currentPage);
    }
  }

  @override
  void didUpdateWidget(NovelLightingList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.source != null && widget.source != oldWidget.source) {
      _store.update(widget.source!).then(_notifyPage);
    } else if (widget.futureGet != null &&
        oldWidget.futureGet != widget.futureGet) {
      _store.source = widget.futureGet!;
      _store.lightSource = null;
      _store.fetch();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _easyRefreshController.dispose();
    super.dispose();
  }

  Widget _buildBody(BuildContext context) {
    if (_store.errorMessage != null) {
      return Container(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                ':(',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            TextButton(
              onPressed: () {
                if (_isPaged) {
                  _store.fetchPage(_store.currentPage, force: true);
                } else {
                  _store.fetch();
                }
              },
              child: Text(I18n.of(context).retry),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('${_store.errorMessage}'),
            ),
          ],
        ),
      );
    }
    return _buildListBody();
  }

  Widget _buildListBody() {
    var novels = _store.novels
        .where((element) => element.novel?.hateByUser() != true)
        .toList();
    final marks = <int, NovelSeenMark>{};
    var hiddenCount = 0;
    if (widget.trackSeen) {
      final ids = [for (final n in novels) n.novel!.id];
      final read = {for (final h in novelHistoryStore.data) h.novelId};
      final key = '${_store.currentPage}:${ids.join(',')}';
      if (key != _snapshotKey) {
        _snapshotKey = key;
        _seenAtLoad = ids.where(novelSeenStore.ids.contains).toSet();
        _readAtLoad = ids.where(read.contains).toSet();
        _itemKeys.clear();
        WidgetsBinding.instance.addPostFrameCallback((_) => _markVisible());
      }
      final list = novelSeenMarks(
        ids,
        seen: _seenAtLoad,
        read: {..._readAtLoad, ...ids.where(read.contains)},
      );
      for (var i = 0; i < ids.length; i++) {
        marks[ids[i]] = list[i];
      }
      if (widget.hideSeen) {
        final before = novels.length;
        novels = [
          for (final n in novels)
            if (!_seenAtLoad.contains(n.novel!.id) &&
                !_readAtLoad.contains(n.novel!.id))
              n,
        ];
        hiddenCount = before - novels.length;
      }
    }
    if (novels.isEmpty && hiddenCount > 0) {
      return ListView(
        controller: _scrollController,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
            child: Text(
              I18n.of(context).novel_page_all_seen(hiddenCount),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      );
    }
    final list = ListView.builder(
      key: _viewportKey,
      controller: _scrollController,
      padding: EdgeInsets.all(0),
      itemBuilder: (context, index) {
        Novel novel = novels[index].novel!;
        final mark = marks[novel.id] ?? NovelSeenMark.none;
        final tokens = WatercolorTokens.of(context);
        final item = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: InkWell(
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                WetPaperPageRoute(
                  builder: (BuildContext context) =>
                      NovelViewerPage(id: novel.id, novelStore: novels[index]),
                ),
              );
            },
            child: Card(
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
                                    width: 76,
                                  ),
                                ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 8.0,
                                  left: 8.0,
                                ),
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      if (mark != NovelSeenMark.none)
                                        WidgetSpan(
                                          alignment:
                                              PlaceholderAlignment.middle,
                                          child: _SeenBadge(mark: mark),
                                        ),
                                      TextSpan(text: novel.title),
                                    ],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  style: tokens == null
                                      ? Theme.of(context).textTheme.bodyLarge
                                      : TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: tokens.ink,
                                        ),
                                  maxLines: 3,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        Navigator.of(
                                          context,
                                          rootNavigator: true,
                                        ).push(
                                          MaterialPageRoute(
                                            builder: (_) => NovelUsersPage(
                                              id: novel.user.id,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Text(
                                        novel.user.name,
                                        maxLines: 1,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall!
                                            .copyWith(
                                              color:
                                                  tokens?.accent ??
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.secondary,
                                            ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.only(left: 8),
                                      child: Row(
                                        children: [
                                          WcIcon(
                                            Icons.article,
                                            size: 12,
                                            color: Theme.of(
                                              context,
                                            ).textTheme.labelSmall!.color,
                                          ),
                                          SizedBox(width: 2),
                                          Text(
                                            '${novel.textLength}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.labelSmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                ),
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 2,
                                  runSpacing: 0,
                                  children: [
                                    for (var f in novel.tags)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 1,
                                        ),
                                        child: Text(
                                          tokens == null
                                              ? f.name
                                              : '#${f.name}',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                                child: NovelIntroPreview(
                                  caption: novel.caption,
                                ),
                              ),
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
                        NovelBookmarkButton(novel: novel),
                        Text(
                          '${novel.totalBookmarks}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        IconButton(
                          key: Key('novelIntroButton_${novel.id}'),
                          tooltip: I18n.of(context).novel_details,
                          icon: const WcIcon(Icons.info_outline),
                          onPressed: () {
                            showNovelIntroDialog(
                              context: context,
                              title: novel.title,
                              caption: novel.caption,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        Widget card = item;
        if (mark == NovelSeenMark.seen || mark == NovelSeenMark.read) {
          card = Opacity(opacity: 0.55, child: card);
        }
        if (widget.trackSeen) {
          card = KeyedSubtree(
            key: _itemKeys.putIfAbsent(novel.id, () => GlobalKey()),
            child: card,
          );
        }
        if (tokens == null) return card;
        return WcEntrance(token: novels[index], index: index, child: card);
      },
      itemCount: novels.length,
    );
    if (!widget.trackSeen) return list;
    return NotificationListener<ScrollEndNotification>(
      onNotification: (_) {
        _markVisible();
        return false;
      },
      child: list,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final list = EasyRefresh(
          onLoad: _isPaged ? null : () => _store.next(),
          onRefresh: () async {
            if (_isPaged) {
              final ok = await _store.fetchPage(
                _store.currentPage,
                force: true,
              );
              if (ok) _notifyPage();
              return;
            }
            await _store.fetch();
          },
          refreshOnStart: (_isNested || _isPaged) ? false : true,
          controller: _easyRefreshController,
          header: PixezDefault.header(context),
          child: _buildBody(context),
        );
        if (!_isPaged) return list;
        return Column(
          children: [
            Expanded(child: list),
            NovelSearchPagerBar(
              currentPage: _store.currentPage,
              loading: _store.refreshing,
              hasPrevious: _store.currentPage > 1,
              hasNext: _store.nextUrl != null,
              onPrevious: () => _loadPage(_store.currentPage - 1),
              onNext: () => _loadPage(_store.currentPage + 1),
              onPickPage: _showPageDialog,
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPageDialog() async {
    final controller = TextEditingController(
      text: _store.currentPage.toString(),
    );
    final page = await showWcDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(I18n.of(context).jump_to_page),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: I18n.of(context).page_number_hint,
          ),
          onSubmitted: (value) {
            final parsed = int.tryParse(value);
            if (parsed != null && parsed > 0) {
              Navigator.of(dialogContext).pop(parsed);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(I18n.of(context).cancel),
          ),
          TextButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text);
              if (parsed != null && parsed > 0) {
                Navigator.of(dialogContext).pop(parsed);
              }
            },
            child: Text(I18n.of(context).ok),
          ),
        ],
      ),
    );
    controller.dispose();
    if (page != null) await _loadPage(page);
  }

  Future<void> _loadPage(int page) async {
    if (page == _store.currentPage) return;
    final success = await _store.fetchPage(page, force: true);
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(I18n.of(context).search_page_unavailable)),
      );
      return;
    }
    widget.onPageChanged?.call(page);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }
}

/// A small label before a novel's title in search results.
class _SeenBadge extends StatelessWidget {
  const _SeenBadge({required this.mark});

  final NovelSeenMark mark;

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);
    final tokens = WatercolorTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final fresh = mark == NovelSeenMark.fresh;
    final label = switch (mark) {
      NovelSeenMark.read => i18n.novel_seen_read,
      NovelSeenMark.seen => i18n.novel_seen_seen,
      _ => i18n.novel_seen_new,
    };
    final background = fresh
        ? (tokens?.pigment(0) ?? scheme.primaryContainer)
        : (tokens?.line ?? scheme.surfaceContainerHighest);
    final foreground = fresh
        ? (tokens?.onPigment ?? scheme.onPrimaryContainer)
        : (tokens?.sub ?? scheme.onSurfaceVariant);
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}
