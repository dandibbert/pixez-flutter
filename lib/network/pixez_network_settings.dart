import 'dart:io';

import 'package:pixez/er/hoster.dart';
import 'package:pixez/network/network_mode.dart';
import 'package:rhttp/rhttp.dart' as r;

class PixezNetworkSettings {
  static const appApiHost = 'app-api.pixiv.net';
  static const oauthHost = 'oauth.secure.pixiv.net';
  static const accountHost = 'accounts.pixiv.net';
  static const imageHost = 'i.pximg.net';
  static const imageStaticHost = 's.pximg.net';
  static const apiTimeoutSettings = r.TimeoutSettings(
    timeout: Duration(seconds: 45),
    connectTimeout: Duration(seconds: 15),
  );
  static const imageTimeoutSettings = r.TimeoutSettings(
    timeout: Duration(seconds: 90),
    connectTimeout: Duration(seconds: 15),
  );

  static r.ClientSettings? forHost(String host, NetworkMode mode) {
    if (mode == NetworkMode.standard) {
      return const r.ClientSettings(timeoutSettings: apiTimeoutSettings);
    }
    if (mode == NetworkMode.ech) {
      return r.ClientSettings(
        timeoutSettings: apiTimeoutSettings,
        enableEch: true,
        requireEch: true,
        tlsSettings: r.TlsSettings(
          verifyCertificates: true,
          rootCertSource: r.RootCertSource.webpki,
          sni: true,
        ),
        dnsSettings: r.DnsSettings.static(
          overrides: {
            appApiHost: ['104.18.10.118', '104.18.11.118'],
            oauthHost: ['104.18.10.118', '104.18.11.118'],
            accountHost: ['104.18.10.118', '104.18.11.118'],
          },
        ),
      );
    }
    return compatible();
  }

  static r.ClientSettings? forImages(String? host, NetworkMode mode) {
    if (mode == NetworkMode.standard || host != imageHost) {
      return const r.ClientSettings(timeoutSettings: imageTimeoutSettings);
    }
    return compatible(timeoutSettings: imageTimeoutSettings);
  }

  static r.ClientSettings compatible({
    r.TimeoutSettings timeoutSettings = apiTimeoutSettings,
  }) {
    return r.ClientSettings(
      timeoutSettings: timeoutSettings,
      tlsSettings: r.TlsSettings(verifyCertificates: false, sni: false),
      dnsSettings: r.DnsSettings.dynamic(
        resolver: (host) async {
          final ip = _compatibleIp(host);
          if (ip != null) return [ip];
          return await InternetAddress.lookup(
            host,
          ).then((value) => value.map((e) => e.address).toList());
        },
      ),
    );
  }

  static String? _compatibleIp(String host) {
    if (host == appApiHost) return Hoster.api();
    if (host == oauthHost) return Hoster.oauth();
    if (host == imageHost) return Hoster.iPximgNet();
    if (host == imageStaticHost) return Hoster.sPximgNet();
    return null;
  }
}
