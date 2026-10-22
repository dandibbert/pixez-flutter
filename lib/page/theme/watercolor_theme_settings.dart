import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/main.dart';
import 'package:pixez/store/user_setting.dart';
import 'package:pixez/utils/haptic_util.dart';
import 'package:pixez/watercolor/watercolor_motion.dart';
import 'package:pixez/watercolor/watercolor_tokens.dart';
import 'package:pixez/watercolor/watercolor_widgets.dart';
import 'package:pixez/watercolor/mingcute.dart';

/// Seed presets of the theme-color palette, as hue and saturation; the seed
/// itself is that hue at 60% lightness.
const List<(double, double)> _presets = [
  (341, 0.95),
  (20, 0.85),
  (45, 0.78),
  (98, 0.34),
  (168, 0.45),
  (208, 0.62),
  (262, 0.52),
  (25, 0.08),
];

Color _seedOf(double hue, double saturation) =>
    HSLColor.fromAHSL(1, hue, saturation, 0.6).toColor();

/// The theme page body of the watercolor style: dark mode, AMOLED, interface
/// style and palette.
class WatercolorThemeSettings extends StatefulWidget {
  const WatercolorThemeSettings({super.key});

  @override
  State<WatercolorThemeSettings> createState() =>
      _WatercolorThemeSettingsState();
}

class _WatercolorThemeSettingsState extends State<WatercolorThemeSettings> {
  late bool _custom;
  late double _hue;
  late double _saturation;

  @override
  void initState() {
    super.initState();
    final hsl = HSLColor.fromColor(userSetting.seedColor);
    _hue = hsl.hue;
    _saturation = hsl.saturation;
    _custom = _presetIndex(userSetting.seedColor) == null;
  }

  int? _presetIndex(Color seed) {
    for (var i = 0; i < _presets.length; i++) {
      if (_seedOf(_presets[i].$1, _presets[i].$2).toARGB32() ==
          seed.toARGB32()) {
        return i;
      }
    }
    return null;
  }

  Future<void> _setSeed(Color seed) async {
    await userSetting.setThemeData(seed);
    topStore.setTop("main");
  }

