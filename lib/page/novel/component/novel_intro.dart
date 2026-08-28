import 'package:material_ui/material_ui.dart';
import 'package:pixez/i18n.dart';

const Key novelIntroButtonKey = Key('novelIntroButton');
const Key novelIntroCaptionKey = Key('novelIntroCaption');

String novelCaptionPlainText(String caption) {
  return caption
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .trim();
}

class NovelIntroPreview extends StatelessWidget {
  final String caption;
  final int maxLines;

  const NovelIntroPreview({
    super.key,
    required this.caption,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    final text = novelCaptionPlainText(caption);
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(
      text,
      key: novelIntroCaptionKey,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

Future<void> showNovelIntroDialog({
  required BuildContext context,
  required String title,
  required String caption,
}) {
  final text = novelCaptionPlainText(caption);
  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(
            text.isEmpty ? I18n.of(context).novel_details : text,
            key: novelIntroCaptionKey,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(I18n.of(context).ok),
          ),
        ],
      );
    },
  );
}
