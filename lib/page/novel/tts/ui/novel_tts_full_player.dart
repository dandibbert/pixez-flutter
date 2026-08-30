import 'package:flutter/material.dart';
import 'package:pixez/page/novel/tts/playback/novel_tts_playback_controller.dart';

class NovelTtsFullPlayer extends StatelessWidget {
  const NovelTtsFullPlayer({super.key, required this.controller, this.onClose});
  final NovelTtsPlaybackController controller;
  final VoidCallback? onClose;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
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
                          item?.title ?? 'Novel narration',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        if (item != null) Text(item.author),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed:
                        onClose ?? () => Navigator.maybeOf(context)?.pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                item?.displayText ?? 'Preparing narration…',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (item != null)
                Text(
                  'Page ${item.pageNumber} · Part ${item.chunkIndex + 1}/${item.chunkCount}',
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
                    tooltip: 'Previous',
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
                    label: Text(snapshot.playing ? 'Pause' : 'Play'),
                  ),
                  IconButton(
                    tooltip: 'Next',
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
              const SizedBox(height: 16),
              Text(
                _stateLabel(snapshot),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    },
  );
  String _stateLabel(NovelTtsPlaybackSnapshot snapshot) =>
      switch (snapshot.state) {
        NovelTtsPlaybackState.idle => 'Idle',
        NovelTtsPlaybackState.preparing => 'Preparing audio',
        NovelTtsPlaybackState.buffering =>
          'Buffering ${snapshot.bufferedDuration.inSeconds}s',
        NovelTtsPlaybackState.playing => 'Playing',
        NovelTtsPlaybackState.paused => 'Paused',
        NovelTtsPlaybackState.completed => 'Completed',
        NovelTtsPlaybackState.failed => 'Playback failed',
      };
}
