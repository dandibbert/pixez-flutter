import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/page/novel/tts/novel_tts_controller.dart';
import 'package:pixez/page/novel/tts/novel_tts_engine.dart';
import 'package:pixez/page/novel/tts/novel_tts_diagnostics.dart';
import 'package:pixez/page/novel/tts/novel_tts_variables_editor.dart';
import 'package:pixez/page/novel/tts/novel_tts_preview.dart';
import 'package:pixez/page/novel/tts/novel_tts_template.dart';
import 'package:pixez/i18n.dart';
import 'package:pixez/page/novel/tts/novel_tts_form.dart';
import 'package:pixez/page/novel/tts/novel_tts_readings.dart';
import 'package:pixez/page/novel/tts/novel_tts_settings.dart';
import 'package:pixez/page/novel/tts/pronunciation/diagnostics/pronunciation_preview.dart';
import 'package:pixez/page/novel/tts/pronunciation/matching/pronunciation_compiler.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_decision.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_rule.dart';
import 'package:pixez/page/novel/tts/pronunciation/storage/pronunciation_migration.dart';
import 'package:pixez/page/novel/tts/pronunciation/storage/pronunciation_repository.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';

const Key novelTtsCustomBodyFieldKey = Key('novelTtsCustomBodyField');
const Key novelTtsBodyPlaceholdersKey = Key('novelTtsBodyPlaceholders');
const Key novelTtsPreviewTextFieldKey = Key('novelTtsPreviewTextField');
const Key novelTtsRequestDetailsKey = Key('novelTtsRequestDetails');
const Key novelTtsRequestTextKey = Key('novelTtsRequestText');
const Key novelTtsPreviewErrorKey = Key('novelTtsPreviewError');
const Key novelTtsSaveVoiceKey = Key('novelTtsSaveVoice');
const Key novelTtsVoiceNameKey = Key('novelTtsVoiceName');
const Key novelTtsVoicePresetsKey = Key('novelTtsVoicePresets');
const Key novelTtsCustomVoiceKey = Key('novelTtsCustomVoice');
const Key novelTtsPreviewVoiceKey = Key('novelTtsPreviewVoice');
const Key novelTtsSaveStatusKey = Key('novelTtsSaveStatus');
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
const Key novelTtsReadingPreviewFieldKey = Key('novelTtsReadingPreview');
const Key novelTtsReadingPreviewSpokenKey = Key('novelTtsReadingPreviewSpoken');

class NovelTtsPage extends StatefulWidget {
  const NovelTtsPage({super.key, this.initial, this.previewFactory});

  final NovelTtsSettings? initial;
  final NovelTtsPreview Function()? previewFactory;

  @override
  State<NovelTtsPage> createState() => _NovelTtsPageState();
}

class _NovelTtsPageState extends State<NovelTtsPage> {
  late NovelTtsSettings _settings;
  final _fields = <String, TextEditingController>{};
  Timer? _persistTimer;
  late String _lastEnqueuedJson;
  int _saveRevision = 0;
  int _previewGeneration = 0;
  late final String _initialPlaybackConfig;
  bool _saving = false;
  bool _saveFailed = false;
  bool _previewRunning = false;
  Object? _previewError;
  String? _previewErrorStage;
  NovelTtsSettings? _previewErrorSettings;
  late Map<String, String> _customVariables;
  int _variablesRevision = 0;
  bool _variablesValid = true;
  bool _revealSecrets = false;
  NovelTtsPreview? _preview;

  TextEditingController _field(String name) => _fields[name]!;

  @override
  void initState() {
    super.initState();
    _settings = widget.initial ?? NovelTtsSettings.load();
    _customVariables = Map.of(_settings.customTemplateVariables);
    final values = _settings.toJson();
    for (final name in [
      'splitChars',
      'microsoftKey',
      'microsoftRegion',
      'microsoftVoice',
      'microsoftLanguage',
      'microsoftRate',
      'openaiBaseUrl',
      'openaiApiKey',
      'openaiModel',
      'openaiVoice',
      'openaiSpeed',
      'customUrl',
      'customHeaders',
      'customBody',
      'customContentType',
    ]) {
      _fields[name] = TextEditingController(text: '${values[name]}');
    }
    _fields['preview'] = TextEditingController();
    _initialPlaybackConfig = _playbackConfig(_draft());
    _lastEnqueuedJson = jsonEncode(_draft().toJson());
  }

