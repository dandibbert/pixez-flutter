import 'package:material_ui/material_ui.dart';
import 'package:pixez/watercolor/watercolor_motion.dart';
import 'package:pixez/watercolor/watercolor_paper.dart';
import 'package:pixez/watercolor/watercolor_tokens.dart';

/// [showDialog] for both styles. The classic style calls it unchanged; the
/// watercolor style grows the dialog from 92% while it fades in (240ms) and
/// fades it out quickly (120ms), or only fades with reduced motion.
Future<T?> showWcDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  String? barrierLabel,
  bool useSafeArea = true,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
}) {
  final tokens = WatercolorTokens.of(context);
  if (tokens == null) {
    return showDialog<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      barrierLabel: barrierLabel,
      useSafeArea: useSafeArea,
      useRootNavigator: useRootNavigator,
      routeSettings: routeSettings,
      anchorPoint: anchorPoint,
    );
  }
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  return navigator.push<T>(
    _WatercolorDialogRoute<T>(
      reduced: WcMotion.reduced(context),
      builder: (context) {
        Widget dialog = themes.wrap(Builder(builder: builder));
        if (useSafeArea) dialog = SafeArea(child: dialog);
        return dialog;
      },
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.3),
      barrierLabel:
          barrierLabel ??
          MaterialLocalizations.of(context).modalBarrierDismissLabel,
      settings: routeSettings,
      anchorPoint: anchorPoint,
    ),
  );
}

class _WatercolorDialogRoute<T> extends RawDialogRoute<T> {
  _WatercolorDialogRoute({
    required WidgetBuilder builder,
    required this.reduced,
    super.barrierDismissible,
    super.barrierColor,
    super.barrierLabel,
    super.settings,
    super.anchorPoint,
  }) : super(
         pageBuilder: (context, animation, secondaryAnimation) =>
             builder(context),
         transitionDuration: reduced ? WcMotion.short : WcMotion.medium,
       );

  final bool reduced;

  @override
  Duration get reverseTransitionDuration => WcMotion.short;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: WcMotion.standard,
      reverseCurve: Curves.linear,
    );
    final faded = FadeTransition(opacity: curved, child: child);
    if (reduced) return faded;
    return ScaleTransition(
      scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
      child: faded,
    );
  }
}

/// Page transition of the watercolor style: the new page slides in from the
/// right on its own sheet of paper, casting a soft shadow, while the page
/// beneath drifts a quarter to the left and dims. Reduced motion fades.
class WatercolorPageTransitionsBuilder extends PageTransitionsBuilder {
  const WatercolorPageTransitionsBuilder();

  @override
  Duration get transitionDuration =>
      WcMotion.reducedGlobally ? WcMotion.short : WcMotion.long;

  @override
  Duration get reverseTransitionDuration => transitionDuration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final paper = WatercolorPaper(child: child);
    if (WcMotion.reduced(context)) {
      return FadeTransition(
        opacity: animation,
        child: FadeTransition(
          opacity: Tween<double>(
            begin: 1,
            end: 0.6,
          ).animate(secondaryAnimation),
          child: paper,
        ),
      );
    }
    final tokens = WatercolorTokens.of(context);
    final incoming = CurvedAnimation(
      parent: animation,
      curve: WcMotion.standard,
      reverseCurve: WcMotion.standard.flipped,
    );
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
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(incoming),
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: tokens?.shadow ?? const Color(0x296E5646),
                blurRadius: 26,
                offset: const Offset(-6, 0),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              paper,
              // Dims the page while a new one covers it.
              Positioned.fill(
                child: IgnorePointer(
                  child: FadeTransition(
                    opacity: outgoing,
                    child: const ColoredBox(color: Color(0x1A000000)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keeps [inner]'s transition (the iOS back swipe) and only puts the route
/// on paper and times it with the watercolor durations.
class WatercolorPaperTransitionsBuilder extends PageTransitionsBuilder {
  const WatercolorPaperTransitionsBuilder(this.inner);

  final PageTransitionsBuilder inner;

  @override
  Duration get transitionDuration =>
      WcMotion.reducedGlobally ? WcMotion.short : WcMotion.long;

  @override
  Duration get reverseTransitionDuration => transitionDuration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final paper = WatercolorPaper(child: child);
    if (WcMotion.reduced(context)) {
      return FadeTransition(opacity: animation, child: paper);
    }
    return inner.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      paper,
    );
  }
}