  @override
  Widget build(BuildContext context) {
    final tokens = WatercolorTokens.of(context)!;
    final i18n = I18n.of(context);
    return Observer(
      builder: (context) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            6,
            16,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            WcSegmented(
              labels: [i18n.system, i18n.light, i18n.dark],
              selected: ThemeMode.values.indexOf(userSetting.themeMode),
              onSelected: (i) {
                HapticUtil.selectionClick();
                userSetting.setThemeMode(i);
              },
            ),
            AnimatedSize(
              duration: WcMotion.medium,
              curve: WcMotion.standard,
              child: dark
                  ? Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: WcPanel(
                        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: userSetting.isAMOLED,
                          onChanged: (v) {
                            HapticUtil.light();
                            userSetting.setIsAMOLED(v);
                          },
                          title: Text(
                            i18n.amoled_black,
                            style: TextStyle(fontSize: 15, color: tokens.ink),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            const SizedBox(height: 18),
            WcSectionLabel(i18n.ui_style),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _StyleCard(
                    style: UiStyle.watercolor,
                    name: i18n.ui_style_watercolor,
                    description: i18n.ui_style_watercolor_desc,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StyleCard(
                    style: UiStyle.classic,
                    name: i18n.ui_style_classic,
                    description: i18n.ui_style_classic_desc,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            WcSectionLabel(i18n.palette),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final (mode, label) in [
                  (WatercolorPaletteMode.multi, i18n.palette_multi),
                  (WatercolorPaletteMode.seed, i18n.palette_seed),
                  (WatercolorPaletteMode.dynamic, i18n.palette_dynamic),
                ]) ...[
                  if (mode != WatercolorPaletteMode.multi)
                    const SizedBox(width: 8),
                  Expanded(
                    child: _PalettePill(
                      label: label,
                      selected: userSetting.paletteMode == mode,
                      onTap: () async {
                        HapticUtil.selectionClick();
                        await userSetting.setPaletteMode(mode);
                        topStore.setTop("main");
                      },
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: WcMotion.medium,
              switchInCurve: WcMotion.standard,
              switchOutCurve: WcMotion.standard,
              child: KeyedSubtree(
                key: ValueKey(userSetting.paletteMode),
                child: switch (userSetting.paletteMode) {
                  WatercolorPaletteMode.multi => _buildMulti(context),
                  WatercolorPaletteMode.seed => _buildSeed(context),
                  WatercolorPaletteMode.dynamic => _buildDynamic(context),
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMulti(BuildContext context) {
    final tokens = WatercolorTokens.of(context)!;
    final i18n = I18n.of(context);
    final labels = [
      i18n.home,
      i18n.rank,
      i18n.quick_view,
      i18n.search,
      i18n.more,
    ];
    return WcPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < labels.length; i++)
                Column(
                  children: [
                    SizedBox(
                      width: 40,
                      height: 30,
                      child: PigmentWash(color: tokens.pigment(i), opacity: 1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      labels[i],
                      style: TextStyle(fontSize: 11, color: tokens.sub),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            i18n.palette_multi_desc,
            style: TextStyle(fontSize: 12, color: tokens.sub),
          ),
        ],
      ),
    );
  }

  Widget _buildDabs(BuildContext context) {
    final tokens = WatercolorTokens.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final pigment in tokens.pigments)
            SizedBox(
              width: 36,
              height: 22,
              child: PigmentWash(color: pigment, opacity: 1),
            ),
        ],
      ),
    );
  }

  Widget _buildSeed(BuildContext context) {
    final tokens = WatercolorTokens.of(context)!;
    final i18n = I18n.of(context);
    final names = [
      i18n.preset_sakura,
      i18n.preset_peach,
      i18n.preset_lemon,
      i18n.preset_matcha,
      i18n.preset_mint,
      i18n.preset_cerulean,
      i18n.preset_lavender,
      i18n.preset_ink,
    ];
    final selected = _custom ? null : _presetIndex(userSetting.seedColor);
    final seed = _seedOf(_hue, _saturation);
    return WcPanel(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GridView.count(
            crossAxisCount: 5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 2,
            childAspectRatio: 0.85,
            children: [
              for (var i = 0; i < _presets.length; i++)
                _SwatchButton(
                  label: names[i],
                  selected: selected == i,
                  swatch: PigmentWash(
                    color: HSLColor.fromAHSL(
                      1,
                      _presets[i].$1,
                      _presets[i].$2.clamp(0, 0.62),
                      tokens.isDark ? 0.56 : 0.72,
                    ).toColor(),
                    opacity: 1,
                  ),
                  onTap: () {
                    HapticUtil.selectionClick();
                    setState(() {
                      _custom = false;
                      _hue = _presets[i].$1;
                      _saturation = _presets[i].$2;
                    });
                    _setSeed(_seedOf(_presets[i].$1, _presets[i].$2));
                  },
                ),
              _SwatchButton(
                label: i18n.palette_custom,
                selected: _custom,
                swatch: const _HueRing(),
                onTap: () {
                  HapticUtil.selectionClick();
                  setState(() => _custom = true);
                },
              ),
            ],
          ),
          AnimatedSize(
            duration: WcMotion.medium,
            curve: WcMotion.standard,
            child: !_custom
                ? const SizedBox(width: double.infinity)
                : Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.only(top: 10),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: tokens.line)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${i18n.hue} ${_hue.round()}°',
                          style: TextStyle(fontSize: 12, color: tokens.sub),
                        ),
                        Slider(
                          value: _hue,
                          max: 360,
                          onChanged: (v) => setState(() => _hue = v),
                          onChangeEnd: (_) => _setSeed(seed),
                        ),
                        Text(
                          '${i18n.pigment_strength} ${(_saturation * 100).round()}%',
                          style: TextStyle(fontSize: 12, color: tokens.sub),
                        ),
                        Slider(
                          value: _saturation,
                          onChanged: (v) => setState(() => _saturation = v),
                          onChangeEnd: (_) => _setSeed(seed),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: seed,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: tokens.line),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '#${(seed.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: tokens.ink,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              i18n.derived_pigments,
                              style: TextStyle(fontSize: 11, color: tokens.sub),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          _buildDabs(context),
        ],
      ),
    );
  }

  Widget _buildDynamic(BuildContext context) {
    final tokens = WatercolorTokens.of(context)!;
    return WcPanel(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [tokens.pigment(3), tokens.pigment(1)],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  I18n.of(context).palette_dynamic_desc,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: tokens.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildDabs(context),
        ],
      ),
    );
  }
}

class _StyleCard extends StatelessWidget {
  const _StyleCard({
    required this.style,
    required this.name,
    required this.description,
  });

