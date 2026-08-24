import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/models/tags.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  for (final oldVersion in [1, 2]) {
    test('migrates tag history v$oldVersion to v3 without data loss', () async {
      final directory = await Directory.systemTemp.createTemp(
        'pixez-tag-history-v$oldVersion-',
      );
      final path = '${directory.path}/tag.db';
      final oldDb = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: oldVersion,
          onCreate: (db, version) async {
            await db.execute('''
create table tag (
  _id integer primary key autoincrement,
  name text not null,
  translated_name text not null
  ${version >= 2 ? ', type integer' : ''}
)
''');
          },
        ),
      );
      await oldDb.insert('tag', {
        'name': 'legacy',
        'translated_name': '',
        if (oldVersion >= 2) 'type': 0,
      });
      await oldDb.close();

      final provider = TagsPersistProvider();
      await provider.open(databasePath: path);
      final rows = await provider.getAllAccount();
      final columns = await provider.db.rawQuery('pragma table_info(tag)');

      expect(rows, hasLength(1));
      expect(rows.single.name, 'legacy');
      expect(rows.single.lastPage, 1);
      expect(rows.single.queryJson, isNull);
      expect(columns.map((column) => column['name']), contains('last_page'));
      expect(columns.map((column) => column['name']), contains('query_json'));

      await provider.replaceByNameAndType(
        TagsPersist(
          name: 'legacy',
          translatedName: '',
          type: 0,
          lastPage: 5,
          queryJson: '{"version":1}',
        ),
      );
      final updated = await provider.getAllAccount();
      expect(updated, hasLength(1));
      expect(updated.single.lastPage, 5);

      await provider.close();
      await directory.delete(recursive: true);
    });
  }
}
