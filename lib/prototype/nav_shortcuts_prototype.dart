// UI prototype: long-press shortcuts on the watercolor palette bar.
//
// Run with `flutter run -d chrome -t lib/prototype/nav_shortcuts_prototype.dart`.
// Everything here is mock content; only the palette bar, the scatter menu and
// the watercolor theme are the app's real widgets.

import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:pixez/watercolor/mingcute.dart';
import 'package:pixez/watercolor/palette_bar.dart';
import 'package:pixez/watercolor/pigment_scatter_menu.dart';
import 'package:pixez/watercolor/watercolor_motion.dart';
import 'package:pixez/watercolor/watercolor_paper.dart';
import 'package:pixez/watercolor/watercolor_routes.dart';
import 'package:pixez/watercolor/watercolor_theme.dart';
import 'package:pixez/watercolor/watercolor_tokens.dart';
import 'package:pixez/watercolor/watercolor_widgets.dart';

void main() => runApp(const NavShortcutsPrototype());

/// What a long press on the first well does.
enum HomeLongPress { scatter, novel, manga }

enum Section { illust, novel }

class ProtoConfig {
  const ProtoConfig({
    this.homeLongPress = HomeLongPress.scatter,
    this.showSectionOnHome = true,
    this.dark = false,
    this.seedPalette = false,
    this.reducedMotion = false,
  });

  final HomeLongPress homeLongPress;
  final bool showSectionOnHome;
  final bool dark;
  final bool seedPalette;
  final bool reducedMotion;

  ProtoConfig copyWith({
    HomeLongPress? homeLongPress,
    bool? showSectionOnHome,
    bool? dark,
    bool? seedPalette,
    bool? reducedMotion,
  }) {
    return ProtoConfig(
      homeLongPress: homeLongPress ?? this.homeLongPress,
      showSectionOnHome: showSectionOnHome ?? this.showSectionOnHome,
      dark: dark ?? this.dark,
      seedPalette: seedPalette ?? this.seedPalette,
      reducedMotion: reducedMotion ?? this.reducedMotion,
    );
  }
}

class NavShortcutsPrototype extends StatefulWidget {
  const NavShortcutsPrototype({super.key});

  @override
  State<NavShortcutsPrototype> createState() => _NavShortcutsPrototypeState();
}

class _NavShortcutsPrototypeState extends State<NavShortcutsPrototype> {
  ProtoConfig _config = const ProtoConfig();
  int _hintGeneration = 0;

  WatercolorTokens get _tokens => WatercolorTokens.resolve(
    brightness: _config.dark ? Brightness.dark : Brightness.light,
    amoled: false,
    mode: _config.seedPalette
        ? WatercolorPaletteMode.seed
        : WatercolorPaletteMode.multi,
    seed: const Color(0xFF5F8FA8),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '下边栏长按快捷动作 · 原型',
      debugShowCheckedModeBanner: false,
      theme: buildWatercolorTheme(_tokens),
      themeAnimationDuration: WcMotion.long,
      themeAnimationCurve: WcMotion.standard,
      home: _Stage(
        config: _config,
        hintGeneration: _hintGeneration,
        onConfig: (config) => setState(() => _config = config),
        onReplayHint: () => setState(() => _hintGeneration++),
      ),
    );
  }
}

/// Phone frame plus, on wide screens, the control panel beside it.
class _Stage extends StatelessWidget {
  const _Stage({
    required this.config,
    required this.hintGeneration,
    required this.onConfig,
    required this.onReplayHint,
  });

  final ProtoConfig config;
  final int hintGeneration;
  final ValueChanged<ProtoConfig> onConfig;
  final VoidCallback onReplayHint;

  static const Size phone = Size(390, 844);

