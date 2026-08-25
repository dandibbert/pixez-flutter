import 'package:material_ui/material_ui.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/page/novel/viewer/novel_pages.dart';
import 'package:pixez/page/novel/viewer/novel_reader_style.dart';

const Key novelReaderHeaderKey = Key('novelReaderHeader');
const Key novelReaderArticleKey = Key('novelReaderArticle');
const Key novelReaderPageNavKey = Key('novelReaderPageNav');
const Key novelReaderSettingsKey = Key('novelReaderSettings');
const Key novelFontFamilySerifKey = Key('novelFontFamilySerif');
const Key novelFontFamilySansKey = Key('novelFontFamilySans');
const Key novelFontFamilySystemKey = Key('novelFontFamilySystem');
const Key novelFontSizeSliderKey = Key('novelFontSizeSlider');
const Key novelLineHeightSliderKey = Key('novelLineHeightSlider');
const Key novelReaderPreviewKey = Key('novelReaderPreview');
const Key novelReaderTitleKey = Key('novelReaderTitle');

class NovelReaderScaffold extends StatelessWidget {
  final Widget header;
  final Widget? seriesBar;
  final Widget article;
  final Widget pageNav;

  const NovelReaderScaffold({
    super.key,
    required this.header,
    required this.article,
    required this.pageNav,
    this.seriesBar,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        header,
        if (seriesBar != null) seriesBar!,
        Expanded(child: article),
        Material(
          color: scheme.surface,
          elevation: 8,
          child: pageNav,
        ),
      ],
    );
  }
}

class NovelReaderHeader extends StatelessWidget {
  final String title;
  final String author;
  final VoidCallback onBack;
  final VoidCallback onTitleTap;
  final VoidCallback onAuthorTap;
  final Widget? trailing;

