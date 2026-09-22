import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:pixez/er/prefer.dart';
import 'package:pixez/page/novel/tts/novel_tts_endpoint.dart';
import 'package:pixez/page/novel/tts/novel_tts_readings.dart';
import 'package:pixez/page/novel/tts/novel_tts_template.dart';

enum NovelTtsProvider { microsoft, openai, custom }

class NovelTtsSettings {
  static const prefKey = 'novel_tts_settings_json';
  static Future<void>? _writeQueue;
  static NovelTtsSettings? _pendingSettings;
  static int _saveRevision = 0;
  static const defaultSplitChars = 200;
  static const minSplitChars = 20;
  static const maxSplitChars = 800;
  static const defaultCustomUrl =
      'https://tts.773421.xyz/tts?t={text}&v={voice}';

  const NovelTtsSettings({
    this.provider = NovelTtsProvider.custom,
    this.splitChars = defaultSplitChars,
    this.autoContinue = true,
    this.prefetchCount = 4,
    this.microsoftKey = '',
    this.microsoftRegion = 'eastasia',
    this.microsoftVoice = 'zh-CN-XiaoxiaoNeural',
    this.microsoftLanguage = 'zh-CN',
    this.microsoftRate = '+0%',
    this.openaiBaseUrl = 'https://api.openai.com/v1',
    this.openaiApiKey = '',
    this.openaiModel = 'tts-1',
    this.openaiVoice = 'alloy',
    this.openaiSpeed = 1.0,
    this.customUrl = defaultCustomUrl,
    this.customMethod = 'GET',
    this.customVoice = '',
    this.customLanguage = 'zh-CN',
    this.customSpeed = '+0%',
    this.customModel = 'tts-1',
    Map<String, String>? customVariables,
    this.voicePresets = const [],
    this.customHeaders = '',
    this.customBody = '',
    this.customContentType = '',
    this.readings = const [],
  }) : _customVariables = customVariables;

  final NovelTtsProvider provider;
  final int splitChars;
  final bool autoContinue;
  final int prefetchCount;
  final String microsoftKey;
  final String microsoftRegion;
  final String microsoftVoice;
  final String microsoftLanguage;
  final String microsoftRate;
  final String openaiBaseUrl;
  final String openaiApiKey;
  final String openaiModel;
  final String openaiVoice;
  final double openaiSpeed;
  final String customUrl;
  final String customMethod;
  final String customVoice;
  final String customLanguage;
  final String customSpeed;
  final String customModel;
  final Map<String, String>? _customVariables;
  final List<NovelTtsVoicePreset> voicePresets;
  final String customHeaders;
  final String customBody;
  final String customContentType;
  final List<NovelTtsReading> readings;

  NovelTtsSettings copyWith({
    NovelTtsProvider? provider,
    int? splitChars,
    bool? autoContinue,
    int? prefetchCount,
    String? microsoftKey,
    String? microsoftRegion,
    String? microsoftVoice,
    String? microsoftLanguage,
    String? microsoftRate,
    String? openaiBaseUrl,
    String? openaiApiKey,
    String? openaiModel,
    String? openaiVoice,
    double? openaiSpeed,
    String? customUrl,
    String? customMethod,
    String? customVoice,
    String? customLanguage,
    String? customSpeed,
    String? customModel,
    Map<String, String>? customVariables,
    List<NovelTtsVoicePreset>? voicePresets,
    String? customHeaders,
    String? customBody,
    String? customContentType,
    List<NovelTtsReading>? readings,
  }) {
    return NovelTtsSettings(
      provider: provider ?? this.provider,
      splitChars: splitChars ?? this.splitChars,
      autoContinue: autoContinue ?? this.autoContinue,
      prefetchCount: prefetchCount ?? this.prefetchCount,
      microsoftKey: microsoftKey ?? this.microsoftKey,
      microsoftRegion: microsoftRegion ?? this.microsoftRegion,
      microsoftVoice: microsoftVoice ?? this.microsoftVoice,
      microsoftLanguage: microsoftLanguage ?? this.microsoftLanguage,
      microsoftRate: microsoftRate ?? this.microsoftRate,
      openaiBaseUrl: openaiBaseUrl ?? this.openaiBaseUrl,
      openaiApiKey: openaiApiKey ?? this.openaiApiKey,
      openaiModel: openaiModel ?? this.openaiModel,
      openaiVoice: openaiVoice ?? this.openaiVoice,
      openaiSpeed: openaiSpeed ?? this.openaiSpeed,
      customUrl: customUrl ?? this.customUrl,
      customMethod: customMethod ?? this.customMethod,
      customVoice: customVoice ?? this.customVoice,
      customLanguage: customLanguage ?? this.customLanguage,
      customSpeed: customSpeed ?? this.customSpeed,
      customModel: customModel ?? this.customModel,
      customVariables: customVariables ?? _customVariables,
      voicePresets: voicePresets ?? this.voicePresets,
      customHeaders: customHeaders ?? this.customHeaders,
      customBody: customBody ?? this.customBody,
      customContentType: customContentType ?? this.customContentType,
      readings: readings ?? this.readings,
    );
  }

