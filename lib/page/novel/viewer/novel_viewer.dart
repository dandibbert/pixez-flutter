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

import 'dart:convert';
import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:mobx/mobx.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pixez/component/painter_avatar.dart';
import 'package:pixez/component/pixiv_image.dart';
import 'package:pixez/component/selectable_html.dart';
import 'package:pixez/er/leader.dart';
import 'package:pixez/er/lprinter.dart';
import 'package:pixez/exts.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/main.dart';
import 'package:pixez/models/ban_tag.dart';
import 'package:pixez/models/novel_recom_response.dart';
import 'package:pixez/models/novel_web_response.dart';
import 'package:pixez/page/comment/comment_page.dart';
import 'package:pixez/page/novel/component/novel_bookmark_button.dart';
import 'package:pixez/page/novel/search/novel_result_page.dart';
import 'package:pixez/page/novel/series/novel_series_page.dart';
import 'package:pixez/page/novel/user/novel_users_page.dart';
import 'package:pixez/page/novel/viewer/image_text.dart';
import 'package:pixez/page/novel/viewer/novel_pages.dart';
import 'package:pixez/page/novel/viewer/novel_reader_background.dart';
import 'package:pixez/page/novel/viewer/novel_reader_keys.dart';
import 'package:pixez/page/novel/viewer/novel_reader_style.dart';
import 'package:pixez/page/novel/viewer/novel_reader_widgets.dart';
import 'package:pixez/page/novel/viewer/novel_spans.dart';
import 'package:pixez/page/novel/tts/novel_tts_bar.dart';
import 'package:pixez/page/novel/tts/novel_tts_controller.dart';
import 'package:pixez/page/novel/tts/novel_tts_follow.dart';
import 'package:pixez/page/novel/tts/novel_tts_text.dart';
import 'package:pixez/page/novel/viewer/novel_store.dart';
import 'package:pixez/saf_plugin.dart';
import 'package:pixez/supportor_plugin.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as Path;

class NovelViewerPage extends StatefulWidget {
  final int id;
  final NovelStore? novelStore;

  const NovelViewerPage({Key? key, required this.id, this.novelStore})
    : super(key: key);

  @override
  _NovelViewerPageState createState() => _NovelViewerPageState();
}

class _NovelViewerPageState extends State<NovelViewerPage> {
  ScrollController? _controller;
  late NovelStore _novelStore;
  late NovelTtsController _tts;
  ReactionDisposer? _offsetDisposer;
  int _currentPage = 1;
  bool supportTranslate = false;
  bool _ttsResumeChecked = false;
  bool _ttsDrivingPage = false;
  int _ttsUiClip = -1;
  NovelTtsStatus? _ttsUiStatus;
  int? _ttsUiPage;
  final Map<int, GlobalKey> _ttsBlockKeys = {};
  final Map<int, NovelStore> _prefetchedTtsStores = {};
  String _selectedText = "";
  NovelSpansGenerator novelSpansGenerator = NovelSpansGenerator();

  Future<void> initMethod() async {
    if (!Platform.isAndroid) return;
    bool results = await SupportorPlugin.processText();
    if (mounted) {
      setState(() {
        supportTranslate = results;
      });
    }
  }

  @override
  void initState() {
    _novelStore = widget.novelStore ?? NovelStore(widget.id, null);
    _offsetDisposer = reaction((_) => _novelStore.bookedOffset, (_) {
      _restoreBookedPage();
    });
    _tts = NovelTtsController.instance;
    _tts.onNavigate = _onTtsNavigate;
    _tts.onLoadChapter = _loadTtsChapter;
    _tts.addListener(_onTtsProgress);
    if (_novelStore.novelTextResponse == null) {
      _novelStore.fetch();
    }
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    super.initState();
    initMethod();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _offsetDisposer?.call();
    _tts.removeListener(_onTtsProgress);
    if (identical(_tts.onNavigate, _onTtsNavigate)) {
      _tts.onNavigate = null;
    }
    if (identical(_tts.onLoadChapter, _loadTtsChapter)) {
      _tts.onLoadChapter = null;
    }
    if (_novelStore.positionBooked) {
      _novelStore.bookPosition(_currentPage.toDouble());
    }
    _controller?.dispose();
    super.dispose();
  }

  final NovelReaderSplitCache _splitCache = NovelReaderSplitCache();

  List<List<NovelSpansData>> get _pages => _splitCache.pages(_novelStore.spans);

