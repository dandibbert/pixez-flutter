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
    this.maxCacheMegabytes = 512,
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
  final int maxCacheMegabytes;
  final bool autoNextPage;
  final bool autoNextNovel;
  final double localPlaybackSpeed;
  TtsSettingsSnapshot copyWith({
    List<TtsProfile>? profiles,
    String? currentProfileId,
    int? targetLength,
    int? maxLength,
    int? startupBufferSeconds,
    int? targetBufferSeconds,
    int? maxCacheMegabytes,
    bool? autoNextPage,
    bool? autoNextNovel,
    double? localPlaybackSpeed,
  }) => TtsSettingsSnapshot(
    profiles: profiles ?? this.profiles,
    currentProfileId: currentProfileId ?? this.currentProfileId,
    targetLength: targetLength ?? this.targetLength,
    maxLength: maxLength ?? this.maxLength,
    startupBufferSeconds: startupBufferSeconds ?? this.startupBufferSeconds,
    targetBufferSeconds: targetBufferSeconds ?? this.targetBufferSeconds,
    maxCacheMegabytes: maxCacheMegabytes ?? this.maxCacheMegabytes,
    autoNextPage: autoNextPage ?? this.autoNextPage,
    autoNextNovel: autoNextNovel ?? this.autoNextNovel,
    localPlaybackSpeed: localPlaybackSpeed ?? this.localPlaybackSpeed,
  );

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
    'maxCacheMegabytes': maxCacheMegabytes,
    'autoNextPage': autoNextPage,
    'autoNextNovel': autoNextNovel,
    'localPlaybackSpeed': localPlaybackSpeed,
  };
  factory TtsSettingsSnapshot.fromJson(Map<String, dynamic> json) {
    final profiles = <TtsProfile>[];
    final rawProfiles = json['profiles'];
    if (rawProfiles is Iterable) {
      for (final rawProfile in rawProfiles) {
        if (rawProfile is! Map) continue;
        try {
          profiles.add(
            TtsProfile.fromJson(Map<String, dynamic>.from(rawProfile)),
          );
        } on Object {
          // Keep valid profiles when one legacy or corrupt entry cannot migrate.
        }
      }
    }
    final playbackSpeed = _finiteDouble(
      json['localPlaybackSpeed'],
      1,
    ).clamp(0.5, 2.0).toDouble();
    return TtsSettingsSnapshot(
      profiles: profiles,
      currentProfileId: json['currentProfileId'] is String
          ? json['currentProfileId'] as String
          : null,
      targetLength: _positiveInt(json['targetLength'], 220),
      maxLength: _positiveInt(json['maxLength'], 360),
      startupBufferSeconds: _positiveInt(json['startupBufferSeconds'], 90),
      targetBufferSeconds: _positiveInt(json['targetBufferSeconds'], 180),
      maxCacheMegabytes: _positiveInt(json['maxCacheMegabytes'], 512),
      autoNextPage: json['autoNextPage'] is bool
          ? json['autoNextPage'] as bool
          : true,
      autoNextNovel: json['autoNextNovel'] is bool
          ? json['autoNextNovel'] as bool
          : true,
      localPlaybackSpeed: playbackSpeed,
    );
  }
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
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map)
        throw const FormatException('TTS settings must be an object');
      return TtsSettingsSnapshot.fromJson(Map<String, dynamic>.from(decoded));
    } on Object {
      await prefs.remove(preferencesKey);
      return const TtsSettingsSnapshot();
    }
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
      ..._stringValues(profile.providerOptions['secretNames']),
    };
    final values = <String, String>{};
    for (final name in names) {
      final value = await secretStore.read(_namespace(profile), name);
      if (value != null && value.isNotEmpty) values[name] = value;
    }
    return values;
  }
}

int _positiveInt(Object? value, int fallback) {
  if (value is! num || !value.isFinite) return fallback;
  final parsed = value.toInt();
  return parsed > 0 ? parsed : fallback;
}

double _finiteDouble(Object? value, double fallback) {
  if (value is! num) return fallback;
  final parsed = value.toDouble();
  return parsed.isFinite ? parsed : fallback;
}

Iterable<String> _stringValues(Object? value) {
  return value is Iterable ? value.whereType<String>() : const <String>[];
}