  /// A missing map is a legacy settings object. An explicitly empty map is
  /// authoritative: deleting all variables must not resurrect legacy fields.
  Set<String> get _legacyVariableNames => _referencedCustomVariables(
    url: customUrl,
    method: customMethod,
    body: customBody,
    headers: customHeaders,
  );

  Map<String, String> get customVariables {
    if (_customVariables case final variables?) return variables;
    final legacy = {
      'voice': customVoice.trim(),
      'voicename': customVoice.trim(),
      'lang': customLanguage.trim(),
      'language': customLanguage.trim(),
      'speed': customSpeed,
      'model': customModel,
      'region': microsoftRegion,
    };
    final referenced = _legacyVariableNames;
    return {
      for (final entry in legacy.entries)
        if (referenced.contains(entry.key)) entry.key: entry.value,
    };
  }

  Map<String, String> get customTemplateVariables => {
    for (final entry in customVariables.entries)
      if (entry.key.toLowerCase() != 'text')
        entry.key.toLowerCase(): entry.value,
  };

  int get clampedSplitChars =>
      splitChars.clamp(minSplitChars, maxSplitChars).toInt();

  String get activeVoice {
    switch (provider) {
      case NovelTtsProvider.microsoft:
        return microsoftVoice.trim();
      case NovelTtsProvider.openai:
        return openaiVoice.trim();
      case NovelTtsProvider.custom:
        return customTemplateVariables['voice'] ?? '';
    }
  }

  String get activeLanguage {
    switch (provider) {
      case NovelTtsProvider.microsoft:
        return microsoftLanguage.trim();
      case NovelTtsProvider.openai:
        return microsoftLanguage.trim();
      case NovelTtsProvider.custom:
        return customTemplateVariables['lang'] ?? '';
    }
  }

  /// Voice presets share connection credentials and are scoped to an endpoint.
  /// Hashing avoids copying URLs containing access tokens into preset metadata.
  String get voiceEndpointKey {
    final endpoint = switch (provider) {
      NovelTtsProvider.microsoft => microsoftRegion.trim().toLowerCase(),
      NovelTtsProvider.openai => resolveNovelTtsOpenaiEndpoint(openaiBaseUrl),
      NovelTtsProvider.custom => customUrl.trim(),
    };
    return sha256.convert(utf8.encode('${provider.name}:$endpoint')).toString();
  }

  List<NovelTtsVoicePreset> get activeVoicePresets => [
    for (final preset in voicePresets)
      if (preset.endpointKey == voiceEndpointKey) preset,
  ];

  NovelTtsVoicePreset voicePreset(String name) => NovelTtsVoicePreset(
    name: name.trim(),
    endpointKey: voiceEndpointKey,
    voice: provider == NovelTtsProvider.custom ? '' : activeVoice,
    language: provider == NovelTtsProvider.microsoft ? activeLanguage : '',
    speed: switch (provider) {
      NovelTtsProvider.microsoft => microsoftRate,
      NovelTtsProvider.openai => openaiSpeed.toString(),
      NovelTtsProvider.custom => '',
    },
    model: provider == NovelTtsProvider.openai ? openaiModel : '',
    variables: provider == NovelTtsProvider.custom
        ? customTemplateVariables
        : null,
  );

  Map<String, String> _presetVariables(NovelTtsVoicePreset preset) {
    if (preset.variables case final variables?) return variables;
    final legacy = {
      'voice': preset.voice,
      'voicename': preset.voice,
      'lang': preset.language,
      'language': preset.language,
      'speed': preset.speed,
      'model': preset.model,
      'region': microsoftRegion,
    };
    final referenced = _legacyVariableNames;
    return {
      for (final entry in legacy.entries)
        if (referenced.contains(entry.key)) entry.key: entry.value,
    };
  }

  bool isVoicePresetSelected(NovelTtsVoicePreset preset) {
    if (preset.endpointKey != voiceEndpointKey) return false;
    if (provider == NovelTtsProvider.custom) {
      final variables = customTemplateVariables;
      final saved = _presetVariables(preset);
      return variables.length == saved.length &&
          variables.entries.every((entry) => saved[entry.key] == entry.value);
    }
    final current = voicePreset(preset.name);
    return current.voice == preset.voice &&
        current.language == preset.language &&
        current.speed == preset.speed &&
        current.model == preset.model;
  }

