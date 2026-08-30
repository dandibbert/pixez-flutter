import 'package:material_ui/material_ui.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/page/novel/tts/novel_tts_settings.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';

const Key novelTtsSettingsPageKey = Key('novelTtsSettingsPage');
const Key novelTtsProviderMicrosoftKey = Key('novelTtsProviderMicrosoft');
const Key novelTtsProviderOpenaiKey = Key('novelTtsProviderOpenai');
const Key novelTtsProviderCustomKey = Key('novelTtsProviderCustom');
const Key novelTtsSplitCharsFieldKey = Key('novelTtsSplitCharsField');
const Key novelTtsAutoContinueKey = Key('novelTtsAutoContinue');
const Key novelTtsCustomUrlFieldKey = Key('novelTtsCustomUrlField');

class NovelTtsPage extends StatefulWidget {
  const NovelTtsPage({super.key, this.initial});

  final NovelTtsSettings? initial;

  @override
  State<NovelTtsPage> createState() => _NovelTtsPageState();
}

class _NovelTtsPageState extends State<NovelTtsPage> {
  late NovelTtsSettings _settings;
  late final TextEditingController _splitChars;
  late final TextEditingController _microsoftKey;
  late final TextEditingController _microsoftRegion;
  late final TextEditingController _microsoftVoice;
  late final TextEditingController _microsoftLanguage;
  late final TextEditingController _microsoftRate;
  late final TextEditingController _openaiBaseUrl;
  late final TextEditingController _openaiApiKey;
  late final TextEditingController _openaiModel;
  late final TextEditingController _openaiVoice;
  late final TextEditingController _openaiSpeed;
  late final TextEditingController _customUrl;
  late final TextEditingController _customVoice;
  late final TextEditingController _customHeaders;
  late final TextEditingController _customBody;
  late final TextEditingController _customContentType;

  @override
  void initState() {
    super.initState();
    _settings = widget.initial ?? NovelTtsSettings.load();
    _splitChars = TextEditingController(text: '${_settings.splitChars}');
    _microsoftKey = TextEditingController(text: _settings.microsoftKey);
    _microsoftRegion = TextEditingController(text: _settings.microsoftRegion);
    _microsoftVoice = TextEditingController(text: _settings.microsoftVoice);
    _microsoftLanguage = TextEditingController(
      text: _settings.microsoftLanguage,
    );
    _microsoftRate = TextEditingController(text: _settings.microsoftRate);
    _openaiBaseUrl = TextEditingController(text: _settings.openaiBaseUrl);
    _openaiApiKey = TextEditingController(text: _settings.openaiApiKey);
    _openaiModel = TextEditingController(text: _settings.openaiModel);
    _openaiVoice = TextEditingController(text: _settings.openaiVoice);
    _openaiSpeed = TextEditingController(text: '${_settings.openaiSpeed}');
    _customUrl = TextEditingController(text: _settings.customUrl);
    _customVoice = TextEditingController(text: _settings.customVoice);
    _customHeaders = TextEditingController(text: _settings.customHeaders);
    _customBody = TextEditingController(text: _settings.customBody);
    _customContentType = TextEditingController(
      text: _settings.customContentType,
    );
  }

  @override
  void dispose() {
    _splitChars.dispose();
    _microsoftKey.dispose();
    _microsoftRegion.dispose();
    _microsoftVoice.dispose();
    _microsoftLanguage.dispose();
    _microsoftRate.dispose();
    _openaiBaseUrl.dispose();
    _openaiApiKey.dispose();
    _openaiModel.dispose();
    _openaiVoice.dispose();
    _openaiSpeed.dispose();
    _customUrl.dispose();
    _customVoice.dispose();
    _customHeaders.dispose();
    _customBody.dispose();
    _persist(_draft(), updateState: false);
    _customContentType.dispose();
    super.dispose();
  }

  Future<void> _persist(NovelTtsSettings next, {bool updateState = true}) async {
    if (updateState && mounted) {
      setState(() {
        _settings = next;
      });
    } else {
      _settings = next;
    }
    await next.save();
  }

