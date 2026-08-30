import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pixez/page/novel/tts/model/tts_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class TtsSecretStore {
  Future<String?> read(String namespace, String name);
  Future<void> write(String namespace, String name, String value);
  Future<void> delete(String namespace, String name);
}

class FlutterSecureTtsSecretStore implements TtsSecretStore {
  const FlutterSecureTtsSecretStore([
    this.storage = const FlutterSecureStorage(),
  ]);
  final FlutterSecureStorage storage;
  String _key(String namespace, String name) => 'pixez.tts.$namespace.$name';
  @override
  Future<String?> read(String namespace, String name) =>
      storage.read(key: _key(namespace, name));
  @override
  Future<void> write(String namespace, String name, String value) =>
      storage.write(key: _key(namespace, name), value: value);
  @override
  Future<void> delete(String namespace, String name) =>
      storage.delete(key: _key(namespace, name));
}

class TtsSettingsSnapshot {
  const TtsSettingsSnapshot({
    this.profiles = const [],
    this.currentProfileId,
    this.targetLength = 220,
    this.maxLength = 360,
    this.startupBufferSeconds = 90,
    this.targetBufferSeconds = 180,
    this.autoNextPage = true,
    this.autoNextNovel = true,
    this.localPlaybackSpeed = 1,
  });
  final List<TtsProfile> profiles;
  final String? currentProfileId;
  final int targetLength;
  final int maxLength;
  final int startupBufferSeconds;
  final int targetBufferSeconds;
  final bool autoNextPage;
  final bool autoNextNovel;
  final double localPlaybackSpeed;
  TtsProfile? get currentProfile => profiles
      .where((profile) => profile.id == currentProfileId && profile.enabled)
      .firstOrNull;
  Map<String, dynamic> toJson() => {
    'schemaVersion': 2,
    'profiles': profiles.map((e) => e.toJson()).toList(),
    'currentProfileId': currentProfileId,
    'targetLength': targetLength,
    'maxLength': maxLength,
    'startupBufferSeconds': startupBufferSeconds,
    'targetBufferSeconds': targetBufferSeconds,
    'autoNextPage': autoNextPage,
    'autoNextNovel': autoNextNovel,
    'localPlaybackSpeed': localPlaybackSpeed,
  };
  factory TtsSettingsSnapshot.fromJson(
    Map<String, dynamic> json,
  ) => TtsSettingsSnapshot(
    profiles: (json['profiles'] as List? ?? const [])
        .map((e) => TtsProfile.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    currentProfileId: json['currentProfileId'] as String?,
    targetLength: json['targetLength'] as int? ?? 220,
    maxLength: json['maxLength'] as int? ?? 360,
    startupBufferSeconds: json['startupBufferSeconds'] as int? ?? 90,
    targetBufferSeconds: json['targetBufferSeconds'] as int? ?? 180,
    autoNextPage: json['autoNextPage'] as bool? ?? true,
    autoNextNovel: json['autoNextNovel'] as bool? ?? true,
    localPlaybackSpeed: (json['localPlaybackSpeed'] as num?)?.toDouble() ?? 1,
  );
}

class TtsSettingsRepository {
  TtsSettingsRepository({TtsSecretStore? secretStore})
    : secretStore = secretStore ?? const FlutterSecureTtsSecretStore();
  static const preferencesKey = 'novel_tts_settings_v2';
  final TtsSecretStore secretStore;
  Future<TtsSettingsSnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(preferencesKey);
    if (raw == null || raw.isEmpty) return const TtsSettingsSnapshot();
    return TtsSettingsSnapshot.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  }

  Future<void> save(TtsSettingsSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(preferencesKey, jsonEncode(snapshot.toJson()));
  }

  String _namespace(TtsProfile profile) =>
      profile.secretNamespace.isEmpty ? profile.id : profile.secretNamespace;
  Future<void> writeSecret(TtsProfile profile, String name, String value) =>
      secretStore.write(_namespace(profile), name, value);
  Future<void> deleteSecret(TtsProfile profile, String name) =>
      secretStore.delete(_namespace(profile), name);
  Future<Map<String, String>> readSecrets(TtsProfile profile) async {
    final names = <String>{
      'api_key',
      ...((profile.providerOptions['secretNames'] as List?)?.cast<String>() ??
          const <String>[]),
    };
    final values = <String, String>{};
    for (final name in names) {
      final value = await secretStore.read(_namespace(profile), name);
      if (value != null && value.isNotEmpty) values[name] = value;
    }
    return values;
  }
}
