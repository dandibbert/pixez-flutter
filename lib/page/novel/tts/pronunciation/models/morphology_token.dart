class MorphologyToken {
  const MorphologyToken({
    required this.start,
    required this.end,
    required this.surface,
    this.basicForm = '',
    this.reading = '',
    this.partOfSpeech = const [],
    this.conjugationType,
    this.conjugationForm,
  });

  final int start;
  final int end;
  final String surface;
  final String basicForm;
  final String reading;
  final List<String> partOfSpeech;
  final String? conjugationType;
  final String? conjugationForm;
}

class MorphologyResult {
  const MorphologyResult({
    required this.tokens,
    this.valid = true,
    this.reason,
  });

  final List<MorphologyToken> tokens;
  final bool valid;
  final String? reason;
}
