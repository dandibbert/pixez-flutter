import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/watercolor/mingcute.dart';
import 'package:pixez/watercolor/watercolor_motion.dart';
import 'package:pixez/watercolor/watercolor_tokens.dart';
import 'package:pixez/watercolor/watercolor_widgets.dart';

class ScatterAction {
  const ScatterAction({
    required this.icon,
    required this.label,
    required this.pigment,
    this.current = false,
  });

  final IconData icon;
  final String label;

  /// Index into [WatercolorTokens.pigments].
  final int pigment;

  /// Marks the entry that is already showing, e.g. the active section.
  final bool current;
}

/// Shortcut menu for a palette bar well: drops of pigment splash out of the
/// pressed well and settle on an arch above the bar, leaving a few specks
/// along the way.
///
/// Wrap the page (bar included) with it and drive it through a
/// `GlobalKey<PigmentScatterMenuState>`: [PigmentScatterMenuState.open] on
/// long press, [PigmentScatterMenuState.track] while the finger moves and
/// [PigmentScatterMenuState.release] when it lifts. Releasing on a drop picks
/// it; releasing in place leaves the menu open so a drop can be tapped.
class PigmentScatterMenu extends StatefulWidget {
  const PigmentScatterMenu({
    super.key,
    required this.child,
    required this.barInset,
  });

  final Widget child;

  /// Height at the bottom that stays uncovered, so the bar stays readable.
  final double barInset;

  @override
  State<PigmentScatterMenu> createState() => PigmentScatterMenuState();
}

class _MenuEntry {
  _MenuEntry({
    required this.anchor,
    required this.sourcePigment,
    required this.actions,
    required this.targets,
    required this.onSelected,
  });

  final Offset anchor;
  final int sourcePigment;
  final List<ScatterAction> actions;
  final List<Offset> targets;
  final ValueChanged<int> onSelected;
}

