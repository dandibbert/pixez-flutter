import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/models/tags.dart';
import 'package:pixez/page/novel/search/novel_search_query.dart';
import 'package:pixez/store/search_result_mode.dart';

void main() {
  group('NovelSearchQuery', () {
    test('uses pixvel page offsets and does not rewrite the word', () {
      const first = NovelSearchQuery(word: 'test');
      final fifth = first.copyWith(page: 5, bookmarkNumMin: 1000);

      expect(first.searchTarget, 'keyword');
      expect(first.mode, SearchResultMode.paged);
      expect(first.offset, isNull);
      expect(fifth.offset, 120);
      expect(fifth.requestWord, 'test');
      expect(fifth.searchAiType, 1);
      expect(fifth.lang, 'ja');
    });

    test('round-trips the complete recoverable query', () {
      final source = NovelSearchQuery(
        word: '猫',
        translatedName: 'cat',
        searchTarget: 'text',
        sort: 'date_asc',
        startDate: DateTime.utc(2024, 1, 2),
        endDate: DateTime.utc(2024, 2, 3),
        bookmarkNumMin: 500,
        bookmarkNumMax: 2000,
        textLengthMin: 3000,
        lang: 'zh-CN',
        includePotentialViolationWorks: true,
        isOriginalOnly: true,
        searchAiType: 0,
        page: 7,
      );

      final restored = NovelSearchQuery.tryDecode(source.encode());

      expect(restored, isNotNull);
      expect(restored!.toJson(), source.toJson());
      expect(restored.offset, 180);
      expect(restored.requestWord, '猫');
      expect(restored.bookmarkNumMin, 500);
    });

    test('reads v1 history star_value as bookmark_num_min', () {
      final restored = NovelSearchQuery.tryDecode('''
{
  "version": 1,
  "kind": "novel",
  "word": "test",
  "search_target": "partial_match_for_tags",
  "star_value": 1000,
  "page": 3
}
''');

      expect(restored, isNotNull);
      expect(restored!.bookmarkNumMin, 1000);
      expect(restored.searchTarget, 'partial_match_for_tags');
      expect(restored.page, 3);
      expect(restored.mode, SearchResultMode.paged);
      expect(restored.requestWord, 'test');
    });

    test('rejects illust snapshots and malformed payloads', () {
      expect(NovelSearchQuery.tryDecode(null), isNull);
      expect(NovelSearchQuery.tryDecode('not-json'), isNull);
      expect(
        NovelSearchQuery.tryDecode(
          '{"version":1,"kind":"illust","word":"test"}',
        ),
        isNull,
      );
      expect(
        NovelSearchQuery.tryDecode(
          '{"version":999,"kind":"novel","word":"test"}',
        ),
        isNull,
      );
    });

    test('normalizes unsafe values from imported history', () {
      final restored = NovelSearchQuery.tryDecode('''
{
  "version": 2,
  "kind": "novel",
  "word": "test",
  "search_target": "invalid",
  "sort": "invalid",
  "bookmark_num_min": -10,
  "page": -3
}
''');

      expect(restored, isNotNull);
      expect(restored!.searchTarget, 'keyword');
      expect(restored.sort, 'date_desc');
      expect(restored.bookmarkNumMin, 0);
      expect(restored.page, 1);
    });

    test('old tag history JSON defaults to page one', () {
      final history = TagsPersist.fromJson({
        '_id': 1,
        'name': 'old',
        'translated_name': '',
        'type': 1,
      });

      expect(history.lastPage, 1);
      expect(history.queryJson, isNull);
      expect(NovelSearchQuery.tryDecode(history.queryJson), isNull);
    });

    test('history restore keeps the saved word, filters, and page', () {
      final saved = NovelSearchQuery(
        word: '猫',
        translatedName: 'cat',
        searchTarget: 'text',
        bookmarkNumMin: 500,
        page: 4,
      );
      final restored = NovelSearchQuery.fromHistory(
        name: '猫',
        translatedName: 'cat',
        lastPage: 4,
        queryJson: saved.encode(),
      );

      expect(restored.word, '猫');
      expect(restored.page, 4);
      expect(restored.bookmarkNumMin, 500);
      expect(restored.searchTarget, 'text');
      expect(restored.mode, SearchResultMode.paged);
    });

    test('history without query_json still opens the saved page', () {
      final restored = NovelSearchQuery.fromHistory(
        name: 'old',
        translatedName: '',
        lastPage: 6,
        queryJson: null,
      );

      expect(restored.word, 'old');
      expect(restored.page, 6);
      expect(restored.mode, SearchResultMode.paged);
    });

    test('parses free-form filter numbers like pixvel', () {
      expect(NovelSearchQuery.parseNumberInput(''), 0);
      expect(NovelSearchQuery.parseNumberInput('  '), 0);
      expect(NovelSearchQuery.parseNumberInput('2500'), 2500);
      expect(NovelSearchQuery.parseNumberInput('2,500'), 2500);
      expect(NovelSearchQuery.parseNumberInput('abc'), 0);
    });

    test('rejects a bookmark maximum below the minimum', () {
      expect(NovelSearchQuery.isBookmarkRangeInvalid(100, 0), isFalse);
      expect(NovelSearchQuery.isBookmarkRangeInvalid(100, 500), isFalse);
      expect(NovelSearchQuery.isBookmarkRangeInvalid(500, 100), isTrue);
    });

    test('date presets match pixvel last-N-days windows', () {
      final now = DateTime.utc(2026, 8, 28);
      final week = NovelSearchQuery.dateRangeForPreset(7, now: now);

      expect(week, isNotNull);
      expect(week!.end, now);
      expect(week.start, DateTime.utc(2026, 8, 21));
      expect(NovelSearchQuery.dateRangeForPreset(0, now: now), isNull);
    });
  });
}