  NovelTtsSettings _draft() {
    return _settings.copyWith(
      splitChars:
          int.tryParse(_splitChars.text.trim()) ?? _settings.splitChars,
      microsoftKey: _microsoftKey.text,
      microsoftRegion: _microsoftRegion.text,
      microsoftVoice: _microsoftVoice.text,
      microsoftLanguage: _microsoftLanguage.text,
      microsoftRate: _microsoftRate.text,
      openaiBaseUrl: _openaiBaseUrl.text,
      openaiApiKey: _openaiApiKey.text,
      openaiModel: _openaiModel.text,
      openaiVoice: _openaiVoice.text,
      openaiSpeed:
          double.tryParse(_openaiSpeed.text.trim()) ?? _settings.openaiSpeed,
      customUrl: _customUrl.text,
      customVoice: _customVoice.text,
      customHeaders: _customHeaders.text,
      customBody: _customBody.text,
      customContentType: _customContentType.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);
    return Scaffold(
      key: novelTtsSettingsPageKey,
      appBar: AppBar(title: Text(i18n.novel_tts_settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            i18n.novel_tts_provider,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: [
                _ProviderChip(
                  key: novelTtsProviderMicrosoftKey,
                  selected: _settings.provider == NovelTtsProvider.microsoft,
                  label: i18n.novel_tts_provider_microsoft,
                  onTap: () => _persist(
                    _draft().copyWith(provider: NovelTtsProvider.microsoft),
                  ),
                ),
                _ProviderChip(
                  key: novelTtsProviderOpenaiKey,
                  selected: _settings.provider == NovelTtsProvider.openai,
                  label: i18n.novel_tts_provider_openai,
                  onTap: () => _persist(
                    _draft().copyWith(provider: NovelTtsProvider.openai),
                  ),
                ),
                _ProviderChip(
                  key: novelTtsProviderCustomKey,
                  selected: _settings.provider == NovelTtsProvider.custom,
                  label: i18n.novel_tts_provider_custom,
                  onTap: () => _persist(
                    _draft().copyWith(provider: NovelTtsProvider.custom),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: novelTtsSplitCharsFieldKey,
            controller: _splitChars,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: i18n.novel_tts_split_chars,
              helperText: i18n.novel_tts_split_chars_hint,
              border: const OutlineInputBorder(),
            ),
            onEditingComplete: () => _persist(_draft()),
            onSubmitted: (_) => _persist(_draft()),
          ),
          SwitchListTile(
            key: novelTtsAutoContinueKey,
            contentPadding: EdgeInsets.zero,
            title: Text(i18n.novel_tts_auto_continue),
            value: _settings.autoContinue,
            onChanged: (value) =>
                _persist(_draft().copyWith(autoContinue: value)),
          ),
          const SizedBox(height: 8),
          if (_settings.provider == NovelTtsProvider.microsoft)
            ..._microsoftFields(i18n),
          if (_settings.provider == NovelTtsProvider.openai)
            ..._openaiFields(i18n),
          if (_settings.provider == NovelTtsProvider.custom)
            ..._customFields(i18n),
        ],
      ),
    );
  }

  List<Widget> _microsoftFields(AppLocalizations i18n) {
    return [
      _box(_microsoftKey, i18n.novel_tts_microsoft_key, obscure: true),
      _box(_microsoftRegion, i18n.novel_tts_microsoft_region),
      _box(_microsoftVoice, i18n.novel_tts_microsoft_voice),
      _box(_microsoftLanguage, i18n.novel_tts_microsoft_language),
      _box(_microsoftRate, i18n.novel_tts_microsoft_rate),
    ];
  }

  List<Widget> _openaiFields(AppLocalizations i18n) {
    return [
      _box(_openaiBaseUrl, i18n.novel_tts_openai_base_url),
      _box(_openaiApiKey, i18n.novel_tts_openai_api_key, obscure: true),
      _box(_openaiModel, i18n.novel_tts_openai_model),
      _box(_openaiVoice, i18n.novel_tts_openai_voice),
      _box(_openaiSpeed, i18n.novel_tts_openai_speed),
    ];
  }

  List<Widget> _customFields(AppLocalizations i18n) {
    return [
      TextField(
        key: novelTtsCustomUrlFieldKey,
        controller: _customUrl,
        minLines: 2,
        maxLines: 4,
        decoration: InputDecoration(
          labelText: i18n.novel_tts_custom_url,
          helperText: i18n.novel_tts_custom_url_hint,
          border: const OutlineInputBorder(),
        ),
        onEditingComplete: () => _persist(_draft()),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: _settings.customMethod == 'POST' ? 'POST' : 'GET',
        decoration: InputDecoration(
          labelText: i18n.novel_tts_custom_method,
          border: const OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: 'GET', child: Text('GET')),
          DropdownMenuItem(value: 'POST', child: Text('POST')),
        ],
        onChanged: (value) {
          if (value == null) {
            return;
          }
          _persist(_draft().copyWith(customMethod: value));
        },
      ),
      const SizedBox(height: 12),
      _box(_customVoice, i18n.novel_tts_custom_voice),
      _box(_customHeaders, i18n.novel_tts_custom_headers, minLines: 2),
      _box(_customBody, i18n.novel_tts_custom_body, minLines: 3),
      _box(_customContentType, i18n.novel_tts_custom_content_type),
      Text(
        i18n.novel_tts_custom_variables,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '{text} {voice} {voiceName} {lang} {speed} {model}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
          ),
        ),
      ),
    ];
  }

  Widget _box(
    TextEditingController controller,
    String label, {
    bool obscure = false,
    int minLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        minLines: minLines,
        maxLines: minLines > 1 ? minLines + 2 : 1,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onEditingComplete: () => _persist(_draft()),
        onSubmitted: (_) => _persist(_draft()),
      ),
    );
  }
}

class _ProviderChip extends StatelessWidget {
  const _ProviderChip({
    super.key,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => onTap(),
    );
  }
}
