import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/lighting/lighting_store.dart';
import 'package:pixez/main.dart';
import 'package:pixez/models/novel_persist.dart';
import 'package:pixez/page/novel/component/novel_lighting_list.dart';
import 'package:pixez/page/novel/search/novel_seen_store.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('novelSeenMarks', () {
    test('marks read, seen, and novels that moved onto a familiar page', () {
      expect(novelSeenMarks([1, 2, 3, 4], seen: {1, 3}, read: {3, 4}), [
        NovelSeenMark.seen,
        NovelSeenMark.fresh,
        NovelSeenMark.read,
        NovelSeenMark.read,
      ]);
    });

    test('a page never visited has no marks', () {
      expect(novelSeenMarks([5, 6], seen: {1}, read: {2}), [
        NovelSeenMark.none,
        NovelSeenMark.none,
      ]);
    });
  });

  test('seen novels survive reopening the store', () async {
    final dir = Directory.systemTemp.createTempSync('seen');
    Future<Database> open() => databaseFactory.openDatabase(
      '${dir.path}/seen.db',
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) => db.execute(
          'create table novel_seen (novel_id integer primary key, '
          'seen_at integer not null)',
        ),
      ),
    );
    final first = NovelSeenStore(openDb: open);
    await first.markSeen([1, 2]);
    await first.markSeen([2, 3]);
    final second = NovelSeenStore(
      openDb: () async {
        return open();
      },
    );
    await second.load();
    expect(second.ids, {1, 2, 3});
  });

  testWidgets('search results mark and hide what was seen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    // Room for all three cards; cover images need the app's image setup,
    // which this test does not start, so their errors are ignored.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final onError = FlutterError.onError;
    FlutterError.onError = (details) {
      final message = details.exceptionAsString();
      if (message.contains('LateInitializationError') ||
          message.contains('overflowed')) {
        return;
      }
      onError?.call(details);
    };
    addTearDown(() => FlutterError.onError = onError);
    final errorBuilder = ErrorWidget.builder;
    ErrorWidget.builder = (_) => const SizedBox(width: 76, height: 76);
    final dir = Directory.systemTemp.createTempSync('seenList');
    await tester.runAsync(() async {
      await databaseFactory.setDatabasesPath(dir.path);
      await novelSeenStore.markSeen([1]);
    });
    novelHistoryStore.data
      ..clear()
      ..add(
        NovelPersist(
          novelId: 2,
          userId: 1,
          pictureUrl: '',
          time: 0,
          title: 'title 2',
          userName: 'user',
        ),
      );
    final source = ApiPagedSource(
      futureGet: (page, force) async => Response(
        requestOptions: RequestOptions(path: '/v1/search/novel'),
        data: {
          'novels': [_novel(1), _novel(2), _novel(3)],
          'next_url': null,
        },
      ),
    );

    Future<void> show({required bool hide}) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: NovelLightingList(
              source: source,
              trackSeen: true,
              hideSeen: hide,
            ),
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 400));
      }
    }

    await show(hide: false);
    Finder badge(int id, String text) => find.descendant(
      of: find.ancestor(
        of: find.textContaining('title $id'),
        matching: find.byType(Card),
      ),
      matching: find.text(text),
    );
    expect(badge(1, 'Seen'), findsOneWidget);
    expect(badge(2, 'Read'), findsOneWidget);
    expect(badge(3, 'New'), findsOneWidget);
    // Novel 3 was on screen, so it is remembered for next time.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    expect(novelSeenStore.ids, containsAll([1, 3]));

    await show(hide: true);
    expect(find.textContaining('title 1'), findsNothing);
    expect(find.textContaining('title 2'), findsNothing);
    expect(find.textContaining('title 3'), findsOneWidget);
    // The test binding checks this before tear-downs run.
    ErrorWidget.builder = errorBuilder;
  });
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
