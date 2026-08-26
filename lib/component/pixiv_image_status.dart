import 'package:material_ui/material_ui.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';

const Key pixivImageLoadingKey = Key('pixiv-image-loading');
const Key pixivImageErrorKey = Key('pixiv-image-error');

/// Fallback edge for a placeholder whose parent constrains neither side.
const double pixivImagePlaceholderFallbackExtent = 120;

/// A placeholder often sits where the loaded image would size itself from its
/// own aspect ratio: a row inside a list item, where the height is unbounded.
/// Expanding into that leaves an infinite box that no painter can fill, so
/// resolve every side to something finite.
Size resolvePlaceholderSize(
  BoxConstraints constraints, {
  double? width,
  double? height,
  double fallback = pixivImagePlaceholderFallbackExtent,
}) {
  double resolve(double? explicit, double available, double sibling) {
    if (explicit != null && explicit.isFinite && explicit > 0) return explicit;
    if (available.isFinite) return available;
    if (sibling.isFinite && sibling > 0) return sibling;
    return fallback;
  }

  final resolvedWidth = resolve(
    width,
    constraints.maxWidth,
    height ?? double.infinity,
  );
  return Size(
    resolvedWidth,
    resolve(height, constraints.maxHeight, resolvedWidth),
  );
}

/// A non-finite side would make the tiling loop never terminate, freezing the
/// whole app instead of drawing a placeholder.
bool shouldPaintCheckerboard(Size size, double squareSize) {
  return !size.isEmpty && size.isFinite && squareSize > 0;
}

/// A geometric fill that cannot be mistaken for a photograph, including a
/// black or dark-gray illustration.
class ImageCheckerboard extends StatelessWidget {
  final double squareSize;

  const ImageCheckerboard({super.key, this.squareSize = 16});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Mid-gray tiles, never near-black, so dark artwork cannot hide as "empty".
    final light = isDark ? const Color(0xFF737373) : const Color(0xFFE8E8E8);
    final dark = isDark ? const Color(0xFF525252) : const Color(0xFFC4C4C4);
    return CustomPaint(
      painter: CheckerboardPainter(
        light: light,
        dark: dark,
        squareSize: squareSize,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class CheckerboardPainter extends CustomPainter {
  final Color light;
  final Color dark;
  final double squareSize;

  const CheckerboardPainter({
    required this.light,
    required this.dark,
    required this.squareSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!shouldPaintCheckerboard(size, squareSize)) {
      return;
    }
    final lightPaint = Paint()..color = light;
    final darkPaint = Paint()..color = dark;
    canvas.drawRect(Offset.zero & size, lightPaint);
    final square = squareSize;
    for (double y = 0; y < size.height; y += square) {
      final oddRow = ((y / square).floor() & 1) == 1;
      for (double x = oddRow ? square : 0; x < size.width; x += square * 2) {
        canvas.drawRect(Rect.fromLTWH(x, y, square, square), darkPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CheckerboardPainter oldDelegate) {
    return oldDelegate.light != light ||
        oldDelegate.dark != dark ||
        oldDelegate.squareSize != squareSize;
  }
}

class PixivImageLoadingPlaceholder extends StatelessWidget {
  final double? width;
  final double? height;
  final double? progress;
  final Widget? indicator;

  const PixivImageLoadingPlaceholder({
    super.key,
    this.width,
    this.height,
    this.progress,
    this.indicator,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spinnerSize = _spinnerSize(width, height);
    final child =
        indicator ??
        SizedBox(
          width: spinnerSize,
          height: spinnerSize,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            value: progress,
            color: scheme.primary,
            backgroundColor: scheme.onSurface.withValues(alpha: 0.12),
          ),
        );
    return Semantics(
      key: pixivImageLoadingKey,
      label: AppLocalizations.of(context)?.footer_loading ?? 'Loading...',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = resolvePlaceholderSize(
            constraints,
            width: width,
            height: height,
          );
          return SizedBox(
            width: size.width,
            height: size.height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ImageCheckerboard(),
                Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surface.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: scheme.shadow.withValues(alpha: 0.24),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: child,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class PixivImageErrorPlaceholder extends StatelessWidget {
  final double? width;
  final double? height;
  final VoidCallback onRetry;

  const PixivImageErrorPlaceholder({
    super.key,
    this.width,
    this.height,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final message =
        AppLocalizations.of(context)?.load_image_failed_click_to_reload ??
        'Failed to load. Click to retry';
    return Semantics(
      key: pixivImageErrorKey,
      button: true,
      label: message,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onRetry,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = resolvePlaceholderSize(
                constraints,
                width: width,
                height: height,
              );
              final compact = size.height < 96 || size.width < 96;
              return SizedBox(
                width: size.width,
                height: size.height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const ImageCheckerboard(),
                    ColoredBox(color: scheme.error.withValues(alpha: 0.10)),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.surface.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.broken_image_outlined,
                                  color: scheme.error,
                                  size: _spinnerSize(width, height),
                                ),
                                if (!compact) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    message,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: scheme.onSurface),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

double _spinnerSize(double? width, double? height) {
  final shortest = [
    width,
    height,
  ].whereType<double>().where((value) => value.isFinite && value > 0);
  if (shortest.isEmpty) {
    return 36;
  }
  return (shortest.reduce((a, b) => a < b ? a : b) * 0.28).clamp(18, 40);
}
