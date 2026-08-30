import 'package:flutter/material.dart';

class NovelTtsMiniPlayer extends StatelessWidget {
  const NovelTtsMiniPlayer({
    super.key,
    required this.displayText,
    required this.statusText,
    required this.pageAndChunkText,
    required this.playing,
    required this.buffering,
    required this.onTogglePlayback,
    required this.onOpen,
    required this.onClose,
  });

  final String displayText;
  final String statusText;
  final String pageAndChunkText;
  final bool playing;
  final bool buffering;
  final VoidCallback onTogglePlayback;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 4,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
          child: Row(
            children: [
              IconButton.filledTonal(
                tooltip: playing ? 'Pause TTS' : 'Play TTS',
                onPressed: onTogglePlayback,
                icon: buffering
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(playing ? Icons.pause : Icons.play_arrow),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayText.isEmpty ? 'Preparing narration…' : displayText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            pageAndChunkText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                        Text(
                          statusText,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: buffering ? scheme.tertiary : scheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close TTS',
                onPressed: onClose,
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
