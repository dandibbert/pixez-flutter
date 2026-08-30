import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const ListTile(
          title: Text('Novel text to speech'),
          subtitle: Text('Choose where narration should begin.'),
        ),
        ListTile(
          leading: const Icon(Icons.first_page),
          title: const Text('Start from first page'),
          onTap: () => _select(context, NovelTtsStartMode.firstPage),
        ),
        ListTile(
          leading: const Icon(Icons.menu_book),
          title: Text('Start from page $currentPage'),
          onTap: () => _select(context, NovelTtsStartMode.currentPage),
        ),
        if (hasSelectedPosition)
          ListTile(
            leading: const Icon(Icons.my_location),
            title: const Text('Start from current position'),
            onTap: () => _select(context, NovelTtsStartMode.currentPosition),
          ),
        const SizedBox(height: 8),
      ],
    ),
  );
}
