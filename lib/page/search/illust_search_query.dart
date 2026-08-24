import 'dart:convert';

import 'package:pixez/store/search_result_mode.dart';

enum UgoiraFilter {
  all('all'),
  onlyUgoira('only_ugoira'),
  noUgoira('no_ugoira');

  const UgoiraFilter(this.code);

  final String code;

  static UgoiraFilter fromCode(String? code) {
    return UgoiraFilter.values.firstWhere(
      (filter) => filter.code == code,
      orElse: () => UgoiraFilter.all,
    );
  }
}

enum IllustSearchSource {
  normal('normal'),
  popularPreview('popular_preview');

  const IllustSearchSource(this.code);

  final String code;

  static IllustSearchSource fromCode(String? code) {
    return IllustSearchSource.values.firstWhere(
      (source) => source.code == code,
      orElse: () => IllustSearchSource.normal,
    );
  }
}

/// 可恢复的插画搜索状态。只保存查询条件，不缓存页面响应或 next_url。
class IllustSearchQuery {
  static const int schemaVersion = 1;
  static const int pageSize = 30;
  static const Set<String> supportedSearchTargets = {
    'partial_match_for_tags',
    'exact_match_for_tags',
    'title_and_caption',
  };
  static const Set<String> supportedSorts = {
    'date_desc',
    'date_asc',
    'popular_desc',
    'popular_male_desc',
    'popular_female_desc',
  };

  const IllustSearchQuery({
    required this.word,
    this.translatedName = '',
    this.searchTarget = 'partial_match_for_tags',
    this.sort = 'date_desc',
    this.startDate,
    this.endDate,
    this.bookmarkRange = const [],
    this.searchAIType = 0,
    this.ugoiraFilter = UgoiraFilter.all,
    this.starValue = 0,
    this.page = 1,
    this.mode = SearchResultMode.infinite,
    this.source = IllustSearchSource.normal,
  });

  final String word;
  final String translatedName;
  final String searchTarget;
  final String sort;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<int> bookmarkRange;
  final int searchAIType;
  final UgoiraFilter ugoiraFilter;
  final int starValue;
  final int page;
  final SearchResultMode mode;
  final IllustSearchSource source;

  int get normalizedPage => page < 1 ? 1 : page;

  int? get offset =>
      normalizedPage == 1 ? null : (normalizedPage - 1) * pageSize;

  String get requestWord => starValue == 0 ? word : '$word ${starValue}users入り';

  IllustSearchQuery copyWith({
    String? word,
    String? translatedName,
    String? searchTarget,
    String? sort,
    DateTime? startDate,
    DateTime? endDate,
    bool clearDateRange = false,
    List<int>? bookmarkRange,
    int? searchAIType,
    UgoiraFilter? ugoiraFilter,
    int? starValue,
    int? page,
    SearchResultMode? mode,
    IllustSearchSource? source,
  }) {
    return IllustSearchQuery(
      word: word ?? this.word,
      translatedName: translatedName ?? this.translatedName,
      searchTarget: searchTarget ?? this.searchTarget,
      sort: sort ?? this.sort,
      startDate: clearDateRange ? null : (startDate ?? this.startDate),
      endDate: clearDateRange ? null : (endDate ?? this.endDate),
      bookmarkRange: List<int>.unmodifiable(
        bookmarkRange ?? this.bookmarkRange,
      ),
      searchAIType: searchAIType ?? this.searchAIType,
      ugoiraFilter: ugoiraFilter ?? this.ugoiraFilter,
      starValue: starValue ?? this.starValue,
      page: page ?? this.page,
      mode: mode ?? this.mode,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': schemaVersion,
      'kind': 'illust',
      'word': word,
      'translated_name': translatedName,
      'search_target': searchTarget,
      'sort': sort,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'bookmark_range': bookmarkRange,
      'search_ai_type': searchAIType,
      'ugoira_filter': ugoiraFilter.code,
      'star_value': starValue,
      'page': normalizedPage,
      'mode': mode.code,
      'source': source.code,
    };
  }

  String encode() => jsonEncode(toJson());

  static IllustSearchQuery? tryDecode(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      final json = jsonDecode(value);
      if (json is! Map<String, dynamic> || json['kind'] != 'illust') {
        return null;
      }
      final version = (json['version'] as num?)?.toInt() ?? 0;
      if (version != schemaVersion) return null;
      final word = json['word'] as String?;
      if (word == null || word.isEmpty) return null;
      final range = (json['bookmark_range'] as List<dynamic>? ?? const [])
          .whereType<num>()
          .map((value) => value.toInt())
          .where((value) => value >= 0)
          .take(2)
          .toList(growable: false);
      final decodedSearchTarget = json['search_target'] as String?;
      final decodedSort = json['sort'] as String?;
      final decodedSearchAIType =
          (json['search_ai_type'] as num?)?.toInt() ?? 0;
      final decodedPage = (json['page'] as num?)?.toInt() ?? 1;
      final decodedStarValue = (json['star_value'] as num?)?.toInt() ?? 0;
      return IllustSearchQuery(
        word: word,
        translatedName: json['translated_name'] as String? ?? '',
        searchTarget: supportedSearchTargets.contains(decodedSearchTarget)
            ? decodedSearchTarget!
            : 'partial_match_for_tags',
        sort: supportedSorts.contains(decodedSort) ? decodedSort! : 'date_desc',
        startDate: DateTime.tryParse(json['start_date'] as String? ?? ''),
        endDate: DateTime.tryParse(json['end_date'] as String? ?? ''),
        bookmarkRange: range,
        searchAIType: decodedSearchAIType == 1 ? 1 : 0,
        ugoiraFilter: UgoiraFilter.fromCode(json['ugoira_filter'] as String?),
        starValue: decodedStarValue >= 0 ? decodedStarValue : 0,
        page: decodedPage > 0 ? decodedPage : 1,
        mode: SearchResultMode.fromCode(json['mode'] as String?),
        source: IllustSearchSource.fromCode(json['source'] as String?),
      );
    } catch (_) {
      return null;
    }
  }
}