class PigmentScatterMenuState extends State<PigmentScatterMenu>
    with SingleTickerProviderStateMixin {
  static const double dropSize = 52;
  static const double _hitRadius = 40;
  static const double _tapSlop = 18;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: WcMotion.long,
    reverseDuration: WcMotion.medium,
  );

  _MenuEntry? _entry;
  int? _hover;
  int? _picked;
  bool _tapMode = false;
  Offset? _pressOrigin;

  bool get isOpen => _entry != null && _picked == null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Opens the menu from [anchor], in this widget's coordinates.
  void open({
    required Offset anchor,
    required int sourcePigment,
    required List<ScatterAction> actions,
    required ValueChanged<int> onSelected,
    Offset? pressPosition,
  }) {
    final box = context.findRenderObject() as RenderBox;
    HapticFeedback.mediumImpact();
    setState(() {
      _entry = _MenuEntry(
        anchor: anchor,
        sourcePigment: sourcePigment,
        actions: actions,
        targets: layoutArch(anchor, actions.length, box.size),
        onSelected: onSelected,
      );
      _hover = null;
      _picked = null;
      _tapMode = false;
      _pressOrigin = pressPosition == null
          ? null
          : box.globalToLocal(pressPosition);
    });
    _controller.forward(from: 0);
  }

  /// Follows the finger after the long press; [globalPosition] in screen
  /// coordinates.
  void track(Offset globalPosition) {
    final entry = _entry;
    if (entry == null || _picked != null) return;
    final local = (context.findRenderObject() as RenderBox).globalToLocal(
      globalPosition,
    );
    final hover = _controller.value < 0.4 ? null : _hitTest(entry, local);
    if (hover != _hover) {
      if (hover != null) HapticFeedback.selectionClick();
      setState(() => _hover = hover);
    }
  }

  void release(Offset globalPosition) {
    final entry = _entry;
    if (entry == null || _picked != null) return;
    track(globalPosition);
    final hover = _hover;
    if (hover != null) {
      _pick(hover);
      return;
    }
    final local = (context.findRenderObject() as RenderBox).globalToLocal(
      globalPosition,
    );
    final origin = _pressOrigin;
    if (origin == null || (local - origin).distance < _tapSlop) {
      setState(() => _tapMode = true);
    } else {
      close();
    }
  }

  void close() {
    if (_entry == null) return;
    setState(() => _hover = null);
    _controller.reverse().whenComplete(() {
      if (mounted && _controller.isDismissed) setState(() => _entry = null);
    });
  }

  void _pick(int index) {
    final entry = _entry!;
    HapticFeedback.lightImpact();
    setState(() {
      _picked = index;
      _hover = index;
    });
    entry.onSelected(index);
    _controller.reverse().whenComplete(() {
      if (mounted && _controller.isDismissed) {
        setState(() {
          _entry = null;
          _picked = null;
        });
      }
    });
  }

  int? _hitTest(_MenuEntry entry, Offset local) {
    int? best;
    var bestDistance = _hitRadius;
    for (var i = 0; i < entry.targets.length; i++) {
      final distance = (entry.targets[i] - local).distance;
      if (distance < bestDistance) {
        best = i;
        bestDistance = distance;
      }
    }
    return best;
  }

  /// Drop centers on an arch above [anchor]: a flat circular arc whose
  /// center sits below the anchor, shifted sideways to stay on screen.
  static List<Offset> layoutArch(Offset anchor, int count, Size size) {
    if (count == 0) return const [];
    const radius = 190.0;
    const drop = 38.0;
    const edge = 40.0;
    final spread = switch (count) {
      1 => 0.0,
      2 => 36.0,
      3 => 64.0,
      _ => 76.0 + (count - 4) * 14.0,
    };
    final angles = [
      for (var i = 0; i < count; i++)
        (90 + spread / 2 - (count == 1 ? 0 : spread * i / (count - 1))) *
            math.pi /
            180,
    ];
    final halfWidth = angles
        .map((a) => (math.cos(a) * radius).abs())
        .fold<double>(0, math.max);
    final minX = edge + halfWidth;
    final maxX = size.width - edge - halfWidth;
    final centerX = minX > maxX
        ? size.width / 2
        : anchor.dx.clamp(minX, maxX).toDouble();
    final center = Offset(centerX, anchor.dy + drop);
    return [
      for (final a in angles)
        center + Offset(math.cos(a) * radius, -math.sin(a) * radius),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    return Stack(
      children: [
        widget.child,
        if (entry != null)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => _buildMenu(context, entry),
            ),
          ),
      ],
    );
  }

  Widget _buildMenu(BuildContext context, _MenuEntry entry) {
    final tokens = WatercolorTokens.of(context)!;
    final reduced = WcMotion.reduced(context);
    final t = _controller.value;
    final fade = WcMotion.standard.transform(t);
    final count = entry.actions.length;
    const stagger = 0.07;
    final span = 1 - stagger * (count - 1);

    double progress(int i) =>
        ((t - stagger * i) / span).clamp(0.0, 1.0).toDouble();

    final drops = <Widget>[];
    for (var i = 0; i < count; i++) {
      final action = entry.actions[i];
      final local = progress(i);
      final picked = _picked == i;
      final spreadT = reduced || picked
          ? 1.0
          : WcMotion.bounce.transform(local);
      final position = Offset.lerp(entry.anchor, entry.targets[i], spreadT)!;
      final scale = reduced
          ? 1.0
          : picked
          ? 1 + 0.3 * (1 - t)
          : 0.35 + 0.65 * spreadT;
      final opacity = picked
          ? t
          : reduced
          ? fade
          : WcMotion.standard.transform(math.min(local * 1.6, 1));
      drops.add(
        Positioned(
          left: position.dx - 50,
          top: position.dy - dropSize / 2,
          width: 100,
          child: IgnorePointer(
            ignoring: !_tapMode,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0).toDouble(),
              child: Transform.scale(
                scale: scale,
                alignment: const Alignment(0, -0.35),
                child: _Drop(
                  action: action,
                  pigment: tokens.pigment(action.pigment),
                  hovered: _hover == i,
                  seed: i,
                  onTap: () => _pick(i),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: widget.barInset,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: close,
            child: Opacity(
              opacity: fade,
              child: ColoredBox(color: tokens.paper.withValues(alpha: 0.86)),
            ),
          ),
        ),
        if (!reduced)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _SpeckPainter(
                  anchor: entry.anchor,
                  targets: entry.targets,
                  colors: [
                    for (final a in entry.actions) tokens.pigment(a.pigment),
                  ],
                  progress: [for (var i = 0; i < count; i++) progress(i)],
                  fade: _picked == null ? 1 : t,
                ),
              ),
            ),
          ),
        Positioned(
          left: entry.anchor.dx - 44,
          top: entry.anchor.dy - 52,
          width: 88,
          height: 64,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.32 * fade,
              child: Transform.scale(
                scale: reduced ? 1 : 0.4 + 0.6 * WcMotion.bounce.transform(t),
                child: PigmentWash(
                  color: tokens.pigment(entry.sourcePigment),
                  opacity: 1,
                ),
              ),
            ),
          ),
        ),
        ...drops,
      ],
    );
  }
}

