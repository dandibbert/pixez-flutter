import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:pixez/watercolor/watercolor_tokens.dart';

/// Motion tokens of the watercolor style: three durations and two curves.
///
/// Nothing in the watercolor style animates for any other length of time.
/// When the system asks for reduced motion, movement is replaced by a plain
/// fade of the short duration.
abstract final class WcMotion {
  static const Duration short = Duration(milliseconds: 120);
  static const Duration medium = Duration(milliseconds: 240);
  static const Duration long = Duration(milliseconds: 360);

  /// Settles without overshoot.
  static const Curve standard = Cubic(0.2, 0, 0, 1);

  /// Overshoots a little, like pigment spreading past its edge and settling.
  static const Curve bounce = Cubic(0.3, 1.4, 0.5, 1);

  /// True when the system asks for reduced motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Reduced motion as the platform reports it, for code without a context.
  static bool get reducedGlobally => WidgetsBinding
      .instance
      .platformDispatcher
      .accessibilityFeatures
      .disableAnimations;

  /// Modal bottom sheets rise past their rest position by a few pixels and
  /// settle; they leave on the standard curve. Null in the classic style.
  static AnimationStyle? sheet(BuildContext context) {
    if (WatercolorTokens.of(context) == null) return null;
    if (reduced(context)) {
      return AnimationStyle(
        duration: short,
        reverseDuration: short,
        curve: Curves.linear,
        reverseCurve: Curves.linear,
      );
    }
    return AnimationStyle(
      duration: long,
      reverseDuration: medium,
      curve: const _SheetOvershoot(),
      reverseCurve: standard.flipped,
    );
  }
}

/// The standard curve plus a small swell past the end, about 4px on a
/// typical sheet.
class _SheetOvershoot extends Curve {
  const _SheetOvershoot();

  @override
  double transformInternal(double t) {
    final swell = t > 0.45 ? math.sin((t - 0.45) / 0.55 * math.pi) * 0.012 : 0;
    return WcMotion.standard.transform(t) + swell;
  }
}

/// Shrinks [child] to 95% while pressed (120ms) and springs back with the
/// bounce curve (240ms). Does nothing with reduced motion.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || WcMotion.reduced(context)) return widget.child;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1,
        duration: _pressed ? WcMotion.short : WcMotion.medium,
        curve: _pressed ? WcMotion.standard : WcMotion.bounce,
        child: widget.child,
      ),
    );
  }
}

/// List entrance: the first eight items rise 12px and fade in, 30ms apart.
/// Each [token] animates once per session, so items scrolled back into view
/// or loaded later appear without motion.
class WcEntrance extends StatefulWidget {
  const WcEntrance({
    super.key,
    required this.token,
    required this.index,
    required this.child,
  });

  final Object token;
  final int index;
  final Widget child;

  static final Expando<bool> _played = Expando('wcEntrance');

  @override
  State<WcEntrance> createState() => _WcEntranceState();
}

