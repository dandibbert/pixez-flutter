import 'dart:async';
import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:pixez/clipboard_plugin.dart';
import 'package:pixez/component/app_keyboard_shortcuts.dart';
import 'package:pixez/component/mouse_drag_scroll_configuration.dart';
import 'package:pixez/component/photo_view_interaction.dart';
import 'package:pixez/component/pixiv_image.dart';
import 'package:pixez/er/pixiv_image_source.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/main.dart';
import 'package:pixez/models/illust.dart';
import 'package:pixez/page/picture/illust_store.dart';
import 'package:pixez/utils/haptic_util.dart';
import 'package:share_plus/share_plus.dart';

class PhotoZoomPage extends StatefulWidget {
  final int index;
  final Illusts illusts;
  final IllustStore illustStore;

  const PhotoZoomPage({
    Key? key,
    required this.index,
    required this.illusts,
    required this.illustStore,
  }) : super(key: key);

  @override
  _PhotoZoomPageState createState() => _PhotoZoomPageState();
}

class _PhotoZoomPageState extends State<PhotoZoomPage> {
  late Illusts _illusts;
  late final PageController _pageController;
  late final List<PhotoViewController> _photoControllers;
  final GlobalKey _photoViewportKey = GlobalKey();
  final Map<String, Future<Size>> _imageSizeFutures = {};
  int _index = 0;

