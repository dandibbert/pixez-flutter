import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pixez/page/novel/tts/data/tts_settings_repository.dart';
import 'package:pixez/page/novel/tts/model/tts_profile.dart';

class MemorySecrets implements TtsSecretStore {
  final values = <String, String>{};
  @override
  Future<void> delete(String namespace, String name) async =>
      values.remove('$namespace/$name');
  @override
  Future<String?> read(String namespace, String name) async =>
      values['$namespace/$name'];
  @override
  Future<void> write(String namespace, String name, String value) async =>
      values['$namespace/$name'] = value;
}

void main() {
  test(
    'profiles persist while secrets stay outside preferences JSON',
    () async {
      SharedPreferences.setMockInitialValues({});
      final secrets = MemorySecrets();
      final repo = TtsSettingsRepository(secretStore: secrets);
      const profile = TtsProfile(
        id: 'p',
        name: 'Azure',
        enabled: true,
        provider: AzureTtsProviderConfig(region: 'japaneast'),
        voice: 'voice',
        providerOptions: {
          'secretNames': ['tenant_token'],
        },
        secretNamespace: 'p',
      );
      await repo.save(
        TtsSettingsSnapshot(profiles: const [profile], currentProfileId: 'p'),
      );
      await repo.writeSecret(profile, 'api_key', 'never-log-this');
      await repo.writeSecret(profile, 'tenant_token', 'named-secret-value');
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(TtsSettingsRepository.preferencesKey),
        allOf(
          isNot(contains('never-log-this')),
          isNot(contains('named-secret-value')),
        ),
      );
      expect((await repo.load()).currentProfile?.voice, 'voice');
      expect(await repo.readSecrets(profile), {
        'api_key': 'never-log-this',
        'tenant_token': 'named-secret-value',
      });
    },
  );

  test('malformed persisted settings fall back to safe defaults', () async {
    SharedPreferences.setMockInitialValues({
      TtsSettingsRepository.preferencesKey: '{not-json',
    });
    final repo = TtsSettingsRepository(secretStore: MemorySecrets());

    final loaded = await repo.load();

    expect(loaded.profiles, isEmpty);
    expect(loaded.targetLength, 220);
    expect(loaded.localPlaybackSpeed, 1);
  });

  test('legacy scalar values and named secrets are sanitized', () async {
    SharedPreferences.setMockInitialValues({
      TtsSettingsRepository.preferencesKey: jsonEncode({
        'profiles': [
          {
            'id': 'legacy',
            'name': 'Legacy',
            'enabled': true,
            'provider': {'kind': 'microsoftAzure', 'region': 'japaneast'},
            'voice': 'voice',
            'speed': 1,
            'pitch': 0,
            'language': 'ja-JP',
            'format': 'mp3',
            'providerOptions': {
              'secretNames': [1, 'tenant_token', null],
            },
          },
        ],
        'targetLength': -10,
        'maxLength': 'bad',
        'startupBufferSeconds': 0,
        'targetBufferSeconds': 180,
        'maxCacheMegabytes': -1,
        'localPlaybackSpeed': 9,
      }),
    });
    final repo = TtsSettingsRepository(secretStore: MemorySecrets());

    final loaded = await repo.load();

    expect(loaded.targetLength, 220);
    expect(loaded.maxLength, 360);
    expect(loaded.startupBufferSeconds, 90);
    expect(loaded.maxCacheMegabytes, 512);
    expect(loaded.localPlaybackSpeed, 2);
    await expectLater(repo.readSecrets(loaded.profiles.single), completes);
  });
}
