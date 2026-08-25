import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/network/refresh_token_interceptor.dart';

class _StubAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Future<String> _settle(Future<Response> request) {
  return request
      .then((_) => 'answered')
      .onError((error, _) => 'failed')
      .timeout(const Duration(seconds: 5), onTimeout: () => 'hung');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a token failure never leaves the request queue stuck', () async {
    final dio = Dio()
      ..httpClientAdapter = _StubAdapter()
      ..interceptors.add(
        RefreshTokenInterceptor(
          tokenReader: () async => throw StateError('no account'),
        ),
      );

    // The first request must settle, and so must the next one. A queued
    // interceptor that leaves its handler uncalled blocks every request
    // behind it, so the app stops loading with no error to show.
    expect(await _settle(dio.get('/v1/novel/recommended')), 'failed');
    expect(await _settle(dio.get('/v1/manga/recommended')), 'failed');
  });

  test('requests still go through when a token is available', () async {
    final dio = Dio()
      ..httpClientAdapter = _StubAdapter()
      ..interceptors.add(
        RefreshTokenInterceptor(tokenReader: () async => 'Bearer token'),
      );

    expect(await _settle(dio.get('/v1/novel/recommended')), 'answered');
  });
}
