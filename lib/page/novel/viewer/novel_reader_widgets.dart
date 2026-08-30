import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/page/novel/viewer/novel_custom_font.dart';
import 'package:pixez/page/novel/viewer/novel_font_picker.dart';
import 'package:pixez/page/novel/viewer/novel_pages.dart';
import 'package:pixez/page/novel/viewer/novel_reader_background.dart';
import 'package:pixez/page/novel/viewer/novel_reader_style.dart';

const Key novelReaderHeaderKey = Key('novelReaderHeader');
const Key novelReaderArticleKey = Key('novelReaderArticle');
const Key novelReaderSeriesBarKey = Key('novelReaderSeriesBar');
const Key novelReaderScrollbarKey = Key('novelReaderScrollbar');
const Key novelReaderProgressKey = Key('novelReaderProgress');
const Key novelReaderPageNavKey = Key('novelReaderPageNav');
const Key novelReaderSettingsKey = Key('novelReaderSettings');
const Key novelFontPickerButtonKey = Key('novelFontPickerButton');
const Key novelFontSizeSliderKey = Key('novelFontSizeSlider');
const Key novelLineHeightSliderKey = Key('novelLineHeightSlider');
const Key novelReaderPreviewKey = Key('novelReaderPreview');
const Key novelReaderBackgroundKey = Key('novelReaderBackground');

Key novelReaderBackgroundChipKey(NovelReaderBackground background) =>
    Key('novelReaderBackground-${background.name}');
const Key novelReaderTitleKey = Key('novelReaderTitle');
const Key novelReaderDetailsButtonKey = Key('novelReaderDetailsButton');

class NovelReaderScaffold extends StatelessWidget {
  final Widget header;
  final Widget? seriesBar;
  final Widget article;
  final Widget? miniPlayer;
  final Widget pageNav;

  const NovelReaderScaffold({
    super.key,
    required this.header,
    required this.article,
    required this.pageNav,
    this.seriesBar,
    this.miniPlayer,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        header,
        if (seriesBar != null) seriesBar!,
        Expanded(child: article),
        if (miniPlayer != null) miniPlayer!,
        Material(color: scheme.surface, elevation: 8, child: pageNav),
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
  final VoidCallback? onDetails;
  final Widget? trailing;

  const NovelReaderHeader({
    super.key,
    required this.title,
    required this.author,
    required this.onBack,
    required this.onTitleTap,
    required this.onAuthorTap,
    this.onDetails,
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
              IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
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
              if (onDetails != null)
                IconButton(
                  key: novelReaderDetailsButtonKey,
                  tooltip: I18n.of(context).novel_details,
                  icon: const Icon(Icons.info_outline),
                  onPressed: onDetails,
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
      color: scheme.surface,
      child: Container(
        key: novelReaderSeriesBarKey,
        height: 32,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            _SeriesNavButton(
              tooltip: i18n.pre,
              icon: Icons.chevron_left,
              enabled: onPrev != null,
              onTap: onPrev,
            ),
            Expanded(
              child: InkWell(
                onTap: onOpenSeries,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            _SeriesNavButton(
              tooltip: i18n.next,
              icon: Icons.chevron_right,
              enabled: onNext != null,
              onTap: onNext,
            ),
          ],
        ),
      ),
    );
  }
}

class _SeriesNavButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _SeriesNavButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, size: 20),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
    );
  }
}

class NovelReaderArticle extends StatefulWidget {
  final Widget? child;
  final int? itemCount;
  final IndexedWidgetBuilder? itemBuilder;
  final ScrollController? controller;
  final EdgeInsetsGeometry padding;

  const NovelReaderArticle({
    super.key,
    this.child,
    this.itemCount,
    this.itemBuilder,
    this.controller,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 24),
  }) : assert(
         child != null || (itemCount != null && itemBuilder != null),
         'Provide child or itemBuilder',
       );

  @override
  State<NovelReaderArticle> createState() => _NovelReaderArticleState();
}

class _NovelReaderArticleState extends State<NovelReaderArticle> {
  ScrollController? _owned;
  double _progress = 0;

  ScrollController get _controller => widget.controller ?? _owned!;

