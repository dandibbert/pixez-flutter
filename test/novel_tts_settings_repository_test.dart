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
}
