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
    this.isUserWord = false,
  });

  final int start;
  final int end;
  final String surface;
  final String basicForm;
  final String reading;
  final List<String> partOfSpeech;
  final String? conjugationType;
  final String? conjugationForm;

  /// The token is a word the caller added to the lattice, such as one of the
  /// user's name aliases, and the analyzer chose it over the dictionary.
  final bool isUserWord;
}

class MorphologyResult {
  const MorphologyResult({
    required this.tokens,
    this.valid = true,
    this.reason,
    this.exactBoundaries = false,
  });

  final List<MorphologyToken> tokens;
  final bool valid;
  final String? reason;

  /// Whether the tokens come from a full lattice search, so a word boundary is
  /// evidence rather than a script-change guess.
  final bool exactBoundaries;
}
