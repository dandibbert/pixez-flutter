import 'package:material_ui/material_ui.dart';
import 'package:pixez/watercolor/mingcute.dart';
import 'package:pixez/watercolor/watercolor_motion.dart';
import 'package:pixez/watercolor/watercolor_tokens.dart';

/// Shape of a pre-rendered pigment wash in `assets/watercolor`.
enum PigmentShape {
  round('blob_round'),
  wide('blob_wide'),
  pill('blob_pill'),
  dot('blob_dot');

  const PigmentShape(this.asset);

  final String asset;
}

/// A rough-edged wash of [color] that fills its box.
class PigmentWash extends StatelessWidget {
  const PigmentWash({
    super.key,
    required this.color,
    this.opacity = 0.9,
    this.shape = PigmentShape.round,
  });

  final Color color;
  final double opacity;
  final PigmentShape shape;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/watercolor/${shape.asset}.png',
      fit: BoxFit.fill,
      color: color.withValues(alpha: color.a * opacity),
      colorBlendMode: BlendMode.srcIn,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    );
  }
}

/// [child] with a pigment wash spreading slightly past its edges while
/// [visible]; the wash grows in with the bounce curve.
class PigmentBackdrop extends StatelessWidget {
  const PigmentBackdrop({
    super.key,
    required this.color,
    required this.child,
    this.visible = true,
    this.opacity = 0.85,
    this.shape = PigmentShape.pill,
    this.bleed = const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
  });

  final Color color;
  final Widget child;
  final bool visible;
  final double opacity;
  final PigmentShape shape;
  final EdgeInsets bleed;

  @override
  Widget build(BuildContext context) {
    final reduced = WcMotion.reduced(context);
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned(
          left: -bleed.left,
          top: -bleed.top,
          right: -bleed.right,
          bottom: -bleed.bottom,
          child: AnimatedScale(
            scale: visible || reduced ? 1 : 0.3,
            duration: reduced ? Duration.zero : WcMotion.medium,
            curve: WcMotion.bounce,
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: reduced ? WcMotion.short : WcMotion.medium,
              curve: WcMotion.standard,
              child: PigmentWash(color: color, opacity: opacity, shape: shape),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Card surface: card color, paper edge and medium radius.
class WcPanel extends StatelessWidget {
  const WcPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = WatercolorTokens.radiusMedium,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final tokens = WatercolorTokens.of(context)!;
    // A Material rather than a DecoratedBox, so list tiles inside keep their
    // ink.
    return Material(
      color: tokens.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: tokens.line),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Pill-shaped single choice with a pigment wash behind the selected item.
class WcSegmented extends StatelessWidget {
  const WcSegmented({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.height = 40,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = WatercolorTokens.of(context)!;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tokens.line),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                inMutuallyExclusiveGroup: true,
                checked: i == selected,
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelected(i),
                  child: PressScale(
                    child: SizedBox(
                      height: height,
                      child: PigmentBackdrop(
                        color: tokens.pigment(0),
                        visible: i == selected,
                        bleed: const EdgeInsets.fromLTRB(2, 4, 2, 4),
                        child: Text(
                          labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: i == selected
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: i == selected
                                ? tokens.onPigment
                                : tokens.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small bold section heading in the secondary ink.
class WcSectionLabel extends StatelessWidget {
  const WcSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = WatercolorTokens.of(context)!;
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: tokens.sub,
      ),
    );
  }
}

/// Tab indicator: a soft pigment wash behind the selected tab's label.
class PigmentTabIndicator extends Decoration {
  const PigmentTabIndicator(this.color);

  final Color color;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _PigmentTabPainter(color);

  @override
  bool operator ==(Object other) =>
      other is PigmentTabIndicator && other.color == color;

  @override
  int get hashCode => color.hashCode;
}

class _PigmentTabPainter extends BoxPainter {
  _PigmentTabPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size!;
    final height = (size.height - 10).clamp(0.0, 30.0);
    final rect = Rect.fromCenter(
      center: offset + size.center(Offset.zero),
      width: size.width + 20,
      height: height,
    );
    final soft = Paint()
      ..color = color.withValues(alpha: color.a * 0.85)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(height / 2)),
      soft,
    );
    // A second, offset wash gives the edge a hand-painted wobble.
    canvas.drawOval(
      Rect.fromLTWH(
        rect.left + rect.width * 0.08,
        rect.top - 2,
        rect.width * 0.7,
        rect.height * 0.75,
      ),
      Paint()
        ..color = color.withValues(alpha: color.a * 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
  }
}

/// Leading icon of a list row. In the watercolor style the icon sits on a
/// small dab of the [pigment]-th pigment; in the classic style it is the
/// plain icon.
class WcListIcon extends StatelessWidget {
  const WcListIcon(this.icon, {super.key, this.pigment = 0});

  final IconData icon;
  final int pigment;

  @override
  Widget build(BuildContext context) {
    final tokens = WatercolorTokens.of(context);
    if (tokens == null) return WcIcon(icon);
    return SizedBox(
      width: 30,
      height: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 8,
            top: 9,
            width: 22,
            height: 18,
            child: PigmentWash(
              color: tokens.pigment(pigment),
              opacity: 0.75,
              shape: PigmentShape.dot,
            ),
          ),
          WcIcon(icon, size: 22, color: tokens.ink),
        ],
      ),
    );
  }
}

/// A group of list rows: a paper card in the watercolor style, the bare
/// rows in the classic style.
class WcListGroup extends StatelessWidget {
  const WcListGroup({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (WatercolorTokens.of(context) == null) return child;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: WcPanel(
        padding: const EdgeInsets.symmetric(vertical: 4),
        radius: 22,
        child: child,
      ),
    );
  }
}
