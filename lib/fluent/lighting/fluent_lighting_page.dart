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

import 'dart:math';

import 'package:easy_refresh/easy_refresh.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
import 'package:pixez/component/pixez_default_header.dart';
import 'package:pixez/fluent/component/illust_card.dart';
import 'package:pixez/exts.dart';
import 'package:pixez/utils.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/lighting/lighting_store.dart';
import 'package:pixez/main.dart';
import 'package:pixez/models/illust.dart';
import 'package:waterfall_flow/waterfall_flow.dart';

class WaterFallLoading extends StatefulWidget {
  const WaterFallLoading({Key? key}) : super(key: key);

  @override
  State<WaterFallLoading> createState() => _WaterFallLoadingState();
}

class _WaterFallLoadingState extends State<WaterFallLoading> {
  @override
  Widget build(BuildContext context) {
    return Container(child: Center(child: ProgressRing()));
  }
}

class LightingList extends StatefulWidget {
  final LightSource source;
  final Widget? header;
  final bool? isNested;
  final ScrollController? scrollController;
  final String? portal;
  final ValueChanged<int>? onPageChanged;
  final bool Function(Illusts)? filter;

  const LightingList({
    Key? key,
      required this.source,
      this.header,
      this.isNested,
      this.scrollController,
    this.portal,
    this.onPageChanged,
    this.filter,
  }) : super(key: key);

  @override
  _LightingListState createState() => _LightingListState();
}

class _LightingListState extends State<LightingList> {
  late LightingStore _store;
  late bool _isNested;
  late ScrollController _scrollController;

  bool get _isPaged => widget.source is ApiPagedSource;

