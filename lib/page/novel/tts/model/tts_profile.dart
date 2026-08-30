enum TtsProviderKind { microsoftAzure, openAiCompatible, customHttp }

enum CustomHttpMethod { get, post, put }

sealed class TtsProviderConfig {
  const TtsProviderConfig();
  TtsProviderKind get kind;
  String get endpoint;
  bool get supportsSsml;
  Map<String, dynamic> toJson();

  static TtsProviderConfig fromJson(Map<String, dynamic> json) {
    return switch (TtsProviderKind.values.byName(json['kind'] as String)) {
      TtsProviderKind.microsoftAzure => AzureTtsProviderConfig.fromJson(json),
      TtsProviderKind.openAiCompatible => OpenAiTtsProviderConfig.fromJson(
        json,
      ),
      TtsProviderKind.customHttp => CustomTtsProviderConfig.fromJson(json),
    };
  }
}

class AzureTtsProviderConfig extends TtsProviderConfig {
  const AzureTtsProviderConfig({required this.region, this.endpointOverride});
  final String region;
  final String? endpointOverride;
  @override
  TtsProviderKind get kind => TtsProviderKind.microsoftAzure;
  @override
  String get endpoint => endpointOverride?.trim().isNotEmpty == true
      ? endpointOverride!.trim()
      : 'https://$region.tts.speech.microsoft.com/cognitiveservices/v1';
  @override
  bool get supportsSsml => true;
  @override
  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'region': region,
    'endpointOverride': endpointOverride,
  };
  factory AzureTtsProviderConfig.fromJson(Map<String, dynamic> json) =>
      AzureTtsProviderConfig(
        region: json['region'] as String? ?? '',
        endpointOverride: json['endpointOverride'] as String?,
      );
}

class OpenAiTtsProviderConfig extends TtsProviderConfig {
  const OpenAiTtsProviderConfig({
    required this.baseUrl,
    this.path = '/v1/audio/speech',
  });
  final String baseUrl;
  final String path;
  @override
  TtsProviderKind get kind => TtsProviderKind.openAiCompatible;
  @override
  String get endpoint =>
      '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}${path.startsWith('/') ? path : '/$path'}';
  @override
  bool get supportsSsml => false;
  @override
  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'baseUrl': baseUrl,
    'path': path,
  };
  factory OpenAiTtsProviderConfig.fromJson(Map<String, dynamic> json) =>
      OpenAiTtsProviderConfig(
        baseUrl: json['baseUrl'] as String? ?? '',
        path: json['path'] as String? ?? '/v1/audio/speech',
      );
}

class CustomTtsProviderConfig extends TtsProviderConfig {
  const CustomTtsProviderConfig({
    required this.endpointTemplate,
    required this.method,
    this.headerTemplates = const {},
    this.bodyTemplate,
    this.bodyIsJson = true,
    this.responseAudioJsonPath,
    this.allowAudioHosts = const {},
    this.ssml = false,
  });
  final String endpointTemplate;
  final CustomHttpMethod method;
  final Map<String, String> headerTemplates;
  final String? bodyTemplate;
  final bool bodyIsJson;
  final String? responseAudioJsonPath;
  final Set<String> allowAudioHosts;
  final bool ssml;
  @override
  TtsProviderKind get kind => TtsProviderKind.customHttp;
  @override
  String get endpoint => endpointTemplate;
  @override
  bool get supportsSsml => ssml;
  @override
  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'endpointTemplate': endpointTemplate,
    'method': method.name,
    'headerTemplates': headerTemplates,
    'bodyTemplate': bodyTemplate,
    'bodyIsJson': bodyIsJson,
    'responseAudioJsonPath': responseAudioJsonPath,
    'allowAudioHosts': allowAudioHosts.toList(),
    'ssml': ssml,
  };
  factory CustomTtsProviderConfig.fromJson(Map<String, dynamic> json) =>
      CustomTtsProviderConfig(
        endpointTemplate: json['endpointTemplate'] as String? ?? '',
        method: CustomHttpMethod.values.byName(
          json['method'] as String? ?? 'get',
        ),
        headerTemplates: Map<String, String>.from(
          json['headerTemplates'] as Map? ?? const {},
        ),
        bodyTemplate: json['bodyTemplate'] as String?,
        bodyIsJson: json['bodyIsJson'] as bool? ?? true,
        responseAudioJsonPath: json['responseAudioJsonPath'] as String?,
        allowAudioHosts: Set<String>.from(
          json['allowAudioHosts'] as List? ?? const [],
        ),
        ssml: json['ssml'] as bool? ?? false,
      );
}

class TtsProfile {
  const TtsProfile({
    required this.id,
    required this.name,
    required this.enabled,
    required this.provider,
    required this.voice,
    this.model,
    this.speed = 1,
    this.pitch = 0,
    this.language = 'ja-JP',
    this.format = 'mp3',
    this.providerOptions = const {},
    this.secretNamespace = '',
    this.schemaVersion = 2,
  });
  final String id;
  final String name;
  final bool enabled;
  final TtsProviderConfig provider;
  final String voice;
  final String? model;
  final double speed;
  final double pitch;
  final String language;
  final String format;
  final Map<String, dynamic> providerOptions;
  final String secretNamespace;
  final int schemaVersion;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'enabled': enabled,
    'provider': provider.toJson(),
    'voice': voice,
    'model': model,
    'speed': speed,
    'pitch': pitch,
    'language': language,
    'format': format,
    'providerOptions': providerOptions,
    'secretNamespace': secretNamespace,
    'schemaVersion': schemaVersion,
  };
  factory TtsProfile.fromJson(Map<String, dynamic> json) => TtsProfile(
    id: json['id'] as String,
    name: json['name'] as String,
    enabled: json['enabled'] as bool? ?? true,
    provider: TtsProviderConfig.fromJson(
      Map<String, dynamic>.from(json['provider'] as Map),
    ),
    voice: json['voice'] as String? ?? '',
    model: json['model'] as String?,
    speed: (json['speed'] as num?)?.toDouble() ?? 1,
    pitch: (json['pitch'] as num?)?.toDouble() ?? 0,
    language: json['language'] as String? ?? 'ja-JP',
    format: json['format'] as String? ?? 'mp3',
    providerOptions: Map<String, dynamic>.from(
      json['providerOptions'] as Map? ?? const {},
    ),
    secretNamespace: json['secretNamespace'] as String? ?? '',
    schemaVersion: json['schemaVersion'] as int? ?? 2,
  );
}
