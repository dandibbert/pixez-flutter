import 'dart:convert';

import 'package:pixez/store/search_result_mode.dart';

/// Recoverable novel search state. Stores the query only, not page responses
/// or next_url. Page numbers map onto Pixiv's `offset` the same way as
/// [IllustSearchQuery].
class NovelSearchQuery {
  static const int schemaVersion = 1;
  static const int pageSize = 30;
  static const Set<String> supportedSearchTargets = {
    'partial_match_for_tags',
    'exact_match_for_tags',
    'text',
    'keyword',
  };
  static const Set<String> supportedSorts = {
    'date_desc',
    'date_asc',
    'popular_desc',
  };

  const NovelSearchQuery({
    required this.word,
    this.translatedName = '',
    this.searchTarget = 'partial_match_for_tags',
    this.sort = 'date_desc',
    this.startDate,
    this.endDate,
    this.starValue = 0,
    this.page = 1,
    this.mode = SearchResultMode.infinite,
  });

  final String word;
  final String translatedName;
  final String searchTarget;
  final String sort;
  final DateTime? startDate;
  final DateTime? endDate;
  final int starValue;
  final int page;
  final SearchResultMode mode;

  int get normalizedPage => page < 1 ? 1 : page;

  int? get offset =>
      normalizedPage == 1 ? null : (normalizedPage - 1) * pageSize;

  String get requestWord => starValue == 0 ? word : '$word ${starValue}users入り';

  NovelSearchQuery copyWith({
    String? word,
    String? translatedName,
    String? searchTarget,
    String? sort,
    DateTime? startDate,
    DateTime? endDate,
    bool clearDateRange = false,
    int? starValue,
    int? page,
    SearchResultMode? mode,
  }) {
    return NovelSearchQuery(
      word: word ?? this.word,
      translatedName: translatedName ?? this.translatedName,
      searchTarget: searchTarget ?? this.searchTarget,
      sort: sort ?? this.sort,
      startDate: clearDateRange ? null : (startDate ?? this.startDate),
      endDate: clearDateRange ? null : (endDate ?? this.endDate),
      starValue: starValue ?? this.starValue,
      page: page ?? this.page,
      mode: mode ?? this.mode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': schemaVersion,
      'kind': 'novel',
      'word': word,
      'translated_name': translatedName,
      'search_target': searchTarget,
      'sort': sort,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'star_value': starValue,
      'page': normalizedPage,
      'mode': mode.code,
    };
  }

  String encode() => jsonEncode(toJson());

  static NovelSearchQuery? tryDecode(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      final json = jsonDecode(value);
      if (json is! Map<String, dynamic> || json['kind'] != 'novel') {
        return null;
      }
      final version = (json['version'] as num?)?.toInt() ?? 0;
      if (version != schemaVersion) return null;
      final word = json['word'] as String?;
      if (word == null || word.isEmpty) return null;
      final decodedSearchTarget = json['search_target'] as String?;
      final decodedSort = json['sort'] as String?;
      final decodedPage = (json['page'] as num?)?.toInt() ?? 1;
      final decodedStarValue = (json['star_value'] as num?)?.toInt() ?? 0;
      return NovelSearchQuery(
        word: word,
        translatedName: json['translated_name'] as String? ?? '',
        searchTarget: supportedSearchTargets.contains(decodedSearchTarget)
            ? decodedSearchTarget!
            : 'partial_match_for_tags',
        sort: supportedSorts.contains(decodedSort) ? decodedSort! : 'date_desc',
        startDate: DateTime.tryParse(json['start_date'] as String? ?? ''),
        endDate: DateTime.tryParse(json['end_date'] as String? ?? ''),
        starValue: decodedStarValue >= 0 ? decodedStarValue : 0,
        page: decodedPage > 0 ? decodedPage : 1,
        mode: SearchResultMode.fromCode(json['mode'] as String?),
      );
    } catch (_) {
      return null;
    }
  }
}
