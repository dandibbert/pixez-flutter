import 'package:material_ui/material_ui.dart';
import 'package:pixez/watercolor/watercolor_tokens.dart';

/// Paper background: the paper color with a tileable grain on top.
///
/// Renders [child] unchanged while the classic style is active.
class WatercolorPaper extends StatelessWidget {
  const WatercolorPaper({super.key, required this.child});

  final Widget child;

  static const AssetImage grain = AssetImage('assets/watercolor/paper.png');

  @override
  Widget build(BuildContext context) {
    final tokens = WatercolorTokens.of(context);
    if (tokens == null) return child;
    return DecoratedBox(decoration: decoration(tokens), child: child);
  }

  static BoxDecoration decoration(WatercolorTokens tokens) {
    return BoxDecoration(
      color: tokens.paper,
      image: tokens.grainOpacity <= 0
          ? null
          : DecorationImage(
              image: grain,
              repeat: ImageRepeat.repeat,
              scale: 2,
              opacity: tokens.grainOpacity,
              colorFilter: ColorFilter.mode(tokens.ink, BlendMode.srcIn),
            ),
    );
  }
}

/// Puts each route on its own sheet of paper, so pages stay opaque while the
/// scaffold background is transparent.
class WatercolorPageTransitionsBuilder extends PageTransitionsBuilder {
  const WatercolorPageTransitionsBuilder(this.inner);

  final PageTransitionsBuilder inner;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return inner.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      WatercolorPaper(child: child),
    );
  }
}
