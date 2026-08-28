import 'dart:convert';

import 'package:pixez/store/search_result_mode.dart';

/// Recoverable novel search state aligned with pixvel's /v1/search/novel
/// params. History still uses PixEz `query_json` + `last_page`.
class NovelSearchQuery {
  static const int schemaVersion = 2;
  static const Set<int> supportedSchemaVersions = {1, 2};
  static const int pageSize = 30;
  static const int maxPage = 100;
  static const Set<String> supportedSearchTargets = {
    'keyword',
    'partial_match_for_tags',
    'exact_match_for_tags',
    'text',
  };
  static const Set<String> supportedSorts = {
    'date_desc',
    'date_asc',
    'popular_desc',
  };
  static const Set<String> supportedLangs = {'ja', 'zh-CN'};
  static const List<int> bookmarkPresets = [0, 100, 500, 1000, 5000, 10000];
  static const List<int> datePresetDays = [7, 30, 180, 365];

  const NovelSearchQuery({
    required this.word,
    this.translatedName = '',
    this.searchTarget = 'keyword',
    this.sort = 'date_desc',
    this.startDate,
    this.endDate,
    this.bookmarkNumMin = 0,
    this.bookmarkNumMax = 0,
    this.textLengthMin = 0,
    this.lang = 'ja',
    this.includePotentialViolationWorks = false,
    this.includeTranslatedTagResults = true,
    this.isOriginalOnly = false,
    this.isReplaceableOnly = false,
    this.mergePlainKeywordResults = true,
    this.searchAiType = 1,
    this.page = 1,
    this.mode = SearchResultMode.paged,
  });

  final String word;
  final String translatedName;
  final String searchTarget;
  final String sort;
  final DateTime? startDate;
  final DateTime? endDate;
  final int bookmarkNumMin;
  final int bookmarkNumMax;
  final int textLengthMin;
  final String lang;
  final bool includePotentialViolationWorks;
  final bool includeTranslatedTagResults;
  final bool isOriginalOnly;
  final bool isReplaceableOnly;
  final bool mergePlainKeywordResults;
  final int searchAiType;
  final int page;
  final SearchResultMode mode;

  int get normalizedPage {
    if (page < 1) return 1;
    if (page > maxPage) return maxPage;
    return page;
  }

  int? get offset =>
      normalizedPage == 1 ? null : (normalizedPage - 1) * pageSize;

  /// Pixvel sends the typed word as-is. Bookmark floors go through
  /// `bookmark_num_min`, not a `users入り` suffix.
  String get requestWord => word;

  int get starValue => bookmarkNumMin;

  NovelSearchQuery copyWith({
    String? word,
    String? translatedName,
    String? searchTarget,
    String? sort,
    DateTime? startDate,
    DateTime? endDate,
    bool clearDateRange = false,
    int? bookmarkNumMin,
    int? bookmarkNumMax,
    int? textLengthMin,
    String? lang,
    bool? includePotentialViolationWorks,
    bool? includeTranslatedTagResults,
    bool? isOriginalOnly,
    bool? isReplaceableOnly,
    bool? mergePlainKeywordResults,
    int? searchAiType,
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
      bookmarkNumMin: bookmarkNumMin ?? this.bookmarkNumMin,
      bookmarkNumMax: bookmarkNumMax ?? this.bookmarkNumMax,
      textLengthMin: textLengthMin ?? this.textLengthMin,
      lang: lang ?? this.lang,
      includePotentialViolationWorks:
          includePotentialViolationWorks ?? this.includePotentialViolationWorks,
      includeTranslatedTagResults:
          includeTranslatedTagResults ?? this.includeTranslatedTagResults,
      isOriginalOnly: isOriginalOnly ?? this.isOriginalOnly,
      isReplaceableOnly: isReplaceableOnly ?? this.isReplaceableOnly,
      mergePlainKeywordResults:
          mergePlainKeywordResults ?? this.mergePlainKeywordResults,
      searchAiType: searchAiType ?? this.searchAiType,
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
      'bookmark_num_min': bookmarkNumMin,
      'bookmark_num_max': bookmarkNumMax,
      'star_value': bookmarkNumMin,
      'text_length_min': textLengthMin,
      'lang': lang,
      'include_potential_violation_works': includePotentialViolationWorks,
      'include_translated_tag_results': includeTranslatedTagResults,
      'is_original_only': isOriginalOnly,
      'is_replaceable_only': isReplaceableOnly,
      'merge_plain_keyword_results': mergePlainKeywordResults,
      'search_ai_type': searchAiType,
      'page': normalizedPage,
      'mode': mode.code,
    };
  }