  NovelTtsSettings saveVoicePreset(String name) {
    final preset = voicePreset(name);
    if (preset.name.isEmpty) return this;
    return copyWith(
      voicePresets: [
        for (final existing in voicePresets)
          if (existing.endpointKey != preset.endpointKey ||
              existing.name != preset.name)
            existing,
        preset,
      ],
    );
  }

  NovelTtsSettings removeVoicePreset(NovelTtsVoicePreset preset) => copyWith(
    voicePresets: [
      for (final existing in voicePresets)
        if (existing.endpointKey != preset.endpointKey ||
            existing.name != preset.name)
          existing,
    ],
  );

  NovelTtsSettings selectVoicePreset(NovelTtsVoicePreset preset) {
    if (preset.endpointKey != voiceEndpointKey) return this;
    return switch (provider) {
      NovelTtsProvider.microsoft => copyWith(
        microsoftVoice: preset.voice,
        microsoftLanguage: preset.language,
        microsoftRate: preset.speed,
      ),
      NovelTtsProvider.openai => copyWith(
        openaiVoice: preset.voice,
        openaiModel: preset.model,
        openaiSpeed: _finiteDouble(
          double.tryParse(preset.speed),
          1,
        ).clamp(0.25, 4).toDouble(),
      ),
      NovelTtsProvider.custom => copyWith(
        customVariables: _presetVariables(preset),
      ),
    };
  }

  bool get isConfigured {
    switch (provider) {
      case NovelTtsProvider.microsoft:
        return microsoftKey.trim().isNotEmpty &&
            microsoftRegion.trim().isNotEmpty &&
            microsoftVoice.trim().isNotEmpty;
      case NovelTtsProvider.openai:
        return openaiBaseUrl.trim().isNotEmpty &&
            openaiApiKey.trim().isNotEmpty &&
            openaiModel.trim().isNotEmpty &&
            openaiVoice.trim().isNotEmpty;
      case NovelTtsProvider.custom:
        return customUrl.trim().isNotEmpty;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'provider': provider.name,
      'splitChars': splitChars,
      'autoContinue': autoContinue,
      'prefetchCount': prefetchCount,
      'microsoftKey': microsoftKey,
      'microsoftRegion': microsoftRegion,
      'microsoftVoice': microsoftVoice,
      'microsoftLanguage': microsoftLanguage,
      'microsoftRate': microsoftRate,
      'openaiBaseUrl': openaiBaseUrl,
      'openaiApiKey': openaiApiKey,
      'openaiModel': openaiModel,
      'openaiVoice': openaiVoice,
      'openaiSpeed': openaiSpeed,
      'customUrl': customUrl,
      'customMethod': customMethod,
      'customVoice': customVoice,
      'customLanguage': customLanguage,
      'customSpeed': customSpeed,
      'customModel': customModel,
      'customVariables': customTemplateVariables,
      'voicePresets': [for (final preset in voicePresets) preset.toJson()],
      'customHeaders': customHeaders,
      'customBody': customBody,
      'customContentType': customContentType,
      'readings': [for (final reading in readings) reading.toJson()],
    };
  }

  factory NovelTtsSettings.fromJson(Map<String, dynamic> json) {
    return NovelTtsSettings(
      provider: NovelTtsProvider.values.firstWhere(
        (value) => value.name == json['provider'],
        orElse: () => NovelTtsProvider.custom,
      ),
      splitChars: _finiteInt(
        json['splitChars'],
        defaultSplitChars,
      ).clamp(minSplitChars, maxSplitChars).toInt(),
      autoContinue: json['autoContinue'] as bool? ?? true,
      prefetchCount: _finiteInt(json['prefetchCount'], 4).clamp(1, 4).toInt(),
      microsoftKey: json['microsoftKey'] as String? ?? '',
      microsoftRegion: json['microsoftRegion'] as String? ?? 'eastasia',
      microsoftVoice:
          json['microsoftVoice'] as String? ?? 'zh-CN-XiaoxiaoNeural',
      microsoftLanguage: json['microsoftLanguage'] as String? ?? 'zh-CN',
      microsoftRate: json['microsoftRate'] as String? ?? '+0%',
      openaiBaseUrl:
          json['openaiBaseUrl'] as String? ?? 'https://api.openai.com/v1',
      openaiApiKey: json['openaiApiKey'] as String? ?? '',
      openaiModel: json['openaiModel'] as String? ?? 'tts-1',
      openaiVoice: json['openaiVoice'] as String? ?? 'alloy',
      openaiSpeed: _finiteDouble(
        json['openaiSpeed'],
        1,
      ).clamp(0.25, 4).toDouble(),
      customUrl: json['customUrl'] as String? ?? defaultCustomUrl,
      customMethod: (json['customMethod'] as String? ?? 'GET').toUpperCase(),
      customVoice: json['customVoice'] as String? ?? '',
      // Older templates borrowed these values from other providers.
      customLanguage:
          json['customLanguage'] as String? ??
          json['microsoftLanguage'] as String? ??
          'zh-CN',
      customSpeed:
          json['customSpeed'] as String? ??
          json['microsoftRate'] as String? ??
          '+0%',
      customModel:
          json['customModel'] as String? ??
          json['openaiModel'] as String? ??
          'tts-1',
      customVariables: json.containsKey('customVariables')
          ? novelTtsVariablesFromJson(json['customVariables'])
          : null,
      voicePresets: NovelTtsVoicePreset.listFromJson(json['voicePresets']),
      customHeaders: json['customHeaders'] as String? ?? '',
      customBody: json['customBody'] as String? ?? '',
      customContentType: json['customContentType'] as String? ?? '',
      readings: readingsFromJson(json['readings']),
    );
  }

