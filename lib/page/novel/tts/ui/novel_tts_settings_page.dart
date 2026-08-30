import 'package:flutter/material.dart';
import 'package:pixez/page/novel/tts/data/tts_settings_repository.dart';
import 'package:pixez/page/novel/tts/model/tts_profile.dart';
import 'package:pixez/page/novel/tts/ui/pronunciation_dictionary_page.dart';

class NovelTtsSettingsPage extends StatefulWidget {
  const NovelTtsSettingsPage({super.key, this.repository});
  final TtsSettingsRepository? repository;
  @override
  State<NovelTtsSettingsPage> createState() => _NovelTtsSettingsPageState();
}

class _NovelTtsSettingsPageState extends State<NovelTtsSettingsPage> {
  late final TtsSettingsRepository repository =
      widget.repository ?? TtsSettingsRepository();
  TtsSettingsSnapshot? settings;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await repository.load();
    if (mounted) setState(() => settings = value);
  }

  Future<void> _save(TtsSettingsSnapshot value) async {
    await repository.save(value);
    if (mounted) setState(() => settings = value);
  }

  Future<void> _editProfile([TtsProfile? profile]) async {
    final draft = await showDialog<_ProfileDraft>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 760),
          child: _ProfileEditor(initial: profile),
        ),
      ),
    );
    if (draft == null) return;
    final current = settings!;
    final profiles = current.profiles.toList();
    final index = profiles.indexWhere((item) => item.id == draft.profile.id);
    if (index < 0) {
      profiles.add(draft.profile);
    } else {
      profiles[index] = draft.profile;
    }
    await _save(
      current.copyWith(
        profiles: profiles,
        currentProfileId: current.currentProfileId ?? draft.profile.id,
      ),
    );
    if (draft.apiKey.trim().isNotEmpty)
      await repository.writeSecret(
        draft.profile,
        'api_key',
        draft.apiKey.trim(),
      );
  }

  TtsProfile _enabled(TtsProfile p, bool enabled) => TtsProfile(
    id: p.id,
    name: p.name,
    enabled: enabled,
    provider: p.provider,
    voice: p.voice,
    model: p.model,
    speed: p.speed,
    pitch: p.pitch,
    language: p.language,
    format: p.format,
    providerOptions: p.providerOptions,
    secretNamespace: p.secretNamespace,
    schemaVersion: p.schemaVersion,
  );
  @override
  Widget build(BuildContext context) {
    final value = settings;
    if (value == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Novel text to speech')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Provider profiles',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text(
            'Credentials are saved in secure platform storage and are never written to profile JSON.',
          ),
          for (final profile in value.profiles)
            Card(
              child: ListTile(
                leading: IconButton(
                  tooltip: 'Use this profile',
                  onPressed: profile.enabled
                      ? () =>
                            _save(value.copyWith(currentProfileId: profile.id))
                      : null,
                  icon: Icon(
                    value.currentProfileId == profile.id
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                ),
                title: Text(profile.name),
                subtitle: Text(
                  '${profile.provider.kind.name} · ${profile.voice}',
                ),
                onTap: () => _editProfile(profile),
                trailing: Switch(
                  value: profile.enabled,
                  onChanged: (enabled) {
                    final profiles = value.profiles
                        .map(
                          (item) => item.id == profile.id
                              ? _enabled(item, enabled)
                              : item,
                        )
                        .toList();
                    _save(value.copyWith(profiles: profiles));
                  },
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const Key('tts-add-profile'),
              onPressed: () => _editProfile(),
              icon: const Icon(Icons.add),
              label: const Text('Add provider profile'),
            ),
          ),
          const Divider(height: 32),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.record_voice_over),
            title: const Text('Pronunciation dictionary'),
            subtitle: const Text(
              'Global, author, series and novel scoped readings',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PronunciationDictionaryPage(),
              ),
            ),
          ),
          const Divider(height: 32),
          Text(
            'Segmentation and buffering',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          _IntSetting(
            label: 'Target graphemes',
            value: value.targetLength,
            onChanged: (v) => _save(value.copyWith(targetLength: v)),
          ),
          _IntSetting(
            label: 'Maximum graphemes',
            value: value.maxLength,
            onChanged: (v) => _save(value.copyWith(maxLength: v)),
          ),
          _IntSetting(
            label: 'Startup buffer seconds',
            value: value.startupBufferSeconds,
            onChanged: (v) => _save(value.copyWith(startupBufferSeconds: v)),
          ),
          _IntSetting(
            label: 'Target buffer seconds',
            value: value.targetBufferSeconds,
            onChanged: (v) => _save(value.copyWith(targetBufferSeconds: v)),
          ),
          _IntSetting(
            label: 'Maximum cache MB',
            value: value.maxCacheMegabytes,
            onChanged: (v) => _save(value.copyWith(maxCacheMegabytes: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Continue across newpage markers'),
            value: value.autoNextPage,
            onChanged: (v) => _save(value.copyWith(autoNextPage: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Continue to next series novel'),
            value: value.autoNextNovel,
            onChanged: (v) => _save(value.copyWith(autoNextNovel: v)),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Local playback speed'),
            subtitle: Slider(
              min: .5,
              max: 2,
              divisions: 15,
              label: '${value.localPlaybackSpeed.toStringAsFixed(1)}×',
              value: value.localPlaybackSpeed,
              onChanged: (v) => _save(value.copyWith(localPlaybackSpeed: v)),
            ),
            trailing: Text('${value.localPlaybackSpeed.toStringAsFixed(1)}×'),
          ),
        ],
      ),
    );
  }
}

class _IntSetting extends StatelessWidget {
  const _IntSetting({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    trailing: SizedBox(
      width: 96,
      child: TextFormField(
        initialValue: value.toString(),
        keyboardType: TextInputType.number,
        onFieldSubmitted: (text) {
          final parsed = int.tryParse(text);
          if (parsed != null && parsed > 0) onChanged(parsed);
        },
      ),
    ),
  );
}

class _ProfileDraft {
  const _ProfileDraft(this.profile, this.apiKey);
  final TtsProfile profile;
  final String apiKey;
}

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor({this.initial});
  final TtsProfile? initial;
  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  late TtsProviderKind kind =
      widget.initial?.provider.kind ?? TtsProviderKind.microsoftAzure;
  late CustomHttpMethod method =
      widget.initial?.provider is CustomTtsProviderConfig
      ? (widget.initial!.provider as CustomTtsProviderConfig).method
      : CustomHttpMethod.post;
  late final name = TextEditingController(text: widget.initial?.name ?? '');
  late final voice = TextEditingController(
    text: widget.initial?.voice ?? 'ja-JP-NanamiNeural',
  );
  late final model = TextEditingController(text: widget.initial?.model ?? '');
  late final endpoint = TextEditingController(text: _endpoint());
  late final path = TextEditingController(
    text: widget.initial?.provider is OpenAiTtsProviderConfig
        ? (widget.initial!.provider as OpenAiTtsProviderConfig).path
        : '/v1/audio/speech',
  );
  late final body = TextEditingController(
    text: widget.initial?.provider is CustomTtsProviderConfig
        ? (widget.initial!.provider as CustomTtsProviderConfig).bodyTemplate ??
              '{"text":"{{text|json}}"}'
        : '',
  );
  late final headers = TextEditingController(
    text: widget.initial?.provider is CustomTtsProviderConfig
        ? (widget.initial!.provider as CustomTtsProviderConfig)
              .headerTemplates
              .entries
              .map((e) => '${e.key}: ${e.value}')
              .join(String.fromCharCode(10))
        : '',
  );
  late final apiKey = TextEditingController();
  late final format = TextEditingController(
    text: widget.initial?.format ?? 'mp3',
  );
  late final language = TextEditingController(
    text: widget.initial?.language ?? 'ja-JP',
  );
  late final speed = TextEditingController(
    text: (widget.initial?.speed ?? 1).toString(),
  );
  late final pitch = TextEditingController(
    text: (widget.initial?.pitch ?? 0).toString(),
  );
  String _endpoint() {
    final p = widget.initial?.provider;
    return switch (p) {
      AzureTtsProviderConfig p => p.region,
      OpenAiTtsProviderConfig p => p.baseUrl,
      CustomTtsProviderConfig p => p.endpointTemplate,
      _ => 'japaneast',
    };
  }

  Map<String, String> _headers() {
    final map = <String, String>{};
    for (final line in headers.text.split(String.fromCharCode(10))) {
      final index = line.indexOf(':');
      if (index > 0)
        map[line.substring(0, index).trim()] = line.substring(index + 1).trim();
    }
    return map;
  }

  TtsProfile? _profile() {
    if (name.text.trim().isEmpty ||
        voice.text.trim().isEmpty ||
        endpoint.text.trim().isEmpty)
      return null;
    final provider = switch (kind) {
      TtsProviderKind.microsoftAzure => AzureTtsProviderConfig(
        region: endpoint.text.trim(),
      ),
      TtsProviderKind.openAiCompatible => OpenAiTtsProviderConfig(
        baseUrl: endpoint.text.trim(),
        path: path.text.trim(),
      ),
      TtsProviderKind.customHttp => CustomTtsProviderConfig(
        endpointTemplate: endpoint.text.trim(),
        method: method,
        headerTemplates: _headers(),
        bodyTemplate: body.text.isEmpty ? null : body.text,
        bodyIsJson: true,
      ),
    };
    return TtsProfile(
      id:
          widget.initial?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.text.trim(),
      enabled: widget.initial?.enabled ?? true,
      provider: provider,
      voice: voice.text.trim(),
      model: model.text.trim().isEmpty ? null : model.text.trim(),
      speed: double.tryParse(speed.text) ?? 1,
      pitch: double.tryParse(pitch.text) ?? 0,
      language: language.text.trim(),
      format: format.text.trim(),
      secretNamespace: widget.initial?.secretNamespace ?? '',
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.initial == null ? 'Add TTS profile' : 'Edit TTS profile',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          DropdownButtonFormField<TtsProviderKind>(
            initialValue: kind,
            decoration: const InputDecoration(labelText: 'Provider'),
            items: [
              for (final k in TtsProviderKind.values)
                DropdownMenuItem(value: k, child: Text(k.name)),
            ],
            onChanged: (v) => setState(() => kind = v!),
          ),
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Profile name'),
            onChanged: (_) => setState(() {}),
          ),
          TextField(
            controller: voice,
            decoration: const InputDecoration(labelText: 'Voice'),
            onChanged: (_) => setState(() {}),
          ),
          if (kind != TtsProviderKind.microsoftAzure)
            TextField(
              controller: model,
              decoration: const InputDecoration(labelText: 'Model'),
            ),
          TextField(
            controller: endpoint,
            decoration: InputDecoration(
              labelText: kind == TtsProviderKind.microsoftAzure
                  ? 'Azure region'
                  : 'Endpoint / base URL',
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (kind == TtsProviderKind.openAiCompatible)
            TextField(
              controller: path,
              decoration: const InputDecoration(labelText: 'Speech path'),
            ),
          if (kind == TtsProviderKind.customHttp) ...[
            DropdownButtonFormField<CustomHttpMethod>(
              initialValue: method,
              decoration: const InputDecoration(labelText: 'HTTP method'),
              items: [
                for (final m in CustomHttpMethod.values)
                  DropdownMenuItem(value: m, child: Text(m.name.toUpperCase())),
              ],
              onChanged: (v) => setState(() => method = v!),
            ),
            TextField(
              controller: headers,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Header templates (one Name: value per line)',
              ),
            ),
            TextField(
              controller: body,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Body template'),
            ),
          ],
          TextField(
            controller: apiKey,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'API key',
              helperText: 'Leave blank to keep the existing secure value',
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: format,
                  decoration: const InputDecoration(labelText: 'Audio format'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: language,
                  decoration: const InputDecoration(labelText: 'Language'),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: speed,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Synthesis speed',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: pitch,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Pitch'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _profile() == null
                    ? null
                    : () => Navigator.pop(
                        context,
                        _ProfileDraft(_profile()!, apiKey.text),
                      ),
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