  int get _totalPages => _pages.length;

  void _restoreBookedPage() {
    final page = restoreNovelPage(
      bookedOffset: _novelStore.bookedOffset,
      totalPages: _totalPages,
    );
    if (!mounted || page == _currentPage) {
      return;
    }
    setState(() {
      _currentPage = page;
    });
    _controller?.jumpTo(0);
  }

  void _goToPage(int page) {
    final next = clampNovelPage(page, _totalPages);
    if (next != _currentPage) {
      _ttsBlockKeys.clear();
    }
    setState(() {
      _currentPage = next;
    });
    _controller?.jumpTo(0);
    if (!_ttsDrivingPage &&
        _tts.isActive &&
        _tts.session?.novelId == widget.id) {
      _attachTtsPage();
    }
  }

  void _openSeriesNovel(int id, {NovelStore? store}) {
    Navigator.of(context, rootNavigator: true).pushReplacement(
      MaterialPageRoute(
        builder: (BuildContext context) => NovelViewerPage(
          id: id,
          novelStore: store ?? NovelStore(id, null),
        ),
      ),
    );
  }

  void _maybeResumeTts() {
    if (_ttsResumeChecked || _novelStore.novel == null) {
      return;
    }
    _ttsResumeChecked = true;
    if (_tts.isActive && _tts.session?.novelId == widget.id) {
      final page = _tts.session?.page;
      if (page != null && page != _currentPage) {
        _ttsDrivingPage = true;
        _goToPage(page);
        _ttsDrivingPage = false;
      }
      return;
    }
    if (!_tts.takePendingResume(widget.id)) {
      return;
    }
    _startTts(fromEnd: _tts.pendingResumeFromEnd);
  }

  void _onTtsNavigate(NovelTtsNavigate navigate) {
    if (!mounted) {
      return;
    }
    if (navigate.kind == NovelTtsNavigateKind.page && navigate.page != null) {
      _ttsBlockKeys.clear();
      _ttsDrivingPage = true;
      _goToPage(navigate.page!);
      _ttsDrivingPage = false;
      if (!navigate.keepPlaying) {
        _attachTtsPage(fromEnd: navigate.fromEnd);
      }
      return;
    }
    if (navigate.kind == NovelTtsNavigateKind.series &&
        navigate.seriesNovelId != null) {
      _openSeriesNovel(
        navigate.seriesNovelId!,
        store: _prefetchedTtsStores.remove(navigate.seriesNovelId),
      );
    }
  }

