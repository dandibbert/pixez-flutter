import 'package:flutter/material.dart';
import 'package:pixez/i18n.dart';
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
  Future<void> _saveTail = Future<void>.value();
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final value = await repository.load();
    if (mounted) setState(() => settings = value);
  }

  Future<void> _save(TtsSettingsSnapshot value) {
    if (mounted) setState(() => settings = value);
    final operation = _saveTail.then((_) => repository.save(value));
    _saveTail = operation.catchError((Object _) {});
    return operation;
  }

  Future<void> _update(
    TtsSettingsSnapshot Function(TtsSettingsSnapshot current) transform,
  ) => _save(transform(settings!));

  Future<void> _editProfile([TtsProfile? profile]) async {
    final draft = await Navigator.of(context).push<_ProfileDraft>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _ProfileEditor(initial: profile),
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
    for (final entry in draft.secretValues.entries) {
      if (entry.value.isNotEmpty) {
        await repository.writeSecret(draft.profile, entry.key, entry.value);
      }
    }
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
    final l10n = I18n.of(context);
    final value = settings;
    if (value == null)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tts_title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.tts_provider_profiles,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(l10n.tts_credentials_secure_hint),
          for (final profile in value.profiles)
            Card(
              child: ListTile(
                leading: IconButton(
                  tooltip: l10n.tts_use_profile,
                  onPressed: profile.enabled
                      ? () => _update(
                          (current) =>
                              current.copyWith(currentProfileId: profile.id),
                        )
                      : null,
                  icon: Icon(
                    value.currentProfileId == profile.id
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                ),
                title: Text(profile.name),
                subtitle: Text(
                  '${_providerLabel(context, profile.provider.kind)} · ${profile.voice}',
                ),
                onTap: () => _editProfile(profile),
                trailing: Switch(
                  value: profile.enabled,
                  onChanged: (enabled) => _update((current) {
                    final profiles = current.profiles
                        .map(
                          (item) => item.id == profile.id
                              ? _enabled(item, enabled)
                              : item,
                        )
                        .toList();
                    return current.copyWith(profiles: profiles);
                  }),
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const Key('tts-add-profile'),
              onPressed: () => _editProfile(),
              icon: const Icon(Icons.add),
              label: Text(l10n.tts_add_provider_profile),
            ),
          ),
          const Divider(height: 32),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.record_voice_over),
            title: Text(l10n.tts_pronunciation_dictionary),
            subtitle: Text(l10n.tts_pronunciation_scope_summary),
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
            l10n.tts_segmentation_buffering,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          _IntSetting(
            label: l10n.tts_target_graphemes,
            step: 10,
            value: value.targetLength,
            onChanged: (v) => _update(
              (current) =>
                  current.copyWith(targetLength: current.targetLength + v),
            ),
          ),
          _IntSetting(
            label: l10n.tts_maximum_graphemes,
            step: 10,
            value: value.maxLength,
            onChanged: (v) => _update(
              (current) => current.copyWith(maxLength: current.maxLength + v),
            ),
          ),
          _IntSetting(
            label: l10n.tts_startup_buffer_seconds,
            step: 10,
            value: value.startupBufferSeconds,
            onChanged: (v) => _update(
              (current) => current.copyWith(
                startupBufferSeconds: current.startupBufferSeconds + v,
              ),
            ),
          ),
          _IntSetting(
            label: l10n.tts_target_buffer_seconds,
            step: 10,
            value: value.targetBufferSeconds,
            onChanged: (v) => _update(
              (current) => current.copyWith(
                targetBufferSeconds: current.targetBufferSeconds + v,
              ),
            ),
          ),
          _IntSetting(
            label: l10n.tts_maximum_cache_mb,
            step: 64,
            value: value.maxCacheMegabytes,
            onChanged: (v) => _update(
              (current) => current.copyWith(
                maxCacheMegabytes: current.maxCacheMegabytes + v,
              ),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.tts_continue_newpage),
            value: value.autoNextPage,
            onChanged: (v) =>
                _update((current) => current.copyWith(autoNextPage: v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.tts_continue_next_novel),
            value: value.autoNextNovel,
            onChanged: (v) =>
                _update((current) => current.copyWith(autoNextNovel: v)),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.tts_local_playback_speed),
            subtitle: Slider(
              min: .5,
              max: 2,
              divisions: 15,
              label: '${value.localPlaybackSpeed.toStringAsFixed(1)}×',
              value: value.localPlaybackSpeed,
              onChanged: (v) =>
                  _update((current) => current.copyWith(localPlaybackSpeed: v)),
            ),
            trailing: Text('${value.localPlaybackSpeed.toStringAsFixed(1)}×'),
          ),
        ],
      ),
    );
  }
}

String _providerLabel(BuildContext context, TtsProviderKind kind) {
  final l10n = I18n.of(context);
  return switch (kind) {
    TtsProviderKind.microsoftAzure => l10n.tts_provider_azure,
    TtsProviderKind.openAiCompatible => l10n.tts_provider_openai,
    TtsProviderKind.customHttp => l10n.tts_provider_custom,
  };
}

class _IntSetting extends StatelessWidget {
  const _IntSetting({
    required this.label,
    required this.value,
    required this.step,
    required this.onChanged,
  });
  final String label;
  final int value;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    trailing: DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value > step ? () => onChanged(-step) : null,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 48,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => onChanged(step),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    ),
  );
}

