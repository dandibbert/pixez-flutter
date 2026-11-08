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

/// Shortcut menu for a palette bar well: a brush stroke of the well's
/// pigment rises straight up from it, and drops of pigment settle along the
/// stroke, the first action nearest the well. Labels sit beside the drops on
/// the side facing the middle of the screen.
///
/// Wrap the page (bar included) with it and drive it through a
/// `GlobalKey<PigmentScatterMenuState>`: [PigmentScatterMenuState.open] on
/// long press, [PigmentScatterMenuState.track] while the finger moves and
/// [PigmentScatterMenuState.release] when it lifts. Sliding up onto a row and
/// releasing picks it; releasing in place leaves the menu open so a row can
/// be tapped.
class PigmentScatterMenu extends StatefulWidget {
  const PigmentScatterMenu({
    super.key,
    required this.child,
    required this.barInset,
    required this.currentLabel,
  });

  final Widget child;

  /// Tag shown beside the label of the [ScatterAction.current] entry.
  final String currentLabel;

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
    required this.labelsRight,
    required this.onSelected,
  });

  final Offset anchor;
  final int sourcePigment;
  final List<ScatterAction> actions;
  final List<Offset> targets;
  final bool labelsRight;
  final ValueChanged<int> onSelected;
}

class PigmentScatterMenuState extends State<PigmentScatterMenu>
    with SingleTickerProviderStateMixin {
  static const double dropSize = 48;

  /// Distance between drop centers along the stroke.
  static const double step = 62;

  /// From the well center to the first drop center: past the bar's top edge
  /// (30) plus a gap, so the first drop never touches the bar.
  static const double _firstLift = 68;

  static const double _labelGap = 10;
  static const double _labelReach = 132;
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

  /// Opens the menu from [anchor], the well center in this widget's
  /// coordinates.
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
        targets: layoutColumn(anchor, actions.length),
        labelsRight: anchor.dx <= box.size.width / 2 + 1,
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

  /// A row is the band of [step] around a drop, spanning the drop and its
  /// label, so the finger only has to reach the right height.
  int? _hitTest(_MenuEntry entry, Offset local) {
    final x = entry.anchor.dx;
    final left = entry.labelsRight ? x - dropSize : x - _labelReach;
    final right = entry.labelsRight ? x + _labelReach : x + dropSize;
    if (local.dx < left || local.dx > right) return null;
    for (var i = 0; i < entry.targets.length; i++) {
      if ((local.dy - entry.targets[i].dy).abs() <= step / 2) return i;
    }
    return null;
  }

  /// Drop centers straight above [anchor], the first one nearest.
  static List<Offset> layoutColumn(Offset anchor, int count) => [
    for (var i = 0; i < count; i++) anchor - Offset(0, _firstLift + step * i),
  ];

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    return Stack(
      children: [
        widget.child,
        if (entry != null)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) => AnimatedBuilder(
                animation: _controller,
                builder: (context, _) =>
                    _buildMenu(context, entry, constraints.biggest),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMenu(BuildContext context, _MenuEntry entry, Size size) {
    final tokens = WatercolorTokens.of(context)!;
    final reduced = WcMotion.reduced(context);
    final t = _controller.value;
    final fade = WcMotion.standard.transform(t);
    final count = entry.actions.length;
    const stagger = 0.08;
    final span = 1 - stagger * (count - 1);

    double progress(int i) =>
        ((t - stagger * i) / span).clamp(0.0, 1.0).toDouble();

    final rows = <Widget>[];
    for (var i = 0; i < count; i++) {
      final local = progress(i);
      final picked = _picked == i;
      final rise = reduced || picked ? 1.0 : WcMotion.bounce.transform(local);
      final center = Offset.lerp(entry.anchor, entry.targets[i], rise)!;
      final dropScale = reduced
          ? 1.0
          : picked
          ? 1 + 0.25 * (1 - t)
          : 0.4 + 0.6 * rise;
      final dropOpacity = picked
          ? t
          : reduced
          ? fade
          : WcMotion.standard.transform((local * 1.8).clamp(0.0, 1.0));
      final labelT = reduced || picked
          ? fade
          : WcMotion.standard.transform(((local - 0.3) / 0.7).clamp(0.0, 1.0));
      final hovered = _hover == i;
      final drop = Opacity(
        opacity: dropOpacity.clamp(0.0, 1.0).toDouble(),
        child: Transform.scale(
          scale: dropScale,
          child: _Drop(
            action: entry.actions[i],
            pigment: tokens.pigment(entry.actions[i].pigment),
            hovered: hovered,
            seed: i,
          ),
        ),
      );
      final label = Opacity(
        opacity: labelT,
        child: Transform.translate(
          offset: Offset((entry.labelsRight ? -8 : 8) * (1 - labelT), 0),
          child: _Label(
            action: entry.actions[i],
            hovered: hovered,
            currentLabel: widget.currentLabel,
          ),
        ),
      );
      final row = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _pick(i),
        child: Semantics(
          button: true,
          selected: entry.actions[i].current,
          label: entry.actions[i].label,
          excludeSemantics: true,
          child: SizedBox(
            height: step,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              textDirection: entry.labelsRight
                  ? TextDirection.ltr
                  : TextDirection.rtl,
              children: [
                SizedBox(
                  width: dropSize,
                  child: Center(child: drop),
                ),
                const SizedBox(width: _labelGap),
                label,
              ],
            ),
          ),
        ),
      );
      rows.add(
        Positioned(
          top: center.dy - step / 2,
          left: entry.labelsRight ? center.dx - dropSize / 2 : null,
          right: entry.labelsRight
              ? null
              : size.width - center.dx - dropSize / 2,
          child: IgnorePointer(ignoring: !_tapMode, child: row),
        ),
      );
    }

    // The stroke runs from the top of the well to just past the last drop
    // and grows upward with the first drop.
    final strokeBottom = entry.anchor.dy - 16;
    final strokeTop = entry.targets.last.dy - dropSize / 2 - 10;
    final strokeGrow = reduced
        ? 1.0
        : WcMotion.standard.transform((t / 0.75).clamp(0.0, 1.0));
    final strokeOpacity = _picked == null ? fade : t;

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
        Positioned(
          left: entry.anchor.dx - 30,
          width: 60,
          top: strokeTop,
          height: strokeBottom - strokeTop,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.3 * strokeOpacity,
              child: Transform.scale(
                scaleY: strokeGrow,
                alignment: Alignment.bottomCenter,
                child: RotatedBox(
                  quarterTurns: 1,
                  child: PigmentWash(
                    color: tokens.pigment(entry.sourcePigment),
                    opacity: 1,
                    shape: PigmentShape.pill,
                  ),
                ),
              ),
            ),
          ),
        ),
        ...rows,
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
  });

  final ScatterAction action;
  final Color pigment;
  final bool hovered;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final tokens = WatercolorTokens.of(context)!;
    const size = PigmentScatterMenuState.dropSize;
    return AnimatedScale(
      scale: hovered ? 1.14 : 1,
      duration: WcMotion.medium,
      curve: WcMotion.bounce,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned(
              left: -5,
              top: -4,
              right: -5,
              bottom: -6,
              child: PigmentWash(
                color: pigment,
                opacity: action.current || hovered ? 0.95 : 0.8,
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _InkedRingPainter(
                  color: tokens.ink.withValues(alpha: hovered ? 0.85 : 0.5),
                  width: hovered ? 2.2 : 1.3,
                  seed: seed,
                ),
              ),
            ),
            WcIcon(
              action.icon,
              size: 21,
              filled: action.current || hovered,
              color: tokens.onPigment,
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({
    required this.action,
    required this.hovered,
    required this.currentLabel,
  });

  final ScatterAction action;
  final bool hovered;
  final String currentLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = WatercolorTokens.of(context)!;
    return AnimatedContainer(
      duration: WcMotion.short,
      padding: const EdgeInsets.fromLTRB(11, 5, 12, 5),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: hovered ? tokens.ink.withValues(alpha: 0.55) : tokens.line,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            action.label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 13,
              height: 1.25,
              fontWeight: hovered ? FontWeight.w700 : FontWeight.w500,
              color: tokens.ink,
            ),
          ),
          if (action.current) ...[
            const SizedBox(width: 6),
            Text(
              currentLabel,
              style: TextStyle(fontSize: 11, height: 1.25, color: tokens.sub),
            ),
          ],
        ],
      ),
    );
  }
}

/// A circle traced by hand: the radius wobbles a little.
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
