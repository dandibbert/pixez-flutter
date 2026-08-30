import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/page/novel/tts/playback/novel_tts_platform_capabilities.dart';

void main() {
  group('NovelTtsPlatformCapabilities', () {
    test('enables full background media only on mobile targets', () {
      expect(
        NovelTtsPlatformCapabilities.forTarget(NovelTtsTargetPlatform.ios),
        const NovelTtsPlatformCapabilities(
          audioPlayback: true,
          backgroundMedia: true,
          liveActivity: true,
        ),
      );
      expect(
        NovelTtsPlatformCapabilities.forTarget(
          NovelTtsTargetPlatform.android,
        ),
        const NovelTtsPlatformCapabilities(
          audioPlayback: true,
          backgroundMedia: true,
          liveActivity: false,
        ),
      );
    });

    test('desktop targets compile with explicit foreground-only fallback', () {
      for (final target in <NovelTtsTargetPlatform>[
        NovelTtsTargetPlatform.macos,
        NovelTtsTargetPlatform.windows,
        NovelTtsTargetPlatform.linux,
      ]) {
        expect(
          NovelTtsPlatformCapabilities.forTarget(target),
          const NovelTtsPlatformCapabilities(
            audioPlayback: true,
            backgroundMedia: false,
            liveActivity: false,
          ),
        );
      }
    });

    test('web disables file-backed remote TTS playback', () {
      expect(
        NovelTtsPlatformCapabilities.forTarget(NovelTtsTargetPlatform.web),
        const NovelTtsPlatformCapabilities(
          audioPlayback: false,
          backgroundMedia: false,
          liveActivity: false,
        ),
      );
    });
  });
}