class _WcEntranceState extends State<WcEntrance>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    final token = widget.token;
    if (widget.index >= 8 || WcEntrance._played[token] == true) return;
    WcEntrance._played[token] = true;
    if (WcMotion.reducedGlobally) return;
    final controller = AnimationController(
      vsync: this,
      duration: WcMotion.medium,
    );
    _controller = controller;
    Future<void>.delayed(Duration(milliseconds: 30 * widget.index), () {
      if (mounted) controller.forward();
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return widget.child;
    final curved = CurvedAnimation(
      parent: controller,
      curve: WcMotion.standard,
    );
    return FadeTransition(
      opacity: curved,
      child: AnimatedBuilder(
        animation: curved,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 12 * (1 - curved.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Ink of the watercolor style: instead of a Material ripple, a soft ring of
/// pigment spreads from the touch point (240ms) and fades (120ms).
class PigmentInkSplash extends InteractiveInkFeature {
  PigmentInkSplash({
    required MaterialInkController controller,
    required super.referenceBox,
    required Offset position,
    required Color color,
    required TextDirection textDirection,
    bool containedInkWell = false,
    RectCallback? rectCallback,
    BorderRadius? borderRadius,
    ShapeBorder? customBorder,
    double? radius,
    super.onRemoved,
  }) : _position = position,
       _borderRadius = borderRadius ?? BorderRadius.zero,
       _customBorder = customBorder,
       _textDirection = textDirection,
       _clipCallback = _clip(referenceBox, containedInkWell, rectCallback),
       _targetRadius =
           radius ??
           _maxRadius(referenceBox, containedInkWell, rectCallback, position),
       super(controller: controller, color: color) {
    _spread =
        AnimationController(duration: WcMotion.medium, vsync: controller.vsync)
          ..addListener(controller.markNeedsPaint)
          ..forward();
    _fade =
        AnimationController(duration: WcMotion.short, vsync: controller.vsync)
          ..addListener(controller.markNeedsPaint)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) dispose();
          });
    controller.addInkFeature(this);
  }

  static const InteractiveInkFeatureFactory factory = _PigmentInkFactory();

  final Offset _position;
  final BorderRadius _borderRadius;
  final ShapeBorder? _customBorder;
  final TextDirection _textDirection;
  final RectCallback? _clipCallback;
  final double _targetRadius;
  late final AnimationController _spread;
  late final AnimationController _fade;

  static RectCallback? _clip(
    RenderBox box,
    bool contained,
    RectCallback? rectCallback,
  ) {
    if (rectCallback != null) return rectCallback;
    if (contained) return () => Offset.zero & box.size;
    return null;
  }

  static double _maxRadius(
    RenderBox box,
    bool contained,
    RectCallback? rectCallback,
    Offset position,
  ) {
    final size = rectCallback != null ? rectCallback().size : box.size;
    final corners = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ];
    var farthest = 0.0;
    for (final corner in corners) {
      farthest = math.max(farthest, (corner - position).distance);
    }
    return contained ? farthest : math.min(farthest, 28);
  }

  /// The ring finishes spreading before it fades.
  @override
  void confirm() {
    if (_spread.isCompleted) {
      _fade.forward();
      return;
    }
    _spread.addStatusListener((status) {
      if (status == AnimationStatus.completed) _fade.forward();
    });
  }

  @override
  void cancel() {
    _fade.forward();
  }

  @override
  void dispose() {
    _spread.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  void paintFeature(Canvas canvas, Matrix4 transform) {
    final spread = WcMotion.standard.transform(_spread.value);
    final alpha = color.a * (1 - _fade.value);
    if (alpha <= 0) return;
    final radius = _targetRadius * (0.35 + 0.65 * spread);
    final center = Offset.lerp(
      _position,
      referenceBox.size.center(Offset.zero),
      spread * 0.5,
    )!;
    final paint = Paint()
      ..color = color.withValues(alpha: alpha * 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final ring = Paint()
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
    paintInkCircle(
      canvas: canvas,
      transform: transform,
      paint: paint,
      center: center,
      textDirection: _textDirection,
      radius: radius,
      customBorder: _customBorder,
      borderRadius: _borderRadius,
      clipCallback: _clipCallback,
    );
    paintInkCircle(
      canvas: canvas,
      transform: transform,
      paint: ring,
      center: center,
      textDirection: _textDirection,
      radius: radius,
      customBorder: _customBorder,
      borderRadius: _borderRadius,
      clipCallback: _clipCallback,
    );
  }
}

class _PigmentInkFactory extends InteractiveInkFeatureFactory {
  const _PigmentInkFactory();

  @override
  InteractiveInkFeature create({
    required MaterialInkController controller,
    required RenderBox referenceBox,
    required Offset position,
    required Color color,
    required TextDirection textDirection,
    bool containedInkWell = false,
    RectCallback? rectCallback,
    BorderRadius? borderRadius,
    ShapeBorder? customBorder,
    double? radius,
    VoidCallback? onRemoved,
  }) {
    return PigmentInkSplash(
      controller: controller,
      referenceBox: referenceBox,
      position: position,
      color: color,
      textDirection: textDirection,
      containedInkWell: containedInkWell,
      rectCallback: rectCallback,
      borderRadius: borderRadius,
      customBorder: customBorder,
      radius: radius,
      onRemoved: onRemoved,
    );
  }
}
