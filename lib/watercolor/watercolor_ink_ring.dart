import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/watercolor/watercolor_motion.dart';
import 'package:pixez/watercolor/watercolor_tokens.dart';

/// A round button drawn as a hand-inked circle.
///
/// On tap the ring is traced again, the button's [pigment] blooms inside it,
/// the icon dips and springs back, and a light haptic fires. The whole
/// gesture runs on [WcMotion.long]; with reduced motion only the pigment
/// fades in and out.
///
/// The [main] variant is larger, sits on an offset pigment wash and uses a
/// heavier ring, for the primary action of a row.
class InkRingButton extends StatefulWidget {
  const InkRingButton({
    super.key,
    required this.icon,
    required this.pigment,
    required this.onPressed,
    this.tooltip,
    this.main = false,
  });

  final Widget icon;
  final Color pigment;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool main;

  double get size => main ? 58 : 40;

  @override
  State<InkRingButton> createState() => _InkRingButtonState();
}

class _InkRingButtonState extends State<InkRingButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tap = AnimationController(
    vsync: this,
    duration: WcMotion.long,
    value: 1,
  );

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    _tap.forward(from: 0);
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = WatercolorTokens.of(context)!;
    final reduced = WcMotion.reduced(context);
    final enabled = widget.onPressed != null;
    final size = widget.size;
    Widget button = AnimatedBuilder(
      animation: _tap,
      builder: (context, child) {
        final t = _tap.value;
        final tapping = _tap.isAnimating;
        // Ring: traced over the first 70%, starting heavier and thinning out.
        final trace = reduced
            ? 1.0
            : WcMotion.standard.transform(math.min(t / 0.7, 1));
        // Bloom: scale .6 → 1.18 → 1 on the bounce curve.
        final bloom = reduced ? 1.0 : 0.6 + 0.4 * WcMotion.bounce.transform(t);
        // Icon: dips to .82 and tilts -6° in the first 30%, then springs back.
        final dip = t < 0.3
            ? t / 0.3
            : 1 - WcMotion.bounce.transform((t - 0.3) / 0.7);
        final iconScale = reduced ? 1.0 : 1 - 0.18 * dip;
        final iconTurn = reduced ? 0.0 : -6 * math.pi / 180 * dip;
        final subWash = widget.main || !tapping
            ? 0.0
            : reduced
            ? 0.7 * math.sin(math.pi * t)
            : 0.7 * math.min(t / 0.2, 1) * (t > 0.7 ? (1 - t) / 0.3 : 1);
        return CustomPaint(
          painter: _InkRingPainter(
            ink: enabled ? tokens.ink : tokens.ink.withValues(alpha: 0.4),
            pigment: widget.pigment,
            main: widget.main,
            trace: tapping ? trace : 1,
            strokeBoost: tapping && !reduced ? (1 - trace) : 0,
            bloom: widget.main ? (tapping ? bloom : 1) : bloom,
            subWash: subWash,
          ),
          child: Center(
            child: Transform.rotate(
              angle: tapping ? iconTurn : 0,
              child: Transform.scale(
                scale: tapping ? iconScale : 1,
                child: child,
              ),
            ),
          ),
        );
      },
      child: IconTheme.merge(
        data: IconThemeData(
          size: widget.main ? 26 : 21,
          color: widget.main ? tokens.onPigment : tokens.ink,
          opacity: enabled ? 1 : 0.4,
        ),
        child: widget.icon,
      ),
    );
    button = Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? _handleTap : null,
        child: SizedBox(
          width: math.max(size, 44),
          height: math.max(size, 44),
          child: Center(
            child: SizedBox(width: size, height: size, child: button),
          ),
        ),
      ),
    );
    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip, child: button);
    }
    return button;
  }
}

class _InkRingPainter extends CustomPainter {
  _InkRingPainter({
    required this.ink,
    required this.pigment,
    required this.main,
    required this.trace,
    required this.strokeBoost,
    required this.bloom,
    required this.subWash,
  });

  final Color ink;
  final Color pigment;
  final bool main;
  final double trace;
  final double strokeBoost;
  final double bloom;
  final double subWash;

  /// The hand-drawn ring in a 44×44 box. It overshoots its start a little,
  /// like a pen that did not stop where it began.
  static final Path _ring = Path()
    ..moveTo(22, 3.6)
    ..cubicTo(32.4, 3.2, 40.6, 11.2, 40.4, 22.4)
    ..cubicTo(40.2, 32.6, 32.2, 40.6, 21.8, 40.4)
    ..cubicTo(11.6, 40.2, 3.4, 32.2, 3.6, 21.8)
    ..cubicTo(3.8, 11.6, 11.8, 4, 22, 3.6)
    ..cubicTo(24.8, 3.5, 27, 4.1, 28.6, 4.9);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 44;
    canvas.save();
    canvas.scale(scale);
    if (main) {
      _wash(canvas, const Offset(24.5, 24.5), 18 * bloom, pigment, 1);
    }
    if (subWash > 0) {
      _wash(canvas, const Offset(23.5, 23.5), 15 * bloom, pigment, subWash);
    }
    final base = main ? 1.7 : 1.3;
    final paint = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = base + (2.4 - base) * strokeBoost;
    if (trace >= 1) {
      canvas.drawPath(_ring, paint);
    } else {
      for (final metric in _ring.computeMetrics()) {
        canvas.drawPath(metric.extractPath(0, metric.length * trace), paint);
      }
    }
    canvas.restore();
  }

  /// A soft pigment disc with a slightly darker rim, the way a wash dries.
  void _wash(Canvas canvas, Offset c, double r, Color color, double opacity) {
    if (r <= 0) return;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.82 * opacity),
            color.withValues(alpha: 0.9 * opacity),
            color.withValues(alpha: opacity),
          ],
          stops: const [0, 0.82, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_InkRingPainter old) =>
      old.ink != ink ||
      old.pigment != pigment ||
      old.main != main ||
      old.trace != trace ||
      old.strokeBoost != strokeBoost ||
      old.bloom != bloom ||
      old.subWash != subWash;
}

/// Four pigment bars that rise and fall while audio is playing, and rest
/// at a low height otherwise (or with reduced motion).
class InkWaveBars extends StatefulWidget {
  const InkWaveBars({super.key, required this.color, required this.active});

  final Color color;
  final bool active;

  @override
  State<InkWaveBars> createState() => _InkWaveBarsState();
}

class _InkWaveBarsState extends State<InkWaveBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1080),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(InkWaveBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final run = widget.active && !WcMotion.reduced(context);
    if (run && !_wave.isAnimating) {
      _wave.repeat();
    } else if (!run && _wave.isAnimating) {
      _wave.stop();
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 16,
      child: AnimatedBuilder(
        animation: _wave,
        builder: (context, _) => CustomPaint(
          painter: _WavePainter(
            color: widget.color,
            phase: _wave.isAnimating ? _wave.value : null,
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({required this.color, required this.phase});

  final Color color;
  final double? phase;

  static const _bars = [
    (1.0, 14.0, 0.0),
    (7.0, 16.0, 0.27),
    (13.0, 13.0, 0.55),
    (19.0, 11.0, 0.14),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final (x, h, delay) in _bars) {
      final p = phase;
      final s = p == null
          ? 0.5
          : 0.35 + 0.65 * (0.5 - 0.5 * math.cos(2 * math.pi * (p + delay)));
      final bh = h * s;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - bh, 3, bh),
          const Radius.circular(1.5),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.color != color || old.phase != phase;
}
