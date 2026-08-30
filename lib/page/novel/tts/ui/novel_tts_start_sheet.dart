import 'package:flutter/material.dart';
import 'package:pixez/i18n.dart';

enum NovelTtsStartMode { firstPage, currentPage, currentPosition }

class NovelTtsStartSheet extends StatelessWidget {
  const NovelTtsStartSheet({
    super.key,
    required this.currentPage,
    this.hasSelectedPosition = false,
    this.onSelected,
  });
  final int currentPage;
  final bool hasSelectedPosition;
  final ValueChanged<NovelTtsStartMode>? onSelected;

  void _select(BuildContext context, NovelTtsStartMode mode) {
    if (onSelected != null) {
      onSelected!(mode);
    } else {
      Navigator.maybeOf(context)?.pop(mode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = I18n.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(l10n.tts_title),
            subtitle: Text(l10n.tts_choose_start),
          ),
          ListTile(
            leading: const Icon(Icons.first_page),
            title: Text(l10n.tts_start_first_page),
            onTap: () => _select(context, NovelTtsStartMode.firstPage),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book),
            title: Text(
              l10n.tts_start_from_page + ' ' + currentPage.toString(),
            ),
            onTap: () => _select(context, NovelTtsStartMode.currentPage),
          ),
          if (hasSelectedPosition)
            ListTile(
              leading: const Icon(Icons.my_location),
              title: Text(l10n.tts_start_current_position),
              onTap: () => _select(context, NovelTtsStartMode.currentPosition),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
