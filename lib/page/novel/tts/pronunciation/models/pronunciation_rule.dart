import 'package:pixez/page/novel/tts/pronunciation/models/pronunciation_scope.dart';

enum PronunciationMatchMode { exactPhrase, nameAlias, force }

class PronunciationLimits {
  static const schemaVersion = 2;
  static const pipelineVersion = 1;
  static const maxSurfaceScalars = 128;
  static const maxReadingScalars = 256;
  static const maxRegionChars = 800;
  static const maxQueuedRegions = 2;
  static const warmUpTimeout = Duration(milliseconds: 1500);
  static const regionTimeout = Duration(milliseconds: 250);
}

class PronunciationRule {
  const PronunciationRule({
    required this.id,
    required this.surface,
    required this.reading,
    required this.mode,
    required this.scope,
    required this.priority,
    required this.enabled,
    required this.updatedAtEpochMs,
    this.entityId,
    this.needsReview = false,
  });

  final String id;
  final String surface;
  final String reading;
  final PronunciationMatchMode mode;
  final PronunciationScope scope;
  final int priority;
  final bool enabled;
  final int updatedAtEpochMs;
  final String? entityId;
  final bool needsReview;

  PronunciationRule copyWith({
    String? surface,
    String? reading,
    PronunciationMatchMode? mode,
    PronunciationScope? scope,
    int? priority,
    bool? enabled,
    int? updatedAtEpochMs,
    String? entityId,
    bool? needsReview,
  }) {
    return PronunciationRule(
      id: id,
      surface: surface ?? this.surface,
      reading: reading ?? this.reading,
      mode: mode ?? this.mode,
      scope: scope ?? this.scope,
      priority: priority ?? this.priority,
      enabled: enabled ?? this.enabled,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
      entityId: entityId ?? this.entityId,
      needsReview: needsReview ?? this.needsReview,
    );
  }

  String? get validationError {
    final written = surface.trim();
    final spoken = reading.trim();
    if (written.isEmpty || spoken.isEmpty) {
      return 'empty';
    }
    if (written.runes.length > PronunciationLimits.maxSurfaceScalars) {
      return 'surface_too_long';
    }
    if (spoken.runes.length > PronunciationLimits.maxReadingScalars) {
      return 'reading_too_long';
    }
    if (_hasUnsafeControl(written) || _hasUnsafeControl(spoken)) {
      return 'control_char';
    }
    if (scope.type == PronunciationScopeType.global && scope.scopeId != null) {
      return 'global_scope_id';
    }
    if (scope.type != PronunciationScopeType.global &&
        (scope.scopeId == null || scope.scopeId!.isEmpty)) {
      return 'missing_scope_id';
    }
    return null;
  }

  bool get isValid => validationError == null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'surface': surface,
      'reading': reading,
      'mode': mode.name,
      'scope': scope.toJson(),
      'priority': priority,
      'enabled': enabled,
      'updatedAtEpochMs': updatedAtEpochMs,
      if (entityId != null) 'entityId': entityId,
      'needsReview': needsReview,
    };
  }

  factory PronunciationRule.fromJson(Map<String, dynamic> json) {
    return PronunciationRule(
      id: json['id'] as String? ?? '',
      surface: json['surface'] as String? ?? '',
      reading: json['reading'] as String? ?? '',
      mode: PronunciationMatchMode.values.firstWhere(
        (value) => value.name == json['mode'],
        orElse: () => PronunciationMatchMode.exactPhrase,
      ),
      scope: PronunciationScope.fromJson(
        Map<String, dynamic>.from(json['scope'] as Map? ?? const {}),
      ),
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      enabled: json['enabled'] as bool? ?? true,
      updatedAtEpochMs: (json['updatedAtEpochMs'] as num?)?.toInt() ?? 0,
      entityId: json['entityId'] as String?,
      needsReview: json['needsReview'] as bool? ?? false,
    );
  }
}

bool _hasUnsafeControl(String value) {
  for (final unit in value.codeUnits) {
    if (unit == 0 || (unit < 32 && unit != 9 && unit != 10 && unit != 13)) {
      return true;
    }
  }
  return false;
}