  String encode() => jsonEncode(toJson());

  static int parseNumberInput(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return 0;
    }
    return int.tryParse(digits) ?? 0;
  }

  static bool isBookmarkRangeInvalid(int min, int max) {
    return max > 0 && min > max;
  }

  static DateTimeRangeDays? dateRangeForPreset(int days, {DateTime? now}) {
    if (days <= 0) return null;
    final end = now ?? DateTime.now();
    return DateTimeRangeDays(
      start: end.subtract(Duration(days: days)),
      end: end,
    );
  }

  static NovelSearchQuery? tryDecode(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      final json = jsonDecode(value);
      if (json is! Map<String, dynamic> || json['kind'] != 'novel') {
        return null;
      }
      final version = (json['version'] as num?)?.toInt() ?? 0;
      if (!supportedSchemaVersions.contains(version)) return null;
      final word = json['word'] as String?;
      if (word == null || word.isEmpty) return null;
      final decodedSearchTarget = json['search_target'] as String?;
      final decodedSort = json['sort'] as String?;
      final decodedPage = (json['page'] as num?)?.toInt() ?? 1;
      final decodedBookmarkMin =
          (json['bookmark_num_min'] as num?)?.toInt() ??
          (json['star_value'] as num?)?.toInt() ??
          0;
      final decodedBookmarkMax = (json['bookmark_num_max'] as num?)?.toInt() ?? 0;
      final decodedTextLength = (json['text_length_min'] as num?)?.toInt() ?? 0;
      final decodedLang = json['lang'] as String? ?? 'ja';
      final decodedAi = (json['search_ai_type'] as num?)?.toInt() ?? 1;
      return NovelSearchQuery(
        word: word,
        translatedName: json['translated_name'] as String? ?? '',
        searchTarget: supportedSearchTargets.contains(decodedSearchTarget)
            ? decodedSearchTarget!
            : 'keyword',
        sort: supportedSorts.contains(decodedSort) ? decodedSort! : 'date_desc',
        startDate: DateTime.tryParse(json['start_date'] as String? ?? ''),
        endDate: DateTime.tryParse(json['end_date'] as String? ?? ''),
        bookmarkNumMin: decodedBookmarkMin >= 0 ? decodedBookmarkMin : 0,
        bookmarkNumMax: decodedBookmarkMax >= 0 ? decodedBookmarkMax : 0,
        textLengthMin: decodedTextLength >= 0 ? decodedTextLength : 0,
        lang: supportedLangs.contains(decodedLang) ? decodedLang : 'ja',
        includePotentialViolationWorks:
            json['include_potential_violation_works'] == true,
        includeTranslatedTagResults:
            json['include_translated_tag_results'] != false,
        isOriginalOnly: json['is_original_only'] == true,
        isReplaceableOnly: json['is_replaceable_only'] == true,
        mergePlainKeywordResults: json['merge_plain_keyword_results'] != false,
        searchAiType: decodedAi == 0 ? 0 : 1,
        page: decodedPage > 0 ? decodedPage : 1,
        mode: SearchResultMode.paged,
      );
    } catch (_) {
      return null;
    }
  }

  /// Restores word, filters, and the saved result page from a history chip.
  static NovelSearchQuery fromHistory({
    required String name,
    required String translatedName,
    required int lastPage,
    String? queryJson,
  }) {
    final decoded = tryDecode(queryJson);
    return (decoded ??
            NovelSearchQuery(word: name, translatedName: translatedName))
        .copyWith(
          word: name,
          translatedName: translatedName,
          page: lastPage > 0 ? lastPage : 1,
          mode: SearchResultMode.paged,
        );
  }
}

class DateTimeRangeDays {
  const DateTimeRangeDays({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}
