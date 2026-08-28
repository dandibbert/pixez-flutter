import 'package:material_ui/material_ui.dart';
import 'package:pixez/i18n.dart';

const Key novelSearchPagerKey = Key('novelSearchPager');

class NovelSearchPagerBar extends StatelessWidget {
  final int currentPage;
  final bool loading;
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPickPage;

  const NovelSearchPagerBar({
    super.key,
    required this.currentPage,
    required this.loading,
    required this.hasPrevious,
    required this.hasNext,
    required this.onPrevious,
    required this.onNext,
    required this.onPickPage,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Container(
          key: novelSearchPagerKey,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: loading || !hasPrevious ? null : onPrevious,
                icon: const Icon(Icons.chevron_left),
                label: Text(I18n.of(context).pre),
              ),
              Expanded(
                child: Center(
                  child: TextButton(
                    onPressed: loading ? null : onPickPage,
                    child: Text(
                      I18n.of(context).search_result_page(currentPage),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: loading || !hasNext ? null : onNext,
                label: Text(I18n.of(context).next),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
