import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager_dio/flutter_cache_manager_dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/component/pixiv_image.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => Directory.systemTemp.path,
        );
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DioCacheManager.initialize(Dio());
    configurePixivCacheManager(DioCacheManager.instance);
  });

  group('Pixiv image decode sizing', () {
    test('converts logical card width to physical pixels', () {
      expect(calculatePixivDecodeDimension(180, 3), 576);
      expect(calculatePixivDecodeDimension(200, 3), 640);
    });

    test('caps very large images and rejects invalid dimensions', () {
      expect(calculatePixivDecodeDimension(2000, 3), 2048);
      expect(calculatePixivDecodeDimension(null, 3), isNull);
      expect(calculatePixivDecodeDimension(double.infinity, 3), isNull);
      expect(calculatePixivDecodeDimension(100, 0), isNull);
    });

    test('limits concurrent image fetches', () {
      expect(
        pixivCacheManager!.config.fileService.concurrentFetches,
        pixivImageConcurrentFetches,
      );
    });

    testWidgets(
      'search thumbnails opt in while zoomable images stay full size',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(devicePixelRatio: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: PixivImage(
                      'https://example.test/thumbnail.jpg',
                      autoResizeMemoryCache: true,
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: PixivImage('https://example.test/zoom.jpg'),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();

        final images = tester
            .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
            .toList(growable: false);
        expect(images, hasLength(2));
        expect(images[0].memCacheWidth, 640);
        expect(images[0].memCacheHeight, isNull);
        expect(images[1].memCacheWidth, isNull);
      },
    );
  });
}