class _ProfileDraft {
  const _ProfileDraft(this.profile, this.secretValues);
  final TtsProfile profile;
  final Map<String, String> secretValues;
}

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor({this.initial});
  final TtsProfile? initial;
  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  final formKey = GlobalKey<FormState>();
  late TtsProviderKind kind =
      widget.initial?.provider.kind ?? TtsProviderKind.microsoftAzure;
  late CustomHttpMethod method =
      widget.initial?.provider is CustomTtsProviderConfig
      ? (widget.initial!.provider as CustomTtsProviderConfig).method
      : CustomHttpMethod.post;
  late bool bodyIsJson = widget.initial?.provider is CustomTtsProviderConfig
      ? (widget.initial!.provider as CustomTtsProviderConfig).bodyIsJson
      : true;
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
  late final secretNames = TextEditingController(
    text: _initialSecretNames().join(', '),
  );
  late final secretValues = TextEditingController();
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
  List<String> _initialSecretNames() {
    final raw = widget.initial?.providerOptions['secretNames'];
    return raw is Iterable ? raw.whereType<String>().toList() : const [];
  }

  @override
  void dispose() {
    for (final controller in [
      name,
      voice,
      model,
      endpoint,
      path,
      body,
      headers,
      apiKey,
      secretNames,
      secretValues,
      format,
      language,
      speed,
      pitch,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

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

  List<String> _secretNames() => secretNames.text
      .split(',')
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty && name != 'api_key')
      .toSet()
      .toList();

  Map<String, String> _secretValues() {
    final values = <String, String>{};
    if (apiKey.text.trim().isNotEmpty) {
      values['api_key'] = apiKey.text.trim();
    }
    for (final entry in secretValues.text.split(';')) {
      final separator = entry.indexOf('=');
      if (separator <= 0) continue;
      final name = entry.substring(0, separator).trim();
      final value = entry.substring(separator + 1).trim();
      if (name.isNotEmpty && value.isNotEmpty) values[name] = value;
    }
    return values;
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
        bodyIsJson: bodyIsJson,
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
      providerOptions: {
        ...?widget.initial?.providerOptions,
        'secretNames': _secretNames(),
      },
      secretNamespace: widget.initial?.secretNamespace ?? '',
    );
  }

  void _submit() {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final profile = _profile();
    if (profile == null) return;
    Navigator.pop(context, _ProfileDraft(profile, _secretValues()));
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty
        ? I18n.of(context).tts_required_field
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = I18n.of(context);
    const gap = SizedBox(height: 12);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initial == null
              ? l10n.tts_add_profile_title
              : l10n.tts_edit_profile_title,
        ),
      ),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              DropdownButtonFormField<TtsProviderKind>(
                initialValue: kind,
                decoration: InputDecoration(labelText: l10n.tts_provider),
                items: [
                  for (final providerKind in TtsProviderKind.values)
                    DropdownMenuItem(
                      value: providerKind,
                      child: Text(_providerLabel(context, providerKind)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => kind = value);
                },
              ),
              gap,
              TextFormField(
                key: const Key('tts-profile-name'),
                controller: name,
                decoration: InputDecoration(labelText: l10n.tts_profile_name),
                validator: _required,
              ),
              gap,
              TextFormField(
                controller: voice,
                decoration: InputDecoration(labelText: l10n.tts_voice),
                validator: _required,
              ),
              if (kind != TtsProviderKind.microsoftAzure) ...[
                gap,
                TextFormField(
                  controller: model,
                  decoration: InputDecoration(labelText: l10n.tts_model),
                ),
              ],
              gap,
              TextFormField(
                controller: endpoint,
                decoration: InputDecoration(
                  labelText: kind == TtsProviderKind.microsoftAzure
                      ? l10n.tts_azure_region
                      : l10n.tts_endpoint_base_url,
                ),
                validator: _required,
              ),
              if (kind == TtsProviderKind.openAiCompatible) ...[
                gap,
                TextFormField(
                  controller: path,
                  decoration: InputDecoration(labelText: l10n.tts_speech_path),
                  validator: _required,
                ),
              ],
              if (kind == TtsProviderKind.customHttp) ...[
                gap,
                DropdownButtonFormField<CustomHttpMethod>(
                  initialValue: method,
                  decoration: InputDecoration(labelText: l10n.tts_http_method),
                  items: [
                    for (final httpMethod in CustomHttpMethod.values)
                      DropdownMenuItem(
                        value: httpMethod,
                        child: Text(httpMethod.name.toUpperCase()),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => method = value);
                  },
                ),
                gap,
                TextFormField(
                  controller: headers,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.tts_header_templates,
                    alignLabelWithHint: true,
                  ),
                ),
                gap,
                TextFormField(
                  controller: body,
                  minLines: 3,
                  maxLines: 6,
                  decoration: InputDecoration(
                    labelText: l10n.tts_body_template,
                    alignLabelWithHint: true,
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.tts_validate_json),
                  value: bodyIsJson,
                  onChanged: (value) => setState(() => bodyIsJson = value),
                ),
              ],
              gap,
              TextFormField(
                controller: apiKey,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.tts_api_key,
                  helperText: l10n.tts_api_key_helper,
                ),
              ),
              gap,
              TextFormField(
                controller: secretNames,
                decoration: InputDecoration(
                  labelText: l10n.tts_named_secret_keys,
                  helperText: l10n.tts_named_secret_keys_helper,
                ),
              ),
              gap,
              TextFormField(
                controller: secretValues,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.tts_named_secret_values,
                  helperText: l10n.tts_named_secret_values_helper,
                ),
              ),
              gap,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: format,
                      decoration: InputDecoration(
                        labelText: l10n.tts_audio_format,
                      ),
                      validator: _required,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: language,
                      decoration: InputDecoration(labelText: l10n.tts_language),
                      validator: _required,
                    ),
                  ),
                ],
              ),
              gap,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: speed,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.tts_synthesis_speed,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: pitch,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: InputDecoration(labelText: l10n.tts_pitch),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton(
                key: const Key('tts-profile-save'),
                onPressed: _submit,
                child: Text(l10n.save),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
