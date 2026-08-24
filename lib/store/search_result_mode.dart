enum SearchResultMode {
  infinite('infinite'),
  paged('paged');

  const SearchResultMode(this.code);

  final String code;

  static SearchResultMode fromCode(String? code) {
    return SearchResultMode.values.firstWhere(
      (mode) => mode.code == code,
      orElse: () => SearchResultMode.infinite,
    );
  }
}
