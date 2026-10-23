import 'package:material_ui/material_ui.dart';
import 'package:pixez/component/pixiv_image.dart';
import 'package:pixez/watercolor/watercolor_tokens.dart';

/// Trend tag on paper: the picture under a card label, with an edge of the
/// [index]-th pigment along the bottom.
class WatercolorTagTile extends StatelessWidget {
  const WatercolorTagTile({
    super.key,
    required this.imageUrl,
    required this.tag,
    required this.index,
    this.translatedName,
  });

  final String imageUrl;
  final String tag;
  final String? translatedName;
  final int index;

  @override
  Widget build(BuildContext context) {
    final tokens = WatercolorTokens.of(context)!;
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.card,
        borderRadius: BorderRadius.circular(WatercolorTokens.radiusSmall),
        border: Border(
          top: BorderSide(color: tokens.line),
          left: BorderSide(color: tokens.line),
          right: BorderSide(color: tokens.line),
          bottom: BorderSide(color: tokens.pigment(index), width: 3),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          PixivImage(imageUrl, fit: BoxFit.cover),
          Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(5),
              padding: const EdgeInsets.fromLTRB(7, 4, 7, 4),
              decoration: BoxDecoration(
                color: tokens.card.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "#$tag",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (translatedName?.isNotEmpty == true)
                    Text(
                      translatedName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: tokens.sub, fontSize: 10),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
