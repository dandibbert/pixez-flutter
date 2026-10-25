import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/page/novel/viewer/novel_custom_font.dart';
import 'package:pixez/page/novel/viewer/novel_font_picker.dart';
import 'package:pixez/page/novel/viewer/novel_pages.dart';
import 'package:pixez/page/novel/viewer/novel_reader_background.dart';
import 'package:pixez/page/novel/viewer/novel_reader_style.dart';
import 'package:pixez/watercolor/mingcute.dart';
import 'package:pixez/watercolor/palette_bar.dart';
import 'package:pixez/watercolor/watercolor_motion.dart';
import 'package:pixez/watercolor/watercolor_tokens.dart';
import 'package:pixez/watercolor/watercolor_widgets.dart';

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
  final Widget pageNav;
  final Widget? player;

  const NovelReaderScaffold({
    super.key,
    required this.header,
    required this.article,
    required this.pageNav,
    this.seriesBar,
    this.player,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        header,
        if (seriesBar != null) seriesBar!,
        Expanded(child: article),
        if (player != null) player!,
        if (WatercolorTokens.of(context) case final tokens?)
          _WatercolorDock(tokens: tokens, child: pageNav)
        else
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
    final tokens = WatercolorTokens.of(context);
    return Material(
      color: tokens == null ? scheme.surface : Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: Container(
          key: novelReaderHeaderKey,
          foregroundDecoration: tokens == null
              ? null
              : _BrushRule(tokens.pigment(0)),
          decoration: tokens == null
              ? BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: scheme.outlineVariant, width: 2),
                  ),
                )
              : null,
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Row(
            children: [
              IconButton(
                icon: const WcIcon(Icons.arrow_back),
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
                        style: tokens != null
                            ? TextStyle(fontSize: 11, color: tokens.accent)
                            : textTheme.labelSmall?.copyWith(
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
                  icon: const WcIcon(Icons.info_outline),
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
    final tokens = WatercolorTokens.of(context);
    return Material(
      color: tokens == null ? scheme.surface : Colors.transparent,
      child: Container(
        key: novelReaderSeriesBarKey,
        height: tokens == null ? 32 : 36,
        margin: tokens == null ? null : const EdgeInsets.fromLTRB(16, 8, 16, 4),
        decoration: tokens == null
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: scheme.outlineVariant),
                ),
              )
            : BoxDecoration(
                color: tokens.pigment(4).withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(18),
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
      icon: WcIcon(icon, size: 20),
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

  /// Identifies the content being shown, such as the current page. When it
  /// changes the list is rebuilt from scratch instead of laying the new
  /// blocks out from the old blocks' positions, which would otherwise shift
  /// the scroll offset away from the top on a page turn.
  final Key? contentKey;

  const NovelReaderArticle({
    super.key,
    this.child,
    this.itemCount,
    this.itemBuilder,
    this.controller,
    this.contentKey,
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
        key: widget.contentKey,
        delegate: SliverChildBuilderDelegate(
          widget.itemBuilder!,
          childCount: widget.itemCount,
          addAutomaticKeepAlives: false,
        ),
      );
    } else {
      sliver = SliverToBoxAdapter(key: widget.contentKey, child: widget.child);
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
            // The header and the page bar already sit inside the status bar
            // and home-indicator insets. Left in place here, the insets
            // shrink the scrollbar track, so its thumb rests a status-bar
            // height down even at the top of the page.
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              removeBottom: true,
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
    final tokens = WatercolorTokens.of(context);
    if (tokens != null) return _buildWatercolor(context, tokens);
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

extension on NovelReaderPageNav {
  /// Outlined back pill, page count over a pigment progress stroke, and a
  /// pigment forward pill.
  Widget _buildWatercolor(BuildContext context, WatercolorTokens tokens) {
    final i18n = I18n.of(context);
    final progress = totalPages <= 0
        ? 0.0
        : (currentPage / totalPages).clamp(0.0, 1.0);
    return Container(
      key: novelReaderPageNavKey,
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _WatercolorPageButton(
            icon: navState.canJumpPrevSeries
                ? Icons.keyboard_double_arrow_left
                : Icons.chevron_left,
            label: navState.canJumpPrevSeries
                ? i18n.reader_series
                : i18n.reader_page,
            enabled: !navState.isPrevDisabled,
            onTap: onPrev,
            leading: true,
          ),
          Expanded(
            child: InkWell(
              onTap: onPickPage,
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$currentPage / $totalPages',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: tokens.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 136,
                    height: 4,
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: tokens.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: AnimatedFractionallySizedBox(
                      duration: WcMotion.medium,
                      curve: WcMotion.standard,
                      widthFactor: progress,
                      child: Container(
                        decoration: BoxDecoration(
                          color: tokens.pigment(0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _WatercolorPageButton(
            icon: navState.canJumpNextSeries
                ? Icons.keyboard_double_arrow_right
                : Icons.chevron_right,
            label: navState.canJumpNextSeries
                ? i18n.reader_series
                : i18n.reader_page,
            enabled: !navState.isNextDisabled,
            onTap: onNext,
            leading: false,
          ),
        ],
      ),
    );
  }
}

class _WatercolorPageButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool leading;

  const _WatercolorPageButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    required this.leading,
  });

  /// Back and forward are small sheets of paper. A usable one has its outer
  /// bottom corner turned up, showing pigment underneath, like a page about
  /// to be turned; an unusable one lies flat and fades. [leading] marks the
  /// back button, whose arrow and turned corner sit on the left.
  @override
  Widget build(BuildContext context) {
    final tokens = WatercolorTokens.of(context)!;
    final color = enabled ? tokens.ink : tokens.ink.withValues(alpha: 0.3);
    final arrow = WcIcon(icon, size: 18, color: color);
    final text = Text(
      label,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
    );
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: PressScale(
        enabled: enabled,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: enabled ? 1 : 0),
          duration: WcMotion.reduced(context) ? Duration.zero : WcMotion.medium,
          curve: WcMotion.standard,
          builder: (context, fold, child) => CustomPaint(
            painter: _PageCornerPainter(
              tokens: tokens,
              backward: leading,
              fold: fold,
            ),
            child: child,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: SizedBox(
              height: 42,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: leading ? [arrow, text] : [text, arrow],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A sheet of paper whose outer bottom corner is turned up by [fold]
/// (0 lies flat, 1 fully turned), showing a pigment-tinted flap.
class _PageCornerPainter extends CustomPainter {
  const _PageCornerPainter({
    required this.tokens,
    required this.backward,
    required this.fold,
  });

  final WatercolorTokens tokens;
  final bool backward;
  final double fold;

  static const double _radius = 10;
  static const double _flap = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final flap = _flap * fold;
    final sheet = Path()..moveTo(_radius, 0);
    sheet
      ..lineTo(w - _radius, 0)
      ..quadraticBezierTo(w, 0, w, _radius);
    // Bottom right.
    if (!backward && flap > 0.5) {
      sheet
        ..lineTo(w, h - flap)
        ..lineTo(w - flap, h);
    } else {
      sheet
        ..lineTo(w, h - _radius)
        ..quadraticBezierTo(w, h, w - _radius, h);
    }
    // Bottom left.
    if (backward && flap > 0.5) {
      sheet
        ..lineTo(flap, h)
        ..lineTo(0, h - flap);
    } else {
      sheet
        ..lineTo(_radius, h)
        ..quadraticBezierTo(0, h, 0, h - _radius);
    }
    sheet
      ..lineTo(0, _radius)
      ..quadraticBezierTo(0, 0, _radius, 0)
      ..close();

    canvas.drawShadow(sheet, tokens.shadow, 2 * fold, false);
    canvas.drawPath(sheet, Paint()..color = tokens.paper);
    canvas.drawPath(
      sheet,
      Paint()
        ..color = tokens.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    if (flap <= 0.5) return;
    final flapPath = backward
        ? (Path()
            ..moveTo(0, h - flap)
            ..lineTo(flap, h - flap)
            ..lineTo(flap, h)
            ..close())
        : (Path()
            ..moveTo(w, h - flap)
            ..lineTo(w - flap, h - flap)
            ..lineTo(w - flap, h)
            ..close());
    canvas.drawPath(flapPath, Paint()..color = tokens.pigment(0));
    canvas.drawPath(
      flapPath,
      Paint()
        ..color = tokens.ink.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_PageCornerPainter oldDelegate) =>
      fold != oldDelegate.fold ||
      backward != oldDelegate.backward ||
      tokens != oldDelegate.tokens;
}

/// The page nav floats on a paper card above the bottom edge.
class _WatercolorDock extends StatelessWidget {
  const _WatercolorDock({required this.tokens, required this.child});

  final WatercolorTokens tokens;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Sits as low as the palette bar does: just above the home indicator.
    final bottom = PaletteBar.bottomGapFor(
      MediaQuery.paddingOf(context).bottom,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 4, 12, bottom),
      // The shadow sits behind an opaque card; drawn inside the card it
      // would grey the whole bar.
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.card,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: tokens.line),
          boxShadow: tokens.cardShadow,
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(26),
          clipBehavior: Clip.antiAlias,
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A short brush stroke of [color] along the bottom edge.
class _BrushRule extends Decoration {
  const _BrushRule(this.color);

  final Color color;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _BrushRulePainter(color);
}

class _BrushRulePainter extends BoxPainter {
  _BrushRulePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size!;
    final left = offset.dx + 12;
    final width = size.width - 24;
    final y = offset.dy + size.height - 2;
    final path = Path()..moveTo(left, y);
    const waves = 14;
    for (var i = 1; i <= waves; i++) {
      final x = left + width * i / waves;
      path.quadraticBezierTo(
        x - width / waves / 2,
        y + (i.isEven ? 1.6 : -1.6),
        x,
        y,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: color.a * 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6),
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
    final tokens = WatercolorTokens.of(context);
    if (tokens != null) return _buildWatercolor(context, tokens);
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
              trailing: const WcIcon(Icons.chevron_right),
              onTap: _openFontPicker,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const WcIcon(Icons.text_fields),
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
                const WcIcon(Icons.format_line_spacing),
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

  static const Map<NovelReaderBackground, (Color, Color)> _swatches = {
    NovelReaderBackground.paper: (Color(0xFFFFFFFF), Color(0xFF1A1A1A)),
    NovelReaderBackground.sepia: (Color(0xFFF4ECD8), Color(0xFF43372A)),
    NovelReaderBackground.dark: (Color(0xFF16181C), Color(0xFFC8CBD0)),
    NovelReaderBackground.black: (Color(0xFF000000), Color(0xFFB7BBC0)),
  };

  Widget _buildWatercolorSlider({
    required WatercolorTokens tokens,
    required String label,
    required String value,
    required Key sliderKey,
    required double min,
    required double max,
    required double current,
    required String minLabel,
    required String maxLabel,
    required Color pigment,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: WcSectionLabel(label)),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: tokens.ink,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Text(minLabel, style: TextStyle(fontSize: 11, color: tokens.sub)),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: pigment,
                  thumbColor: tokens.card,
                  thumbShape: _RingThumb(tokens.ink, pigment),
                ),
                child: Slider(
                  key: sliderKey,
                  min: min,
                  max: max,
                  value: current,
                  onChanged: onChanged,
                ),
              ),
            ),
            Text(maxLabel, style: TextStyle(fontSize: 11, color: tokens.sub)),
          ],
        ),
      ],
    );
  }

  /// Font card, size and line-height sliders, background swatches and a
  /// preview line, laid out like the watercolor reading sheet.
  Widget _buildWatercolor(BuildContext context, WatercolorTokens tokens) {
    final i18n = I18n.of(context);
    final previewStyle = NovelReaderStyle.resolve(
      color: tokens.ink,
      fontSize: _fontSize,
      lineHeight: _lineHeight,
      fontFamily: _fontFamily,
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          key: novelReaderSettingsKey,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WcSectionLabel(i18n.novel_font),
            const SizedBox(height: 8),
            WcPanel(
              padding: EdgeInsets.zero,
              child: ListTile(
                key: novelFontPickerButtonKey,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                leading: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tokens.pigment(3).withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '文',
                    style: TextStyle(fontSize: 20, color: tokens.onPigment),
                  ),
                ),
                title: Text(
                  _fontLabel(),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: tokens.ink,
                  ),
                ),
                subtitle: Text(I18n.of(context).novel_font_search),
                trailing: WcIcon(Icons.chevron_right, color: tokens.sub),
                onTap: _openFontPicker,
              ),
            ),
            const SizedBox(height: 16),
            _buildWatercolorSlider(
              tokens: tokens,
              label: i18n.novel_font_size,
              value: _fontSize.round().toString(),
              sliderKey: novelFontSizeSliderKey,
              min: NovelReaderStyle.minFontSize,
              max: NovelReaderStyle.maxFontSize,
              current: _fontSize,
              minLabel: NovelReaderStyle.minFontSize.round().toString(),
              maxLabel: NovelReaderStyle.maxFontSize.round().toString(),
              pigment: tokens.pigment(3),
              onChanged: (value) {
                setState(() => _fontSize = value);
                widget.onFontSizeChanged(value);
              },
            ),
            const SizedBox(height: 8),
            _buildWatercolorSlider(
              tokens: tokens,
              label: i18n.novel_line_height,
              value: _lineHeight.toStringAsFixed(1),
              sliderKey: novelLineHeightSliderKey,
              min: NovelReaderStyle.minLineHeight,
              max: NovelReaderStyle.maxLineHeight,
              current: _lineHeight,
              minLabel: NovelReaderStyle.minLineHeight.toStringAsFixed(1),
              maxLabel: NovelReaderStyle.maxLineHeight.toStringAsFixed(1),
              pigment: tokens.pigment(0),
              onChanged: (value) {
                setState(() => _lineHeight = value);
                widget.onLineHeightChanged(value);
              },
            ),
            const SizedBox(height: 16),
            WcSectionLabel(i18n.novel_background),
            const SizedBox(height: 10),
            Row(
              key: novelReaderBackgroundKey,
              children: [
                for (final value in NovelReaderBackground.values)
                  Expanded(child: _buildBackgroundSwatch(tokens, value)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tokens.pigment(1).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(
                  WatercolorTokens.radiusSmall,
                ),
                border: Border.all(color: tokens.pigment(1)),
              ),
              child: Text(
                '本文プレビュー Preview 预览',
                key: novelReaderPreviewKey,
                style: previewStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundSwatch(
    WatercolorTokens tokens,
    NovelReaderBackground value,
  ) {
    final selected = _background == value;
    final (fill, text) = _swatches[value] ?? (tokens.paper, tokens.ink);
    return Semantics(
      key: novelReaderBackgroundChipKey(value),
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: () => _setBackground(value),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: WcMotion.medium,
          curve: WcMotion.standard,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(WatercolorTokens.radiusSmall),
            border: Border.all(
              color: selected ? tokens.ink : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: fill,
                  shape: BoxShape.circle,
                  border: Border.all(color: tokens.line),
                ),
                child: Text('文', style: TextStyle(fontSize: 15, color: text)),
              ),
              const SizedBox(height: 6),
              Text(
                _backgroundLabel(value),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: tokens.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Slider thumb: a paper disc with an ink ring and a pigment dot.
class _RingThumb extends SliderComponentShape {
  const _RingThumb(this.ink, this.pigment);

  final Color ink;
  final Color pigment;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.square(22);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(center, 10, Paint()..color = sliderTheme.thumbColor!);
    canvas.drawCircle(
      center,
      10,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(center, 4, Paint()..color = pigment);
  }
}

/// The reader's read-aloud icon in the watercolor style: a headphone that
/// sits on a pigment wash while reading, a fainter one while paused.
class NovelReaderTtsIcon extends StatelessWidget {
  const NovelReaderTtsIcon({
    required this.tokens,
    required this.active,
    required this.paused,
  });

  final WatercolorTokens tokens;
  final bool active;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final strength = active ? 0.6 : (paused ? 0.3 : 0.0);
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            left: -8,
            top: -8,
            right: -8,
            bottom: -8,
            child: AnimatedOpacity(
              opacity: strength,
              duration: WcMotion.medium,
              curve: WcMotion.standard,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      tokens.pigment(0),
                      tokens.pigment(0).withValues(alpha: 0.85),
                      tokens.pigment(0).withValues(alpha: 0),
                    ],
                    stops: const [0, 0.78, 1],
                  ),
                ),
              ),
            ),
          ),
          const WcIcon(Icons.headphones, size: 21),
        ],
      ),
    );
  }
}