  static NovelTtsSettings load() {
    if (_pendingSettings case final pending?) return pending;
    final raw = Prefer.getString(prefKey);
    if (raw == null || raw.isEmpty) {
      return const NovelTtsSettings(customVariables: {'voice': ''});
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return NovelTtsSettings.fromJson(decoded);
      }
      if (decoded is Map) {
        return NovelTtsSettings.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return const NovelTtsSettings(customVariables: {'voice': ''});
  }

  Future<void> save() {
    final raw = jsonEncode(toJson());
    final revision = ++_saveRevision;
    _pendingSettings = this;
    // Keep only active work. Retaining a completed Future also retains the
    // zone that created it, which can outlive the page or widget-test clock.
    final previous = _writeQueue ?? Future<void>.value();
    final write = previous.then((_) async {
      final preferences = await Prefer.getInstance();
      if (!await preferences.setString(prefKey, raw)) {
        throw StateError('Could not save speech settings');
      }
    });
    // A failed write must not prevent the next settings change being saved.
    final settled = write.catchError((Object _) {});
    _writeQueue = settled;
    return write.whenComplete(() {
      if (identical(_writeQueue, settled)) _writeQueue = null;
      if (revision == _saveRevision) _pendingSettings = null;
    });
  }
}

int _finiteInt(dynamic value, int fallback) =>
    value is num && value.isFinite ? value.toInt() : fallback;

double _finiteDouble(dynamic value, double fallback) =>
    value is num && value.isFinite ? value.toDouble() : fallback;

class NovelTtsVoicePreset {
  const NovelTtsVoicePreset({
    required this.name,
    required this.endpointKey,
    this.voice = '',
    this.language = '',
    this.speed = '',
    this.model = '',
    this.variables,
  });

  final String name;
  final String endpointKey;
  final String voice;
  final String language;
  final String speed;
  final String model;
  final Map<String, String>? variables;

  Map<String, dynamic> toJson() => {
    'name': name,
    'endpointKey': endpointKey,
    'voice': voice,
    'language': language,
    'speed': speed,
    'model': model,
    if (variables != null) 'variables': variables,
  };

  static List<NovelTtsVoicePreset> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    final result = <NovelTtsVoicePreset>[];
    for (final item in raw) {
      if (item is! Map ||
          item['name'] is! String ||
          item['endpointKey'] is! String ||
          (item['voice'] is! String && item['variables'] is! Map))
        continue;
      final name = (item['name'] as String).trim();
      final endpointKey = item['endpointKey'] as String;
      if (name.isEmpty || endpointKey.isEmpty) continue;
      result.add(
        NovelTtsVoicePreset(
          name: name,
          endpointKey: endpointKey,
          voice: item['voice'] is String ? item['voice'] as String : '',
          // Old presets may belong to an endpoint other than the active one.
          // Preserve their metadata until selected against that endpoint's
          // actual template; filtering here would discard still-needed values.
          variables: item.containsKey('variables')
              ? novelTtsVariablesFromJson(item['variables'])
              : null,
          language: item['language'] is String
              ? item['language'] as String
              : '',
          speed: item['speed'] is String ? item['speed'] as String : '',
          model: item['model'] is String ? item['model'] as String : '',
        ),
      );
    }
    return result;
  }
}

Map<String, String> novelTtsVariablesFromJson(dynamic raw) => {
  if (raw is Map)
    for (final entry in raw.entries)
      if (entry.key is String &&
          entry.value is String &&
          (entry.key as String).toLowerCase() != 'text')
        (entry.key as String).toLowerCase(): entry.value as String,
};

Set<String> _referencedCustomVariables({
  required String url,
  required String method,
  required String body,
  required String headers,
}) => {
  ...novelTtsTemplateVariableNames(url),
  ...novelTtsTemplateVariableNames(headers),
  if (method.trim().toUpperCase() != 'GET')
    ...novelTtsTemplateVariableNames(body),
}..remove('text');