  @override
  void didUpdateWidget(LightingList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _configureLoadMoreListener();
      _fetch(source: widget.source);
    }
  }

  _fetch({LightSource? source}) async {
    final success = source == null
        ? await _store.fetch(force: true)
        : await _store.update(source, force: true);
    if (success && _isPaged) {
      widget.onPageChanged?.call(_store.currentPage);
    }
    if (!_isNested && _store.errorMessage == null && !_store.iStores.isEmpty) {
      _scrollController.position.jumpTo(0.0);
    }
  }

  ReactionDisposer? disposer;

  void Function()? _disableListener;

  @override
  void initState() {
    _isNested = widget.isNested ?? false;
    _scrollController = widget.scrollController ?? ScrollController();
    _refreshController = EasyRefreshController(
      controlFinishLoad: true,
      controlFinishRefresh: true,
    );
    _store = LightingStore(widget.source);
    _store.easyRefreshController = _refreshController;
    super.initState();
    _store.fetch().then((success) {
      if (success && mounted && _isPaged) {
        widget.onPageChanged?.call(_store.currentPage);
      }
    });
    _configureLoadMoreListener();
  }

  void _configureLoadMoreListener() {
    _disableListener?.call();
    _disableListener = _isPaged
        ? null
        : initializeScrollController(_scrollController, _store.fetchNext);
  }

  @override
  void dispose() {
    if (_disableListener != null) _disableListener!();
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    _store.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  bool backToTopVisible = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Observer(
        builder: (_) {
          final content = Container(child: _buildContent(context));
          if (!_isPaged) return content;
          return Column(
            children: [
              Expanded(child: content),
              _buildPaginationBar(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPaginationBar(BuildContext context) {
    final loading = _store.refreshing;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Button(
            onPressed: loading || _store.currentPage <= 1
                ? null
                : () => _loadPage(_store.currentPage - 1),
            child: Row(
              children: [
                const Icon(FluentIcons.chevron_left),
                const SizedBox(width: 6),
                Text(I18n.of(context).pre),
              ],
            ),
          ),
          Button(
            onPressed: loading ? null : _showPageDialog,
            child: Text(
              I18n.of(context).search_result_page(_store.currentPage),
            ),
          ),
          Button(
            onPressed: loading || _store.nextUrl == null
                ? null
                : () => _loadPage(_store.currentPage + 1),
            child: Row(
              children: [
                Text(I18n.of(context).next),
                const SizedBox(width: 6),
                const Icon(FluentIcons.chevron_right),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPageDialog() async {
    final controller = TextEditingController(
      text: _store.currentPage.toString(),
    );
    final page = await showDialog<int>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: Text(I18n.of(context).jump_to_page),
        content: TextBox(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          placeholder: I18n.of(context).page_number_hint,
          onSubmitted: (value) {
            final parsed = int.tryParse(value);
            if (parsed != null && parsed > 0) {
              Navigator.of(dialogContext).pop(parsed);
            }
          },
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(I18n.of(context).cancel),
          ),
          FilledButton(
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
      displayInfoBar(
        context,
        builder: (context, close) =>
            InfoBar(title: Text(I18n.of(context).search_page_unavailable)),
      );
      return;
    }
    widget.onPageChanged?.call(page);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  late EasyRefreshController _refreshController;

  Widget _buildWithoutHeader(context) {
    _store.iStores.removeWhere((element) {
      final illust = element.illusts!;
      return illust.hateByUser() ||
          (widget.filter != null && !widget.filter!(illust));
    });
    return NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          if (widget.isNested == true) {
            return true;
          }
          ScrollMetrics metrics = notification.metrics;
          if (backToTopVisible == metrics.atEdge && mounted) {
            setState(() {
              backToTopVisible = !backToTopVisible;
            });
          }
          return true;
        },
        child: EasyRefresh.builder(
          controller: _refreshController,
          header: PixezDefault.header(context),
          scrollController: _scrollController,
          onRefresh: () {
          if (_isPaged) {
            _store.fetchPage(_store.currentPage, force: true);
          } else {
            _store.fetch(force: true);
          }
          },
        onLoad: _isPaged ? null : _store.fetchNext,
          childBuilder: (context, physics) => WaterfallFlow.builder(
            physics: physics,
            controller: widget.isNested ?? false ? null : _scrollController,
            padding: EdgeInsets.all(5.0),
            itemCount: _store.iStores.length,
            itemBuilder: (context, index) {
              return _buildItem(index);
            },
            gridDelegate: _buildGridDelegate(),
          ),
      ),
    );
  }

  bool needToBan(Illusts illust) {
    for (var i in muteStore.banillusts) {
      if (i.illustId == illust.id.toString()) return true;
    }
    for (var j in muteStore.banUserIds) {
      if (j.userId == illust.user.id.toString()) return true;
    }
    for (var t in muteStore.banTags) {
      for (var f in illust.tags) {
        if (f.name == t.name) return true;
      }
    }
    return false;
  }

  Widget _buildContent(context) {
    return _store.errorMessage != null
        ? _buildErrorContent(context)
        : _store.iStores.isNotEmpty
            ? (widget.header != null
                ? _buildWithHeader(context)
                : _buildWithoutHeader(context))
            : Container(
                child: _store.refreshing ? WaterFallLoading() : Container(),
              );
  }

  Container _buildErrorContent(context) {
    return Container(
      child: Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(height: 50),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              ':(',
              style: FluentTheme.of(context).typography.subtitle,
            ),
          ),
          Button(
              onPressed: () {
              if (_isPaged) {
                _store.fetchPage(_store.currentPage, force: true);
              } else {
                _store.fetch(force: true);
              }
              },
            child: Text(I18n.of(context).retry),
          ),
          Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                (_store.errorMessage?.contains("400") == true
                    ? '${I18n.of(context).error_400_hint}\n ${_store.errorMessage}'
                    : '${_store.errorMessage}'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWithHeader(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        ScrollMetrics metrics = notification.metrics;
        if (backToTopVisible == metrics.atEdge && mounted) {
          setState(() {
            backToTopVisible = !backToTopVisible;
          });
        }
        return true;
      },
      child: EasyRefresh.builder(
        controller: _refreshController,
        scrollController: _scrollController,
        header: PixezDefault.header(context),
        onRefresh: () {
          if (_isPaged) {
            _store.fetchPage(_store.currentPage, force: true);
          } else {
          _store.fetch(force: true);
          }
        },
        onLoad: _isPaged ? null : _store.fetchNext,
        childBuilder: ((context, physics) {
          return CustomScrollView(
            physics: physics,
            controller: widget.isNested ?? false ? null : _scrollController,
            slivers: [
              SliverToBoxAdapter(child: Container(child: widget.header)),
              SliverWaterfallFlow(
                gridDelegate: _buildGridDelegate(),
                delegate: _buildSliverChildBuilderDelegate(context),
              ),
            ],
          );
        }),
      ),
    );
  }

  SliverChildBuilderDelegate _buildSliverChildBuilderDelegate(
    BuildContext context,
  ) {
    _store.iStores.removeWhere((element) {
      final illust = element.illusts!;
      return illust.hateByUser() ||
          (widget.filter != null && !widget.filter!(illust));
    });
    return SliverChildBuilderDelegate((BuildContext context, int index) {
      return IllustCard(
        store: _store.iStores[index],
        lightingStore: _store,
        iStores: _store.iStores,
        allowDetailLoadMore: !_isPaged,
      );
    }, childCount: _store.iStores.length);
  }

  SliverWaterfallFlowDelegate _buildGridDelegate() {
    var count = 2;
    if (userSetting.crossAdapt) {
      count = _buildSliderValue();
    } else {
      count = (MediaQuery.of(context).orientation == Orientation.portrait)
          ? userSetting.crossCount
          : userSetting.hCrossCount;
    }
    return SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
      crossAxisCount: count,
    );
  }

  int _buildSliderValue() {
    final currentValue =
        (MediaQuery.of(context).orientation == Orientation.portrait
                ? userSetting.crossAdapterWidth
                : userSetting.hCrossAdapterWidth)
            .toDouble();
    var nowAdaptWidth = max(currentValue, 250.0);
    nowAdaptWidth = min(nowAdaptWidth, 2160.0);
    final screenWidth = MediaQuery.of(context).size.width;
    final result = max(screenWidth / nowAdaptWidth, 1.0).toInt();
    return result;
  }

  Widget _buildItem(int index) {
    return IllustCard(
      store: _store.iStores[index],
      lightingStore: _store,
      iStores: _store.iStores,
      allowDetailLoadMore: !_isPaged,
    );
  }
}