  @override
  Widget build(BuildContext context) {
    final tokens = WatercolorTokens.of(context)!;
    final shell = _PhoneShell(key: ValueKey(hintGeneration), config: config);
    final panel = _ControlPanel(
      config: config,
      onConfig: onConfig,
      onReplayHint: onReplayHint,
    );
    return Material(
      color: tokens.paper,
      child: WatercolorPaper(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 760) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(disableAnimations: config.reducedMotion),
                      child: shell,
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 8,
                    right: 8,
                    child: IconButton.filledTonal(
                      icon: const WcIcon(Icons.tune),
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        sheetAnimationStyle: WcMotion.sheet(context),
                        builder: (_) => panel,
                      ),
                    ),
                  ),
                ],
              );
            }
            final height = math.min(constraints.maxHeight - 48, phone.height);
            final scale = height / phone.height;
            return Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 360,
                    height: constraints.maxHeight - 48,
                    child: panel,
                  ),
                  const SizedBox(width: 40),
                  SizedBox(
                    width: (phone.width + 20) * scale,
                    height: (phone.height + 20) * scale,
                    child: FittedBox(
                      child: _PhoneFrame(
                        reducedMotion: config.reducedMotion,
                        child: shell,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.child, required this.reducedMotion});

  final Widget child;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final tokens = WatercolorTokens.of(context)!;
    const size = _Stage.phone;
    return Container(
      width: size.width + 20,
      height: size.height + 20,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF2B2420),
        borderRadius: BorderRadius.circular(54),
        boxShadow: tokens.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(44),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: size,
            padding: const EdgeInsets.only(top: 44, bottom: 22),
            viewPadding: const EdgeInsets.only(top: 44, bottom: 22),
            disableAnimations: reducedMotion,
          ),
          child: Stack(
            children: [
              Positioned.fill(child: child),
              Positioned(
                top: 14,
                left: 34,
                child: IgnorePointer(
                  child: Text(
                    '9:41',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: tokens.ink,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: size.width / 2 - 66,
                child: IgnorePointer(
                  child: Container(
                    width: 132,
                    height: 5,
                    decoration: BoxDecoration(
                      color: tokens.ink.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Model

class _Model extends ChangeNotifier {
  Section section = Section.illust;
  int tab = 0;
  bool hintVisible = false;
  final Map<String, int> _chips = {};

  int chip(Section s, int tab) => _chips['${s.name}-$tab'] ?? 0;

  void setChip(Section s, int tab, int chip) {
    _chips['${s.name}-$tab'] = chip;
    notifyListeners();
  }

  void selectTab(int index) {
    tab = index;
    notifyListeners();
  }

  void switchSection(Section s, {int tab = 0}) {
    section = s;
    this.tab = tab;
    notifyListeners();
  }

  void setHint(bool visible) {
    if (hintVisible == visible) return;
    hintVisible = visible;
    notifyListeners();
  }
}

const _sectionPigment = {Section.illust: 0, Section.novel: 3};
const _mangaPigment = 1;

String _sectionLabel(Section s) => s == Section.illust ? '插画' : '小说';
IconData _sectionIcon(Section s) =>
    s == Section.illust ? Icons.image : Icons.book;

List<String> _tabLabels(Section s) => s == Section.illust
    ? ['首页', '排行', '速览', '搜索', '更多']
    : ['首页', '排行', '动态', '搜索', '设置'];

List<IconData> _tabIcons(Section s) => s == Section.illust
    ? [
        Icons.home,
        Icons.leaderboard,
        Icons.favorite,
        Icons.search,
        Icons.more_horiz,
      ]
    : [
        Icons.home,
        Icons.leaderboard,
        Icons.favorite,
        Icons.search,
        Icons.settings,
      ];

List<String> _chipsFor(Section s, int tab) => switch ((s, tab)) {
  (Section.illust, 0) => ['推荐', '特辑'],
  (Section.illust, 1) => ['每日', '每周', '每月', '原创'],
  (Section.illust, 2) => ['动态', '收藏', '追更列表', '已关注'],
  (Section.novel, 0) => ['推荐', '新作'],
  (Section.novel, 1) => ['每日', '每周', '男性向', '女性向'],
  (Section.novel, 2) => ['动态', '收藏', '追更列表', '已关注'],
  _ => const [],
};

/// Shortcuts of each well, by section.
List<ScatterAction> _actionsFor(Section s, int tab) {
  if (tab == 0) {
    return [
      ScatterAction(
        icon: Icons.image,
        label: '插画',
        pigment: _sectionPigment[Section.illust]!,
        current: s == Section.illust,
      ),
      const ScatterAction(
        icon: Icons.layers_outlined,
        label: '漫画',
        pigment: _mangaPigment,
      ),
      ScatterAction(
        icon: Icons.book,
        label: '小说',
        pigment: _sectionPigment[Section.novel]!,
        current: s == Section.novel,
      ),
    ];
  }
  if (tab == 1 || tab == 2) {
    final icons = tab == 1
        ? [
            Icons.calendar_today_outlined,
            Icons.date_range,
            Icons.stars,
            Icons.star_outline,
          ]
        : [Icons.feed, Icons.bookmark, Icons.list, Icons.people_outline];
    final chips = _chipsFor(s, tab);
    return [
      for (var i = 0; i < chips.length; i++)
        ScatterAction(icon: icons[i], label: chips[i], pigment: i + 1),
    ];
  }
  if (tab == 3) {
    return s == Section.illust
        ? const [
            ScatterAction(icon: Icons.photo, label: '以图搜图', pigment: 2),
            ScatterAction(icon: Icons.tag, label: '作品 ID', pigment: 4),
            ScatterAction(icon: Icons.book, label: '搜小说', pigment: 3),
          ]
        : const [
            ScatterAction(icon: Icons.tag, label: '作品 ID', pigment: 4),
            ScatterAction(icon: Icons.image, label: '搜插画', pigment: 0),
          ];
  }
  return s == Section.illust
      ? const [
          ScatterAction(icon: Icons.history, label: '历史记录', pigment: 1),
          ScatterAction(icon: Icons.save_alt, label: '任务进度', pigment: 0),
          ScatterAction(icon: Icons.bookmark, label: '收藏标签', pigment: 3),
        ]
      : const [
          ScatterAction(icon: Icons.history, label: '阅读历史', pigment: 1),
          ScatterAction(icon: Icons.headphones, label: '小说朗读', pigment: 4),
          ScatterAction(icon: Icons.bookmark, label: '收藏标签', pigment: 3),
        ];
}

// ---------------------------------------------------------------------------
// Phone shell

class _PhoneShell extends StatefulWidget {
  const _PhoneShell({super.key, required this.config});

  final ProtoConfig config;

  @override
  State<_PhoneShell> createState() => _PhoneShellState();
}

class _PhoneShellState extends State<_PhoneShell> {
  final _model = _Model();
  final _navigator = GlobalKey<NavigatorState>();
  final _wash = GlobalKey<_SectionWashState>();
  final _toast = GlobalKey<_ToastHostState>();
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    _hintTimer = Timer(const Duration(milliseconds: 700), () {
      _model.setHint(true);
      _hintTimer = Timer(
        const Duration(seconds: 7),
        () => _model.setHint(false),
      );
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _model.dispose();
    super.dispose();
  }

  void _push(Widget page) {
    _navigator.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  void _switchSection(
    Section target,
    Offset origin, {
    int tab = 0,
    String? toast,
  }) {
    final tokens = WatercolorTokens.of(context)!;
    _navigator.currentState!.popUntil((route) => route.isFirst);
    _wash.currentState!.play(
      origin: origin,
      color: tokens.pigment(_sectionPigment[target]!),
      label: _sectionLabel(target),
      icon: _sectionIcon(target),
      onPeak: () => _model.switchSection(target, tab: tab),
      onDone: toast == null ? null : () => _toast.currentState!.show(toast),
    );
  }

  void _directJump(Offset origin) {
    final section = _model.section;
    if (widget.config.homeLongPress == HomeLongPress.manga) {
      _push(const _MangaPage());
      _toast.currentState!.show('长按「首页」直达漫画');
      return;
    }
    final target = section == Section.novel ? Section.illust : Section.novel;
    _switchSection(
      target,
      origin,
      toast: '已切换到${_sectionLabel(target)} · 再次长按「首页」切回',
    );
  }

  void _runAction(Section section, int tab, int index, Offset origin) {
    if (tab == 0) {
      switch (index) {
        case 0:
          if (section != Section.illust) _switchSection(Section.illust, origin);
        case 1:
          _push(const _MangaPage());
        case 2:
          if (section != Section.novel) _switchSection(Section.novel, origin);
      }
      return;
    }
    if (tab == 1 || tab == 2) {
      _model.selectTab(tab);
      _model.setChip(section, tab, index);
      return;
    }
    final label = _actionsFor(section, tab)[index].label;
    switch (label) {
      case '搜小说':
        _switchSection(Section.novel, origin, tab: 3);
      case '搜插画':
        _switchSection(Section.illust, origin, tab: 3);
      case '作品 ID':
        _askId();
      default:
        final action = _actionsFor(section, tab)[index];
        _push(
          _SubPage(
            title: action.label,
            icon: action.icon,
            pigment: action.pigment,
          ),
        );
    }
  }

  void _askId() {
    showWcDialog<void>(
      context: _navigator.currentContext!,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: const Text('输入作品 ID'),
        content: const TextField(
          autofocus: true,
          decoration: InputDecoration(hintText: 'pixiv ID，例如 12345678'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('打开'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WatercolorPaper(
      child: Stack(
        children: [
          Positioned.fill(
            child: HeroControllerScope.none(
              child: Navigator(
                key: _navigator,
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) => _Home(
                    model: _model,
                    config: widget.config,
                    onDirectJump: _directJump,
                    onAction: _runAction,
                    onSwitchSection: _switchSection,
                    onPush: _push,
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(child: _SectionWash(key: _wash)),
          Positioned.fill(child: _ToastHost(key: _toast)),
        ],
      ),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home({
    required this.model,
    required this.config,
    required this.onDirectJump,
    required this.onAction,
    required this.onSwitchSection,
    required this.onPush,
  });

  final _Model model;
  final ProtoConfig config;
  final void Function(Offset origin) onDirectJump;
  final void Function(Section section, int tab, int index, Offset origin)
  onAction;
  final void Function(Section target, Offset origin) onSwitchSection;
  final ValueChanged<Widget> onPush;

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  final _menu = GlobalKey<PigmentScatterMenuState>();

  Offset _anchor(Size size, int index, double safeBottom) {
    final wellWidth = (size.width - 24) / 5;
    final barCenter =
        size.height -
        PaletteBar.bottomGapFor(safeBottom) -
        PaletteBar.height / 2;
    return Offset(12 + wellWidth * (index + 0.5), barCenter - 8);
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final barInset = PaletteBar.height + PaletteBar.bottomGapFor(safeBottom);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return ListenableBuilder(
          listenable: model,
          builder: (context, _) {
            final section = model.section;
            final labels = _tabLabels(section);
            final icons = _tabIcons(section);
            final showSection = widget.config.showSectionOnHome;
            return PigmentScatterMenu(
              key: _menu,
              barInset: barInset,
              child: Scaffold(
                extendBody: true,
                body: Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedSwitcher(
                        duration: WcMotion.medium,
                        switchInCurve: WcMotion.standard,
                        switchOutCurve: WcMotion.standard,
                        child: KeyedSubtree(
                          key: ValueKey('${section.name}-${model.tab}'),
                          child: _pageFor(section, model.tab),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      bottom: barInset + 8,
                      child: _LongPressHint(
                        visible: model.hintVisible,
                        homeLongPress: widget.config.homeLongPress,
                        section: section,
                      ),
                    ),
                  ],
                ),
                bottomNavigationBar: PaletteBar(
                  items: [
                    PaletteBarItem(
                      icon: showSection ? _sectionIcon(section) : icons[0],
                      label: showSection ? _sectionLabel(section) : labels[0],
                    ),
                    for (var i = 1; i < 5; i++)
                      PaletteBarItem(icon: icons[i], label: labels[i]),
                  ],
                  selectedIndex: model.tab,
                  onSelected: model.selectTab,
                  onLongPressStart: (index, details) {
                    model.setHint(false);
                    final anchor = _anchor(size, index, safeBottom);
                    if (index == 0 &&
                        widget.config.homeLongPress != HomeLongPress.scatter) {
                      widget.onDirectJump(anchor);
                      return;
                    }
                    final actions = _actionsFor(section, index);
                    _menu.currentState!.open(
                      anchor: anchor,
                      sourcePigment: index,
                      actions: actions,
                      pressPosition: details.globalPosition,
                      onSelected: (picked) {
                        final targets = PigmentScatterMenuState.layoutArch(
                          anchor,
                          actions.length,
                          size,
                        );
                        widget.onAction(
                          section,
                          index,
                          picked,
                          targets[picked],
                        );
                      },
                    );
                  },
                  onLongPressMoveUpdate: (_, details) =>
                      _menu.currentState?.track(details.globalPosition),
                  onLongPressEnd: (_, details) =>
                      _menu.currentState?.release(details.globalPosition),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _pageFor(Section section, int tab) {
    final model = widget.model;
    if (tab == 3) return _SearchPage(section: section);
    if (tab == 4) {
      return _MorePage(
        section: section,
        onPush: widget.onPush,
        onSwitchSection: (target) => widget.onSwitchSection(
          target,
          Offset(
            MediaQuery.sizeOf(context).width / 2,
            MediaQuery.sizeOf(context).height / 2,
          ),
        ),
      );
    }
    final titles = section == Section.illust
        ? ['插画', '排行', '速览']
        : ['小说', '小说排行', '动态'];
    return _FeedPage(
      title: titles[tab],
      section: section,
      ranked: tab == 1,
      chips: _chipsFor(section, tab),
      chip: model.chip(section, tab),
      onChip: (i) => model.setChip(section, tab, i),
    );
  }
}

/// One-time coach mark above the first well.
class _LongPressHint extends StatelessWidget {
  const _LongPressHint({
    required this.visible,
    required this.homeLongPress,
    required this.section,
  });

  final bool visible;
  final HomeLongPress homeLongPress;
  final Section section;

  @override
  Widget build(BuildContext context) {
    final tokens = WatercolorTokens.of(context)!;
    final text = switch (homeLongPress) {
      HomeLongPress.scatter => '长按可切换  插画 · 漫画 · 小说',
      HomeLongPress.novel => section == Section.novel ? '长按切回插画' : '长按直达小说',
      HomeLongPress.manga => '长按直达漫画',
    };
    return IgnorePointer(
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 0.25),
        duration: WcMotion.medium,
        curve: WcMotion.standard,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: visible ? WcMotion.medium : WcMotion.short,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
                decoration: BoxDecoration(
                  color: tokens.card,
                  borderRadius: BorderRadius.circular(
                    WatercolorTokens.radiusSmall,
                  ),
                  border: Border.all(color: tokens.line),
                  boxShadow: tokens.cardShadow,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 14,
                      child: PigmentWash(
                        color: tokens.pigment(0),
                        shape: PigmentShape.dot,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      text,
                      style: TextStyle(fontSize: 13, color: tokens.ink),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: CustomPaint(
                  size: const Size(14, 7),
                  painter: _PointerPainter(tokens.card, tokens.line),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PointerPainter extends CustomPainter {
  const _PointerPainter(this.fill, this.edge);

  final Color fill;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_PointerPainter oldDelegate) =>
      fill != oldDelegate.fill || edge != oldDelegate.edge;
}

// ---------------------------------------------------------------------------
// Section switch: a wash of the section's pigment soaks the page from the
// chosen drop, the content changes under it, and it dries away.

class _SectionWash extends StatefulWidget {
  const _SectionWash({super.key});

  @override
  State<_SectionWash> createState() => _SectionWashState();
}

class _SectionWashState extends State<_SectionWash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spread = AnimationController(
    vsync: this,
    duration: WcMotion.long,
  );
  late final AnimationController _dry = AnimationController(
    vsync: this,
    duration: WcMotion.long,
  );
  Offset _origin = Offset.zero;
  Color _color = Colors.transparent;
  String _label = '';
  IconData _icon = Icons.book;
  bool _active = false;

  @override
  void dispose() {
    _spread.dispose();
    _dry.dispose();
    super.dispose();
  }

  Future<void> play({
    required Offset origin,
    required Color color,
    required String label,
    required IconData icon,
    required VoidCallback onPeak,
    VoidCallback? onDone,
  }) async {
    setState(() {
      _origin = origin;
      _color = color;
      _label = label;
      _icon = icon;
      _active = true;
    });
    _dry.value = 0;
    await _spread.forward(from: 0);
    onPeak();
    await Future<void>.delayed(const Duration(milliseconds: 160));
    await _dry.forward(from: 0);
    if (!mounted) return;
    setState(() => _active = false);
    onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) return const SizedBox.shrink();
    final tokens = WatercolorTokens.of(context)!;
    final reduced = WcMotion.reduced(context);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: Listenable.merge([_spread, _dry]),
        builder: (context, _) {
          final size = MediaQuery.sizeOf(context);
          final grow = WcMotion.standard.transform(_spread.value);
          final dry = WcMotion.standard.transform(_dry.value);
          final full = size.longestSide * 2.8;
          final diameter = reduced ? full : full * grow;
          final opacity = (reduced ? grow : 1.0) * (1 - dry);
          final labelOpacity = math.min(grow, 1 - dry);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: _origin.dx - diameter / 2,
                top: _origin.dy - diameter / 2,
                width: diameter,
                height: diameter,
                child: Opacity(
                  opacity: opacity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      PigmentWash(
                        color: Color.alphaBlend(
                          _color.withValues(alpha: 0.55),
                          tokens.paper,
                        ),
                        opacity: 1,
                      ),
                    ],
                  ),
                ),
              ),
              Center(
                child: Opacity(
                  opacity: labelOpacity,
                  child: Transform.translate(
                    offset: Offset(0, reduced ? 0 : 10 * (1 - grow) - 8 * dry),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        WcIcon(
                          _icon,
                          size: 40,
                          filled: true,
                          color: tokens.ink,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _label,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: tokens.ink,
                            letterSpacing: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ToastHost extends StatefulWidget {
  const _ToastHost({super.key});

  @override
  State<_ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<_ToastHost> {
  String? _text;
  bool _visible = false;
  Timer? _timer;

  void show(String text) {
    _timer?.cancel();
    setState(() {
      _text = text;
      _visible = true;
    });
    _timer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _text;
    if (text == null) return const SizedBox.shrink();
    final tokens = WatercolorTokens.of(context)!;
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, 0.62),
        child: AnimatedSlide(
          offset: _visible ? Offset.zero : const Offset(0, 0.6),
          duration: _visible ? WcMotion.medium : WcMotion.short,
          curve: WcMotion.standard,
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: _visible ? WcMotion.medium : WcMotion.short,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.fromLTRB(14, 10, 18, 10),
              decoration: BoxDecoration(
                color: tokens.ink.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(999),
                boxShadow: tokens.cardShadow,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: tokens.pigment(2),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      text,
                      style: TextStyle(fontSize: 13, color: tokens.paper),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mock pages

final _entranceTokens = <String, Object>{};

/// [WcEntrance] keys its once-per-session state on object identity, which
/// strings can't carry.
Object _entranceToken(String key) =>
    _entranceTokens.putIfAbsent(key, Object.new);

const _illustTitles = [
  '春日',
  '午后的猫',
  '青',
  '夏の終わり',
  '雨宿り',
  '星屑',
  '花信',
  '海辺の約束',
  '薄荷',
  '黄昏电车',
  '白昼梦',
  '一期一会',
];
const _artists = ['ミナト', '白鸟', 'sora', '柚子', '凪', 'Haru', '月見', '小林'];
const _novelTitles = [
  '雨夜的水彩信笺',
  '第七号图书馆',
  '星屑与旧城',
  '夏天结束之前',
  '猫与魔女的茶会',
  '海边的回声',
  '无人知晓的车站',
  '纸飞机的约定',
  '冬日限定的魔法',
  '三月的告白',
];
const _novelTags = ['恋爱', '奇幻', '日常', '治愈', '悬疑', '校园', '原创', '短篇'];

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    this.chips = const [],
    this.chip = 0,
    this.onChip,
    this.pigment = 0,
  });

  final String title;
  final List<String> chips;
  final int chip;
  final ValueChanged<int>? onChip;
  final int pigment;

  @override
  Widget build(BuildContext context) {
    final tokens = WatercolorTokens.of(context)!;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.paddingOf(context).top + 14,
        20,
        10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PigmentBackdrop(
            color: tokens.pigment(pigment),
            opacity: 0.55,
            shape: PigmentShape.wide,
            bleed: const EdgeInsets.fromLTRB(8, 2, 14, 0),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: tokens.ink,
              ),
            ),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < chips.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => onChip?.call(i),
                        child: PressScale(
                          child: AnimatedContainer(
                            duration: WcMotion.medium,
                            curve: WcMotion.standard,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: i == chip
                                  ? Colors.transparent
                                  : tokens.card,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: i == chip
                                    ? Colors.transparent
                                    : tokens.line,
                              ),
                            ),
                            child: PigmentBackdrop(
                              color: tokens.pigment(i + 1),
                              visible: i == chip,
                              bleed: const EdgeInsets.fromLTRB(14, 7, 14, 7),
                              child: Text(
                                chips[i],
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: i == chip
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: i == chip
                                      ? tokens.onPigment
                                      : tokens.ink,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeedPage extends StatelessWidget {
  const _FeedPage({
    required this.title,
    required this.section,
    required this.ranked,
    required this.chips,
    required this.chip,
    required this.onChip,
  });

  final String title;
  final Section section;
  final bool ranked;
  final List<String> chips;
  final int chip;
  final ValueChanged<int> onChip;

  @override
  Widget build(BuildContext context) {
    final seed = title.hashCode ^ (chip * 7919);
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _PageHeader(
            title: title,
            chips: chips,
            chip: chip,
            onChip: onChip,
            pigment: _sectionPigment[section]!,
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            14,
            4,
            14,
            PaletteBar.height + PaletteBar.bottomGapFor(safeBottom) + 24,
          ),
          sliver: section == Section.illust
              ? SliverGrid.builder(
                  key: ValueKey(seed),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.74,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, i) => WcEntrance(
                    token: _entranceToken('$seed'),
                    index: i,
                    child: _IllustCard(
                      seed: seed + i,
                      rank: ranked ? i + 1 : null,
                    ),
                  ),
                )
              : SliverList.builder(
                  key: ValueKey(seed),
                  itemCount: 10,
                  itemBuilder: (context, i) => WcEntrance(
                    token: _entranceToken('$seed'),
                    index: i,
                    child: _NovelCard(
                      seed: seed + i,
                      rank: ranked ? i + 1 : null,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _IllustCard extends StatelessWidget {
  const _IllustCard({required this.seed, this.rank});

  final int seed;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final tokens = WatercolorTokens.of(context)!;
    final r = math.Random(seed);
    final a = tokens.pigment(r.nextInt(5));
    final b = tokens.pigment(r.nextInt(5));
    return WcPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: Color.alphaBlend(
                      a.withValues(alpha: 0.18),
                      tokens.card,
                    ),
                  ),
                ),
                Positioned(
                  left: -20 + r.nextDouble() * 30,
                  top: 10 + r.nextDouble() * 30,
                  width: 150,
                  height: 110,
                  child: PigmentWash(
                    color: a,
                    opacity: 0.75,
                    shape: PigmentShape.wide,
                  ),
                ),
                Positioned(
                  right: -10 + r.nextDouble() * 20,
                  bottom: 6 + r.nextDouble() * 20,
                  width: 80,
                  height: 70,
                  child: PigmentWash(color: b, opacity: 0.7),
                ),
                if (rank != null)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: tokens.ink.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$rank',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: tokens.paper,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _illustTitles[seed.abs() % _illustTitles.length],
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: tokens.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _artists[r.nextInt(_artists.length)],
                  maxLines: 1,
                  style: TextStyle(fontSize: 11, color: tokens.sub),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NovelCard extends StatelessWidget {
  const _NovelCard({required this.seed, this.rank});

  final int seed;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final tokens = WatercolorTokens.of(context)!;
    final r = math.Random(seed);
    final pigment = tokens.pigment(r.nextInt(5));
    final tags = [
      _novelTags[r.nextInt(_novelTags.length)],
      _novelTags[r.nextInt(_novelTags.length)],
    ].toSet();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: WcPanel(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 62,
                height: 86,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(
                        color: Color.alphaBlend(
                          pigment.withValues(alpha: 0.22),
                          tokens.card,
                        ),
                      ),
                    ),
                    Positioned(
                      left: -14,
                      top: 14,
                      width: 90,
                      height: 60,
                      child: PigmentWash(
                        color: pigment,
                        opacity: 0.8,
                        shape: PigmentShape.wide,
                      ),
                    ),
                    if (rank != null)
                      Positioned(
                        left: 4,
                        top: 4,
                        child: Text(
                          '$rank',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: tokens.ink,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _novelTitles[seed.abs() % _novelTitles.length],
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: tokens.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _artists[r.nextInt(_artists.length)],
                    style: TextStyle(fontSize: 12, color: tokens.accent),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final tag in tags)
                        Text(
                          '#$tag',
                          style: TextStyle(fontSize: 12, color: tokens.sub),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${(r.nextInt(80) + 5) / 10} 万字 · ${r.nextInt(3000) + 100} 收藏',
                    style: TextStyle(fontSize: 11, color: tokens.sub),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchPage extends StatelessWidget {
  const _SearchPage({required this.section});

  final Section section;

  @override
  Widget build(BuildContext context) {
    final tokens = WatercolorTokens.of(context)!;
    final tags = section == Section.illust
        ? ['原神', '風景', 'オリジナル', '猫', '女の子', '夏', '百合', '水彩']
        : ['恋爱', '原创', '奇幻', '悬疑', '日常', '治愈', '百合', '短篇'];
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _PageHeader(
          title: section == Section.illust ? '搜索' : '搜索小说',
          pigment: _sectionPigment[section]!,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: tokens.card,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: tokens.line),
            ),
            child: Row(
              children: [
                WcIcon(Icons.search, size: 20, color: tokens.sub),
                const SizedBox(width: 10),
                Text(
                  section == Section.illust ? '搜索插画、用户或标签' : '搜索小说、作者或标签',
                  style: TextStyle(fontSize: 14, color: tokens.sub),
                ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 22, 20, 10),
          child: WcSectionLabel('热门标签'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < tags.length; i++)
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
                  decoration: BoxDecoration(
                    color: tokens.card,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: tokens.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: tokens.pigment(i),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        tags[i],
                        style: TextStyle(fontSize: 13, color: tokens.ink),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MorePage extends StatelessWidget {
  const _MorePage({
    required this.section,
    required this.onPush,
    required this.onSwitchSection,
  });

  final Section section;
  final ValueChanged<Widget> onPush;
  final ValueChanged<Section> onSwitchSection;

  @override
  Widget build(BuildContext context) {
    final tokens = WatercolorTokens.of(context)!;
    final other = section == Section.illust ? Section.novel : Section.illust;
    ListTile tile(
      IconData icon,
      int pigment,
      String title, {
      VoidCallback? onTap,
    }) {
      return ListTile(
        leading: WcListIcon(icon, pigment: pigment),
        title: Text(title),
        onTap:
            onTap ??
            () => onPush(_SubPage(title: title, icon: icon, pigment: pigment)),
      );
    }

    return ListView(
      padding: EdgeInsets.only(
        bottom:
            PaletteBar.height +
            PaletteBar.bottomGapFor(MediaQuery.paddingOf(context).bottom) +
            24,
      ),
      children: [
        _PageHeader(
          title: section == Section.illust ? '更多' : '设置',
          pigment: _sectionPigment[section]!,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              WcListGroup(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: tokens.pigment(4),
                    child: Text('M', style: TextStyle(color: tokens.onPigment)),
                  ),
                  title: const Text('Mizuki'),
                  subtitle: const Text('@mizuki'),
                ),
              ),
              WcListGroup(
                child: Column(
                  children: [
                    tile(
                      Icons.history,
                      1,
                      section == Section.illust ? '历史记录' : '阅读历史',
                    ),
                    tile(Icons.save_alt, 0, '任务进度'),
                    tile(Icons.bookmark, 3, '收藏标签'),
                    tile(Icons.block, 4, '屏蔽设置'),
                  ],
                ),
              ),
              WcListGroup(
                child: Column(
                  children: [
                    tile(
                      Icons.layers_outlined,
                      2,
                      '漫画',
                      onTap: () => onPush(const _MangaPage()),
                    ),
                    tile(
                      _sectionIcon(other),
                      3,
                      _sectionLabel(other),
                      onTap: () => onSwitchSection(other),
                    ),
                    tile(Icons.headphones, 4, '小说朗读'),
                    tile(Icons.message, 0, '关于'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MangaPage extends StatelessWidget {
  const _MangaPage();

  @override
  Widget build(BuildContext context) {
    final tokens = WatercolorTokens.of(context)!;
    return Scaffold(
      appBar: AppBar(title: const Text('漫画')),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 40),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 10,
          childAspectRatio: 0.62,
        ),
        itemCount: 18,
        itemBuilder: (context, i) {
          final r = math.Random(i * 31 + 7);
          final pigment = tokens.pigment(r.nextInt(5));
          return WcEntrance(
            token: _entranceToken('manga'),
            index: i,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: WcPanel(
                    padding: EdgeInsets.zero,
                    radius: 12,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ColoredBox(
                            color: Color.alphaBlend(
                              pigment.withValues(alpha: 0.2),
                              tokens.card,
                            ),
                          ),
                        ),
                        Positioned(
                          left: -10,
                          top: 20 + r.nextDouble() * 40,
                          width: 120,
                          height: 80,
                          child: PigmentWash(
                            color: pigment,
                            opacity: 0.8,
                            shape: PigmentShape.wide,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _illustTitles[(i * 5) % _illustTitles.length],
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.ink,
                  ),
                ),
                Text(
                  '第 ${r.nextInt(40) + 1} 话',
                  style: TextStyle(fontSize: 11, color: tokens.sub),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SubPage extends StatelessWidget {
  const _SubPage({
    required this.title,
    required this.icon,
    required this.pigment,
  });

  final String title;
  final IconData icon;
  final int pigment;

  @override
  Widget build(BuildContext context) {
    final tokens = WatercolorTokens.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 40),
        itemCount: 8,
        itemBuilder: (context, i) {
          final r = math.Random(title.hashCode + i);
          return WcEntrance(
            token: _entranceToken(title),
            index: i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: WcPanel(
                child: Row(
                  children: [
                    WcListIcon(icon, pigment: (pigment + i) % 5),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (i.isEven ? _illustTitles : _novelTitles)[r.nextInt(
                              8,
                            )],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: tokens.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${r.nextInt(23)}:${(r.nextInt(50) + 10)} · ${_artists[r.nextInt(_artists.length)]}',
                            style: TextStyle(fontSize: 12, color: tokens.sub),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Control panel

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.config,
    required this.onConfig,
    required this.onReplayHint,
  });

  final ProtoConfig config;
  final ValueChanged<ProtoConfig> onConfig;
  final VoidCallback onReplayHint;

  @override
  Widget build(BuildContext context) {
    final tokens = WatercolorTokens.of(context)!;
    Widget group(String label, Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [WcSectionLabel(label), const SizedBox(height: 8), child],
      ),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PigmentBackdrop(
            color: tokens.pigment(3),
            opacity: 0.5,
            shape: PigmentShape.wide,
            bleed: const EdgeInsets.fromLTRB(8, 2, 14, 0),
            child: Text(
              '下边栏长按快捷动作',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: tokens.ink,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'UI 原型 · 水彩主题',
            style: TextStyle(fontSize: 13, color: tokens.sub),
          ),
          const SizedBox(height: 20),
          WcPanel(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                group(
                  '长按「首页」',
                  WcSegmented(
                    labels: const ['散开菜单', '直达小说', '直达漫画'],
                    selected: config.homeLongPress.index,
                    onSelected: (i) => onConfig(
                      config.copyWith(homeLongPress: HomeLongPress.values[i]),
                    ),
                  ),
                ),
                group(
                  '第一个按钮显示',
                  WcSegmented(
                    labels: const ['当前分区', '「首页」'],
                    selected: config.showSectionOnHome ? 0 : 1,
                    onSelected: (i) =>
                        onConfig(config.copyWith(showSectionOnHome: i == 0)),
                  ),
                ),
                group(
                  '外观',
                  WcSegmented(
                    labels: const ['浅色', '深色'],
                    selected: config.dark ? 1 : 0,
                    onSelected: (i) => onConfig(config.copyWith(dark: i == 1)),
                  ),
                ),
                group(
                  '调色板',
                  WcSegmented(
                    labels: const ['多彩', '跟随主题色'],
                    selected: config.seedPalette ? 1 : 0,
                    onSelected: (i) =>
                        onConfig(config.copyWith(seedPalette: i == 1)),
                  ),
                ),
                group(
                  '动效',
                  WcSegmented(
                    labels: const ['标准', '减少动态'],
                    selected: config.reducedMotion ? 1 : 0,
                    onSelected: (i) =>
                        onConfig(config.copyWith(reducedMotion: i == 1)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OutlinedButton.icon(
                    onPressed: onReplayHint,
                    icon: const WcIcon(Icons.refresh, size: 18),
                    label: const Text('重置并显示新手提示'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const WcSectionLabel('怎么操作'),
          const SizedBox(height: 8),
          Text(
            '在右侧手机里长按任意下边栏按钮：按住不放滑到选项上松手即可直达；'
            '也可以直接松手，再点选项。点空白处收起。',
            style: TextStyle(fontSize: 13, height: 1.6, color: tokens.body),
          ),
          const SizedBox(height: 20),
          const WcSectionLabel('各按钮的快捷动作'),
          const SizedBox(height: 8),
          for (final section in Section.values) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: Text(
                '${_sectionLabel(section)}分区',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: tokens.ink,
                ),
              ),
            ),
            for (var tab = 0; tab < 5; tab++)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${_tabLabels(section)[tab]}　',
                        style: TextStyle(
                          color: tokens.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: _actionsFor(
                          section,
                          tab,
                        ).map((a) => a.label).join(' · '),
                      ),
                    ],
                  ),
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: tokens.body,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
