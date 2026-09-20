import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:pixez/er/prefer.dart';
import 'package:pixez/page/novel/tts/novel_tts_endpoint.dart';
import 'package:pixez/page/novel/tts/novel_tts_readings.dart';

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
    this.voicePresets = const [],
    this.customHeaders = '',
    this.customBody = '',
    this.customContentType = '',
    this.readings = const [],
  });

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
      voicePresets: voicePresets ?? this.voicePresets,
      customHeaders: customHeaders ?? this.customHeaders,
      customBody: customBody ?? this.customBody,
      customContentType: customContentType ?? this.customContentType,
      readings: readings ?? this.readings,
    );
  }

  int get clampedSplitChars =>
      splitChars.clamp(minSplitChars, maxSplitChars).toInt();

  String get activeVoice {
    switch (provider) {
      case NovelTtsProvider.microsoft:
        return microsoftVoice.trim();
      case NovelTtsProvider.openai:
        return openaiVoice.trim();
      case NovelTtsProvider.custom:
        return customVoice.trim();
    }
  }

  String get activeLanguage {
    switch (provider) {
      case NovelTtsProvider.microsoft:
        return microsoftLanguage.trim();
      case NovelTtsProvider.openai:
        return microsoftLanguage.trim();
      case NovelTtsProvider.custom:
        return customLanguage.trim();
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
    voice: activeVoice,
    language: provider == NovelTtsProvider.openai ? '' : activeLanguage,
    speed: switch (provider) {
      NovelTtsProvider.microsoft => microsoftRate,
      NovelTtsProvider.openai => openaiSpeed.toString(),
      NovelTtsProvider.custom => customSpeed,
    },
    model: switch (provider) {
      NovelTtsProvider.microsoft => '',
      NovelTtsProvider.openai => openaiModel,
      NovelTtsProvider.custom => customModel,
    },
  );

  bool isVoicePresetSelected(NovelTtsVoicePreset preset) {
    final current = voicePreset(preset.name);
    return current.endpointKey == preset.endpointKey &&
        current.voice == preset.voice &&
        current.language == preset.language &&
        current.speed == preset.speed &&
        current.model == preset.model;
  }

  NovelTtsSettings saveVoicePreset(String name) {
    final preset = voicePreset(name);
    if (preset.name.isEmpty) return this;
    return copyWith(voicePresets: [
      for (final existing in voicePresets)
        if (existing.endpointKey != preset.endpointKey ||
            existing.name != preset.name) existing,
      preset,
    ]);
  }

  NovelTtsSettings removeVoicePreset(NovelTtsVoicePreset preset) => copyWith(
    voicePresets: [
      for (final existing in voicePresets)
        if (existing.endpointKey != preset.endpointKey ||
            existing.name != preset.name) existing,
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
        openaiSpeed: _finiteDouble(double.tryParse(preset.speed), 1).clamp(0.25, 4).toDouble(),
      ),
      NovelTtsProvider.custom => copyWith(
        customVoice: preset.voice,
        customLanguage: preset.language,
        customSpeed: preset.speed,
        customModel: preset.model,
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
      splitChars:
          _finiteInt(json['splitChars'], defaultSplitChars)
              .clamp(minSplitChars, maxSplitChars).toInt(),
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
      openaiSpeed: _finiteDouble(json['openaiSpeed'], 1).clamp(0.25, 4).toDouble(),
      customUrl: json['customUrl'] as String? ?? defaultCustomUrl,
      customMethod: (json['customMethod'] as String? ?? 'GET').toUpperCase(),
      customVoice: json['customVoice'] as String? ?? '',
      // Older templates borrowed these values from other providers.
      customLanguage: json['customLanguage'] as String? ??
          json['microsoftLanguage'] as String? ?? 'zh-CN',
      customSpeed: json['customSpeed'] as String? ??
          json['microsoftRate'] as String? ?? '+0%',
      customModel: json['customModel'] as String? ??
          json['openaiModel'] as String? ?? 'tts-1',
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
      return const NovelTtsSettings();
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
    return const NovelTtsSettings();
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
    required this.voice,
    this.language = '',
    this.speed = '',
    this.model = '',
  });

  final String name;
  final String endpointKey;
  final String voice;
  final String language;
  final String speed;
  final String model;

  Map<String, dynamic> toJson() => {
    'name': name,
    'endpointKey': endpointKey,
    'voice': voice,
    'language': language,
    'speed': speed,
    'model': model,
  };

  static List<NovelTtsVoicePreset> listFromJson(dynamic raw) {
    if (raw is! List) return const [];
    final result = <NovelTtsVoicePreset>[];
    for (final item in raw) {
      if (item is! Map || item['name'] is! String ||
          item['endpointKey'] is! String || item['voice'] is! String) continue;
      final name = (item['name'] as String).trim();
      final endpointKey = item['endpointKey'] as String;
      if (name.isEmpty || endpointKey.isEmpty) continue;
      result.add(NovelTtsVoicePreset(
        name: name,
        endpointKey: endpointKey,
        voice: item['voice'] as String,
        language: item['language'] is String ? item['language'] as String : '',
        speed: item['speed'] is String ? item['speed'] as String : '',
        model: item['model'] is String ? item['model'] as String : '',
      ));
    }
    return result;
  }
}
