enum NovelTtsTargetPlatform { android, ios, macos, windows, linux, web }

class NovelTtsPlatformCapabilities {
  const NovelTtsPlatformCapabilities({
    required this.audioPlayback,
    required this.backgroundMedia,
    required this.liveActivity,
  });

  final bool audioPlayback;
  final bool backgroundMedia;
  final bool liveActivity;

  factory NovelTtsPlatformCapabilities.forTarget(
    NovelTtsTargetPlatform target,
  ) {
    return switch (target) {
      NovelTtsTargetPlatform.ios => const NovelTtsPlatformCapabilities(
        audioPlayback: true,
        backgroundMedia: true,
        liveActivity: true,
      ),
      NovelTtsTargetPlatform.android => const NovelTtsPlatformCapabilities(
        audioPlayback: true,
        backgroundMedia: true,
        liveActivity: false,
      ),
      NovelTtsTargetPlatform.macos ||
      NovelTtsTargetPlatform.windows ||
      NovelTtsTargetPlatform.linux => const NovelTtsPlatformCapabilities(
        audioPlayback: true,
        backgroundMedia: false,
        liveActivity: false,
      ),
      NovelTtsTargetPlatform.web => const NovelTtsPlatformCapabilities(
        audioPlayback: false,
        backgroundMedia: false,
        liveActivity: false,
      ),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is NovelTtsPlatformCapabilities &&
        other.audioPlayback == audioPlayback &&
        other.backgroundMedia == backgroundMedia &&
        other.liveActivity == liveActivity;
  }

  @override
  int get hashCode => Object.hash(audioPlayback, backgroundMedia, liveActivity);
}
