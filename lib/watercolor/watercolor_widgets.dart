import 'package:material_ui/material_ui.dart';
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
                          color: i == selected ? tokens.onPigment : tokens.ink,
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