  @override
  void initState() {
    super.initState();
    _owned = widget.controller == null ? ScrollController() : null;
    _controller.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  @override
  void didUpdateWidget(NovelReaderArticle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }
    oldWidget.controller?.removeListener(_onScroll);
    _owned?.removeListener(_onScroll);
    _owned?.dispose();
    _owned = widget.controller == null ? ScrollController() : null;
    _controller.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _owned?.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) {
      return;
    }
    final max = _controller.position.maxScrollExtent;
    final next = max <= 0 ? 1.0 : (_controller.offset / max).clamp(0.0, 1.0);
    if ((next - _progress).abs() < 0.002) {
      return;
    }
    setState(() => _progress = next);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = math.max(16.0, (width - 720) / 2);
    final resolvedPadding = widget.padding.add(
      EdgeInsets.symmetric(horizontal: math.max(0, horizontal - 16)),
    );
    final Widget sliver;
    if (widget.itemBuilder != null && widget.itemCount != null) {
      sliver = SliverList(
        delegate: SliverChildBuilderDelegate(
          widget.itemBuilder!,
          childCount: widget.itemCount,
          addAutomaticKeepAlives: false,
        ),
      );
    } else {
      sliver = SliverToBoxAdapter(child: widget.child);
    }
    return ColoredBox(
      key: novelReaderArticleKey,
      color: scheme.surface,
      child: Column(
        children: [
          LinearProgressIndicator(
            key: novelReaderProgressKey,
            value: _progress,
            minHeight: 3,
            color: scheme.primary,
            backgroundColor: scheme.outlineVariant,
          ),
          Expanded(
            child: ScrollbarTheme(
              data: ScrollbarThemeData(
                thumbVisibility: const WidgetStatePropertyAll(true),
                thickness: const WidgetStatePropertyAll(6),
                radius: const Radius.circular(4),
                thumbColor: WidgetStatePropertyAll(
                  scheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
              child: Scrollbar(
                key: novelReaderScrollbarKey,
                controller: _controller,
                interactive: true,
                child: CustomScrollView(
                  controller: _controller,
                  slivers: [
                    SliverPadding(padding: resolvedPadding, sliver: sliver),
                  ],
                ),
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
  final String? fontFilePath;
  final List<String>? fontFamilies;
  final Future<NovelImportedFont?> Function()? importFont;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double> onLineHeightChanged;
  final ValueChanged<NovelFontChoice> onFontFamilyChanged;
  final NovelReaderBackground background;
  final ValueChanged<NovelReaderBackground>? onBackgroundChanged;

  const NovelReaderSettingsSheet({
    super.key,
    required this.fontSize,
    required this.lineHeight,
    required this.fontFamily,
    required this.onFontSizeChanged,
    required this.onLineHeightChanged,
    required this.onFontFamilyChanged,
    this.background = NovelReaderBackground.system,
    this.onBackgroundChanged,
    this.fontFilePath,
    this.fontFamilies,
    this.importFont,
  });

  @override
  State<NovelReaderSettingsSheet> createState() =>
      _NovelReaderSettingsSheetState();
}

class _NovelReaderSettingsSheetState extends State<NovelReaderSettingsSheet> {
  late double _fontSize;
  late double _lineHeight;
  late String _fontFamily;
  String? _fontFilePath;
  late NovelReaderBackground _background;

  @override
  void initState() {
    super.initState();
    _fontSize = widget.fontSize;
    _lineHeight = widget.lineHeight;
    _fontFamily = widget.fontFamily;
    _fontFilePath = widget.fontFilePath;
    _background = widget.background;
  }

  void _setBackground(NovelReaderBackground value) {
    setState(() => _background = value);
    widget.onBackgroundChanged?.call(value);
  }

  String _backgroundLabel(NovelReaderBackground value) {
    final i18n = I18n.of(context);
    switch (value) {
      case NovelReaderBackground.system:
        return i18n.novel_background_system;
      case NovelReaderBackground.paper:
        return i18n.novel_background_paper;
      case NovelReaderBackground.sepia:
        return i18n.novel_background_sepia;
      case NovelReaderBackground.dark:
        return i18n.novel_background_dark;
      case NovelReaderBackground.black:
        return i18n.novel_background_black;
    }
  }

  void _setFamily(NovelFontChoice choice) {
    setState(() {
      _fontFamily = choice.family;
      _fontFilePath = choice.filePath;
    });
    widget.onFontFamilyChanged(choice);
  }

  String _fontLabel() {
    if (NovelReaderStyle.isDefaultFamily(_fontFamily)) {
      return I18n.of(context).novel_font_default;
    }
    return NovelCustomFont.displayName(_fontFamily);
  }

  Future<void> _openFontPicker() async {
    final choice = await Navigator.of(context, rootNavigator: true)
        .push<NovelFontChoice>(
          MaterialPageRoute(
            builder: (context) {
              return NovelFontPickerPage(
                selectedFamily: _fontFamily,
                selectedFilePath: _fontFilePath,
                families: widget.fontFamilies,
                importFont: widget.importFont,
              );
            },
          ),
        );
    if (choice != null) {
      _setFamily(choice);
    }
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
            ListTile(
              key: novelFontPickerButtonKey,
              contentPadding: EdgeInsets.zero,
              title: Text(_fontLabel()),
              subtitle: Text(I18n.of(context).novel_font_search),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openFontPicker,
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
            const SizedBox(height: 12),
            Text(
              i18n.novel_background,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              key: novelReaderBackgroundKey,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in NovelReaderBackground.values)
                  ChoiceChip(
                    key: novelReaderBackgroundChipKey(value),
                    label: Text(_backgroundLabel(value)),
                    selected: _background == value,
                    onSelected: (_) => _setBackground(value),
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
