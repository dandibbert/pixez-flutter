import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:material_ui/material_ui.dart';
import 'package:pixez/page/novel/tts/novel_tts_settings.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/page/novel/tts/novel_tts_controller.dart';
import 'package:pixez/page/novel/tts/novel_tts_page.dart';
import 'package:pixez/watercolor/mingcute.dart';
import 'package:pixez/watercolor/watercolor_ink_ring.dart';
import 'package:pixez/watercolor/watercolor_tokens.dart';
import 'package:pixez/watercolor/watercolor_motion.dart';

const Key novelTtsQuickVoiceKey = Key('novelTtsQuickVoice');
const Key novelTtsBarKey = Key('novelTtsBar');
const Key novelTtsPlayButtonKey = Key('novelTtsPlayButton');
const Key novelTtsPauseButtonKey = Key('novelTtsPauseButton');
const Key novelTtsStopButtonKey = Key('novelTtsStopButton');
const Key novelTtsNextButtonKey = Key('novelTtsNextButton');
const Key novelTtsPrevButtonKey = Key('novelTtsPrevButton');
const Key novelTtsSubtitleKey = Key('novelTtsSubtitle');
const Key novelTtsAddReadingFromBarKey = Key('novelTtsAddReadingFromBar');

class NovelTtsBar extends StatelessWidget {
  const NovelTtsBar({
    super.key,
    required this.controller,
    required this.onOpenSettings,
    this.onSubtitleTap,
    this.onAddReading,
  });

  final NovelTtsController controller;
  final VoidCallback onOpenSettings;
  final VoidCallback? onSubtitleTap;