  void _onTtsProgress() {
    if (!mounted) {
      return;
    }
    final clip = _tts.clipIndex;
    final status = _tts.status;
    final page = _tts.session?.page;
    if (clip == _ttsUiClip && status == _ttsUiStatus && page == _ttsUiPage) {
      return;
    }
    final clipMoved = clip != _ttsUiClip || page != _ttsUiPage;
    _ttsUiClip = clip;
    _ttsUiStatus = status;
    _ttsUiPage = page;
    setState(() {});
    if (clipMoved && _tts.isActive && _tts.session?.novelId == widget.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToTtsClip();
        }
      });
    }
  }

  void _scrollToTtsClip() {
    if (_tts.session?.novelId != widget.id ||
        _tts.session?.page != _currentPage) {
      return;
    }
    final pages = _pages;
    if (pages.isEmpty) {
      return;
    }
    final pageIndex = clampNovelPage(_currentPage, pages.length) - 1;
    final blocks = _splitCache.blocks(pages[pageIndex], pageIndex);
    final index = novelTtsBlockIndexForClip(
      blocks: blocks,
      clipText: _tts.subtitle,
    );
    final targetContext = _ttsBlockKeys[index]?.currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        alignment: 0.28,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
      return;
    }
    final controller = _controller;
    if (controller == null || !controller.hasClients || blocks.isEmpty) {
      return;
    }
    final max = controller.position.maxScrollExtent;
    final target = max * (index / blocks.length);
    controller.animateTo(
      target.clamp(controller.position.minScrollExtent, max),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  Future<NovelTtsChapter?> _loadTtsChapter(int id) async {
    final store = _prefetchedTtsStores[id] ?? NovelStore(id, null);
    if (store.novel == null || store.spans.isEmpty) {
      await store.fetch();
    }
    final novel = store.novel;
    if (novel == null || store.spans.isEmpty) {
      return null;
    }
    _prefetchedTtsStores[id] = store;
    final pages = NovelReaderSplitCache().pages(store.spans);
    final navigation = store.novelTextResponse?.seriesNavigation;
    return NovelTtsChapter(
      novelId: id,
      title: novel.title,
      author: novel.user.name,
      pageTexts: [
        for (var i = 0; i < pages.length; i++) novelTtsTextFromPages(pages, i),
      ],
      coverUrl: novel.imageUrls.medium,
      prevSeriesId: navigation?.prevNovel?.viewable == true
          ? navigation!.prevNovel!.id
          : null,
      nextSeriesId: navigation?.nextNovel?.viewable == true
          ? navigation!.nextNovel!.id
          : null,
    );
  }

  Future<void> _startTts({bool fromEnd = false}) async {
    final novel = _novelStore.novel;
    if (novel == null) {
      return;
    }
    final pages = _pages;
    final totalPages = pages.isEmpty ? 1 : pages.length;
    final page = clampNovelPage(_currentPage, totalPages);
    final pageTexts = [
      for (var i = 0; i < totalPages; i++) novelTtsTextFromPages(pages, i),
    ];
    final navigation = _novelStore.novelTextResponse?.seriesNavigation;
    await _tts.start(
      novelId: widget.id,
      title: novel.title,
      author: novel.user.name,
      page: page,
      totalPages: totalPages,
      pageText: pageTexts[page - 1],
      pageTexts: pageTexts,
      coverUrl: novel.imageUrls.medium,
      prevSeriesId: navigation?.prevNovel?.viewable == true
          ? navigation!.prevNovel!.id
          : null,
      nextSeriesId: navigation?.nextNovel?.viewable == true
          ? navigation!.nextNovel!.id
          : null,
      startChunk: fromEnd ? 1 << 20 : 0,
    );
  }

  Future<void> _attachTtsPage({bool fromEnd = false}) async {
    final pages = _pages;
    final totalPages = pages.isEmpty ? 1 : pages.length;
    final page = clampNovelPage(_currentPage, totalPages);
    final navigation = _novelStore.novelTextResponse?.seriesNavigation;
    await _tts.attachPage(
      page: page,
      totalPages: totalPages,
      pageText: novelTtsTextFromPages(pages, page - 1),
      prevSeriesId: navigation?.prevNovel?.viewable == true
          ? navigation!.prevNovel!.id
          : null,
      nextSeriesId: navigation?.nextNovel?.viewable == true
          ? navigation!.nextNovel!.id
          : null,
      fromEnd: fromEnd,
    );
  }

  Future<void> _toggleTts() async {
    if (_tts.isActive && _tts.session?.novelId == widget.id) {
      await _tts.toggle();
      return;
    }
    await _startTts();
  }

  void _handleNav(String direction) {
    final navigation = _novelStore.novelTextResponse?.seriesNavigation;
    final action = resolveNovelReaderNavigation(
      direction: direction,
      currentPage: _currentPage,
      totalPages: _totalPages,
      prevNovel: navigation?.prevNovel,
      nextNovel: navigation?.nextNovel,
    );
    if (action.kind == NovelReaderNavKind.series &&
        action.seriesNovelId != null) {
      _openSeriesNovel(action.seriesNovelId!);
      return;
    }
    if (action.kind == NovelReaderNavKind.page) {
      _goToPage(direction == 'prev' ? _currentPage - 1 : _currentPage + 1);
    }
  }

  bool _onHardwareKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return false;
    }
    if (!mounted ||
        _novelStore.novelTextResponse == null ||
        ModalRoute.of(context)?.isCurrent != true) {
      return false;
    }
    final action = resolveNovelReaderKey(
      key: event.logicalKey,
      isEditingText: novelReaderIsEditingText(
        FocusManager.instance.primaryFocus,
      ),
      hasModifier: novelReaderHasModifier(
        HardwareKeyboard.instance.logicalKeysPressed,
      ),
      canScrollUp:
          _controller != null &&
          _controller!.hasClients &&
          novelReaderCanScroll(_controller!.position, -1),
      canScrollDown:
          _controller != null &&
          _controller!.hasClients &&
          novelReaderCanScroll(_controller!.position, 1),
      isRepeat: event is KeyRepeatEvent,
    );
    if (action == null) {
      return false;
    }
    _performKeyAction(action);
    return true;
  }

  void _performKeyAction(NovelReaderKeyAction action) {
    switch (action) {
      case NovelReaderKeyAction.prevPage:
        _handleNav('prev');
      case NovelReaderKeyAction.nextPage:
        _handleNav('next');
      case NovelReaderKeyAction.firstPage:
        _goToPage(1);
      case NovelReaderKeyAction.lastPage:
        _goToPage(_totalPages);
      case NovelReaderKeyAction.jumpToPage:
        _showJumpDialog(context, _totalPages);
      case NovelReaderKeyAction.goBack:
        Navigator.of(context).maybePop();
      case NovelReaderKeyAction.scrollUp:
        _scrollArticle(-1);
      case NovelReaderKeyAction.scrollDown:
        _scrollArticle(1);
    }
  }

  void _scrollArticle(double direction) {
    final controller = _controller;
    if (controller == null || !controller.hasClients) {
      return;
    }
    final position = controller.position;
    final delta = position.viewportDimension * 0.9 * direction;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    controller.animateTo(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  TextStyle _readerStyle(BuildContext context) {
    // Track MobX text style so font family / line height changes rebuild.
    userSetting.novelTextStyle;
    return NovelReaderStyle.resolve(
      color: Theme.of(context).colorScheme.onSurface,
      fontSize: userSetting.novelFontsize,
      lineHeight: userSetting.novelLineHeight,
      fontFamily: userSetting.novelFontFamily,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        if (_novelStore.errorMessage != null) {
          return _buildErrorContent(context);
        }
        if (_novelStore.novelTextResponse != null &&
            _novelStore.novel != null) {
          if (_controller == null) {
            _controller = ScrollController();
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _maybeResumeTts();
          });
          // Recolour the whole reader subtree so the chrome, the article and
          // the settings sheet all follow the reading background.
          return Theme(
            data: applyNovelReaderTheme(
              Theme.of(context),
              userSetting.novelReaderBackground,
            ),
            child: Focus(
              autofocus: true,
              child: Builder(
                builder: (context) => Scaffold(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  body: _buildReader(context),
                ),
              ),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(elevation: 0.0, backgroundColor: Colors.transparent),
          body: const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  Widget _buildReader(BuildContext context) {
    final novel = _novelStore.novel!;
    final pages = _pages;
    final totalPages = pages.isEmpty ? 1 : pages.length;
    final pageIndex = clampNovelPage(_currentPage, totalPages) - 1;
    final pageSpans = pages.isEmpty ? <NovelSpansData>[] : pages[pageIndex];
    final blocks = _splitCache.blocks(pageSpans, pageIndex);
    final navigation = _novelStore.novelTextResponse?.seriesNavigation;
    final navState = resolveNovelPageNavState(
      currentPage: clampNovelPage(_currentPage, totalPages),
      totalPages: totalPages,
      hasPrevSeries: navigation?.prevNovel?.viewable == true,
      hasNextSeries: navigation?.nextNovel?.viewable == true,
    );
    final style = _readerStyle(context);

    return NovelReaderScaffold(
      header: NovelReaderHeader(
        title: novel.title,
        author: novel.user.name,
        onBack: () => Navigator.of(context).pop(),
        onTitleTap: () => _showDetails(context),
        onDetails: () => _showDetails(context),
        onAuthorTap: () {
          Leader.push(context, NovelUsersPage(id: novel.user.id));
        },
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListenableBuilder(
              listenable: _tts,
              builder: (context, _) {
                final mine = _tts.session?.novelId == widget.id;
                final paused = mine && _tts.status == NovelTtsStatus.paused;
                final listening = mine && _tts.isActive && !paused;
                return IconButton(
                  tooltip: paused
                      ? I18n.of(context).novel_tts_resume
                      : listening
                      ? I18n.of(context).novel_tts_pause
                      : I18n.of(context).novel_tts_play,
                  icon: Icon(
                    paused
                        ? Icons.play_circle_outline
                        : listening
                        ? Icons.pause_circle_outline
                        : Icons.headphones,
                  ),
                  onPressed: _toggleTts,
                );
              },
            ),
            NovelBookmarkButton(novel: novel),
            IconButton(
              tooltip: I18n.of(context).setting,
              icon: const Icon(Icons.text_fields),
              onPressed: () => _showSettings(context),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showMessage(context),
            ),
          ],
        ),
      ),
      seriesBar: novel.series.id == null
          ? null
          : NovelReaderSeriesBar(
              title: novel.series.title ?? '',
              onOpenSeries: () {
                Leader.push(context, NovelSeriesPage(novel.series.id!));
              },
              onPrev: navigation?.prevNovel?.viewable == true
                  ? () => _openSeriesNovel(navigation!.prevNovel!.id)
                  : null,
              onNext: navigation?.nextNovel?.viewable == true
                  ? () => _openSeriesNovel(navigation!.nextNovel!.id)
                  : null,
            ),
      article: SelectionArea(
        onSelectionChanged: (value) {
          _selectedText = value?.plainText ?? "";
        },
        contextMenuBuilder: (context, editableTextState) {
          return _buildSelectionMenu(editableTextState, context);
        },
        child: NovelReaderArticle(
          controller: _controller,
          itemCount: blocks.length,
          itemBuilder: (context, index) {
            return _buildReaderBlock(context, blocks[index], style, index);
          },
        ),
      ),
      pageNav: NovelReaderPageNav(
        currentPage: clampNovelPage(_currentPage, totalPages),
        totalPages: totalPages,
        navState: navState,
        onPrev: () => _handleNav('prev'),
        onNext: () => _handleNav('next'),
        onPickPage: () => _showJumpDialog(context, totalPages),
      ),
      player: ListenableBuilder(
        listenable: _tts,
        builder: (context, _) {
          if (!_tts.isActive && _tts.status != NovelTtsStatus.error) {
            return const SizedBox.shrink();
          }
          return NovelTtsBar(
            controller: _tts,
            onOpenSettings: () => openNovelTtsSettings(context),
          );
        },
      ),
    );
  }

  Widget _buildReaderBlock(
    BuildContext context,
    NovelReaderBlock block,
    TextStyle style,
    int index,
  ) {
    if (block.isBlank) {
      return SizedBox(height: style.fontSize ?? 16);
    }
    final follow = _tts.isActive &&
        _tts.session?.novelId == widget.id &&
        _tts.session?.page == _currentPage;
    var highlighted = false;
    if (follow) {
      final pages = _pages;
      if (pages.isNotEmpty) {
        final pageIndex = clampNovelPage(_currentPage, pages.length) - 1;
        highlighted =
            index ==
            novelTtsBlockIndexForClip(
              blocks: _splitCache.blocks(pages[pageIndex], pageIndex),
              clipText: _tts.subtitle,
            );
      }
    }
    final scheme = Theme.of(context).colorScheme;
    final key = _ttsBlockKeys.putIfAbsent(index, GlobalKey.new);
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: highlighted
              ? scheme.primaryContainer.withValues(alpha: 0.45)
              : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: highlighted
              ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
              : EdgeInsets.zero,
          child: Text.rich(
            TextSpan(
              style: style,
              children: [
                for (final span in block.spans)
                  novelSpansGenerator.novelSpansDatatoInlineSpan(
                    context,
                    span,
                    onJumpToPage: _goToPage,
                    onOpenNovel: (id) {
                      Leader.push(context, NovelViewerPage(id: id));
                    },
                    style: style,
                  ),
              ],
            ),
            textHeightBehavior: const TextHeightBehavior(
              applyHeightToLastDescent: true,
            ),
          ),
        ),
      ),
    );
  }

  Scaffold _buildErrorContent(BuildContext context) {
    return Scaffold(
      appBar: AppBar(elevation: 0.0),
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: Text(
                  ':(',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                _novelStore.fetch();
              },
              child: Text(I18n.of(context).retry),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text('${_novelStore.errorMessage}'),
            ),
          ],
        ),
      ),
    );
  }

  AdaptiveTextSelectionToolbar _buildSelectionMenu(
    SelectableRegionState editableTextState,
    BuildContext context,
  ) {
    final List<ContextMenuButtonItem> buttonItems =
        editableTextState.contextMenuButtonItems;
    if (supportTranslate) {
      buttonItems.insert(
        buttonItems.length,
        ContextMenuButtonItem(
          label: I18n.of(context).translate,
          onPressed: () async {
            final selectionText = _selectedText;
            if (Platform.isIOS) {
              final box = context.findRenderObject() as RenderBox?;
              final pos = box != null
                  ? box.localToGlobal(Offset.zero) & box.size
                  : null;
              SharePlus.instance.share(
                ShareParams(text: selectionText, sharePositionOrigin: pos),
              );
              return;
            }
            await SupportorPlugin.start(selectionText);
            ContextMenuController.removeAny();
          },
        ),
      );
    }
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }

  Future<void> _showJumpDialog(BuildContext context, int totalPages) async {
    final controller = TextEditingController(text: _currentPage.toString());
    final page = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(I18n.of(context).jump_to_page),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (value) {
              Navigator.of(context).pop(int.tryParse(value));
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(I18n.of(context).cancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(int.tryParse(controller.text));
              },
              child: Text(I18n.of(context).ok),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (page != null) {
      _goToPage(page);
    }
  }

  Future<void> _showSettings(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return NovelReaderSettingsSheet(
          fontSize: userSetting.novelFontsize,
          lineHeight: userSetting.novelLineHeight,
          fontFamily: userSetting.novelFontFamily,
          fontFilePath: userSetting.novelFontFile,
          background: userSetting.novelReaderBackground,
          onBackgroundChanged: (value) {
            userSetting.setNovelReaderBackground(value);
          },
          onFontSizeChanged: (value) {
            userSetting.setNovelFontsizeWithoutSave(value);
          },
          onLineHeightChanged: (value) {
            userSetting.setNovelLineHeight(value, persist: false);
          },
          onFontFamilyChanged: (choice) {
            userSetting.setNovelFontFamily(
              choice.family,
              filePath: choice.filePath,
            );
          },
        );
      },
    );
    await userSetting.setNovelFontsize(userSetting.novelFontsize);
    await userSetting.setNovelLineHeight(userSetting.novelLineHeight);
  }

  Future<void> _showDetails(BuildContext context) async {
    final novel = _novelStore.novel!;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.4,
          maxChildSize: 0.94,
          builder: (context, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        I18n.of(context).novel_details,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: SizedBox(
                    height: 160,
                    child: PixivImage(novel.imageUrls.medium),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  novel.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (novel.series.id != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        Leader.push(context, NovelSeriesPage(novel.series.id!));
                      },
                      child: Text(
                        novel.series.title ?? '',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ),
                _buildNumItem(novel),
                Text(
                  "${novel.createDate}",
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 2,
                    runSpacing: 0,
                    children: [
                      if (novel.NovelAIType == 2)
                        Text(
                          I18n.of(context).ai_generated,
                          style: Theme.of(context).textTheme.bodySmall!
                              .copyWith(
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                        ),
                      for (var f in novel.tags) buildRow(context, f),
                    ],
                  ),
                ),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SelectionArea(
                      onSelectionChanged: (value) {
                        _selectedText = value?.plainText ?? "";
                      },
                      contextMenuBuilder: (context, editableTextState) {
                        return _buildSelectionMenu(editableTextState, context);
                      },
                      child: SelectableHtml(data: novel.caption),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Leader.push(
                      context,
                      CommentPage(
                        id: _novelStore.id,
                        type: CommentArtWorkType.NOVEL,
                      ),
                    );
                  },
                  child: Text(
                    '${I18n.of(context).view_comment}(${novel.totalComments})',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future _longPressTag(BuildContext context, Tag f) async {
    switch (await showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: Text(f.name),
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, 0);
              },
              child: Text(I18n.of(context).ban),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, 2);
              },
              child: Text(I18n.of(context).copy),
            ),
          ],
        );
      },
    )) {
      case 0:
        {
          await muteStore.insertBanTag(
            BanTagPersist(name: f.name, translateName: f.translatedName ?? ""),
          );
          Navigator.of(context).pop();
        }
        break;
      case 2:
        {
          await Clipboard.setData(ClipboardData(text: f.name));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 1),
              content: Text(I18n.of(context).copied_to_clipboard),
            ),
          );
        }
    }
  }

  Widget buildRow(BuildContext context, Tag f) {
    return GestureDetector(
      onLongPress: () async {
        _longPressTag(context, f);
      },
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) {
              return NovelResultPage(
                word: f.name,
                translatedName: f.translatedName ?? "",
              );
            },
          ),
        );
      },
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          text: "#${f.name}",
          children: [
            TextSpan(text: " ", style: Theme.of(context).textTheme.bodySmall),
            TextSpan(
              text: "${f.translatedName ?? "~"}",
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      ),
    );
  }

  Widget _buildNumItem(Novel novel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 2,
        runSpacing: 0,
        children: [
          Text(I18n.of(context).total_bookmark),
          Text(
            "${novel.totalBookmarks}",
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(I18n.of(context).total_view),
          ),
          Text(
            "${novel.totalView}",
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
    );
  }

  Future _showMessage(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ListTile(
                subtitle: Text(_novelStore.novel!.user.name, maxLines: 2),
                title: Text(_novelStore.novel!.title, maxLines: 2),
                leading: PainterAvatar(
                  url: _novelStore.novel!.user.profileImageUrls.medium,
                  id: _novelStore.novel!.user.id,
                  size: const Size(40, 40),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) {
                          return NovelUsersPage(id: _novelStore.novel!.user.id);
                        },
                      ),
                    );
                  },
                ),
              ),
              ListTile(
                title: Text(I18n.of(context).history),
                leading: Icon(
                  Icons.history,
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(
                    _novelStore.positionBooked ? 225 : 120,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  if (_novelStore.positionBooked) {
                    _novelStore.deleteBookPosition();
                  } else {
                    _novelStore.bookPosition(_currentPage.toDouble());
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(I18n.of(context).pre),
              ),
              buildListTile(
                _novelStore.novelTextResponse!.seriesNavigation?.prevNovel,
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(I18n.of(context).next),
              ),
              buildListTile(
                _novelStore.novelTextResponse!.seriesNavigation?.nextNovel,
              ),
              if (Platform.isAndroid)
                ListTile(
                  title: Text(I18n.of(context).export),
                  leading: const Icon(Icons.folder_zip),
                  onTap: () {
                    _export();
                  },
                ),
              ListTile(
                title: Text(I18n.of(context).setting),
                leading: const Icon(Icons.settings),
                onTap: () {
                  Navigator.of(context).pop();
                  _showSettings(context);
                },
              ),
              ListTile(
                title: Text(I18n.of(context).novel_tts_settings),
                leading: const Icon(Icons.headphones),
                onTap: () {
                  Navigator.of(context).pop();
                  openNovelTtsSettings(context);
                },
              ),
              Builder(
                builder: (context) {
                  return ListTile(
                    title: Text(I18n.of(context).share),
                    leading: const Icon(Icons.share),
                    onTap: () {
                      Navigator.of(context).pop();
                      final box = context.findRenderObject() as RenderBox?;
                      final pos = box != null
                          ? box.localToGlobal(Offset.zero) & box.size
                          : null;
                      final link =
                          "https://www.pixiv.net/novel/show.php?id=${widget.id}";
                      SharePlus.instance.share(
                        ShareParams(text: link, sharePositionOrigin: pos),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildListTile(PrevNovel? series) {
    if (series == null) return ListTile(title: Text(I18n.of(context).no_more));
    return ListTile(
      title: Text(
        series.title ?? series.contentOrder,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      enabled: series.viewable,
      onTap: series.viewable
          ? () {
              _openSeriesNovel(series.id);
            }
          : null,
    );
  }

  void _export() async {
    if (_novelStore.novelTextResponse == null) return;
    if (Platform.isAndroid) {
      final data = _novelStore.novelTextResponse!.text;
      final uri = await SAFPlugin.createFile(
        "${_novelStore.novel!.title.trim().toLegal()}.txt",
        "application/txt",
      );
      await SAFPlugin.writeUri(uri!, utf8.encode(data));
      BotToast.showText(text: "export success");
    } else if (Platform.isIOS) {
      final path = await getApplicationDocumentsDirectory();
      final dirPath = Path.join(path.path, "novel_export");
      final dir = Directory(dirPath);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final allPath = Path.join(dirPath, "All");
      final allDir = Directory(allPath);
      if (!allDir.existsSync()) {
        allDir.createSync(recursive: true);
      }
      final novelDirPath = Path.join(
        dirPath,
        _novelStore.novel!.title.trim().toLegal(),
      );
      final novelDir = Directory(novelDirPath);
      if (!novelDir.existsSync()) {
        novelDir.createSync(recursive: true);
      }
      final fileInAllPath = Path.join(
        allPath,
        "${_novelStore.novel!.title.trim().toLegal()}.txt",
      );
      final filePath = Path.join(novelDirPath, "${_novelStore.novel!.id}.txt");
      final resultFile = File(filePath);
      final data = _novelStore.novelTextResponse!.text;
      resultFile.writeAsStringSync(data);
      File(fileInAllPath).writeAsStringSync(data);
      LPrinter.d("path: $filePath");
      BotToast.showText(text: "export ${filePath}");
    }
  }
}
