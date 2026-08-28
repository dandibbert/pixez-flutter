import 'dart:io';

import 'package:flutter/services.dart';

class InstalledFonts {
  static const MethodChannel _channel = MethodChannel('com.perol.dev/fonts');

  static Future<List<String>> Function()? debugLister;
  static Future<Uint8List?> Function(String family)? debugFamilyLoader;
  static final Set<String> _registered = <String>{};

  static bool isUserInstalledFontPath(String path) {
    final lower = path.toLowerCase();
    if (lower.contains('/system/') || lower.contains('/usr/share')) {
      return false;
    }
    // macOS ships fonts in /Library/Fonts. iOS profile fonts live under
    // /var/mobile/Library/Fonts and must stay user-installed.
    if (lower.startsWith('/library/fonts/')) {
      return false;
    }
    return path.trim().isNotEmpty;
  }

  static Future<void> ensureRegistered(String family) async {
    final name = family.trim();
    if (name.isEmpty || _registered.contains(name)) {
      return;
    }
    try {
      if (debugLister != null && debugFamilyLoader == null) {
        _registered.add(name);
        return;
      }
      final raw = debugFamilyLoader != null
          ? await debugFamilyLoader!(name)
          : await _channel.invokeMethod<Uint8List>('loadFamily', name);
      if (raw == null || raw.isEmpty) {
        _registered.add(name);
        return;
      }
      final loader = FontLoader(name);
      loader.addFont(
        Future<ByteData>.value(
          ByteData.view(raw.buffer, raw.offsetInBytes, raw.lengthInBytes),
        ),
      );
      try {
        await loader.load();
      } catch (_) {
        // Flutter only allows a family to be registered once per process.
      }
      _registered.add(name);
    } catch (_) {}
  }

  static Future<List<String>> listFamilies() async {
    final override = debugLister;
    if (override != null) {
      return normalizeFamilies(await override());
    }
    if (Platform.isLinux) {
      return normalizeFamilies(await _listLinuxFamilies());
    }
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('listFamilies');
      return normalizeFamilies(
        (raw ?? const <dynamic>[]).map((item) => item.toString()),
      );
    } catch (_) {
      return const <String>[];
    }
  }

  static List<String> normalizeFamilies(Iterable<String> families) {
    final unique = <String>{};
    for (final family in families) {
      final name = family.trim();
      if (name.isEmpty || name.startsWith('@')) {
        continue;
      }
      unique.add(name);
    }
    final list = unique.toList();
    list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  static List<String> mergeSelected(List<String> families, String selected) {
    final name = selected.trim();
    if (name.isEmpty || families.contains(name)) {
      return families;
    }
    return <String>[name, ...families];
  }

  static List<String> filterFamilies(List<String> families, String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      return families;
    }
    return families.where((family) {
      final haystack = family.toLowerCase();
      return haystack.contains(needle) ||
          haystack.replaceFirst('pixez__', '').contains(needle);
    }).toList();
  }

  static Future<List<String>> _listLinuxFamilies() async {
    try {
      final result = await Process.run('fc-list', const <String>[':', 'family']);
      if (result.exitCode != 0) {
        return const <String>[];
      }
      final names = <String>[];
      for (final line in result.stdout.toString().split('\n')) {
        for (final part in line.split(',')) {
          names.add(part.trim());
        }
      }
      return names;
    } catch (_) {
      return const <String>[];
    }
  }
}