  @override
  void dispose() {
    _persistTimer?.cancel();
    _previewGeneration++;
    // A popped page has already enqueued its final draft. Do not enqueue that
    // stale snapshot again after another entry point has changed the voice.
    final draft = _draft();
    if (jsonEncode(draft.toJson()) != _lastEnqueuedJson) {
      unawaited(_persist(draft, updateState: false));
    }
    unawaited(_preview?.dispose());
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    setState(() {
      _saving = true;
      _previewError = null;
    });
    _persistTimer = Timer(const Duration(milliseconds: 350), () {
      unawaited(_persist(_draft()));
    });
  }

  Future<void> _persist(
    NovelTtsSettings next, {
    bool updateState = true,
  }) async {
    _persistTimer?.cancel();
    _settings = next;
    _lastEnqueuedJson = jsonEncode(next.toJson());
    final revision = ++_saveRevision;
    if (updateState && mounted) setState(() => _saving = true);
    try {
      // Enqueue immediately in the shared settings store, including writes from
      // the reading bar. A second page-local queue could overwrite newer input.
      await next.save();
      if (mounted && updateState && revision == _saveRevision) {
        setState(() {
          _saving = false;
          _saveFailed = false;
        });
      }
    } catch (_) {
      if (mounted && updateState && revision == _saveRevision) {
        setState(() {
          _saving = false;
          _saveFailed = true;
        });
      }
    }
  }

  NovelTtsSettings _draft() {
    final values = _settings.toJson();
    for (final entry in _fields.entries) {
      if (entry.key != 'preview' &&
          entry.key != 'splitChars' &&
          entry.key != 'openaiSpeed')
        values[entry.key] = entry.value.text;
    }
    values['customVariables'] = _customVariables;
    values['splitChars'] =
        int.tryParse(_field('splitChars').text.trim()) ?? _settings.splitChars;
    values['openaiSpeed'] =
        double.tryParse(_field('openaiSpeed').text.trim()) ??
        _settings.openaiSpeed;
    return NovelTtsSettings.fromJson(values);
  }

  void _syncVoiceFields(NovelTtsSettings next) {
    _customVariables = Map.of(next.customTemplateVariables);
    _variablesRevision++;
    _variablesValid = true;
    final values = next.toJson();
    for (final name in [
      'microsoftVoice',
      'microsoftLanguage',
      'microsoftRate',
      'openaiVoice',
      'openaiModel',
      'openaiSpeed',
    ]) {
      _field(name).text = '${values[name]}';
    }
  }

  Future<void> _setReadings(List<NovelTtsReading> readings) async {
    await _persist(_draft().copyWith(readings: readings));
    await PronunciationRepository().replaceFromSettings(readings);
  }

