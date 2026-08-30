import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_scope.dart';

class PronunciationEntity {
  const PronunciationEntity({
    required this.id,
    required this.label,
    required this.scope,
    required this.ruleIds,
    required this.enabled,
  });

  final String id;
  final String label;
  final PronunciationScope scope;
  final List<String> ruleIds;
  final bool enabled;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'scope': scope.toJson(),
      'ruleIds': ruleIds,
      'enabled': enabled,
    };
  }

  factory PronunciationEntity.fromJson(Map<String, dynamic> json) {
    return PronunciationEntity(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      scope: PronunciationScope.fromJson(
        Map<String, dynamic>.from(json['scope'] as Map? ?? const {}),
      ),
      ruleIds: [
        for (final id in json['ruleIds'] as List? ?? const [])
          if (id is String) id,
      ],
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}
