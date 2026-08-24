import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/models/tags.dart';
import 'package:pixez/page/search/illust_search_query.dart';
import 'package:pixez/store/search_result_mode.dart';

void main() {
  group('IllustSearchQuery', () {
    test('converts page numbers to Pixiv offsets', () {
      const first = IllustSearchQuery(word: 'test');
      final fifth = first.copyWith(page: 5, mode: SearchResultMode.paged);

      expect(first.offset, isNull);
      expect(fifth.offset, 120);
      expect(fifth.requestWord, 'test');
    });

    test('round-trips the complete recoverable query', () {
      final source = IllustSearchQuery(
        word: '猫',
        translatedName: 'cat',
        searchTarget: 'title_and_caption',
        sort: 'date_asc',
        startDate: DateTime.utc(2024, 1, 2),
        endDate: DateTime.utc(2024, 2, 3),
        bookmarkRange: const [100, 499],
        searchAIType: 1,
        ugoiraFilter: UgoiraFilter.noUgoira,
        starValue: 500,
        page: 7,
        mode: SearchResultMode.paged,
      );

      final restored = IllustSearchQuery.tryDecode(source.encode());

      expect(restored, isNotNull);
      expect(restored!.toJson(), source.toJson());
      expect(restored.offset, 180);
      expect(restored.requestWord, '猫 500users入り');
    });

    test('rejects malformed or unknown snapshots', () {
      expect(IllustSearchQuery.tryDecode(null), isNull);
      expect(IllustSearchQuery.tryDecode('not-json'), isNull);
      expect(
        IllustSearchQuery.tryDecode(
          '{"version":999,"kind":"illust","word":"test"}',
        ),
        isNull,
      );
    });

    test('normalizes unsafe values from imported history', () {
      final restored = IllustSearchQuery.tryDecode('''
{
  "version": 1,
  "kind": "illust",
  "word": "test",
  "search_target": "invalid",
  "sort": "invalid",
  "bookmark_range": [-1, 100, 200],
  "search_ai_type": 99,
  "star_value": -10,
  "page": -3
}
''');

      expect(restored, isNotNull);
      expect(restored!.searchTarget, 'partial_match_for_tags');
      expect(restored.sort, 'date_desc');
      expect(restored.bookmarkRange, [100, 200]);
      expect(restored.searchAIType, 0);
      expect(restored.starValue, 0);
      expect(restored.page, 1);
    });

    test('old tag history JSON defaults to page one', () {
      final history = TagsPersist.fromJson({
        '_id': 1,
        'name': 'old',
        'translated_name': '',
        'type': 0,
      });

      expect(history.lastPage, 1);
      expect(history.queryJson, isNull);
    });
  });
}
