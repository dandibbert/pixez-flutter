import 'dart:convert';

import 'package:pixez/er/prefer.dart';

enum NovelTtsProvider { microsoft, openai, custom }

class NovelTtsSettings {
  static const prefKey = 'novel_tts_settings_json';
  static const defaultSplitChars = 200;
  static const minSplitChars = 20;
  static const maxSplitChars = 800;
  static const defaultCustomUrl =
      'https://tts.773421.xyz/tts?t={text}&v={voice}';

  const NovelTtsSettings({
    this.provider = NovelTtsProvider.custom,
    this.splitChars = defaultSplitChars,
    this.autoContinue = true,
    this.prefetchCount = 2,
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
    this.customHeaders = '',
    this.customBody = '',
    this.customContentType = '',
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
  final String customHeaders;
  final String customBody;
  final String customContentType;

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
    String? customHeaders,
    String? customBody,
    String? customContentType,
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
      customHeaders: customHeaders ?? this.customHeaders,
      customBody: customBody ?? this.customBody,
      customContentType: customContentType ?? this.customContentType,
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
      case NovelTtsProvider.custom:
        return microsoftLanguage.trim();
    }
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
      'customHeaders': customHeaders,
      'customBody': customBody,
      'customContentType': customContentType,
    };
  }

  factory NovelTtsSettings.fromJson(Map<String, dynamic> json) {
    return NovelTtsSettings(
      provider: NovelTtsProvider.values.firstWhere(
        (value) => value.name == json['provider'],
        orElse: () => NovelTtsProvider.custom,
      ),
      splitChars:
          (json['splitChars'] as num?)?.toInt() ?? defaultSplitChars,
      autoContinue: json['autoContinue'] as bool? ?? true,
      prefetchCount: (json['prefetchCount'] as num?)?.toInt() ?? 2,
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
      openaiSpeed: (json['openaiSpeed'] as num?)?.toDouble() ?? 1.0,
      customUrl: json['customUrl'] as String? ?? defaultCustomUrl,
      customMethod: (json['customMethod'] as String? ?? 'GET').toUpperCase(),
      customVoice: json['customVoice'] as String? ?? '',
      customHeaders: json['customHeaders'] as String? ?? '',
      customBody: json['customBody'] as String? ?? '',
      customContentType: json['customContentType'] as String? ?? '',
    );
  }

  static NovelTtsSettings load() {
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
    return Prefer.setString(prefKey, jsonEncode(toJson()));
  }
}
