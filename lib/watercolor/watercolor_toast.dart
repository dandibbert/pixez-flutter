import 'package:bot_toast/bot_toast.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/main.dart';
import 'package:pixez/watercolor/watercolor_motion.dart';
import 'package:pixez/watercolor/watercolor_tokens.dart';

/// [BotToast.showText] for both styles. The watercolor style shows an ink
/// pill with a pigment dot that rises in (240ms) and fades out (120ms).
CancelFunc wcToast({required String text}) {
  final context = rootNavigatorKey.currentContext;
  final tokens = context == null ? null : WatercolorTokens.of(context);
  if (tokens == null) return BotToast.showText(text: text);
  final reduced = WcMotion.reducedGlobally;
  return BotToast.showCustomText(
    duration: const Duration(seconds: 2),
    onlyOne: true,
    align: const Alignment(0, 0.8),
    animationDuration: reduced ? WcMotion.short : WcMotion.medium,
    animationReverseDuration: WcMotion.short,
    wrapToastAnimation: (controller, cancel, child) {
      final curved = CurvedAnimation(
        parent: controller,
        curve: WcMotion.standard,
        reverseCurve: Curves.linear,
      );
      final faded = FadeTransition(opacity: curved, child: child);
      if (reduced) return faded;
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.6),
          end: Offset.zero,
        ).animate(curved),
        child: faded,
      );
    },
    toastBuilder: (_) => _WatercolorToast(tokens: tokens, text: text),
  );
}

class _WatercolorToast extends StatelessWidget {
  const _WatercolorToast({required this.tokens, required this.text});

  final WatercolorTokens tokens;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.fromLTRB(14, 10, 18, 10),
      decoration: BoxDecoration(
        color: tokens.ink.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
        boxShadow: tokens.cardShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: tokens.pigment(2),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: tokens.paper),
            ),
          ),
        ],
      ),
    );
  }
}
