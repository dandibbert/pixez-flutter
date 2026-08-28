import 'dart:async';

import 'package:dio/dio.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/lighting/lighting_store.dart';
import 'package:pixez/page/novel/component/novel_lighting_store.dart';

void main() {
  test('a request that never answers surfaces instead of spinning', () async {
    final store = NovelLightingStore(
      () => Completer<Response>().future,
      EasyRefreshController(
        controlFinishLoad: true,
        controlFinishRefresh: true,
      ),
    )..timeout = const Duration(milliseconds: 20);

    await store.fetch();

    expect(store.novels, isEmpty);
    expect(store.errorMessage, contains('did not answer'));
  });

  test('a failing request keeps its error message', () async {
    final store = NovelLightingStore(
      () => Future<Response>.error(
        DioException(
          requestOptions: RequestOptions(path: '/v1/novel/recommended'),
          message: 'boom',
        ),
      ),
      EasyRefreshController(
        controlFinishLoad: true,
        controlFinishRefresh: true,
      ),
    );

    await store.fetch();

    expect(store.errorMessage, contains('boom'));
  });

  test('paged source replaces novels and keeps the page on empty results',
      () async {
    final requested = <int>[];
    final store = NovelLightingStore(
      () => Future.error(StateError('legacy source should not run')),
      EasyRefreshController(
        controlFinishLoad: true,
        controlFinishRefresh: true,
      ),
      lightSource: ApiPagedSource(
        initialPage: 2,
        futureGet: (page, force) async {
          requested.add(page);
          if (page == 4) {
            return _novelResponse(const []);
          }
          return _novelResponse([_novel(page)], nextUrl: 'https://example.test');
        },
      ),
    );

    await store.fetch();
    expect(store.currentPage, 2);
    expect(store.novels.map((item) => item.id), [2]);

    expect(await store.fetchPage(3, force: true), isTrue);
    expect(store.currentPage, 3);
    expect(store.novels.map((item) => item.id), [3]);

    expect(await store.fetchPage(4, force: true), isFalse);
    expect(store.currentPage, 3);
    expect(store.novels.map((item) => item.id), [3]);
    expect(requested, [2, 3, 4]);
  });

  test('keeps the restored page number when the first request fails', () async {
    final store = NovelLightingStore(
      () => Future.error(StateError('legacy source should not run')),
      EasyRefreshController(
        controlFinishLoad: true,
        controlFinishRefresh: true,
      ),
      lightSource: ApiPagedSource(
        initialPage: 5,
        futureGet: (page, force) async {
          throw StateError('offline');
        },
      ),
    );

    expect(store.currentPage, 5);
    await store.fetch();
    expect(store.currentPage, 5);
    expect(await store.fetchPage(store.currentPage, force: true), isFalse);
    expect(store.currentPage, 5);
  });
}

Response _novelResponse(List<Map<String, dynamic>> novels, {String? nextUrl}) {
  return Response(
    requestOptions: RequestOptions(path: '/v1/search/novel'),
    data: {'novels': novels, 'next_url': nextUrl},
  );
}

Map<String, dynamic> _novel(int id) {
  return {
    'id': id,
    'title': 'title $id',
    'caption': '',
    'restrict': 0,
    'x_restrict': 0,
    'is_original': false,
    'image_urls': {
      'square_medium': 'https://example.test/square.jpg',
      'medium': 'https://example.test/medium.jpg',
      'large': 'https://example.test/large.jpg',
    },
    'create_date': '2026-01-01T00:00:00+09:00',
    'tags': <Map<String, dynamic>>[],
    'page_count': 1,
    'text_length': 10,
    'user': {
      'id': 1,
      'name': 'user',
      'account': 'account',
      'profile_image_urls': {'medium': 'https://example.test/user.jpg'},
      'is_followed': false,
    },
    'series': <String, dynamic>{},
    'is_bookmarked': false,
    'total_bookmarks': 0,
    'total_view': 0,
    'visible': true,
    'total_comments': 0,
    'is_muted': false,
    'is_mypixiv_only': false,
    'is_x_restricted': false,
    'novel_ai_type': 0,
  };
}