  final UiStyle style;
  final String name;
  final String description;

  @override
  Widget build(BuildContext context) {
    final tokens = WatercolorTokens.of(context)!;
    final selected = userSetting.uiStyle == style;
    final watercolor = style == UiStyle.watercolor;
    final previewBg = watercolor
        ? (tokens.isDark ? const Color(0xFF2E2925) : const Color(0xFFF4EEE4))
        : (tokens.isDark ? const Color(0xFF211F26) : const Color(0xFFF7F2FA));
    final previewCard = watercolor
        ? tokens.card
        : (tokens.isDark ? const Color(0xFF36343B) : const Color(0xFFEADDEA));
    final dots = watercolor
        ? tokens.pigments
        : [
            const Color(0xFFE8B4C8),
            for (var i = 0; i < 4; i++) const Color(0xFF9E96A0),
          ];
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticUtil.selectionClick();
          userSetting.setUiStyle(style);
        },
        child: AnimatedContainer(
          duration: WcMotion.medium,
          curve: WcMotion.standard,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: tokens.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? tokens.ink : tokens.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 70,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: previewBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        for (var i = 0; i < 2; i++)
                          Container(
                            width: 46,
                            height: 30,
                            margin: const EdgeInsets.fromLTRB(2, 2, 4, 0),
                            decoration: BoxDecoration(
                              color: previewCard,
                              borderRadius: BorderRadius.circular(
                                watercolor ? 8 : 4,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: watercolor ? tokens.card : previewCard,
                        borderRadius: BorderRadius.circular(
                          watercolor ? 10 : 0,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          for (var i = 0; i < dots.length; i++)
                            Container(
                              width: i == 0 ? 18 : 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: dots[i],
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: tokens.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: tokens.sub),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PalettePill extends StatelessWidget {
  const _PalettePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = WatercolorTokens.of(context)!;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: WcMotion.medium,
          curve: WcMotion.standard,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? tokens.card : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? tokens.ink : tokens.line,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: tokens.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _SwatchButton extends StatelessWidget {
  const _SwatchButton({
    required this.label,
    required this.selected,
    required this.swatch,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Widget swatch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = WatercolorTokens.of(context)!;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            SizedBox(
              width: 44,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      child: swatch,
                    ),
                  ),
                  if (selected) ...[
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          shape: OvalBorder(
                            side: BorderSide(color: tokens.ink, width: 1.6),
                          ),
                        ),
                      ),
                    ),
                    WcIcon(Icons.check, size: 18, color: tokens.onPigment),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
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
    );
  }
}

/// The custom swatch: a ring of hues.
class _HueRing extends StatelessWidget {
  const _HueRing();

  @override
  Widget build(BuildContext context) {
    final tokens = WatercolorTokens.of(context)!;
    return Center(
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: [
              for (var h = 0; h <= 360; h += 60)
                HSLColor.fromAHSL(1, h % 360, 0.7, 0.72).toColor(),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tokens.card,
            ),
          ),
        ),
      ),
    );
  }
}
