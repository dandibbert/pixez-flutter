import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/er/leader.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/main.dart';
import 'package:pixez/page/book/tag/book_tag_page.dart';
import 'package:pixez/page/hello/ranking/rank_store.dart';
import 'package:pixez/page/hello/recom/recom_manga_page.dart';
import 'package:pixez/page/hello/tab_jump.dart';
import 'package:pixez/page/history/history_page.dart';
import 'package:pixez/page/novel/history/novel_history_page.dart';
import 'package:pixez/page/novel/novel_rail.dart';
import 'package:pixez/page/novel/tts/novel_tts_bar.dart';
import 'package:pixez/page/novel/viewer/novel_viewer.dart';
import 'package:pixez/page/picture/illust_lighting_page.dart';
import 'package:pixez/page/saucenao/sauce_nao_modal.dart';
import 'package:pixez/page/task/job_page.dart';
import 'package:pixez/page/webview/saucenao_webview_page.dart';
import 'package:pixez/watercolor/mingcute.dart';
import 'package:pixez/watercolor/palette_bar.dart';
import 'package:pixez/watercolor/pigment_scatter_menu.dart';
import 'package:pixez/watercolor/section_wash.dart';
import 'package:pixez/watercolor/watercolor_routes.dart';
import 'package:pixez/watercolor/watercolor_toast.dart';
import 'package:pixez/watercolor/watercolor_tokens.dart';

enum AppSection { illust, novel }

/// What a long press on the first palette well does.
enum HomeLongPressMode { menu, novel, manga }

class _Shortcut {
  const _Shortcut(this.action, this.run);

  final ScatterAction action;

  /// Runs the shortcut; [origin] is the drop's center on screen.
  final void Function(Offset origin) run;
}

/// Long-press shortcuts of the palette bar of a section's home. Every well
/// opens a [PigmentScatterMenu] of shortcuts; the first one switches
/// section, or jumps straight to novels or manga when the user chose so.
class PaletteShortcuts {
  PaletteShortcuts({required this.section, required this.selectTab});

  final AppSection section;

  /// Shows a tab of the home, as tapping its well does.
  final ValueChanged<int> selectTab;

  static const int wellCount = 5;
  static const int illustPigment = 0;
  static const int mangaPigment = 1;
  static const int novelPigment = 3;

  final GlobalKey<PigmentScatterMenuState> _menuKey = GlobalKey();

  bool get isMenuOpen => _menuKey.currentState?.isOpen ?? false;

