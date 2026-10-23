import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobx/mobx.dart' show ReactionDisposer, reaction;
import 'package:pixez/main.dart';
import 'package:pixez/store/user_setting.dart';
import 'package:pixez/watercolor/watercolor_motion.dart';
import 'package:pixez/watercolor/watercolor_paper.dart';
import 'package:pixez/watercolor/watercolor_tokens.dart';
import 'package:pixez/watercolor/watercolor_widgets.dart';

bool _isCupertino(BuildContext context) {
  final platform = Theme.of(context).platform;
  return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
}

/// Route for opening a work (an illust or a novel).
///
/// In the watercolor style the page is laid down like a sheet of wet paper:
/// it rises a little from below while it comes into focus, and is lifted off
/// the same way on the way back. The page beneath stays put. On iOS the
/// slide and back swipe stay and only the focus pull is added. The classic
/// style is a plain [MaterialPageRoute].
class WetPaperPageRoute<T> extends MaterialPageRoute<T> {
  WetPaperPageRoute({required super.builder, super.settings});

  bool get _watercolor {
    final context = navigator?.context;
    return context != null && WatercolorTokens.of(context) != null;
  }

  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) {
    final context = navigator?.context;
    if (_watercolor && context != null && !_isCupertino(context)) {
      return false;
    }
    return super.canTransitionFrom(previousRoute);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final tokens = WatercolorTokens.of(context);
    if (tokens == null || WcMotion.reduced(context)) {
      return super.buildTransitions(
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    final curved = CurvedAnimation(
      parent: animation,
      curve: WcMotion.standard,
      reverseCurve: WcMotion.standard.flipped,
    );
    if (_isCupertino(context)) {
      return super.buildTransitions(
        context,
        animation,
        secondaryAnimation,
        _FocusPull(animation: curved, child: child),
      );
    }
    final outgoing = CurvedAnimation(
      parent: secondaryAnimation,
      curve: WcMotion.standard,
      reverseCurve: WcMotion.standard.flipped,
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(-0.25, 0),
      ).animate(outgoing),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // The page beneath dims as the wet sheet settles over it.
          Positioned.fill(
            child: IgnorePointer(
              child: FadeTransition(
                opacity: curved,
                child: const ColoredBox(color: Color(0x14000000)),
              ),
            ),
          ),
          SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(curved),
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: const Interval(0, 0.5),
              ),
              child: _FocusPull(
                animation: curved,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: tokens.shadow,
                        blurRadius: 26,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: WatercolorPaper(child: child),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Blurs [child] by 5px at the start of [animation] and sharpens it as the
/// animation completes, like ink settling in damp paper.
class _FocusPull extends StatelessWidget {
  const _FocusPull({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final sigma = 5 * (1 - animation.value);
        if (sigma < 0.05) return child!;
        return ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: child,
        );
      },
    );
  }
}

/// Long-press feedback of the watercolor style: once a press becomes a long
/// press the card swells slightly like a water droplet and a highlight
/// floats across it; it settles back on release. The long-press action
/// itself is left to [child].
class DropletPress extends StatefulWidget {
  const DropletPress({
    super.key,
    required this.child,
    this.borderRadius = BorderRadius.zero,
  });

  final Widget child;
  final BorderRadius borderRadius;

  @override
  State<DropletPress> createState() => _DropletPressState();
}

class _DropletPressState extends State<DropletPress> {
  Timer? _timer;
  Offset? _origin;
  bool _swollen = false;

  void _down(PointerDownEvent event) {
    _timer?.cancel();
    _origin = event.position;
    _timer = Timer(kLongPressTimeout, () {
      if (mounted) setState(() => _swollen = true);
    });
  }

  void _move(PointerMoveEvent event) {
    final origin = _origin;
    if (origin != null && (event.position - origin).distance > kTouchSlop) {
      _release();
    }
  }

  void _release() {
    _timer?.cancel();
    _timer = null;
    _origin = null;
    if (_swollen && mounted) setState(() => _swollen = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (WcMotion.reduced(context)) return widget.child;
    return Listener(
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: AnimatedScale(
        scale: _swollen ? 1.03 : 1,
        duration: WcMotion.medium,
        curve: _swollen ? WcMotion.bounce : WcMotion.standard,
        child: Stack(
          children: [
            widget.child,
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _swollen ? 1 : 0,
                  duration: _swollen ? WcMotion.medium : WcMotion.short,
                  curve: WcMotion.standard,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: widget.borderRadius,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment(0.2, 0.2),
                        colors: [Color(0x59FFFFFF), Color(0x00FFFFFF)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Effect { splash, ink, water }

/// Paints the full-screen watercolor effects over the app:
///
/// * a new theme color floods up from the palette bar, throws a few drops,
///   and soaks into the paper while the theme cross-fades beneath;
/// * switching to dark drops a bead of ink that spreads over the screen with
///   a ripple; switching back to light washes it away with clear water.
///
/// Nothing is drawn in the classic style or with reduced motion.
class WatercolorEffectsHost extends StatefulWidget {
  const WatercolorEffectsHost({super.key, required this.child});

  final Widget child;

  @override
  State<WatercolorEffectsHost> createState() => _WatercolorEffectsHostState();
}

class _WatercolorEffectsHostState extends State<WatercolorEffectsHost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: WcMotion.long,
  )..addStatusListener(_onStatus);
  late final ReactionDisposer _paletteReaction;
  _Effect? _effect;
  Color _color = const Color(0x00000000);
  Brightness? _brightness;

  @override
  void initState() {
    super.initState();
    _paletteReaction = reaction(
      (_) => (
        userSetting.paletteMode,
        userSetting.seedColor.toARGB32(),
        userSetting.uiStyle,
      ),
      (_) => WidgetsBinding.instance.addPostFrameCallback((_) => _splash()),
    );
  }

  @override
  void dispose() {
    _paletteReaction();
    _controller.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _effect = null);
    }
  }

  bool get _active =>
      userSetting.uiStyle == UiStyle.watercolor && !WcMotion.reducedGlobally;

  /// The tokens the app is animating towards, not the in-between ones.
  WatercolorTokens? _targetTokens(Brightness brightness) {
    final app = context.findAncestorWidgetOfExactType<MaterialApp>();
    final theme = brightness == Brightness.dark ? app?.darkTheme : app?.theme;
    return theme?.extension<WatercolorTokens>();
  }

  void _play(_Effect effect, Color color) {
    if (!mounted) return;
    setState(() {
      _effect = effect;
      _color = color;
    });
    _controller.forward(from: 0);
  }

  void _splash() {
    if (!mounted || !_active) return;
    final tokens = _targetTokens(_brightness ?? Brightness.light);
    if (tokens == null) return;
    _play(_Effect.splash, tokens.pigment(0));
  }

  Brightness _effectiveBrightness(BuildContext context) {
    return switch (userSetting.themeMode) {
      ThemeMode.dark => Brightness.dark,
      ThemeMode.light => Brightness.light,
      ThemeMode.system => MediaQuery.platformBrightnessOf(context),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        final brightness = _effectiveBrightness(context);
        final previous = _brightness;
        _brightness = brightness;
        if (previous != null && previous != brightness && _active) {
          final dark = brightness == Brightness.dark;
          final tokens = _targetTokens(brightness);
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _play(
              dark ? _Effect.ink : _Effect.water,
              tokens?.paper ??
                  (dark ? const Color(0xFF26221F) : const Color(0xFFFBF6EC)),
            ),
          );
        }
        final effect = _effect;
        return Stack(
          textDirection: TextDirection.ltr,
          children: [
            widget.child,
            if (effect != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _EffectPainter(
                        effect: effect,
                        color: _color,
                        progress: _controller,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _EffectPainter extends CustomPainter {
  _EffectPainter({
    required this.effect,
    required this.color,
    required this.progress,
  }) : super(repaint: progress);

  final _Effect effect;
  final Color color;
  final Animation<double> progress;

  static const List<(double, double, double)> _drops = [
    (-2.2, 1.05, 7),
    (-1.7, 0.92, 11),
    (-1.25, 1.1, 6),
    (-0.85, 0.95, 13),
    (-0.4, 1.08, 8),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    switch (effect) {
      case _Effect.splash:
        _paintSplash(canvas, size, t);
      case _Effect.ink:
      case _Effect.water:
        _paintDrop(canvas, size, t);
    }
  }

  void _paintSplash(Canvas canvas, Size size, double t) {
    final origin = Offset(size.width / 2, size.height - 60);
    final reach = math.sqrt(
      size.width * size.width / 4 + size.height * size.height,
    );
    final spread = WcMotion.standard.transform(t);
    final radius = reach * spread;
    final opacity = t < 0.25 ? t / 0.25 * 0.4 : 0.4 * (1 - (t - 0.25) / 0.75);
    final paint = Paint()
      ..color = color.withValues(alpha: opacity.clamp(0, 1))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(origin, radius, paint);
    for (final (angle, distance, dot) in _drops) {
      final at = origin + Offset.fromDirection(angle, radius * distance);
      canvas.drawCircle(at, dot * (0.5 + spread), paint);
    }
  }

  void _paintDrop(Canvas canvas, Size size, double t) {
    final center = size.center(Offset.zero);
    const fall = 0.3;
    if (t < fall) {
      final q = WcMotion.standard.transform(t / fall);
      final at = Offset(center.dx, -20 + (center.dy + 20) * q);
      canvas.drawOval(
        Rect.fromCenter(center: at, width: 16, height: 20),
        Paint()..color = color.withValues(alpha: 0.9),
      );
      return;
    }
    final q = (t - fall) / (1 - fall);
    final spread = WcMotion.standard.transform(q);
    final reach = center.distance + 40;
    final radius = 12 + reach * spread;
    // Squashed flat as it lands, then rounding out as it spreads.
    final squash = 1 - 0.45 * (1 - spread);
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: radius * 2,
        height: radius * 2 * squash,
      ),
      // Dense enough to run ahead of the theme cross-fade, so the screen
      // reads as being stained by the drop.
      Paint()
        ..color = color.withValues(alpha: 0.92 * (1 - q * q))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(
      center,
      radius * 1.08,
      Paint()
        ..color =
            (color.computeLuminance() < 0.5
                    ? const Color(0xFF000000)
                    : const Color(0xFFFFFFFF))
                .withValues(alpha: 0.3 * (1 - q))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
  }

  @override
  bool shouldRepaint(_EffectPainter oldDelegate) =>
      effect != oldDelegate.effect || color != oldDelegate.color;
}

/// The loading wash: pigment slowly seeping into the paper and back while
/// a picture loads. Still with reduced motion.
class PigmentSeep extends StatefulWidget {
  const PigmentSeep({super.key, required this.color});

  final Color color;

  @override
  State<PigmentSeep> createState() => _PigmentSeepState();
}

class _PigmentSeepState extends State<PigmentSeep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: WcMotion.long,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (WcMotion.reduced(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: WcMotion.standard,
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => Transform.scale(
        scale: 0.9 + 0.1 * curved.value,
        child: PigmentWash(
          color: widget.color,
          opacity: 0.25 + 0.15 * curved.value,
          shape: PigmentShape.wide,
        ),
      ),
    );
  }
}
