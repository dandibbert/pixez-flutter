import 'dart:async';
import 'dart:math' as math;

import 'package:bot_toast/bot_toast.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/watercolor/mingcute.dart';
import 'package:pixez/watercolor/watercolor_motion.dart';
import 'package:pixez/watercolor/watercolor_tokens.dart';
import 'package:pixez/watercolor/watercolor_widgets.dart';

/// Changes section under a wash of [color]: the wash soaks the screen from
/// [origin] (global coordinates), [onPeak] swaps the content while it is
/// covered, then the wash dries away. Reduced motion fades it in place; the
/// classic style calls [onPeak] at once.
///
/// The wash lives in the toast layer above the navigator, so [onPeak] may
/// replace the route it was started from.
Future<void> playSectionWash({
  required BuildContext context,
  required Offset origin,
  required Color color,
  required String label,
  required IconData icon,
  required VoidCallback onPeak,
}) {
  final tokens = WatercolorTokens.of(context);
  if (tokens == null) {
    onPeak();
    return Future.value();
  }
  final done = Completer<void>();
  late final CancelFunc cancel;
  cancel = BotToast.showWidget(
    toastBuilder: (_) => _SectionWash(
      tokens: tokens,
      reduced: WcMotion.reduced(context),
      origin: origin,
      color: color,
      label: label,
      icon: icon,
      onPeak: onPeak,
      onDone: () {
        cancel();
        if (!done.isCompleted) done.complete();
      },
    ),
  );
  return done.future;
}

class _SectionWash extends StatefulWidget {
  const _SectionWash({
    required this.tokens,
    required this.reduced,
    required this.origin,
    required this.color,
    required this.label,
    required this.icon,
    required this.onPeak,
    required this.onDone,
  });

  final WatercolorTokens tokens;
  final bool reduced;
  final Offset origin;
  final Color color;
  final String label;
  final IconData icon;
  final VoidCallback onPeak;
  final VoidCallback onDone;

  @override
  State<_SectionWash> createState() => _SectionWashState();
}

class _SectionWashState extends State<_SectionWash>
    with TickerProviderStateMixin {
  late final AnimationController _spread = AnimationController(
    vsync: this,
    duration: WcMotion.long,
  );
  late final AnimationController _dry = AnimationController(
    vsync: this,
    duration: WcMotion.long,
  );

  @override
  void initState() {
    super.initState();
    _play();
  }

  Future<void> _play() async {
    await _spread.forward();
    widget.onPeak();
    // Lets the new section lay out its first frame while still covered.
    await Future<void>.delayed(const Duration(milliseconds: 160));
    if (!mounted) return;
    await _dry.forward();
    widget.onDone();
  }

  @override
  void dispose() {
    _spread.dispose();
    _dry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final reduced = widget.reduced;
    return SizedBox.expand(
      child: AbsorbPointer(
        child: AnimatedBuilder(
          animation: Listenable.merge([_spread, _dry]),
          builder: (context, _) {
            final size = MediaQuery.sizeOf(context);
            final grow = WcMotion.standard.transform(_spread.value);
            final dry = WcMotion.standard.transform(_dry.value);
            final full = size.longestSide * 2.8;
            final diameter = reduced ? full : full * grow;
            final opacity = (reduced ? grow : 1.0) * (1 - dry);
            final labelOpacity = math.min(grow, 1 - dry);
            final wash = Color.alphaBlend(
              widget.color.withValues(alpha: 0.55),
              tokens.paper,
            );
            return Material(
              type: MaterialType.transparency,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: widget.origin.dx - diameter / 2,
                    top: widget.origin.dy - diameter / 2,
                    width: diameter,
                    height: diameter,
                    child: Opacity(
                      opacity: opacity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // The blob texture is soft all over; a solid core
                          // hides the page while it changes underneath.
                          Padding(
                            padding: EdgeInsets.all(diameter * 0.14),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: wash,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          PigmentWash(color: wash, opacity: 1),
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Opacity(
                      opacity: labelOpacity,
                      child: Transform.translate(
                        offset: Offset(
                          0,
                          reduced ? 0 : 10 * (1 - grow) - 8 * dry,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            WcIcon(
                              widget.icon,
                              size: 40,
                              filled: true,
                              color: tokens.ink,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              widget.label,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: tokens.ink,
                              ),
                            ),
                          ],
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
    );
  }
}
