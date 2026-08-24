import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/lighting/lighting_store.dart';

void main() {
  test(
    'paged source replaces items and preserves state on invalid pages',
    () async {
      final responses = <int, Response>{
        2: _response([_illust(2)], nextUrl: 'https://example.test?offset=60'),
        3: _response([_illust(3)], nextUrl: 'https://example.test?offset=90'),
        4: _response(const [], nextUrl: null),
      };
      final store = LightingStore(
        ApiPagedSource(
          initialPage: 2,
          searchQueryJson: '{"query":"test"}',
          searchPage: 2,
          futureGet: (page, force) async => responses[page]!,
        ),
      );

      expect(await store.fetch(), isTrue);
      expect(store.currentPage, 2);
      expect(store.iStores.map((item) => item.id), [2]);
      expect(store.iStores.single.sourcePage, 2);
      expect(store.iStores.single.sourceQueryJson, '{"query":"test"}');

      expect(await store.fetchPage(3, force: true), isTrue);
      expect(store.currentPage, 3);
      expect(store.iStores.map((item) => item.id), [3]);
      expect(store.iStores.single.sourcePage, 3);

      expect(await store.fetchPage(4, force: true), isFalse);
      expect(store.currentPage, 3);
      expect(store.iStores.map((item) => item.id), [3]);
    },
  );

  test(
    'keeps the restored page number when the initial request fails',
    () async {
      final requestedPages = <int>[];
      final store = LightingStore(
        ApiPagedSource(
          initialPage: 5,
          futureGet: (page, force) async {
            requestedPages.add(page);
            throw StateError('offline');
          },
        ),
      );

      expect(store.currentPage, 5);
      expect(await store.fetch(), isFalse);
      expect(store.currentPage, 5);
      expect(await store.fetchPage(store.currentPage, force: true), isFalse);
      expect(requestedPages, [5, 5]);
    },
  );

  test('discards stale responses and runs the latest source update', () async {
    final firstResponse = Completer<Response>();
    final store = LightingStore(
      ApiPagedSource(futureGet: (page, force) => firstResponse.future),
    );

    final firstFetch = store.fetch();
    final latestFetch = store.update(
      ApiPagedSource(futureGet: (page, force) async => _response([_illust(2)])),
      force: true,
    );
    firstResponse.complete(_response([_illust(1)]));

    expect(await firstFetch, isFalse);
    expect(await latestFetch, isTrue);
    expect(store.iStores.map((item) => item.id), [2]);
  });
}

Response _response(List<Map<String, dynamic>> illusts, {String? nextUrl}) {
  return Response(
    requestOptions: RequestOptions(path: '/v1/search/illust'),
    data: {'illusts': illusts, 'next_url': nextUrl},
  );
}

Map<String, dynamic> _illust(int id) {
  return {
    'id': id,
    'title': 'title $id',
    'type': 'illust',
    'image_urls': {
      'square_medium': 'https://example.test/square.jpg',
      'medium': 'https://example.test/medium.jpg',
      'large': 'https://example.test/large.jpg',
    },
    'caption': '',
    'restrict': 0,
    'user': {
      'id': 1,
      'name': 'user',
      'account': 'account',
      'profile_image_urls': {'medium': 'https://example.test/user.jpg'},
      'is_followed': false,
    },
    'tags': <Map<String, dynamic>>[],
    'tools': <String>[],
    'create_date': '2026-01-01T00:00:00+09:00',
    'page_count': 1,
    'width': 100,
    'height': 100,
    'sanity_level': 2,
    'x_restrict': 0,
    'meta_single_page': <String, dynamic>{},
    'meta_pages': <Map<String, dynamic>>[],
    'total_view': 0,
    'total_bookmarks': 0,
    'is_bookmarked': false,
    'visible': true,
    'is_muted': false,
    'illust_ai_type': 0,
    'illust_book_style': 0,
    'total_comments': 0,
  };
}
