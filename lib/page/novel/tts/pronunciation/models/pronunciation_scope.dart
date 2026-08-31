enum PronunciationScopeType { global, series, work }

class PronunciationScope {
  const PronunciationScope({required this.type, this.scopeId});

  final PronunciationScopeType type;
  final String? scopeId;

  int get rank {
    switch (type) {
      case PronunciationScopeType.work:
        return 3;
      case PronunciationScopeType.series:
        return 2;
      case PronunciationScopeType.global:
        return 1;
    }
  }

  bool appliesTo({String? workId, String? seriesId}) {
    switch (type) {
      case PronunciationScopeType.global:
        return true;
      case PronunciationScopeType.series:
        return seriesId != null && seriesId == scopeId;
      case PronunciationScopeType.work:
        return workId != null && workId == scopeId;
    }
  }

  Map<String, dynamic> toJson() {
    return {'type': type.name, if (scopeId != null) 'scopeId': scopeId};
  }

  factory PronunciationScope.fromJson(Map<String, dynamic> json) {
    final type = PronunciationScopeType.values.firstWhere(
      (value) => value.name == json['type'],
      orElse: () => PronunciationScopeType.global,
    );
    return PronunciationScope(
      type: type,
      scopeId: json['scopeId'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PronunciationScope &&
        other.type == type &&
        other.scopeId == scopeId;
  }

  @override
  int get hashCode => Object.hash(type, scopeId);
}
