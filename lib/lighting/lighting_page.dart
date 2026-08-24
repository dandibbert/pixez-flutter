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
import 'package:material_ui/material_ui.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
import 'package:pixez/component/illust_card.dart';
import 'package:pixez/component/pixez_default_header.dart';
import 'package:pixez/constants.dart';
import 'package:pixez/exts.dart';
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
    return Container(child: Center(child: CircularProgressIndicator()));
  }
}

class LightingList extends StatefulWidget {
  final LightSource source;
  final Widget? header;
  final bool? isNested;
  final ScrollController? scrollController;
  final String? portal;
  final bool? ai;
  final bool Function(Illusts)? filter;
  final ValueChanged<int>? onPageChanged;

  const LightingList({
    Key? key,
      required this.source,
      this.header,
      this.isNested,
      this.scrollController,
      this.portal,
      this.ai,
    this.filter,
    this.onPageChanged,
  }) : super(key: key);

  @override
  _LightingListState createState() => _LightingListState();
}

class _LightingListState extends State<LightingList> {
  late LightingStore _store;
  late bool _isNested;
  late ScrollController _scrollController;
  late bool _ai;

  bool get _isPaged => widget.source is ApiPagedSource;

  @override
  void didUpdateWidget(LightingList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
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
    if (!_isNested &&
        _store.errorMessage == null &&
        !_store.iStores.isEmpty &&
        _scrollController.hasClients) {
      _scrollController.position.jumpTo(0.0);
    }
  }

  ReactionDisposer? disposer;

  @override
  void initState() {
    _ai = widget.ai ?? false;
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
  }

  @override
  void dispose() {
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

  late EasyRefreshController _refreshController;

  Widget _buildWithoutHeader(context) {
    _store.iStores.removeWhere((element) {
      if (element.illusts!.hateByUser(ai: _ai)) return true;
      if (widget.filter != null && !widget.filter!(element.illusts!)) {
        return true;
      }
      return false;
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
        footer: _isPaged ? null : PixezDefault.footer(context),
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

  Widget _buildErrorContent(context) {
    final errorText = _buildErrorText(context);
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
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          TextButton(
              onPressed: () {
              if (_isPaged) {
                _store.fetchPage(_store.currentPage, force: true);
              } else {
                _store.fetch(force: true);
              }
              },
            child: Text(I18n.of(context).retry),
          ),
          Padding(padding: const EdgeInsets.all(16.0), child: Text(errorText)),
        ],
      ),
    );
  }

  String _buildErrorText(BuildContext context) {
    final errorMessage = _store.errorMessage;
    final message = errorMessage?.contains("400") == true
        ? '${I18n.of(context).error_400_hint}\n $errorMessage'
        : '$errorMessage';
    return '(${Constants.tagName}) $message';
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
        footer: _isPaged
            ? null
            : PixezDefault.footer(context, position: IndicatorPosition.locator),
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
              if (!_isPaged) const FooterLocator.sliver(),
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
      if (element.illusts!.hateByUser(ai: _ai)) return true;
      if (widget.filter != null && !widget.filter!(element.illusts!)) {
        return true;
      }
      return false;
    });
    return SliverChildBuilderDelegate((BuildContext context, int index) {
      return IllustCard(
        lightingStore: _store,
        store: _store.iStores[index],
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
    var nowAdaptWidth = max(currentValue, 50.0);
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
