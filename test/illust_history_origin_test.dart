import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/models/illust_persist.dart';
import 'package:pixez/page/history/illust_history_origin.dart';
import 'package:pixez/page/search/illust_search_query.dart';
import 'package:pixez/store/search_result_mode.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  for (final oldVersion in [1, 2]) {
    test('migrates artwork history v$oldVersion to v3', () async {
      final directory = await Directory.systemTemp.createTemp(
        'pixez-illust-history-v$oldVersion-',
      );
      final path = '${directory.path}/illustpersist.db';
      final oldDb = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: oldVersion,
          onCreate: (db, version) async {
            await db.execute('''
create table illustpersist (
  id integer primary key autoincrement,
  illust_id integer not null,
  user_id integer not null,
  picture_url text not null,
  ${version >= 2 ? 'title text, user_name text,' : ''}
  time integer not null
)
''');
          },
        ),
      );
      await oldDb.insert('illustpersist', {
        'illust_id': 1,
        'user_id': 2,
        'picture_url': 'https://example.test/1.jpg',
        if (oldVersion >= 2) 'title': 'title',
        if (oldVersion >= 2) 'user_name': 'user',
        'time': 1,
      });
      await oldDb.close();

      final provider = IllustPersistProvider();
      await provider.open(databasePath: path);
      final migrated = await provider.getAllAccount();

      expect(migrated, hasLength(1));
      expect(migrated.single.sourceQueryJson, isNull);
      expect(migrated.single.sourcePage, isNull);

      const query = IllustSearchQuery(
        word: '猫',
        page: 4,
        mode: SearchResultMode.paged,
      );
      await provider.insert(
        IllustPersist(
          illustId: 1,
          userId: 2,
          pictureUrl: 'https://example.test/1.jpg',
          time: 2,
          title: 'title',
          userName: 'user',
          sourceQueryJson: query.encode(),
          sourcePage: 4,
        ),
      );
      final updated = await provider.getAllAccount();
      final restored = restoreIllustHistoryOrigin(updated.single);

      expect(restored, isNotNull);
      expect(restored!.word, '猫');
      expect(restored.page, 4);
      expect(restored.mode, SearchResultMode.paged);

      await provider.close();
      await directory.delete(recursive: true);
    });
  }

  test(
    'keeps an existing search origin when reopened outside search',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'pixez-illust-history-origin-',
      );
      final path = '${directory.path}/illustpersist.db';
      final provider = IllustPersistProvider();
      await provider.open(databasePath: path);
      const query = IllustSearchQuery(word: 'cat', page: 3);

      await provider.insert(
        IllustPersist(
          illustId: 1,
          userId: 2,
          pictureUrl: 'https://example.test/1.jpg',
          time: 1,
          title: 'title',
          userName: 'user',
          sourceQueryJson: query.encode(),
          sourcePage: 3,
        ),
      );
      await provider.insert(
        IllustPersist(
          illustId: 1,
          userId: 2,
          pictureUrl: 'https://example.test/1.jpg',
          time: 2,
          title: 'title',
          userName: 'user',
        ),
      );

      final history = (await provider.getAllAccount()).single;
      expect(history.sourceQueryJson, query.encode());
      expect(history.sourcePage, 3);

      await provider.close();
      await directory.delete(recursive: true);
    },
  );
}