  /// Opens the pronunciation dialog for the sentence being spoken.
  final VoidCallback? onAddReading;

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final session = controller.session;
    final subtitle = controller.subtitle;
    final statusLabel = switch (controller.status) {
      NovelTtsStatus.synthesizing => i18n.novel_tts_synthesizing,
      NovelTtsStatus.playing => i18n.novel_tts_playing,
      NovelTtsStatus.paused => i18n.novel_tts_pause,
      NovelTtsStatus.error =>
        controller.errorMessage == 'not_configured'
            ? i18n.novel_tts_not_configured
            : controller.errorMessage == 'empty'
            ? i18n.novel_tts_empty
            : i18n.novel_tts_error,
      NovelTtsStatus.idle => '',
    };
    final tokens = WatercolorTokens.of(context);
    if (tokens != null) {
      return _buildWatercolor(context, tokens, statusLabel);
    }
    final bar = Material(
      key: novelTtsBarKey,
      color: tokens?.card ?? scheme.surfaceContainerHigh,
      shape: tokens == null
          ? null
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: tokens.line),
            ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (session != null)
              Text(
                '${session.title} · ${session.page}/${session.totalPages}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            if (subtitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: InkWell(
                  key: novelTtsSubtitleKey,
                  onTap: onSubtitleTap,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ),
            if (statusLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  statusLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: controller.status == NovelTtsStatus.error
                        ? scheme.error
                        : tokens?.accent ?? scheme.primary,
                    fontWeight: tokens == null ? null : FontWeight.w700,
                  ),
                ),
              ),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              children: [
                IconButton(
                  key: novelTtsPrevButtonKey,
                  tooltip: i18n.novel_tts_prev,
                  onPressed: () => controller.skip(direction: 'prev'),
                  icon: const WcIcon(Icons.skip_previous),
                ),
                if (controller.status == NovelTtsStatus.playing ||
                    controller.status == NovelTtsStatus.synthesizing)
                  _wellButton(
                    tokens,
                    IconButton(
                      key: novelTtsPauseButtonKey,
                      tooltip: i18n.novel_tts_pause,
                      onPressed: controller.pause,
                      icon: WcIcon(
                        tokens == null
                            ? Icons.pause_circle_filled
                            : Icons.pause,
                        color: tokens?.onPigment,
                      ),
                    ),
                  )
                else
                  _wellButton(
                    tokens,
                    IconButton(
                      key: novelTtsPlayButtonKey,
                      tooltip: controller.status == NovelTtsStatus.paused
                          ? i18n.novel_tts_resume
                          : i18n.novel_tts_play,
                      onPressed: controller.status == NovelTtsStatus.paused
                          ? controller.resume
                          : null,
                      icon: WcIcon(
                        tokens == null
                            ? Icons.play_circle_filled
                            : Icons.play_arrow,
                        color: tokens?.onPigment,
                      ),
                    ),
                  ),
                IconButton(
                  key: novelTtsNextButtonKey,
                  tooltip: i18n.novel_tts_next,
                  onPressed: () => controller.skip(direction: 'next'),
                  icon: const WcIcon(Icons.skip_next),
                ),
                IconButton(
                  key: novelTtsStopButtonKey,
                  tooltip: i18n.novel_tts_stop,
                  onPressed: controller.stop,
                  icon: const WcIcon(Icons.stop),
                ),
                IconButton(
                  key: novelTtsQuickVoiceKey,
                  tooltip: i18n.novel_tts_quick_voice,
                  onPressed: () => _selectVoice(context),
                  icon: const WcIcon(Icons.record_voice_over_outlined),
                ),
                if (onAddReading != null && controller.currentClip != null)
                  IconButton(
                    key: novelTtsAddReadingFromBarKey,
                    tooltip: i18n.novel_tts_reading_add_current,
                    onPressed: onAddReading,
                    icon: const WcIcon(Icons.spellcheck),
                  ),
                IconButton(
                  tooltip: i18n.novel_tts_settings,
                  onPressed: onOpenSettings,
                  icon: const WcIcon(Icons.tune),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (tokens == null) return bar;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: tokens.cardShadow,
        ),
        child: bar,
      ),
    );
  }

  /// The watercolor bar: a wave and status line, the spoken sentence, and a
  /// row of hand-inked ring buttons with the play button on a pigment wash.
  Widget _buildWatercolor(
    BuildContext context,
    WatercolorTokens tokens,
    String statusLabel,
  ) {
    final i18n = I18n.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final session = controller.session;
    final subtitle = controller.subtitle;
    final status = controller.status;
    final speaking =
        status == NovelTtsStatus.playing ||
        status == NovelTtsStatus.synthesizing;
    final neutral = Color.lerp(tokens.line, tokens.sub, 0.18)!;
    final sand = Color.lerp(tokens.pigment(1), const Color(0xFFEBD3A8), 0.6)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: tokens.cardShadow,
        ),
        child: Material(
          key: novelTtsBarKey,
          color: tokens.card,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: tokens.line),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -30,
                top: -30,
                width: 200,
                height: 90,
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _WashBlobPainter(
                      tokens.pigment(4).withValues(alpha: 0.28),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        InkWaveBars(color: tokens.liked, active: speaking),
                        if (statusLabel.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            statusLabel,
                            style: textTheme.labelMedium?.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: status == NovelTtsStatus.error
                                  ? scheme.error
                                  : tokens.accent,
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Expanded(
                          child: session == null
                              ? const SizedBox.shrink()
                              : Text(
                                  '${session.title} · ${session.page}/${session.totalPages}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: textTheme.labelMedium?.copyWith(
                                    fontSize: 12,
                                    color: tokens.sub,
                                  ),
                                ),
                        ),
                      ],
                    ),
                    if (subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: InkWell(
                          key: novelTtsSubtitleKey,
                          onTap: onSubtitleTap,
                          borderRadius: BorderRadius.circular(6),
                          child: Text(
                            subtitle,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyMedium?.copyWith(
                              fontSize: 14,
                              height: 1.6,
                              color: tokens.ink,
                            ),
                          ),
                        ),
                      ),
                    SizedBox(
                      height: 64,
                      child: _fitRow(
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkRingButton(
                              key: novelTtsPrevButtonKey,
                              tooltip: i18n.novel_tts_prev,
                              pigment: tokens.pigment(1),
                              onPressed: () =>
                                  controller.skip(direction: 'prev'),
                              icon: const WcIcon(Icons.skip_previous),
                            ),
                            if (speaking)
                              InkRingButton(
                                key: novelTtsPauseButtonKey,
                                main: true,
                                tooltip: i18n.novel_tts_pause,
                                pigment: tokens.pigment(0),
                                onPressed: controller.pause,
                                icon: const WcIcon(Icons.pause, filled: true),
                              )
                            else
                              InkRingButton(
                                key: novelTtsPlayButtonKey,
                                main: true,
                                tooltip: status == NovelTtsStatus.paused
                                    ? i18n.novel_tts_resume
                                    : i18n.novel_tts_play,
                                pigment: tokens.pigment(0),
                                onPressed: status == NovelTtsStatus.paused
                                    ? controller.resume
                                    : null,
                                icon: const WcIcon(
                                  Icons.play_arrow,
                                  filled: true,
                                ),
                              ),
                            InkRingButton(
                              key: novelTtsNextButtonKey,
                              tooltip: i18n.novel_tts_next,
                              pigment: tokens.pigment(2),
                              onPressed: () =>
                                  controller.skip(direction: 'next'),
                              icon: const WcIcon(Icons.skip_next),
                            ),
                            InkRingButton(
                              key: novelTtsStopButtonKey,
                              tooltip: i18n.novel_tts_stop,
                              pigment: neutral,
                              onPressed: controller.stop,
                              icon: const WcIcon(Icons.stop),
                            ),
                            InkRingButton(
                              key: novelTtsQuickVoiceKey,
                              tooltip: i18n.novel_tts_quick_voice,
                              pigment: tokens.pigment(3),
                              onPressed: () => _selectVoice(context),
                              icon: const WcIcon(
                                Icons.record_voice_over_outlined,
                              ),
                            ),
                            if (onAddReading != null &&
                                controller.currentClip != null)
                              InkRingButton(
                                key: novelTtsAddReadingFromBarKey,
                                tooltip: i18n.novel_tts_reading_add_current,
                                pigment: tokens.pigment(4),
                                onPressed: onAddReading,
                                icon: const WcIcon(Icons.spellcheck),
                              ),
                            InkRingButton(
                              tooltip: i18n.novel_tts_settings,
                              pigment: sand,
                              onPressed: onOpenSettings,
                              icon: const WcIcon(Icons.tune),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Keeps the button row on one line, shrinking it on very narrow screens.
  Widget _fitRow(Row row) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final needed = (row.children.length - 1) * 44.0 + 58;
        if (constraints.maxWidth >= needed) return row;
        return FittedBox(
          child: SizedBox(width: needed, child: row),
        );
      },
    );
  }

  /// In the watercolor style the play button sits in a pigment-filled well.
  Widget _wellButton(WatercolorTokens? tokens, Widget button) {
    if (tokens == null) return button;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: tokens.pigment(0).withValues(alpha: 0.85),
        border: Border.all(color: tokens.ink, width: 1.5),
      ),
      child: Center(child: button),
    );
  }

  Future<void> _selectVoice(BuildContext context) async {
    final settings = controller.settings;
    final i18n = I18n.of(context);
    final selected = await showModalBottomSheet<NovelTtsVoicePreset>(
      sheetAnimationStyle: WcMotion.sheet(context),
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                i18n.novel_tts_quick_voice,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (settings.activeVoicePresets.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(i18n.novel_tts_no_saved_voices),
                ),
              for (final preset in settings.activeVoicePresets)
                ListTile(
                  title: Text(preset.name),
                  subtitle: preset.voice.isEmpty ? null : Text(preset.voice),
                  leading: Icon(
                    settings.isVoicePresetSelected(preset)
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  onTap: () => Navigator.pop(context, preset),
                ),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onOpenSettings();
                },
                icon: const WcIcon(Icons.tune),
                label: Text(i18n.novel_tts_settings),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null) return;
    await controller.settings.selectVoicePreset(selected).save();
    await controller.applySettings();
  }
}

Future<void> openNovelTtsSettings(BuildContext context) {
  final fluentTheme = context
      .findAncestorWidgetOfExactType<fluent.FluentTheme>();
  final theme = fluentTheme == null
      ? Theme.of(context)
      : ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: fluentTheme.data.accentColor.normal,
            brightness: fluentTheme.data.brightness,
          ),
        );
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => Theme(data: theme, child: const NovelTtsPage()),
    ),
  );
}

/// A soft pigment blot bleeding off the bar's corner.
class _WashBlobPainter extends CustomPainter {
  const _WashBlobPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawOval(
      Rect.fromCenter(
        center: size.center(Offset.zero),
        width: size.width * 0.8,
        height: size.height * 0.75,
      ),
      Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  @override
  bool shouldRepaint(_WashBlobPainter old) => old.color != color;
}
