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
