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
import 'package:pixez/page/novel/component/novel_lighting_store.dart';
import 'package:pixez/page/novel/viewer/novel_viewer.dart';
import 'package:pixez/exts.dart';

class NovelLightingList extends StatefulWidget {
  final FutureGet? futureGet;
  final LightSource? source;
  final bool? isNested;
  final ValueChanged<int>? onPageChanged;

  const NovelLightingList({
    Key? key,
    this.futureGet,
    this.source,
    this.isNested,
    this.onPageChanged,
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
        controlFinishLoad: true, controlFinishRefresh: true);
    _store = NovelLightingStore(
      _legacySource,
      _easyRefreshController,
      lightSource: widget.source,
    );
    super.initState();
    if (_isNested || _isPaged) {
      _store.fetch().then(_notifyPage);
    }
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
              child:
                  Text(':(', style: Theme.of(context).textTheme.headlineMedium),
            ),
            TextButton(
                onPressed: () {
                  if (_isPaged) {
                    _store.fetchPage(_store.currentPage, force: true);
                  } else {
                    _store.fetch();
                  }
                },
                child: Text(I18n.of(context).retry)),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('${_store.errorMessage}'),
            )
          ],
        ),
      );
    }
    return _buildListBody();
  }

  ListView _buildListBody() {
    final novels = _store.novels
        .where((element) => element.novel?.hateByUser() != true)
        .toList();
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(0),
      itemBuilder: (context, index) {
        Novel novel = novels[index].novel!;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: InkWell(
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
                  builder: (BuildContext context) => NovelViewerPage(
                        id: novel.id,
                        novelStore: novels[index],
                      )));
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
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: PixivImage(
                            novel.imageUrls.medium,
                            width: 80,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 8.0, left: 8.0),
                                child: Text(
                                  novel.title,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                  maxLines: 3,
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      novel.user.name,
                                      maxLines: 1,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall!
                                          .copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .secondary),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.only(left: 8),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.article,
                                            size: 12,
                                            color: Theme.of(context)
                                                .textTheme
                                                .labelSmall!
                                                .color,
                                          ),
                                          SizedBox(
                                            width: 2,
                                          ),
                                          Text(
                                            '${novel.textLength}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall,
                                          )
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 2,
                                  runSpacing: 0,
                                  children: [
                                    for (var f in novel.tags)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 1),
                                        child: Text(
                                          f.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      )
                                  ],
                                ),
                              ),
                              Container(
                                height: 8.0,
                              )
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
                        Text('${novel.totalBookmarks}',
                            style: Theme.of(context).textTheme.bodySmall)
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      },
      itemCount: novels.length,
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
              final ok = await _store.fetchPage(_store.currentPage, force: true);
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
            _buildPaginationBar(context),
          ],
        );
      },
    );
  }

  Widget _buildPaginationBar(BuildContext context) {
    final loading = _store.refreshing;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: loading || _store.currentPage <= 1
                  ? null
                  : () => _loadPage(_store.currentPage - 1),
              icon: const Icon(Icons.chevron_left),
              label: Text(I18n.of(context).pre),
            ),
            TextButton(
              onPressed: loading ? null : _showPageDialog,
              child: Text(
                I18n.of(context).search_result_page(_store.currentPage),
              ),
            ),
            TextButton.icon(
              onPressed: loading || _store.nextUrl == null
                  ? null
                  : () => _loadPage(_store.currentPage + 1),
              label: Text(I18n.of(context).next),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPageDialog() async {
    final controller = TextEditingController(
      text: _store.currentPage.toString(),
    );
    final page = await showDialog<int>(
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
