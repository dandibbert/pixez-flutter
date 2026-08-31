import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/page/novel/tts/novel_tts_form.dart';
import 'package:pixez/page/novel/tts/novel_tts_readings.dart';
import 'package:pixez/page/novel/tts/novel_tts_settings.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_rule.dart';
import 'package:pixez/page/novel/tts/pronunciation/storage/pronunciation_migration.dart';
import 'package:pixez/page/novel/tts/pronunciation/storage/pronunciation_repository.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';

const Key novelTtsSettingsPageKey = Key('novelTtsSettingsPage');
const Key novelTtsProviderMicrosoftKey = Key('novelTtsProviderMicrosoft');
const Key novelTtsProviderOpenaiKey = Key('novelTtsProviderOpenai');
const Key novelTtsProviderCustomKey = Key('novelTtsProviderCustom');
const Key novelTtsSplitCharsFieldKey = Key('novelTtsSplitCharsField');
const Key novelTtsAutoContinueKey = Key('novelTtsAutoContinue');
const Key novelTtsCustomUrlFieldKey = Key('novelTtsCustomUrlField');
const Key novelTtsReadingsSectionKey = Key('novelTtsReadingsSection');
const Key novelTtsAddReadingKey = Key('novelTtsAddReading');
const Key novelTtsBulkReadingKey = Key('novelTtsBulkReading');
const Key novelTtsReadingSurfaceFieldKey = Key('novelTtsReadingSurface');
const Key novelTtsReadingValueFieldKey = Key('novelTtsReadingValue');
const Key novelTtsReadingSaveKey = Key('novelTtsReadingSave');

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
  Timer? _persistTimer;

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
    _persistTimer?.cancel();
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

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 350), () {
      _persist(_draft());
    });
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

  Future<void> _setReadings(List<NovelTtsReading> readings) async {
    await _persist(_draft().copyWith(readings: readings));
    await PronunciationRepository().replaceFromSettings(readings);
  }

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);
    return Scaffold(
      key: novelTtsSettingsPageKey,
      appBar: AppBar(title: Text(i18n.novel_tts_settings)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          _Section(
            title: i18n.novel_tts_section_voice,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
                const SizedBox(height: 16),
                if (_settings.provider == NovelTtsProvider.microsoft)
                  ..._microsoftFields(i18n),
                if (_settings.provider == NovelTtsProvider.openai)
                  ..._openaiFields(i18n),
                if (_settings.provider == NovelTtsProvider.custom)
                  ..._customFields(i18n),
              ],
            ),
          ),
          _Section(
            title: i18n.novel_tts_section_playback,
            child: Column(
              children: [
                TextField(
                  key: novelTtsSplitCharsFieldKey,
                  controller: _splitChars,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: i18n.novel_tts_split_chars,
                    helperText: i18n.novel_tts_split_chars_hint,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => _schedulePersist(),
                  onEditingComplete: () => _persist(_draft()),
                  onSubmitted: (_) => _persist(_draft()),
                ),
                SwitchListTile(
                  key: novelTtsAutoContinueKey,
                  contentPadding: EdgeInsets.zero,
                  title: Text(i18n.novel_tts_auto_continue),
                  subtitle: Text(i18n.novel_tts_lock_screen_hint),
                  value: _settings.autoContinue,
                  onChanged: (value) =>
                      _persist(_draft().copyWith(autoContinue: value)),
                ),
              ],
            ),
          ),
          _Section(
            key: novelTtsReadingsSectionKey,
            title: i18n.novel_tts_section_readings,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  i18n.novel_tts_analyzer_boundary,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                _ReadingsEditor(
                  readings: _settings.readings,
                  onChanged: _setReadings,
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  List<Widget> _microsoftFields(AppLocalizations i18n) {
    final rate = parseMicrosoftRatePercent(_microsoftRate.text);
    return [
      _box(_microsoftKey, i18n.novel_tts_microsoft_key, obscure: true),
      NovelTtsChoiceField(
        label: i18n.novel_tts_microsoft_region,
        controller: _microsoftRegion,
        choices: microsoftRegionChoices,
        onChanged: (_) {
          setState(() {});
          _schedulePersist();
        },
      ),
      NovelTtsChoiceField(
        label: i18n.novel_tts_microsoft_voice,
        controller: _microsoftVoice,
        choices: microsoftVoiceChoices,
        onChanged: (value) {
          final language = languageFromMicrosoftVoice(value);
          if (language != null && _microsoftLanguage.text.trim().isEmpty) {
            _microsoftLanguage.text = language;
          } else if (language != null &&
              microsoftLanguageChoices.any((choice) =>
                  choice.value == _microsoftLanguage.text.trim())) {
            _microsoftLanguage.text = language;
          }
          setState(() {});
          _schedulePersist();
        },
      ),
      NovelTtsChoiceField(
        label: i18n.novel_tts_microsoft_language,
        controller: _microsoftLanguage,
        choices: microsoftLanguageChoices,
        onChanged: (_) {
          setState(() {});
          _schedulePersist();
        },
      ),
      Text(i18n.novel_tts_microsoft_rate),
      Slider(
        value: rate,
        min: -50,
        max: 50,
        divisions: 20,
        label: formatMicrosoftRatePercent(rate),
        onChanged: (value) {
          setState(() {
            _microsoftRate.text = formatMicrosoftRatePercent(value);
          });
          _schedulePersist();
        },
      ),
      Align(
        alignment: Alignment.centerRight,
        child: Text(
          formatMicrosoftRatePercent(rate),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      const SizedBox(height: 8),
    ];
  }

  List<Widget> _openaiFields(AppLocalizations i18n) {
    final speed = (_openaiSpeed.text.trim().isEmpty
            ? _settings.openaiSpeed
            : double.tryParse(_openaiSpeed.text.trim()) ??
                _settings.openaiSpeed)
        .clamp(0.25, 4.0);
    return [
      _box(_openaiBaseUrl, i18n.novel_tts_openai_base_url),
      _box(_openaiApiKey, i18n.novel_tts_openai_api_key, obscure: true),
      NovelTtsChoiceField(
        label: i18n.novel_tts_openai_model,
        controller: _openaiModel,
        choices: openaiModelChoices,
        onChanged: (_) {
          setState(() {});
          _schedulePersist();
        },
      ),
      NovelTtsChoiceField(
        label: i18n.novel_tts_openai_voice,
        controller: _openaiVoice,
        choices: openaiVoiceChoices,
        onChanged: (_) {
          setState(() {});
          _schedulePersist();
        },
      ),
      Text(i18n.novel_tts_openai_speed),
      Slider(
        value: speed,
        min: 0.25,
        max: 4,
        divisions: 15,
        label: speed.toStringAsFixed(2),
        onChanged: (value) {
          setState(() {
            _openaiSpeed.text = value.toStringAsFixed(2);
          });
          _schedulePersist();
        },
      ),
      Align(
        alignment: Alignment.centerRight,
        child: Text(
          speed.toStringAsFixed(2),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      const SizedBox(height: 8),
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
        onChanged: (_) => _schedulePersist(),
        onEditingComplete: () => _persist(_draft()),
      ),
      const SizedBox(height: 8),
      NovelTtsPlaceholderChips(
        caption: i18n.novel_tts_insert_placeholder,
        onInsert: (token) {
          insertNovelTtsToken(_customUrl, token);
          _schedulePersist();
        },
      ),
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
      NovelTtsAdvancedPanel(
        title: i18n.novel_tts_advanced,
        children: [
          Text(
            i18n.novel_tts_custom_headers,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          NovelTtsHeaderListEditor(
            initial: _customHeaders.text,
            nameLabel: i18n.novel_tts_header_name,
            valueLabel: i18n.novel_tts_header_value,
            addLabel: i18n.novel_tts_header_add,
            onChanged: (raw) {
              _customHeaders.text = raw;
              _persist(_draft(), updateState: false);
            },
          ),
          _box(_customBody, i18n.novel_tts_custom_body, minLines: 3),
          NovelTtsPlaceholderChips(
            caption: i18n.novel_tts_insert_placeholder,
            onInsert: (token) {
              insertNovelTtsToken(_customBody, token);
              _schedulePersist();
            },
          ),
          NovelTtsChoiceField(
            label: i18n.novel_tts_custom_content_type,
            controller: _customContentType,
            choices: contentTypeChoices,
            onChanged: (_) {
              setState(() {});
              _schedulePersist();
            },
          ),
        ],
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
        onChanged: (_) => _schedulePersist(),
        onEditingComplete: () => _persist(_draft()),
        onSubmitted: (_) => _persist(_draft()),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadingsEditor extends StatelessWidget {
  const _ReadingsEditor({required this.readings, required this.onChanged});

  final List<NovelTtsReading> readings;
  final ValueChanged<List<NovelTtsReading>> onChanged;

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          i18n.novel_tts_readings_hint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (readings.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              i18n.novel_tts_readings_empty,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ...[
            for (var i = 0; i < readings.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${readings[i].surface}  →  ${readings[i].reading}'),
                subtitle: Text(_modeLabel(i18n, readings[i])),
                onTap: () => _edit(context, index: i),
                trailing: IconButton(
                  tooltip: i18n.novel_tts_reading_delete,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    final next = [...readings]..removeAt(i);
                    onChanged(next);
                  },
                ),
              ),
          ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              key: novelTtsAddReadingKey,
              onPressed: () => _edit(context),
              icon: const Icon(Icons.add),
              label: Text(i18n.novel_tts_reading_add),
            ),
            OutlinedButton(
              key: novelTtsBulkReadingKey,
              onPressed: () => _bulk(context),
              child: Text(i18n.novel_tts_reading_bulk),
            ),
          ],
        ),
      ],
    );
  }

  String _modeLabel(AppLocalizations i18n, NovelTtsReading reading) {
    final mode = reading.mode ??
        const PronunciationMigration().classifyV1Surface(reading.surface).mode;
    switch (mode) {
      case PronunciationMatchMode.exactPhrase:
        return i18n.novel_tts_mode_exact;
      case PronunciationMatchMode.nameAlias:
        return i18n.novel_tts_mode_alias;
      case PronunciationMatchMode.force:
        return i18n.novel_tts_mode_force;
    }
  }

  Future<void> _edit(BuildContext context, {int? index}) async {
    final saved = await showDialog<NovelTtsReading>(
      context: context,
      builder: (context) {
        return _ReadingDialog(initial: index == null ? null : readings[index]);
      },
    );
    if (saved == null) {
      return;
    }
    final next = [...readings];
    if (index == null) {
      next.add(saved);
    } else {
      next[index] = saved;
    }
    onChanged(next);
  }

  Future<void> _bulk(BuildContext context) async {
    final raw = await showDialog<String>(
      context: context,
      builder: (context) => const _BulkReadingDialog(),
    );
    if (raw == null) {
      return;
    }
    final parsed = parseNovelTtsReadingLines(raw);
    if (parsed.isEmpty) {
      return;
    }
    onChanged([...readings, ...parsed]);
  }
}

class _ReadingDialog extends StatefulWidget {
  const _ReadingDialog({this.initial});

  final NovelTtsReading? initial;

  @override
  State<_ReadingDialog> createState() => _ReadingDialogState();
}

class _ReadingDialogState extends State<_ReadingDialog> {
  late final TextEditingController _surface;
  late final TextEditingController _reading;
  late PronunciationMatchMode _mode;

  @override
  void initState() {
    super.initState();
    _surface = TextEditingController(text: widget.initial?.surface ?? '');
    _reading = TextEditingController(text: widget.initial?.reading ?? '');
    _mode = widget.initial?.mode ??
        const PronunciationMigration().classifyV1Surface(
          widget.initial?.surface ?? '',
        ).mode;
    if (widget.initial == null) {
      _mode = PronunciationMatchMode.exactPhrase;
    }
  }

  @override
  void dispose() {
    _surface.dispose();
    _reading.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);
    return AlertDialog(
      title: Text(
        widget.initial == null
            ? i18n.novel_tts_reading_add
            : i18n.novel_tts_reading_edit,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: novelTtsReadingSurfaceFieldKey,
              controller: _surface,
              autofocus: true,
              decoration: InputDecoration(
                labelText: i18n.novel_tts_reading_surface,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: novelTtsReadingValueFieldKey,
              controller: _reading,
              decoration: InputDecoration(
                labelText: i18n.novel_tts_reading_value,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PronunciationMatchMode>(
              initialValue: _mode,
              decoration: InputDecoration(
                labelText: i18n.novel_tts_reading_mode,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: PronunciationMatchMode.exactPhrase,
                  child: Text(i18n.novel_tts_mode_exact),
                ),
                DropdownMenuItem(
                  value: PronunciationMatchMode.nameAlias,
                  child: Text(i18n.novel_tts_mode_alias),
                ),
                DropdownMenuItem(
                  value: PronunciationMatchMode.force,
                  child: Text(i18n.novel_tts_mode_force),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _mode = value);
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                switch (_mode) {
                  PronunciationMatchMode.exactPhrase =>
                    i18n.novel_tts_mode_exact_hint,
                  PronunciationMatchMode.nameAlias =>
                    i18n.novel_tts_mode_alias_hint,
                  PronunciationMatchMode.force =>
                    i18n.novel_tts_mode_force_warning,
                },
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: _mode == PronunciationMatchMode.force
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(i18n.cancel),
        ),
        FilledButton(
          key: novelTtsReadingSaveKey,
          onPressed: () {
            final next = NovelTtsReading(
              surface: _surface.text,
              reading: _reading.text,
              mode: _mode,
            ).trimmed();
            if (!next.isValid) {
              return;
            }
            Navigator.of(context).pop(next);
          },
          child: Text(i18n.novel_tts_reading_save),
        ),
      ],
    );
  }
}

class _BulkReadingDialog extends StatefulWidget {
  const _BulkReadingDialog();

  @override
  State<_BulkReadingDialog> createState() => _BulkReadingDialogState();
}

class _BulkReadingDialogState extends State<_BulkReadingDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);
    return AlertDialog(
      title: Text(i18n.novel_tts_reading_bulk),
      content: TextField(
        controller: _controller,
        minLines: 6,
        maxLines: 12,
        decoration: InputDecoration(
          hintText: i18n.novel_tts_reading_bulk_hint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(i18n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(i18n.novel_tts_reading_save),
        ),
      ],
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
