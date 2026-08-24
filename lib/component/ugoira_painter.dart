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

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:pixez/main.dart';
import 'package:pixez/models/ugoira_metadata_response.dart';

class UgoiraWidget extends StatefulWidget {
  final List<FileSystemEntity> drawPools;
  final int delay;
  final Size size;
  final UgoiraMetadataResponse ugoiraMetadataResponse;

  const UgoiraWidget(
      {Key? key,
      required this.drawPools,
      required this.delay,
      required this.size,
      required this.ugoiraMetadataResponse})
      : super(key: key);

  @override
  _UgoiraWidgetState createState() => _UgoiraWidgetState();
}

class _UgoiraWidgetState extends State<UgoiraWidget>
    with RouteAware, WidgetsBindingObserver {
  static const int _imageCacheBudgetBytes = 32 * 1024 * 1024;

  final LinkedHashMap<File, _CachedUgoiraImage> _imageCache =
      LinkedHashMap<File, _CachedUgoiraImage>();
  int _imageCacheBytes = 0;
  Timer? _frameTimer;
  ModalRoute<void>? _subscribedRoute;
  late AppLifecycleState _appLifecycleState;
  bool _routeVisible = true;
  bool _frameLoadInProgress = false;
  bool _disposed = false;
  int _playGeneration = 0;

  Future<ui.Image?> _loadImage(File file) async {
    final cached = _imageCache.remove(file);
    if (cached != null) {
      _imageCache[file] = cached;
      return cached.image;
    }

    final data = await file.readAsBytes();
    final decoded = await decodeImageFromList(data.buffer.asUint8List());
    if (_disposed) {
      decoded.dispose();
      return null;
    }

    final entry = _CachedUgoiraImage(decoded);
    _imageCache[file] = entry;
    _imageCacheBytes += entry.bytes;
    _trimImageCache(protectedImage: decoded, secondaryProtectedImage: image);
    return decoded;
  }

  int point = 0;
  ui.Image? image;

  @override
  void initState() {
    super.initState();
    _appLifecycleState =
        WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _resumePlayback());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of<void>(context);
    if (route != null && !identical(route, _subscribedRoute)) {
      if (_subscribedRoute != null) routeObserver.unsubscribe(this);
      routeObserver.subscribe(this, route);
      _subscribedRoute = route;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _pausePlayback();
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    _subscribedRoute = null;
    final images = HashSet<ui.Image>.identity();
    images.addAll(_imageCache.values.map((entry) => entry.image));
    final currentImage = image;
    if (currentImage != null) images.add(currentImage);
    for (final cachedImage in images) {
      cachedImage.dispose();
    }
    _imageCache.clear();
    _imageCacheBytes = 0;
    image = null;
    super.dispose();
  }

  @override
  void didPopNext() {
    super.didPopNext();
    _routeVisible = true;
    _resumePlayback();
  }

  @override
  void didPushNext() {
    super.didPushNext();
    _routeVisible = false;
    _pausePlayback();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      _resumePlayback();
    } else {
      _pausePlayback();
    }
  }

  bool get _canPlay =>
      !_disposed &&
      mounted &&
      _routeVisible &&
      _appLifecycleState == AppLifecycleState.resumed;

  void _pausePlayback() {
    _playGeneration++;
    _frameTimer?.cancel();
    _frameTimer = null;
  }

  void _resumePlayback() {
    if (!_canPlay || _frameTimer?.isActive == true || _frameLoadInProgress) {
      return;
    }
    _playGeneration++;
    _beginNextFrame(_playGeneration);
  }

  void _beginNextFrame(int generation) {
    if (!_canPlay ||
        generation != _playGeneration ||
        _frameLoadInProgress) {
      return;
    }
    _frameLoadInProgress = true;
    unawaited(_showNextFrame(generation));
  }

  Future<void> _showNextFrame(int generation) async {
    var nextDelay = Duration(milliseconds: widget.delay);
    try {
      final frameCount = widget.drawPools.length <
              widget.ugoiraMetadataResponse.ugoiraMetadata.frames.length
          ? widget.drawPools.length
          : widget.ugoiraMetadataResponse.ugoiraMetadata.frames.length;
      if (frameCount == 0 || !_canPlay || generation != _playGeneration) {
        return;
      }

      final frameIndex = point % frameCount;
      final entity = widget.drawPools[frameIndex];
      point = (frameIndex + 1) % frameCount;
      nextDelay = Duration(
        milliseconds: widget
            .ugoiraMetadataResponse
            .ugoiraMetadata
            .frames[frameIndex]
            .delay,
      );
      if (entity is! File) return;

      final decoded = await _loadImage(entity);
      if (decoded == null || !_canPlay || generation != _playGeneration) {
        return;
      }
      setState(() {
        image = decoded;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) _trimImageCache(protectedImage: image);
      });
    } catch (_) {
      // 单帧损坏时跳过该帧，避免未处理异常终止整条播放循环。
    } finally {
      _frameLoadInProgress = false;
      if (!_canPlay) return;
      if (generation != _playGeneration) {
        _resumePlayback();
        return;
      }
      _frameTimer = Timer(nextDelay, () {
        _frameTimer = null;
        _beginNextFrame(generation);
      });
    }
  }

  void _trimImageCache({
    ui.Image? protectedImage,
    ui.Image? secondaryProtectedImage,
  }) {
    while (_imageCacheBytes > _imageCacheBudgetBytes &&
        _imageCache.length > 1) {
      File? evictionKey;
      for (final entry in _imageCache.entries) {
        if (!identical(entry.value.image, protectedImage) &&
            !identical(entry.value.image, secondaryProtectedImage)) {
          evictionKey = entry.key;
          break;
        }
      }
      if (evictionKey == null) return;
      final evicted = _imageCache.remove(evictionKey)!;
      _imageCacheBytes -= evicted.bytes;
      evicted.image.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return image != null
        ? CustomPaint(
            painter: UgoiraPainter(image!),
            size: widget.size,
          )
        : Container();
  }
}

class UgoiraPainter extends CustomPainter {
  final ui.Image image;

  final Paint _paint = Paint();

  UgoiraPainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    Rect dstRect =
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    canvas.drawImageRect(
        image,
        dstRect,
        Rect.fromLTWH(0, 0, size.width.toDouble(), size.height.toDouble()),
        _paint);
  }

  @override
  bool shouldRepaint(UgoiraPainter oldDelegate) {
    return oldDelegate.image != image;
  }
}

class _CachedUgoiraImage {
  _CachedUgoiraImage(this.image) : bytes = image.width * image.height * 4;

  final ui.Image image;
  final int bytes;
}