  @override
  void initState() {
    _loadSource = userSetting.zoomQuality == 1;
    _illusts = widget.illusts;
    _index = widget.index;
    _pageController = PageController(initialPage: _index);
    final photoCount = _illusts.pageCount == 1 ? 1 : _illusts.metaPages.length;
    _photoControllers = List.generate(
      photoCount > 0 ? photoCount : 1,
      (_) => PhotoViewController(),
    );
    nowUrl = _illusts.pageCount == 1
        ? (_loadSource
              ? _illusts.metaSinglePage!.originalImageUrl!
              : _illusts.imageUrls.large)
        : (_loadSource
              ? _illusts.metaPages[_index].imageUrls!.original
              : _illusts.metaPages[_index].imageUrls!.large);

    super.initState();
    initCache();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _photoControllers) {
      controller.dispose();
    }
    if (_fullScreen)
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    super.dispose();
  }

  initCache() async {
    final requestedUrl = nowUrl;
    var fileInfo = await pixivCacheManager!.getFileFromCache(
      _sourceUrl(requestedUrl),
    );
    if (mounted && nowUrl == requestedUrl) {
      setState(() {
        shareShow = fileInfo != null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final enablePagingShortcuts = _illusts.pageCount > 1;
    return AppKeyboardShortcuts(
      onMetaI: Platform.isMacOS
          ? () => unawaited(_fitCurrentPhotoToWidth())
          : null,
      onArrowLeft: enablePagingShortcuts ? () => _goToPage(_index - 1) : null,
      onArrowRight: enablePagingShortcuts ? () => _goToPage(_index + 1) : null,
      child: Builder(
        builder: (context) {
          if (_illusts.pageCount == 1) {
            final url = _loadSource
                ? _illusts.metaSinglePage!.originalImageUrl!
                : _illusts.imageUrls.large;
            return Scaffold(
              extendBody: true,
              extendBodyBehindAppBar: true,
              backgroundColor: Colors.black,
              bottomNavigationBar: _buildBottom(context),
              body: _buildPhotoViewport(
                PhotoView(
                  filterQuality: FilterQuality.medium,
                  initialScale: PhotoViewComputedScale.contained,
                  controller: _photoControllers.first,
                  heroAttributes: PhotoViewHeroAttributes(tag: url),
                  imageProvider: PixivProvider.url(url),
                  loadingBuilder: (context, event) => _buildLoading(event),
                ),
              ),
            );
          } else {
            return Scaffold(
              extendBody: true,
              bottomNavigationBar: _buildBottom(context),
              extendBodyBehindAppBar: true,
              backgroundColor: Colors.black,
              body: _buildPhotoViewport(
                MouseDragScrollConfiguration(
                  child: PhotoViewGallery.builder(
                    scrollPhysics: const BouncingScrollPhysics(),
                    pageController: _pageController,
                    builder: (BuildContext context, int index) {
                      final url = _loadSource
                          ? _illusts.metaPages[index].imageUrls!.original
                          : _illusts.metaPages[index].imageUrls!.large;
                      return PhotoViewGalleryPageOptions(
                        imageProvider: PixivProvider.url(url),
                        initialScale: PhotoViewComputedScale.contained,
                        controller: _photoControllers[index],
                        heroAttributes: PhotoViewHeroAttributes(tag: url),
                        filterQuality: FilterQuality.medium,
                      );
                    },
                    itemCount: _illusts.metaPages.length,
                    onPageChanged: _onPageChanged,
                    loadingBuilder: (context, event) => _buildLoading(event),
                  ),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  String nowUrl = "";

  String _sourceUrl(String url) => PixivImageSource.resolve(
    url,
    networkMode: userSetting.networkMode,
    pictureSource: userSetting.pictureSource,
  );

  bool show = false;
  bool shareShow = false;
  bool _loadSource = false;
  bool _fullScreen = false;
  bool _fittingWidth = false;

  PhotoViewController get _currentPhotoController =>
      _photoControllers[_illusts.pageCount == 1 ? 0 : _index];

  Widget _buildPhotoViewport(Widget child) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Listener(
          key: _photoViewportKey,
          behavior: HitTestBehavior.opaque,
          onPointerSignal: _onPointerSignal,
          child: child,
        ),
        Positioned.fill(
          child: SafeArea(
            minimum: const EdgeInsets.all(8),
            child: Align(
              alignment: Alignment.topLeft,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  key: const ValueKey('photo_back_button'),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (!Platform.isMacOS ||
        event is! PointerScrollEvent ||
        event.scrollDelta.dy == 0) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (signal) {
      final scrollEvent = signal as PointerScrollEvent;
      unawaited(_scrollCurrentPhoto(scrollEvent.scrollDelta.dy));
    });
  }

  Future<void> _scrollCurrentPhoto(double scrollDelta) async {
    final index = _index;
    final url = nowUrl;
    final controller = _currentPhotoController;
    try {
      final imageSize = await _resolveImageSize(url, context);
      if (!mounted || index != _index || url != nowUrl) return;
      final viewportSize = _photoViewportSize;
      if (viewportSize == null) return;
      scrollPhotoViewVertically(
        controller: controller,
        imageSize: imageSize,
        viewportSize: viewportSize,
        scrollDelta: scrollDelta,
      );
    } catch (_) {
      // 图片尚未加载完成时忽略本次滚轮事件；下次滚动会重新解析尺寸。
    }
  }

  Size? get _photoViewportSize {
    final renderObject = _photoViewportKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    return renderObject.size;
  }

  Future<Size> _resolveImageSize(String url, BuildContext context) {
    final cached = _imageSizeFutures[url];
    if (cached != null) return cached;

    final completer = Completer<Size>();
    final provider = PixivProvider.url(url);
    final stream = provider.resolve(createLocalImageConfiguration(context));
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        if (!completer.isCompleted) {
          completer.complete(
            Size(info.image.width.toDouble(), info.image.height.toDouble()),
          );
        }
      },
      onError: (Object error, StackTrace? stackTrace) {
        stream.removeListener(listener);
        _imageSizeFutures.remove(url);
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
    );
    stream.addListener(listener);
    final future = completer.future;
    _imageSizeFutures[url] = future;
    return future;
  }

  Future<void> _fitCurrentPhotoToWidth() async {
    if (_fittingWidth) return;
    final index = _index;
    final url = nowUrl;
    final controller = _currentPhotoController;
    setState(() {
      _fittingWidth = true;
    });
    try {
      final imageSize = await _resolveImageSize(url, context);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || index != _index || url != nowUrl) return;
      final viewportSize = _photoViewportSize;
      if (viewportSize == null) return;
      fitPhotoViewToWidth(
        controller: controller,
        imageSize: imageSize,
        viewportSize: viewportSize,
      );
    } catch (_) {
      if (mounted) {
        BotToast.showText(
          text: I18n.of(context).load_image_failed_click_to_reload,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _fittingWidth = false;
        });
      }
    }
  }

  Future<void> _onPageChanged(int index) async {
    nowUrl = _loadSource
        ? _illusts.metaPages[index].imageUrls!.original
        : _illusts.metaPages[index].imageUrls!.large;
    setState(() {
      _index = index;
      shareShow = false;
    });
    final requestedUrl = nowUrl;
    final file = await pixivCacheManager!.getFileFromCache(
      _sourceUrl(requestedUrl),
    );
    if (file != null && mounted && nowUrl == requestedUrl && _index == index) {
      setState(() {
        shareShow = true;
      });
    }
  }

  void _goToPage(int index) {
    if (!_pageController.hasClients ||
        index < 0 ||
        index >= _illusts.metaPages.length ||
        index == _index) {
      return;
    }
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  void _toggleImageQuality() {
    for (final controller in _photoControllers) {
      controller.reset();
    }
    setState(() {
      _loadSource = !_loadSource;
      nowUrl = _illusts.pageCount == 1
          ? (_loadSource
                ? _illusts.metaSinglePage!.originalImageUrl!
                : _illusts.imageUrls.large)
          : (_loadSource
                ? _illusts.metaPages[_index].imageUrls!.original
                : _illusts.metaPages[_index].imageUrls!.large);
      shareShow = false;
    });
    initCache();
  }

  Widget _buildBottom(BuildContext context) {
    if (_fullScreen) {
      return BottomAppBar(
        color: Colors.transparent,
        child: Row(
          children: [
            IconButton(
              onPressed: () {
                setState(() {
                  _fullScreen = false;
                });
                SystemChrome.setEnabledSystemUIMode(
                  SystemUiMode.manual,
                  overlays: SystemUiOverlay.values,
                );
              },
              icon: Icon(
                Icons.fullscreen_exit,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            _buildFitWidthButton(context),
          ],
        ),
      );
    }
    return BottomAppBar(
      color: Colors.transparent,
      child: Visibility(
        visible: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        if (Platform.isMacOS || Platform.isLinux)
                          IconButton(
                            tooltip: I18n.of(context).pre,
                            icon: const Icon(
                              Icons.navigate_before,
                              color: Colors.white,
                            ),
                            onPressed: _index > 0
                                ? () => _goToPage(_index - 1)
                                : null,
                          ),
                        IconButton(
                          iconSize: 16,
                          icon: Icon(
                            Icons.photo_library_outlined,
                            color: Colors.white,
                          ),
                          onPressed: () {},
                        ),
                        Text(
                          "${_index + 1}/${widget.illusts.pageCount}",
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge!.copyWith(color: Colors.white),
                        ),
                        if (Platform.isMacOS || Platform.isLinux)
                          IconButton(
                            tooltip: I18n.of(context).next,
                            icon: const Icon(
                              Icons.navigate_next,
                              color: Colors.white,
                            ),
                            onPressed: _index + 1 < _illusts.metaPages.length
                                ? () => _goToPage(_index + 1)
                                : null,
                          ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(Icons.fullscreen, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              _fullScreen = true;
                            });
                            SystemChrome.setEnabledSystemUIMode(
                              SystemUiMode.manual,
                              overlays: [],
                            );
                          },
                        ),
                        _buildFitWidthButton(context),
                        if (ClipboardPlugin.supported)
                          IconButton(
                            icon: Icon(Icons.copy, color: Colors.white),
                            onPressed: () =>
                                ClipboardPlugin.copy(context, _illusts, _index),
                          ),
                        GestureDetector(
                          child: IconButton(
                            icon: Icon(Icons.save_alt, color: Colors.white),
                            onPressed: () {
                              if (_illusts.metaPages.isNotEmpty)
                                saveStore.saveImage(
                                  widget.illusts,
                                  index: _index,
                                );
                              else
                                saveStore.saveImage(widget.illusts);
                              if (userSetting.starAfterSave &&
                                  (widget.illustStore.state == 0)) {
                                widget.illustStore.star(
                                  restrict: userSetting.defaultPrivateLike
                                      ? "private"
                                      : "public",
                                );
                              }
                            },
                          ),
                          onLongPress: () async {
                            HapticUtil.heavy();
                            if (_illusts.metaPages.isNotEmpty)
                              saveStore.saveImage(
                                widget.illusts,
                                index: _index,
                              );
                            else
                              saveStore.saveImage(widget.illusts);
                          },
                        ),
                        AnimatedOpacity(
                          opacity: shareShow ? 1 : 0.5,
                          duration: Duration(milliseconds: 500),
                          child: Builder(
                            builder: (context) {
                              return IconButton(
                                icon: Icon(Icons.share, color: Colors.white),
                                onPressed: () async {
                                  var file = await pixivCacheManager!
                                      .getFileFromCache(_sourceUrl(nowUrl));
                                  if (file != null) {
                                    String targetPath = path.join(
                                      (await getTemporaryDirectory()).path,
                                      "share_cache",
                                      path.basenameWithoutExtension(
                                            file.file.path,
                                          ) +
                                          (nowUrl.endsWith(".png")
                                              ? ".png"
                                              : ".jpg"),
                                    );
                                    File targetFile = new File(targetPath);
                                    if (!targetFile.existsSync()) {
                                      targetFile.createSync(recursive: true);
                                    }
                                    file.file.copySync(targetPath);
                                    final box =
                                        context.findRenderObject()
                                            as RenderBox?;
                                    SharePlus.instance.share(
                                      ShareParams(
                                        files: [XFile(targetPath)],
                                        sharePositionOrigin:
                                            box!.localToGlobal(Offset.zero) &
                                            box.size,
                                      ),
                                    );
                                  } else {
                                    BotToast.showText(
                                      text: "can not find image cache",
                                    );
                                  }
                                },
                              );
                            },
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            !_loadSource ? Icons.hd_outlined : Icons.hd,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            _toggleImageQuality();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFitWidthButton(BuildContext context) {
    return IconButton(
      key: const ValueKey('photo_fit_width_button'),
      tooltip: I18n.of(context).fit_width,
      onPressed: _fittingWidth ? null : _fitCurrentPhotoToWidth,
      icon: _fittingWidth
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.width_full, color: Colors.white),
    );
  }

  Center _buildLoading(ImageChunkEvent? event) {
    double value = event == null || event.expectedTotalBytes == null
        ? 0
        : event.cumulativeBytesLoaded / event.expectedTotalBytes!;
    if (value == 1.0) {
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            shareShow = true;
          });
        }
      });
    }
    return Center(
      child: Container(
        width: 20.0,
        height: 20.0,
        child: CircularProgressIndicator(value: value),
      ),
    );
  }
}
