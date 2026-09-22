import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:material_ui/material_ui.dart';
import 'package:pixez/page/novel/tts/novel_tts_settings.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/page/novel/tts/novel_tts_controller.dart';
import 'package:pixez/page/novel/tts/novel_tts_page.dart';

const Key novelTtsQuickVoiceKey = Key('novelTtsQuickVoice');
const Key novelTtsBarKey = Key('novelTtsBar');
const Key novelTtsPlayButtonKey = Key('novelTtsPlayButton');
const Key novelTtsPauseButtonKey = Key('novelTtsPauseButton');
const Key novelTtsStopButtonKey = Key('novelTtsStopButton');
const Key novelTtsNextButtonKey = Key('novelTtsNextButton');
const Key novelTtsPrevButtonKey = Key('novelTtsPrevButton');
const Key novelTtsSubtitleKey = Key('novelTtsSubtitle');

class NovelTtsBar extends StatelessWidget {
  const NovelTtsBar({
    super.key,
    required this.controller,
    required this.onOpenSettings,
    this.onSubtitleTap,
  });

  final NovelTtsController controller;
  final VoidCallback onOpenSettings;
  final VoidCallback? onSubtitleTap;

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
    return Material(
      key: novelTtsBarKey,
      color: scheme.surfaceContainerHigh,
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
                        : scheme.primary,
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
                  icon: const Icon(Icons.skip_previous),
                ),
                if (controller.status == NovelTtsStatus.playing ||
                    controller.status == NovelTtsStatus.synthesizing)
                  IconButton(
                    key: novelTtsPauseButtonKey,
                    tooltip: i18n.novel_tts_pause,
                    onPressed: controller.pause,
                    icon: const Icon(Icons.pause_circle_filled),
                  )
                else
                  IconButton(
                    key: novelTtsPlayButtonKey,
                    tooltip: controller.status == NovelTtsStatus.paused
                        ? i18n.novel_tts_resume
                        : i18n.novel_tts_play,
                    onPressed: controller.status == NovelTtsStatus.paused
                        ? controller.resume
                        : null,
                    icon: const Icon(Icons.play_circle_filled),
                  ),
                IconButton(
                  key: novelTtsNextButtonKey,
                  tooltip: i18n.novel_tts_next,
                  onPressed: () => controller.skip(direction: 'next'),
                  icon: const Icon(Icons.skip_next),
                ),
                IconButton(
                  key: novelTtsStopButtonKey,
                  tooltip: i18n.novel_tts_stop,
                  onPressed: controller.stop,
                  icon: const Icon(Icons.stop),
                ),
                IconButton(
                  key: novelTtsQuickVoiceKey,
                  tooltip: i18n.novel_tts_quick_voice,
                  onPressed: () => _selectVoice(context),
                  icon: const Icon(Icons.record_voice_over_outlined),
                ),
                IconButton(
                  tooltip: i18n.novel_tts_settings,
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.tune),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectVoice(BuildContext context) async {
    final settings = controller.settings;
    final i18n = I18n.of(context);
    final selected = await showModalBottomSheet<NovelTtsVoicePreset>(
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
                icon: const Icon(Icons.tune),
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
