import 'dart:async';

import 'package:dio/dio.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
