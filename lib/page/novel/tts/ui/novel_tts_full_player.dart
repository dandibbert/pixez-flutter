import 'package:flutter/material.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/page/novel/tts/playback/novel_tts_playback_controller.dart';

class NovelTtsFullPlayer extends StatelessWidget {
  const NovelTtsFullPlayer({super.key, required this.controller, this.onClose});
  final NovelTtsPlaybackController controller;
  final VoidCallback? onClose;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final l10n = I18n.of(context);
      final snapshot = controller.snapshot;
      final item = snapshot.currentItem;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item?.title ?? l10n.tts_narration_title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (item != null) Text(item.author),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.tts_close,
                    onPressed:
                        onClose ?? () => Navigator.maybeOf(context)?.pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                item?.displayText ?? l10n.tts_preparing_narration,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (item != null)
                Text(
                  l10n.tts_page_part(
                    item.chunkCount,
                    item.pageNumber,
                    item.chunkIndex + 1,
                  ),
                ),
              Slider(
                value: snapshot.progress,
                onChanged: item == null
                    ? null
                    : (value) => controller.seek(
                        Duration(
                          milliseconds: (item.duration.inMilliseconds * value)
                              .round(),
                        ),
                      ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: l10n.tts_previous,
                    onPressed: item == null
                        ? null
                        : () => controller.skipTo(
                            ((snapshot.currentIndex ?? 0) - 1).clamp(
                              0,
                              snapshot.items.length - 1,
                            ),
                          ),
                    icon: const Icon(Icons.skip_previous),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: item == null
                        ? null
                        : () => snapshot.playing
                              ? controller.pause()
                              : controller.play(),
                    icon: Icon(
                      snapshot.playing ? Icons.pause : Icons.play_arrow,
                    ),
                    label: Text(
                      snapshot.playing ? l10n.tts_pause : l10n.tts_play,
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.next,
                    onPressed: item == null
                        ? null
                        : () => controller.skipTo(
                            ((snapshot.currentIndex ?? 0) + 1).clamp(
                              0,
                              snapshot.items.length - 1,
                            ),
                          ),
                    icon: const Icon(Icons.skip_next),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _NovelTtsSpeedControl(controller: controller),
              const SizedBox(height: 16),
              Text(
                _stateLabel(context, snapshot),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    },
  );
  String _stateLabel(BuildContext context, NovelTtsPlaybackSnapshot snapshot) {
    final l10n = I18n.of(context);
    return switch (snapshot.state) {
      NovelTtsPlaybackState.idle => l10n.tts_state_idle,
      NovelTtsPlaybackState.preparing => l10n.tts_state_preparing,
      NovelTtsPlaybackState.buffering => l10n.tts_state_buffering_seconds(
        snapshot.bufferedDuration.inSeconds,
      ),
      NovelTtsPlaybackState.playing => l10n.tts_state_playing,
      NovelTtsPlaybackState.paused => l10n.tts_state_paused,
      NovelTtsPlaybackState.completed => l10n.tts_state_completed,
      NovelTtsPlaybackState.failed => l10n.tts_state_failed,
    };
  }
}

class _NovelTtsSpeedControl extends StatefulWidget {
  const _NovelTtsSpeedControl({required this.controller});
  final NovelTtsPlaybackController controller;
  @override
  State<_NovelTtsSpeedControl> createState() => _NovelTtsSpeedControlState();
}

class _NovelTtsSpeedControlState extends State<_NovelTtsSpeedControl> {
  double speed = 1;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Icon(Icons.speed),
      Expanded(
        child: Slider(
          min: 0.5,
          max: 2,
          divisions: 15,
          value: speed,
          label: '${speed.toStringAsFixed(1)}×',
          onChanged: (value) {
            setState(() => speed = value);
            widget.controller.setSpeed(value);
          },
        ),
      ),
      SizedBox(width: 44, child: Text('${speed.toStringAsFixed(1)}×')),
    ],
  );
}