  /// Wraps the home's scaffold, bar included, so the menu can cover it.
  Widget wrap(BuildContext context, Widget child) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return PigmentScatterMenu(
      key: _menuKey,
      barInset: PaletteBar.height + PaletteBar.bottomGapFor(safeBottom),
      currentLabel: I18n.of(context).shortcut_current,
      child: child,
    );
  }

  /// Label of the first well: the section showing.
  static String sectionLabel(BuildContext context, AppSection section) =>
      section == AppSection.illust
      ? I18n.of(context).illust
      : I18n.of(context).novel;

  static IconData sectionIcon(AppSection section) =>
      section == AppSection.illust ? Icons.image : Icons.book;

  static int _sectionPigment(AppSection section) =>
      section == AppSection.illust ? illustPigment : novelPigment;

  /// Points out the first well's long press once, on the first visit.
  static void showHintOnce(BuildContext context) {
    if (WatercolorTokens.of(context) == null ||
        userSetting.homeLongPressHintShown) {
      return;
    }
    unawaited(userSetting.markHomeLongPressHintShown());
    wcToast(text: I18n.of(context).shortcut_hint);
  }

  void onLongPressStart(
    BuildContext context,
    int index,
    LongPressStartDetails details,
  ) {
    unawaited(userSetting.markHomeLongPressHintShown());
    final mode = HomeLongPressMode.values[userSetting.homeLongPressMode];
    if (index == 0 && mode != HomeLongPressMode.menu) {
      HapticFeedback.mediumImpact();
      _jumpDirectly(context, mode, details.globalPosition);
      return;
    }
    final menu = _menuKey.currentState;
    final shortcuts = _shortcutsFor(context, index);
    if (menu == null || shortcuts.isEmpty) return;
    final box = menu.context.findRenderObject() as RenderBox;
    final size = box.size;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final cell = (size.width - 24) / wellCount;
    // The icon sits 8px above the middle of the well, over its label.
    final anchor = Offset(
      12 + cell * (index + 0.5),
      size.height -
          PaletteBar.bottomGapFor(safeBottom) -
          PaletteBar.height / 2 -
          8,
    );
    final targets = PigmentScatterMenuState.layoutColumn(
      anchor,
      shortcuts.length,
    );
    menu.open(
      anchor: anchor,
      sourcePigment: index,
      actions: [for (final s in shortcuts) s.action],
      pressPosition: details.globalPosition,
      onSelected: (i) => shortcuts[i].run(box.localToGlobal(targets[i])),
    );
  }

  /// Switch to the other section for the navigation rail of wide layouts,
  /// which has no palette bar to long-press.
  Widget railSwitch(BuildContext context) {
    final other = section == AppSection.illust
        ? AppSection.novel
        : AppSection.illust;
    return Builder(
      builder: (context) => IconButton(
        tooltip: sectionLabel(context, other),
        icon: WcIcon(sectionIcon(other)),
        onPressed: () {
          final box = context.findRenderObject() as RenderBox;
          _switchSection(
            context,
            other,
            box.localToGlobal(box.size.center(Offset.zero)),
          );
        },
      ),
    );
  }

  void onLongPressMoveUpdate(LongPressMoveUpdateDetails details) =>
      _menuKey.currentState?.track(details.globalPosition);

  void onLongPressEnd(LongPressEndDetails details) =>
      _menuKey.currentState?.release(details.globalPosition);

  void _jumpDirectly(
    BuildContext context,
    HomeLongPressMode mode,
    Offset origin,
  ) {
    if (mode == HomeLongPressMode.manga) {
      Leader.push(context, RecomMangaPage());
      return;
    }
    final target = section == AppSection.novel
        ? AppSection.illust
        : AppSection.novel;
    final message = I18n.of(
      context,
    ).shortcut_switched(sectionLabel(context, target));
    _switchSection(context, target, origin).then((_) => wcToast(text: message));
  }

  Future<void> _switchSection(
    BuildContext context,
    AppSection target,
    Offset origin, {
    int initialIndex = 0,
  }) {
    final navigator = Navigator.of(context, rootNavigator: true);
    final tokens = WatercolorTokens.of(context);
    return playSectionWash(
      context: context,
      origin: origin,
      color: tokens?.pigment(_sectionPigment(target)) ?? Colors.transparent,
      label: sectionLabel(context, target),
      icon: sectionIcon(target),
      onPeak: () => navigator.pushReplacement(
        target == AppSection.novel
            ? novelRailRoute(initialIndex: initialIndex, instant: true)
            : illustHomeRoute(initialIndex: initialIndex, instant: true),
      ),
    );
  }

  List<_Shortcut> _shortcutsFor(BuildContext context, int index) {
    final i18n = I18n.of(context);
    final novel = section == AppSection.novel;
    switch (index) {
      case 0:
        final other = novel ? AppSection.illust : AppSection.novel;
        // The other section sits nearest the well, so a short slide up
        // always toggles between illusts and novels.
        return [
          _Shortcut(
            ScatterAction(
              icon: sectionIcon(other),
              label: sectionLabel(context, other),
              pigment: _sectionPigment(other),
            ),
            (origin) => _switchSection(context, other, origin),
          ),
          _Shortcut(
            ScatterAction(
              icon: Icons.library_books,
              label: i18n.manga,
              pigment: mangaPigment,
            ),
            (_) => Leader.push(context, RecomMangaPage()),
          ),
          _Shortcut(
            ScatterAction(
              icon: sectionIcon(section),
              label: sectionLabel(context, section),
              pigment: _sectionPigment(section),
              current: true,
            ),
            (_) => selectTab(0),
          ),
        ];
      case 1:
        return _rankShortcuts(context);
      case 2:
        if (accountStore.now == null) return const [];
        final labels = [
          i18n.news,
          i18n.bookmark,
          i18n.watchlist,
          novel ? i18n.follow : i18n.news_follow_title,
        ];
        const icons = [
          Icons.feed,
          Icons.bookmark,
          Icons.list,
          Icons.people_outline,
        ];
        final request = novel ? TabJumps.novelNews : TabJumps.illustNews;
        return [
          for (var i = 0; i < labels.length; i++)
            _Shortcut(
              ScatterAction(icon: icons[i], label: labels[i], pigment: i + 1),
              (_) => _openTab(2, request, i),
            ),
        ];
      case 3:
        final workId = _Shortcut(
          ScatterAction(
            icon: Icons.tag,
            label: i18n.shortcut_work_id,
            pigment: 4,
          ),
          (_) => _openWorkId(context),
        );
        if (novel) {
          return [
            workId,
            _Shortcut(
              ScatterAction(
                icon: Icons.image,
                label: i18n.shortcut_search_illust,
                pigment: illustPigment,
              ),
              (origin) => _switchSection(
                context,
                AppSection.illust,
                origin,
                initialIndex: 3,
              ),
            ),
          ];
        }
        return [
          _Shortcut(
            ScatterAction(
              icon: Icons.photo,
              label: i18n.shortcut_saucenao,
              pigment: 2,
            ),
            (_) {
              if (userSetting.useSaunceNaoWebview) {
                Leader.push(context, SauncenaoWebview());
              } else {
                SauceNaoModal.show(context);
              }
            },
          ),
          workId,
          _Shortcut(
            ScatterAction(
              icon: Icons.book,
              label: i18n.shortcut_search_novel,
              pigment: novelPigment,
            ),
            (origin) => _switchSection(
              context,
              AppSection.novel,
              origin,
              initialIndex: 3,
            ),
          ),
        ];
      default:
        return [
          _Shortcut(
            ScatterAction(
              icon: Icons.history,
              label: novel ? i18n.novel_history : i18n.history_record,
              pigment: 1,
            ),
            (_) => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => novel ? NovelHistory() : HistoryPage(),
              ),
            ),
          ),
          if (novel)
            _Shortcut(
              ScatterAction(
                icon: Icons.headphones,
                label: i18n.novel_tts_settings,
                pigment: 4,
              ),
              (_) => openNovelTtsSettings(context),
            )
          else
            _Shortcut(
              ScatterAction(
                icon: Icons.save_alt,
                label: i18n.task_progress,
                pigment: 0,
              ),
              (_) => Leader.push(context, JobPage()),
            ),
          _Shortcut(
            ScatterAction(
              icon: Icons.bookmark,
              label: i18n.favorited_tag,
              pigment: 3,
            ),
            (_) => Leader.pushWithScaffold(context, BookTagPage()),
          ),
        ];
    }
  }

  List<_Shortcut> _rankShortcuts(BuildContext context) {
    const icons = [
      Icons.calendar_today_outlined,
      Icons.date_range,
      Icons.stars,
      Icons.star_outline,
    ];
    final List<String> labels;
    final List<int> tabs;
    final TabJumpRequest request;
    if (section == AppSection.novel) {
      final names = I18n.of(context).novel_mode_list.split(' ');
      // Daily, weekly, then the male and female dailies.
      tabs = const [0, 3, 1, 2];
      labels = [for (final t in tabs) names[t]];
      request = TabJumps.novelRank;
    } else {
      final names = I18n.of(context).mode_list.split(' ');
      final modes = savedRankModes().take(icons.length).toList();
      tabs = [for (var i = 0; i < modes.length; i++) i];
      labels = [
        for (final mode in modes)
          names.elementAtOrNull(rankModeKeys.indexOf(mode)) ?? mode,
      ];
      request = TabJumps.illustRank;
    }
    return [
      for (var i = 0; i < tabs.length; i++)
        _Shortcut(
          ScatterAction(icon: icons[i], label: labels[i], pigment: i + 1),
          (_) => _openTab(1, request, tabs[i]),
        ),
    ];
  }

  void _openTab(int well, TabJumpRequest request, int tab) {
    request.request(tab);
    selectTab(well);
  }

  Future<void> _openWorkId(BuildContext context) async {
    final id = await showWcDialog<int>(
      context: context,
      builder: (context) => const _WorkIdDialog(),
    );
    if (id == null || !context.mounted) return;
    if (section == AppSection.novel) {
      Leader.push(context, NovelViewerPage(id: id));
    } else {
      Leader.push(context, IllustLightingPage(id: id));
    }
  }
}

class _WorkIdDialog extends StatefulWidget {
  const _WorkIdDialog();

  @override
  State<_WorkIdDialog> createState() => _WorkIdDialogState();
}

class _WorkIdDialogState extends State<_WorkIdDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? get _id => int.tryParse(_controller.text.trim());

  void _submit() {
    final id = _id;
    if (id != null) Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);
    return AlertDialog(
      title: Text(i18n.shortcut_work_id),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(hintText: i18n.shortcut_work_id_hint),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(i18n.cancel),
        ),
        TextButton(
          onPressed: _id == null ? null : _submit,
          child: Text(i18n.shortcut_open),
        ),
      ],
    );
  }
}