  Future<void> _saveVoice() async {
    final draft = _draft();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _VoiceNameDialog(initial: draft.activeVoice),
    );
    if (!mounted || name == null) return;
    await _persist(_draft().saveVoicePreset(name));
  }

  Future<void> _previewVoice() async {
    if (_previewRunning) {
      _previewGeneration++;
      await _preview?.stop();
      if (mounted) setState(() => _previewRunning = false);
      return;
    }
    final generation = ++_previewGeneration;
    final i18n = I18n.of(context);
    final sample = _field('preview').text.trim();
    final text = sample.isEmpty ? i18n.novel_tts_preview_sample : sample;
    final settings = _draft();
    try {
      // Validate before pausing current playback or starting a network request.
      buildNovelTtsRequest(settings, text);
    } catch (error) {
      setState(() {
        _previewError = error;
        _previewErrorStage = i18n.novel_tts_stage_request;
        _previewErrorSettings = settings;
      });
      return;
    }
    setState(() {
      _previewRunning = true;
      _previewError = null;
    });
    try {
      await NovelTtsController.maybeInstance?.pause();
      if (!mounted || generation != _previewGeneration) return;
      _preview ??= widget.previewFactory?.call() ?? NovelTtsPreview();
      await _preview!.play(settings, text);
    } catch (error) {
      if (mounted && generation == _previewGeneration) {
        setState(() {
          _previewError = error;
          _previewErrorStage = i18n.novel_tts_stage_preview;
          _previewErrorSettings = settings;
        });
      }
    } finally {
      if (mounted && generation == _previewGeneration) {
        setState(() => _previewRunning = false);
      }
    }
  }

  String _playbackConfig(NovelTtsSettings settings) =>
      jsonEncode(settings.toJson()..remove('voicePresets'));

  Future<void> _finishEditing() async {
    _previewGeneration++;
    final draft = _draft();
    await _persist(draft);
    await _preview?.stop();
    if (_playbackConfig(draft) != _initialPlaybackConfig) {
      await NovelTtsController.maybeInstance?.applySettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);
    final draft = _draft();
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) unawaited(_finishEditing());
      },
      child: Scaffold(
        key: novelTtsSettingsPageKey,
        appBar: AppBar(title: Text(i18n.novel_tts_settings)),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      key: novelTtsSaveStatusKey,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        _saveFailed
                            ? Icons.error_outline
                            : _saving
                            ? Icons.sync
                            : Icons.check_circle_outline,
                      ),
                      title: Text(
                        !_variablesValid
                            ? i18n.novel_tts_variables_invalid
                            : _saveFailed
                            ? i18n.novel_tts_save_failed
                            : _saving
                            ? i18n.novel_tts_saving
                            : i18n.novel_tts_saved,
                      ),
                      subtitle: Text(i18n.novel_tts_settings_apply_hint),
                      onTap: _saveFailed ? () => _persist(_draft()) : null,
                    ),
                    _Section(
                      title: i18n.novel_tts_connection,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(i18n.novel_tts_connection_hint),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final provider in NovelTtsProvider.values)
                                _ProviderChip(
                                  key: switch (provider) {
                                    NovelTtsProvider.microsoft =>
                                      novelTtsProviderMicrosoftKey,
                                    NovelTtsProvider.openai =>
                                      novelTtsProviderOpenaiKey,
                                    NovelTtsProvider.custom =>
                                      novelTtsProviderCustomKey,
                                  },
                                  selected: _settings.provider == provider,
                                  label: switch (provider) {
                                    NovelTtsProvider.microsoft =>
                                      i18n.novel_tts_provider_microsoft,
                                    NovelTtsProvider.openai =>
                                      i18n.novel_tts_provider_openai,
                                    NovelTtsProvider.custom =>
                                      i18n.novel_tts_provider_custom,
                                  },
                                  onTap: () {
                                    _variablesValid = true;
                                    unawaited(
                                      _persist(
                                        _draft().copyWith(provider: provider),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ..._connectionFields(i18n),
                        ],
                      ),
                    ),
                    _Section(
                      title: _settings.provider == NovelTtsProvider.custom
                          ? i18n.novel_tts_variables
                          : i18n.novel_tts_section_voice,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            i18n.novel_tts_voice_presets,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            i18n.novel_tts_voice_presets_hint,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            key: novelTtsVoicePresetsKey,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final preset in draft.activeVoicePresets)
                                InputChip(
                                  label: Text(preset.name),
                                  selected: draft.isVoicePresetSelected(preset),
                                  onPressed: () {
                                    final next = _draft().selectVoicePreset(
                                      preset,
                                    );
                                    _syncVoiceFields(next);
                                    unawaited(_persist(next));
                                  },
                                  deleteButtonTooltipMessage:
                                      i18n.novel_tts_delete_voice,
                                  onDeleted: () => _persist(
                                    _draft().removeVoicePreset(preset),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ..._voiceFields(i18n),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              key: novelTtsSaveVoiceKey,
                              onPressed: _variablesValid ? _saveVoice : null,
                              icon: const Icon(Icons.add),
                              label: Text(i18n.novel_tts_save_voice),
                            ),
                          ),
                          const Divider(height: 32),
                          TextField(
                            key: novelTtsPreviewTextFieldKey,
                            controller: _field('preview'),
                            onChanged: (_) => setState(() {}),
                            minLines: 2,
                            maxLines: 4,
                            maxLength: 160,
                            decoration: InputDecoration(
                              labelText: i18n.novel_tts_preview_text,
                              hintText: i18n.novel_tts_preview_sample,
                              helperText: i18n.novel_tts_preview_hint,
                              helperMaxLines: 5,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          _requestDetails(i18n),
                          if (_previewError != null)
                            _diagnosticText(
                              '${_previewErrorStage ?? i18n.novel_tts_stage_preview}\n'
                              '${describeNovelTtsError(_previewError!, _previewErrorSettings ?? draft, revealSecrets: _revealSecrets)}',
                              textKey: novelTtsPreviewErrorKey,
                              error: true,
                            ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FilledButton.tonalIcon(
                              key: novelTtsPreviewVoiceKey,
                              onPressed: _previewRunning || _variablesValid
                                  ? _previewVoice
                                  : null,
                              icon: Icon(
                                _previewRunning
                                    ? Icons.stop
                                    : Icons.volume_up_outlined,
                              ),
                              label: Text(
                                _previewRunning
                                    ? i18n.novel_tts_stop
                                    : i18n.novel_tts_preview_voice,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _Section(
                      title: i18n.novel_tts_section_playback,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            key: novelTtsSplitCharsFieldKey,
                            controller: _field('splitChars'),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            decoration: InputDecoration(
                              labelText: i18n.novel_tts_split_chars,
                              helperText: i18n.novel_tts_split_range,
                              helperMaxLines: 3,
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (_) => _schedulePersist(),
                            onEditingComplete: _commitSplitChars,
                            onSubmitted: (_) => _commitSplitChars(),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${i18n.novel_tts_prefetch}: ${_settings.prefetchCount}',
                          ),
                          Text(
                            i18n.novel_tts_prefetch_hint,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Slider(
                            value: _settings.prefetchCount
                                .clamp(1, 4)
                                .toDouble(),
                            min: 1,
                            max: 4,
                            divisions: 3,
                            label: '${_settings.prefetchCount}',
                            onChanged: (value) => _persist(
                              _draft().copyWith(prefetchCount: value.round()),
                            ),
                          ),
                          SwitchListTile(
                            key: novelTtsAutoContinueKey,
                            contentPadding: EdgeInsets.zero,
                            title: Text(i18n.novel_tts_auto_continue),
                            subtitle: Text(i18n.novel_tts_lock_screen_hint),
                            value: _settings.autoContinue,
                            onChanged: (value) => _persist(
                              _draft().copyWith(autoContinue: value),
                            ),
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
                            i18n.novel_tts_analyzer_lexicon,
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
            ),
          ),
        ),
      ),
    );
  }

  void _commitSplitChars() {
    final next = _draft();
    _field('splitChars').text = '${next.clampedSplitChars}';
    FocusScope.of(context).unfocus();
    unawaited(_persist(next));
  }

  List<Widget> _connectionFields(AppLocalizations i18n) {
    switch (_settings.provider) {
      case NovelTtsProvider.microsoft:
        return [
          _box('microsoftKey', i18n.novel_tts_microsoft_key, obscure: true),
          _choice(
            'microsoftRegion',
            i18n.novel_tts_microsoft_region,
            microsoftRegionChoices,
          ),
        ];
      case NovelTtsProvider.openai:
        return [
          _box('openaiBaseUrl', i18n.novel_tts_openai_base_url, url: true),
          _box('openaiApiKey', i18n.novel_tts_openai_api_key, obscure: true),
        ];
      case NovelTtsProvider.custom:
        return _customConnection(i18n);
    }
  }

  List<Widget> _voiceFields(AppLocalizations i18n) {
    switch (_settings.provider) {
      case NovelTtsProvider.microsoft:
        final rate = parseMicrosoftRatePercent(_field('microsoftRate').text);
        return [
          NovelTtsChoiceField(
            label: i18n.novel_tts_microsoft_voice,
            controller: _field('microsoftVoice'),
            choices: microsoftVoiceChoices,
            onChanged: (value) {
              final language = languageFromMicrosoftVoice(value);
              if (language != null) _field('microsoftLanguage').text = language;
              _schedulePersist();
            },
          ),
          _choice(
            'microsoftLanguage',
            i18n.novel_tts_microsoft_language,
            microsoftLanguageChoices,
          ),
          Text(
            '${i18n.novel_tts_microsoft_rate}: ${formatMicrosoftRatePercent(rate)}',
          ),
          Slider(
            value: rate,
            min: -50,
            max: 50,
            divisions: 20,
            label: formatMicrosoftRatePercent(rate),
            onChanged: (value) {
              _field('microsoftRate').text = formatMicrosoftRatePercent(value);
              _schedulePersist();
            },
          ),
        ];
      case NovelTtsProvider.openai:
        final speed = _draft().openaiSpeed;
        return [
          _choice(
            'openaiVoice',
            i18n.novel_tts_openai_voice,
            openaiVoiceChoices,
          ),
          _choice(
            'openaiModel',
            i18n.novel_tts_openai_model,
            openaiModelChoices,
          ),
          Text('${i18n.novel_tts_openai_speed}: ${speed.toStringAsFixed(2)}×'),
          Slider(
            value: speed,
            min: 0.25,
            max: 4,
            divisions: 15,
            label: '${speed.toStringAsFixed(2)}×',
            onChanged: (value) {
              _field('openaiSpeed').text = value.toStringAsFixed(2);
              _schedulePersist();
            },
          ),
        ];
      case NovelTtsProvider.custom:
        return [
          NovelTtsVariablesEditor(
            key: ValueKey(_variablesRevision),
            initial: _customVariables,
            legacyVoiceFieldKey: novelTtsCustomVoiceKey,
            onValidityChanged: (valid) =>
                setState(() => _variablesValid = valid),
            onChanged: (variables) {
              _customVariables = variables;
              _schedulePersist();
            },
          ),
        ];
    }
  }

  List<Widget> _customConnection(AppLocalizations i18n) {
    final url = _field('customUrl').text.trim();
    final uri = Uri.tryParse(url);
    final validUrl =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
    final hasText =
        novelTtsTemplateHasTextPlaceholder(url) ||
        (_settings.customMethod == 'POST' &&
            novelTtsTemplateHasTextPlaceholder(_field('customBody').text));
    return [
      _box(
        'customUrl',
        i18n.novel_tts_custom_url,
        fieldKey: novelTtsCustomUrlFieldKey,
        minLines: 2,
        url: true,
        helper: i18n.novel_tts_custom_url_hint,
        error: url.isNotEmpty && !validUrl
            ? i18n.novel_tts_url_invalid
            : !hasText
            ? i18n.novel_tts_text_required
            : null,
      ),
      NovelTtsPlaceholderChips(
        caption: i18n.novel_tts_insert_placeholder,
        names: _variableNames,
        onInsert: (token) {
          insertNovelTtsToken(_field('customUrl'), token);
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
          if (value != null)
            unawaited(_persist(_draft().copyWith(customMethod: value)));
        },
      ),
      NovelTtsAdvancedPanel(
        title: i18n.novel_tts_advanced,
        children: [
          Text(
            i18n.novel_tts_custom_headers,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          NovelTtsHeaderListEditor(
            initial: _field('customHeaders').text,
            nameLabel: i18n.novel_tts_header_name,
            valueLabel: i18n.novel_tts_header_value,
            addLabel: i18n.novel_tts_header_add,
            onChanged: (raw) {
              _field('customHeaders').text = raw;
              unawaited(_persist(_draft()));
            },
          ),
          if (_settings.customMethod == 'GET')
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(i18n.novel_tts_get_body_ignored),
            ),
          _box(
            'customBody',
            i18n.novel_tts_custom_body,
            minLines: 3,
            fieldKey: novelTtsCustomBodyFieldKey,
          ),
          NovelTtsPlaceholderChips(
            key: novelTtsBodyPlaceholdersKey,
            caption: i18n.novel_tts_insert_placeholder,
            names: _variableNames,
            useTextKey: false,
            onInsert: (token) {
              insertNovelTtsToken(_field('customBody'), token);
              _schedulePersist();
            },
          ),
          _choice(
            'customContentType',
            i18n.novel_tts_custom_content_type,
            contentTypeChoices,
          ),
        ],
      ),
    ];
  }

  Set<String> get _variableNames => {
    'text',
    ..._customVariables.keys,
    ...novelTtsTemplateVariableNames(_field('customUrl').text),
    ...novelTtsTemplateVariableNames(_field('customBody').text),
    ...novelTtsTemplateVariableNames(_field('customHeaders').text),
  };

  Widget _requestDetails(AppLocalizations i18n) {
    final sample = _field('preview').text.trim();
    final text = sample.isEmpty ? i18n.novel_tts_preview_sample : sample;
    final settings = _draft();
    String details;
    try {
      if (!_variablesValid) {
        throw FormatException(i18n.novel_tts_variables_invalid);
      }
      final request = buildNovelTtsRequest(settings, text);
      details = describeNovelTtsRequest(request, revealSecrets: _revealSecrets);
    } catch (error) {
      details =
          '${i18n.novel_tts_stage_request}\n'
          '${describeNovelTtsError(error, settings, revealSecrets: _revealSecrets)}';
    }
    return NovelTtsAdvancedPanel(
      title: i18n.novel_tts_request_details,
      toggleKey: novelTtsRequestDetailsKey,
      children: [
        Text(i18n.novel_tts_request_hint),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(i18n.novel_tts_reveal_secrets),
          value: _revealSecrets,
          onChanged: (value) => setState(() => _revealSecrets = value),
        ),
        _diagnosticText(details, textKey: novelTtsRequestTextKey),
      ],
    );
  }

  Widget _diagnosticText(
    String details, {
    required Key textKey,
    bool error = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelectableText(
          details,
          key: textKey,
          style: TextStyle(
            color: error ? Theme.of(context).colorScheme.error : null,
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            icon: const Icon(Icons.copy_outlined),
            label: Text(I18n.of(context).novel_tts_copy_details),
            onPressed: () => Clipboard.setData(ClipboardData(text: details)),
          ),
        ),
      ],
    ),
  );

  Widget _choice(String name, String label, List<NovelTtsChoice> choices) =>
      NovelTtsChoiceField(
        label: label,
        controller: _field(name),
        choices: choices,
        onChanged: (_) => _schedulePersist(),
      );

  Widget _box(
    String name,
    String label, {
    Key? fieldKey,
    bool obscure = false,
    int minLines = 1,
    bool url = false,
    String? helper,
    String? error,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: fieldKey,
        controller: _field(name),
        obscureText: obscure,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: url ? TextInputType.url : null,
        minLines: minLines,
        maxLines: minLines > 1 ? minLines + 2 : 1,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 5,
          errorText: error,
          errorMaxLines: 4,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => _schedulePersist(),
        onEditingComplete: () => _persist(_draft()),
        onSubmitted: (_) => _persist(_draft()),
      ),
    );
  }
}

