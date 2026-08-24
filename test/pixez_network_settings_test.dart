import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/network/network_mode.dart';
import 'package:pixez/network/pixez_network_settings.dart';

void main() {
  test('API clients always have bounded request timeouts', () {
    for (final mode in NetworkMode.values) {
      final settings = PixezNetworkSettings.forHost(
        PixezNetworkSettings.appApiHost,
        mode,
      );
      expect(
        settings?.timeoutSettings?.connectTimeout,
        const Duration(seconds: 15),
      );
      expect(settings?.timeoutSettings?.timeout, const Duration(seconds: 45));
    }
  });

  test(
    'image clients allow longer transfers but keep connect time bounded',
    () {
      for (final mode in NetworkMode.values) {
        final settings = PixezNetworkSettings.forImages(
          PixezNetworkSettings.imageHost,
          mode,
        );
        expect(
          settings?.timeoutSettings?.connectTimeout,
          const Duration(seconds: 15),
        );
        expect(settings?.timeoutSettings?.timeout, const Duration(seconds: 90));
      }
    },
  );
}
