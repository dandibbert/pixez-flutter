import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/models/tags.dart';
import 'package:pixez/page/novel/search/novel_search_query.dart';
import 'package:pixez/store/search_result_mode.dart';

void main() {
  group('NovelSearchQuery', () {
    test('converts page numbers to Pixiv offsets', () {
      const first = NovelSearchQuery(word: 'test');
      final fifth = first.copyWith(page: 5, mode: SearchResultMode.paged);

      expect(first.offset, isNull);
      expect(fifth.offset, 120);
      expect(fifth.requestWord, 'test');
    });

    test('round-trips the complete recoverable query', () {
      final source = NovelSearchQuery(
        word: '猫',
        translatedName: 'cat',
        searchTarget: 'text',
        sort: 'date_asc',
        startDate: DateTime.utc(2024, 1, 2),
        endDate: DateTime.utc(2024, 2, 3),
        starValue: 500,
        page: 7,
        mode: SearchResultMode.paged,
      );

      final restored = NovelSearchQuery.tryDecode(source.encode());

      expect(restored, isNotNull);
      expect(restored!.toJson(), source.toJson());
      expect(restored.offset, 180);
      expect(restored.requestWord, '猫 500users入り');
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
  "version": 1,
  "kind": "novel",
  "word": "test",
  "search_target": "invalid",
  "sort": "invalid",
  "star_value": -10,
  "page": -3
}
''');

      expect(restored, isNotNull);
      expect(restored!.searchTarget, 'partial_match_for_tags');
      expect(restored.sort, 'date_desc');
      expect(restored.starValue, 0);
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
  });
}