class _Drop extends StatelessWidget {
  const _Drop({
    required this.action,
    required this.pigment,
    required this.hovered,
    required this.seed,
    required this.onTap,
  });

  final ScatterAction action;
  final Color pigment;
  final bool hovered;
  final int seed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = WatercolorTokens.of(context)!;
    const size = PigmentScatterMenuState.dropSize;
    return Semantics(
      button: true,
      selected: action.current,
      label: action.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedScale(
          scale: hovered ? 1.14 : 1,
          duration: WcMotion.medium,
          curve: WcMotion.bounce,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: -6,
                      top: -5,
                      right: -6,
                      bottom: -7,
                      child: PigmentWash(
                        color: pigment,
                        opacity: action.current || hovered ? 0.95 : 0.78,
                      ),
                    ),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _InkedRingPainter(
                          color: tokens.ink.withValues(
                            alpha: hovered ? 0.85 : 0.5,
                          ),
                          width: hovered ? 2.2 : 1.3,
                          seed: seed,
                        ),
                      ),
                    ),
                    WcIcon(
                      action.icon,
                      size: 22,
                      filled: action.current || hovered,
                      color: tokens.onPigment,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.fromLTRB(9, 3, 10, 3),
                decoration: BoxDecoration(
                  color: tokens.card,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: hovered
                        ? tokens.ink.withValues(alpha: 0.5)
                        : tokens.line,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (action.current) ...[
                      WcIcon(Icons.check, size: 12, color: tokens.ink),
                      const SizedBox(width: 3),
                    ],
                    Text(
                      action.label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.25,
                        fontWeight: hovered || action.current
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: tokens.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A circle traced by hand: the radius wobbles a little, and the stroke
/// thins where the brush lifts.
class _InkedRingPainter extends CustomPainter {
  const _InkedRingPainter({
    required this.color,
    required this.width,
    required this.seed,
  });

  final Color color;
  final double width;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final base = size.shortestSide / 2 - 1;
    final phase = seed * 1.7;
    final path = Path();
    const steps = 48;
    for (var i = 0; i <= steps; i++) {
      final a = i / steps * math.pi * 2;
      final r = base + math.sin(a * 3 + phase) * 0.9 + math.sin(a * 5) * 0.4;
      final p = center + Offset(math.cos(a) * r, math.sin(a) * r);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6),
    );
  }

  @override
  bool shouldRepaint(_InkedRingPainter oldDelegate) =>
      color != oldDelegate.color ||
      width != oldDelegate.width ||
      seed != oldDelegate.seed;
}

/// Small pigment specks left behind each drop on its way out of the well.
class _SpeckPainter extends CustomPainter {
  _SpeckPainter({
    required this.anchor,
    required this.targets,
    required this.colors,
    required this.progress,
    required this.fade,
  });

  final Offset anchor;
  final List<Offset> targets;
  final List<Color> colors;
  final List<double> progress;
  final double fade;

  static const _stops = [0.34, 0.52, 0.7];
  static const _sizes = [1.6, 2.6, 1.9];
  static const _offsets = [5.0, -6.0, 3.5];

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < targets.length; i++) {
      final direction = targets[i] - anchor;
      final length = direction.distance;
      if (length == 0) continue;
      final normal = Offset(-direction.dy, direction.dx) / length;
      for (var s = 0; s < _stops.length; s++) {
        final appear = ((progress[i] - _stops[s] * 0.6) / 0.25).clamp(0.0, 1.0);
        if (appear <= 0) continue;
        final jitter = _offsets[(s + i) % _offsets.length];
        final p = anchor + direction * _stops[s] + normal * jitter;
        canvas.drawCircle(
          p,
          _sizes[(s + i * 2) % _sizes.length],
          Paint()
            ..color = colors[i].withValues(alpha: 0.7 * appear * fade)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_SpeckPainter oldDelegate) => true;
}
