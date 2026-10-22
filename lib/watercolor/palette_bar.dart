import 'package:material_ui/material_ui.dart';
import 'package:pixez/watercolor/mingcute.dart';
import 'package:pixez/watercolor/watercolor_motion.dart';
import 'package:pixez/watercolor/watercolor_tokens.dart';

class PaletteBarItem {
  const PaletteBarItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// The watercolor bottom bar: a floating palette with one paint well per
/// destination. The selected well fills with its pigment.
class PaletteBar extends StatelessWidget {
  const PaletteBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<PaletteBarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const double height = 76;
  static const double bottomGap = 14;

  /// How far the bar must move down to leave the screen, beyond the safe
  /// area: its height, the gap below it and its shadow.
  static const double hiddenOffset = height + bottomGap + 36;

  @override
  Widget build(BuildContext context) {
    final tokens = WatercolorTokens.of(context)!;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottomGap + safeBottom),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: tokens.card,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: tokens.line),
          boxShadow: tokens.cardShadow,
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _PaletteWell(
                  item: items[i],
                  pigment: tokens.pigment(i),
                  selected: i == selectedIndex,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PaletteWell extends StatelessWidget {
  const _PaletteWell({
    required this.item,
    required this.pigment,
    required this.selected,
    required this.onTap,
  });

  final PaletteBarItem item;
  final Color pigment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = WatercolorTokens.of(context)!;
    final reduced = WcMotion.reduced(context);
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: PressScale(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 46,
                height: 40,
                child: CustomPaint(
                  painter: _WellPainter(
                    paper: tokens.paper,
                    shade: tokens.isDark
                        ? const Color(0x59000000)
                        : const Color(0x2E6E5646),
                    highlight: tokens.isDark
                        ? const Color(0x14FFFFFF)
                        : const Color(0xE6FFFFFF),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 3,
                        height: 8,
                        child: _Pigment(color: pigment, opacity: 0.6),
                      ),
                      Positioned(
                        left: -1,
                        top: 1,
                        right: -1,
                        bottom: 1,
                        child: AnimatedScale(
                          scale: selected ? 1 : 0,
                          duration: reduced ? Duration.zero : WcMotion.medium,
                          curve: WcMotion.bounce,
                          child: AnimatedOpacity(
                            opacity: selected ? 1 : 0,
                            duration: reduced
                                ? WcMotion.short
                                : WcMotion.medium,
                            curve: WcMotion.standard,
                            child: _Pigment(color: pigment, opacity: 0.9),
                          ),
                        ),
                      ),
                      WcIcon(
                        item.icon,
                        size: 24,
                        filled: selected,
                        color: selected ? tokens.onPigment : tokens.sub,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: WcMotion.short,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? tokens.ink : tokens.sub,
                ),
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A soft rough-edged wash of [color], from the pre-rendered blob texture.
class _Pigment extends StatelessWidget {
  const _Pigment({required this.color, required this.opacity});

  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/watercolor/blob_round.png',
      fit: BoxFit.fill,
      color: color.withValues(alpha: opacity),
      colorBlendMode: BlendMode.srcIn,
      gaplessPlayback: true,
    );
  }
}

/// The hollow of a paint well: paper with an inner shadow on top and a thin
/// highlight on the bottom edge.
class _WellPainter extends CustomPainter {
  const _WellPainter({
    required this.paper,
    required this.shade,
    required this.highlight,
  });

  final Color paper;
  final Color shade;
  final Color highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final oval = Offset.zero & size;
    final well = Path()..addOval(oval);
    canvas.drawPath(well, Paint()..color = paper);
    canvas.save();
    canvas.clipPath(well);
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(oval.inflate(12))
      ..addOval(oval);
    canvas.drawPath(
      outside.shift(const Offset(0, 2)),
      Paint()
        ..color = shade
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
    canvas.drawPath(
      outside.shift(const Offset(0, -1)),
      Paint()..color = highlight,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WellPainter oldDelegate) =>
      paper != oldDelegate.paper ||
      shade != oldDelegate.shade ||
      highlight != oldDelegate.highlight;
}