class _VoiceNameDialog extends StatefulWidget {
  const _VoiceNameDialog({required this.initial});
  final String initial;

  @override
  State<_VoiceNameDialog> createState() => _VoiceNameDialogState();
}

class _VoiceNameDialogState extends State<_VoiceNameDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);
    return AlertDialog(
      title: Text(i18n.novel_tts_save_voice),
      content: SingleChildScrollView(
        child: TextField(
          key: novelTtsVoiceNameKey,
          controller: _name,
          autofocus: true,
          maxLength: 48,
          decoration: InputDecoration(
            labelText: i18n.novel_tts_voice_name,
            hintText: i18n.novel_tts_voice_name_hint,
            helperText: i18n.novel_tts_voice_name_exists,
            helperMaxLines: 4,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            if (_name.text.trim().isNotEmpty)
              Navigator.pop(context, _name.text.trim());
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(i18n.cancel),
        ),
        FilledButton(
          onPressed: _name.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, _name.text.trim()),
          child: Text(i18n.novel_tts_reading_save),
        ),
      ],
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
        else ...[
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
    final mode =
        reading.mode ??
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
  late final TextEditingController _previewSource;
  late PronunciationMatchMode _mode;
  final _previewer = PronunciationPreview();
  PronunciationPreviewResult? _preview;
  Timer? _previewTimer;
  var _previewSourceEdited = false;
  var _previewGeneration = 0;
  var _modeEdited = false;

  @override
  void initState() {
    super.initState();
    _surface = TextEditingController(text: widget.initial?.surface ?? '');
    _reading = TextEditingController(text: widget.initial?.reading ?? '');
    _modeEdited = widget.initial?.mode != null;
    _mode = widget.initial?.mode ?? _modeForSurface(_surface.text);
    _previewSource = TextEditingController(
      text: defaultPronunciationPreviewText(_surface.text),
    );
    _schedulePreview();
  }

  /// A written form long enough to be unambiguous is replaced verbatim; a lone
  /// kanji is a name that has to survive `悟った`, so it goes through the
  /// disambiguator instead.
  PronunciationMatchMode _modeForSurface(String surface) {
    final trimmed = surface.trim();
    if (trimmed.isEmpty) {
      return PronunciationMatchMode.exactPhrase;
    }
    return const PronunciationMigration().classifyV1Surface(trimmed).mode;
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _surface.dispose();
    _reading.dispose();
    _previewSource.dispose();
    super.dispose();
  }

  void _onRuleChanged() {
    if (!_previewSourceEdited) {
      _previewSource.text = defaultPronunciationPreviewText(_surface.text);
    }
    if (!_modeEdited) {
      final auto = _modeForSurface(_surface.text);
      if (auto != _mode) {
        setState(() => _mode = auto);
      }
    }
    _schedulePreview();
  }

  void _schedulePreview() {
    _previewTimer?.cancel();
    _previewTimer = Timer(const Duration(milliseconds: 250), _runPreview);
  }

  Future<void> _runPreview() async {
    final rule = NovelTtsReading(
      surface: _surface.text,
      reading: _reading.text,
      mode: _mode,
    ).trimmed();
    final source = _previewSource.text;
    if (!rule.isValid || source.trim().isEmpty) {
      if (mounted) {
        setState(() => _preview = null);
      }
      return;
    }
    final generation = ++_previewGeneration;
    final snapshot = PronunciationCompiler().compile(
      const PronunciationMigration().migrateV1([rule]),
    );
    PronunciationPreviewResult? result;
    try {
      result = await _previewer.preview(source: source, snapshot: snapshot);
    } catch (_) {
      // A preview that cannot be produced shows nothing. Saving the rule is
      // still the user's call, and the pipeline degrades on its own at read
      // time, so there is nothing here worth blocking the dialog over.
    }
    if (!mounted || generation != _previewGeneration) {
      return;
    }
    setState(() => _preview = result);
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
              onChanged: (_) => _onRuleChanged(),
            ),
            const SizedBox(height: 12),
            TextField(
              key: novelTtsReadingValueFieldKey,
              controller: _reading,
              decoration: InputDecoration(
                labelText: i18n.novel_tts_reading_value,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => _onRuleChanged(),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PronunciationMatchMode>(
              // The field keeps its own value, so it has to be rebuilt when the
              // surface picks a different mode for the user.
              key: ValueKey(_mode),
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
                  setState(() {
                    _mode = value;
                    _modeEdited = true;
                  });
                  _onRuleChanged();
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
            const SizedBox(height: 16),
            TextField(
              key: novelTtsReadingPreviewFieldKey,
              controller: _previewSource,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: i18n.novel_tts_preview_source,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                _previewSourceEdited = true;
                _schedulePreview();
              },
            ),
            if (_preview case final preview?) _PreviewReport(preview: preview),
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

class _PreviewReport extends StatelessWidget {
  const _PreviewReport({required this.preview});

  final PronunciationPreviewResult preview;

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);
    final theme = Theme.of(context);
    final decisions = [...preview.resolved.allDecisions]
      ..sort((a, b) => a.start.compareTo(b.start));
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${i18n.novel_tts_preview_spoken}: ${preview.spoken}',
            key: novelTtsReadingPreviewSpokenKey,
            style: theme.textTheme.bodyMedium,
          ),
          for (final decision in decisions)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${decision.surface} · '
                '${decision.isApplied ? i18n.novel_tts_preview_applied : i18n.novel_tts_preview_skipped}'
                ' · ${_reasonLabel(i18n, decision.reason)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: decision.isApplied
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _reasonLabel(AppLocalizations i18n, PronunciationReason reason) {
    switch (reason) {
      case PronunciationReason.explicitRuby:
        return i18n.novel_tts_reason_ruby;
      case PronunciationReason.exactPhrase:
        return i18n.novel_tts_mode_exact;
      case PronunciationReason.forcedRule:
        return i18n.novel_tts_mode_force;
      case PronunciationReason.morphologyProperName:
      case PronunciationReason.nameParticleContext:
      case PronunciationReason.quotativeNameContext:
      case PronunciationReason.aliasWithoutConflict:
        return i18n.novel_tts_reason_name;
      case PronunciationReason.rejectedVerbOrAdjective:
      case PronunciationReason.rejectedInflectionSuffix:
        return i18n.novel_tts_reason_verb;
      case PronunciationReason.rejectedInsideLargerToken:
        return i18n.novel_tts_reason_word;
      case PronunciationReason.rejectedOverlap:
      case PronunciationReason.rejectedLowConfidence:
      case PronunciationReason.analyzerUnavailable:
      case PronunciationReason.analyzerTimeout:
      case PronunciationReason.invalidAnalyzerOffsets:
      case PronunciationReason.invalidSourceRange:
      case PronunciationReason.staleSession:
        return i18n.novel_tts_reason_uncertain;
    }
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
