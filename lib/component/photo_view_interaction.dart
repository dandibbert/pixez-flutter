import 'dart:ui';

import 'package:photo_view/photo_view.dart';

double calculateFitWidthScale({
  required Size imageSize,
  required double viewportWidth,
}) {
  if (!imageSize.width.isFinite ||
      imageSize.width <= 0 ||
      !viewportWidth.isFinite ||
      viewportWidth <= 0) {
    throw ArgumentError('Image width and viewport width must be positive.');
  }
  return viewportWidth / imageSize.width;
}

double calculateVerticalOverflow({
  required Size imageSize,
  required Size viewportSize,
  required double scale,
}) {
  if (!imageSize.height.isFinite ||
      imageSize.height <= 0 ||
      !viewportSize.height.isFinite ||
      viewportSize.height <= 0 ||
      !scale.isFinite ||
      scale <= 0) {
    return 0;
  }
  final overflow = imageSize.height * scale - viewportSize.height;
  return overflow > 0 ? overflow : 0;
}

void fitPhotoViewToWidth({
  required PhotoViewController controller,
  required Size imageSize,
  required Size viewportSize,
}) {
  final scale = calculateFitWidthScale(
    imageSize: imageSize,
    viewportWidth: viewportSize.width,
  );
  final overflow = calculateVerticalOverflow(
    imageSize: imageSize,
    viewportSize: viewportSize,
    scale: scale,
  );
  controller.updateMultiple(
    scale: scale,
    // PhotoView 默认以中心为基准；正的半溢出量会把图片顶部对齐视口顶部。
    position: Offset(0, overflow / 2),
  );
}

void scrollPhotoViewVertically({
  required PhotoViewController controller,
  required Size imageSize,
  required Size viewportSize,
  required double scrollDelta,
}) {
  final scale = controller.scale;
  if (scale == null || !scrollDelta.isFinite || scrollDelta == 0) return;

  final overflow = calculateVerticalOverflow(
    imageSize: imageSize,
    viewportSize: viewportSize,
    scale: scale,
  );
  if (overflow == 0) {
    controller.position = Offset(controller.position.dx, 0);
    return;
  }

  final limit = overflow / 2;
  final nextY = (controller.position.dy - scrollDelta).clamp(-limit, limit);
  controller.position = Offset(controller.position.dx, nextY);
}