  const NovelReaderHeader({
    super.key,
    required this.title,
    required this.author,
    required this.onBack,
    required this.onTitleTap,
    required this.onAuthorTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: scheme.surface,
      child: SafeArea(
        bottom: false,
        child: Container(
          key: novelReaderHeaderKey,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: scheme.outlineVariant, width: 2),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: onTitleTap,
                      child: Text(
                        title,
                        key: novelReaderTitleKey,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: onAuthorTap,
                      child: Text(
                        author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class NovelReaderSeriesBar extends StatelessWidget {
  final String title;
  final VoidCallback? onOpenSeries;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const NovelReaderSeriesBar({
    super.key,
    required this.title,
    this.onOpenSeries,
    this.onPrev,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final i18n = I18n.of(context);
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            _SeriesChip(
              label: i18n.pre,
              enabled: onPrev != null,
              onTap: onPrev,
              leading: true,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: InkWell(
                  onTap: onOpenSeries,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
            _SeriesChip(
              label: i18n.next,
              enabled: onNext != null,
              onTap: onNext,
              leading: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _SeriesChip extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool leading;
  final VoidCallback? onTap;

  const _SeriesChip({
    required this.label,
    required this.enabled,
    required this.leading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = Icon(
      leading ? Icons.chevron_left : Icons.chevron_right,
      size: 18,
      color: enabled ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.3),
    );
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: enabled ? scheme.surface : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled ? scheme.outlineVariant : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading) icon,
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: enabled
                    ? scheme.onSurface
                    : scheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
            if (!leading) icon,
          ],
        ),
      ),
    );
  }
}

class NovelReaderArticle extends StatelessWidget {
  final Widget child;
  final ScrollController? controller;
  final EdgeInsetsGeometry padding;

  const NovelReaderArticle({
    super.key,
    required this.child,
    this.controller,
    this.padding = const EdgeInsets.fromLTRB(16, 24, 16, 32),
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.28),
      child: ListView(
        controller: controller,
        padding: padding,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Container(
                key: novelReaderArticleKey,
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border(
                    bottom: BorderSide(
                      color: scheme.surfaceContainerHighest,
                      width: 8,
                    ),
                  ),
                ),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NovelReaderPageNav extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final NovelPageNavState navState;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPickPage;

  const NovelReaderPageNav({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.navState,
    required this.onPrev,
    required this.onNext,
    required this.onPickPage,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);
    return SafeArea(
      top: false,
      child: Container(
        key: novelReaderPageNavKey,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
              width: 2,
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            _PageNavButton(
              icon: navState.canJumpPrevSeries
                  ? Icons.keyboard_double_arrow_left
                  : Icons.chevron_left,
              label: navState.canJumpPrevSeries
                  ? i18n.reader_series
                  : i18n.reader_page,
              enabled: !navState.isPrevDisabled,
              onTap: onPrev,
            ),
            Expanded(
              child: Center(
                child: InkWell(
                  onTap: onPickPage,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(
                      '$currentPage / $totalPages',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _PageNavButton(
              icon: navState.canJumpNextSeries
                  ? Icons.keyboard_double_arrow_right
                  : Icons.chevron_right,
              label: navState.canJumpNextSeries
                  ? i18n.reader_series
                  : i18n.reader_page,
              enabled: !navState.isNextDisabled,
              onTap: onNext,
            ),
          ],
        ),
      ),
    );
  }
}

class _PageNavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _PageNavButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = enabled
        ? scheme.onSurface
        : scheme.onSurface.withValues(alpha: 0.28);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NovelReaderSettingsSheet extends StatefulWidget {
  final double fontSize;
  final double lineHeight;
  final String fontFamily;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double> onLineHeightChanged;
  final ValueChanged<String> onFontFamilyChanged;

  const NovelReaderSettingsSheet({
    super.key,
    required this.fontSize,
    required this.lineHeight,
    required this.fontFamily,
    required this.onFontSizeChanged,
    required this.onLineHeightChanged,
    required this.onFontFamilyChanged,
  });

  @override
  State<NovelReaderSettingsSheet> createState() =>
      _NovelReaderSettingsSheetState();
}

class _NovelReaderSettingsSheetState extends State<NovelReaderSettingsSheet> {
  late double _fontSize;
  late double _lineHeight;
  late String _fontFamily;

  @override
  void initState() {
    super.initState();
    _fontSize = widget.fontSize;
    _lineHeight = widget.lineHeight;
    _fontFamily = NovelFontFamily.normalize(widget.fontFamily);
  }

  void _setFamily(String family) {
    setState(() {
      _fontFamily = family;
    });
    widget.onFontFamilyChanged(family);
  }

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final previewStyle = NovelReaderStyle.resolve(
      color: scheme.onSurface,
      fontSize: _fontSize,
      lineHeight: _lineHeight,
      fontFamily: _fontFamily,
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          key: novelReaderSettingsKey,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              i18n.novel_font,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  key: novelFontFamilySerifKey,
                  label: Text(i18n.novel_font_serif),
                  selected: _fontFamily == NovelFontFamily.serif,
                  onSelected: (_) => _setFamily(NovelFontFamily.serif),
                ),
                ChoiceChip(
                  key: novelFontFamilySansKey,
                  label: Text(i18n.novel_font_sans),
                  selected: _fontFamily == NovelFontFamily.sans,
                  onSelected: (_) => _setFamily(NovelFontFamily.sans),
                ),
                ChoiceChip(
                  key: novelFontFamilySystemKey,
                  label: Text(i18n.system),
                  selected: _fontFamily == NovelFontFamily.system,
                  onSelected: (_) => _setFamily(NovelFontFamily.system),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.text_fields),
                const SizedBox(width: 12),
                Text(_fontSize.round().toString()),
                Expanded(
                  child: Slider(
                    key: novelFontSizeSliderKey,
                    min: NovelReaderStyle.minFontSize,
                    max: NovelReaderStyle.maxFontSize,
                    value: _fontSize,
                    onChanged: (value) {
                      setState(() {
                        _fontSize = value;
                      });
                      widget.onFontSizeChanged(value);
                    },
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.format_line_spacing),
                const SizedBox(width: 12),
                Text(_lineHeight.toStringAsFixed(1)),
                Expanded(
                  child: Slider(
                    key: novelLineHeightSliderKey,
                    min: NovelReaderStyle.minLineHeight,
                    max: NovelReaderStyle.maxLineHeight,
                    value: _lineHeight,
                    onChanged: (value) {
                      setState(() {
                        _lineHeight = value;
                      });
                      widget.onLineHeightChanged(value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '本文プレビュー Preview 预览',
              key: novelReaderPreviewKey,
              style: previewStyle,
            ),
          ],
        ),
      ),
    );
  }
}
