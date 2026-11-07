import 'dart:async';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// How a novel in search results relates to what the user has already looked
/// at.
enum NovelSeenMark {
  /// Nothing to say: the user has not seen it, and nothing on the page is
  /// familiar either (a page they have never been on).
  none,

  /// Not seen before, on a page that has novels the user already saw. This is
  /// the case of a novel that climbed the ranking past where they stopped.
  fresh,

  /// Shown fully on screen in search results before, but never opened.
  seen,

  /// Opened in the reader.
  read,
}

/// Marks each of [ids] in page order. [seen] is what had been seen when the
/// page loaded; [read] is what has been opened.
List<NovelSeenMark> novelSeenMarks(
  List<int> ids, {
  required Set<int> seen,
  required Set<int> read,
}) {
  final familiar = ids.any((id) => seen.contains(id) || read.contains(id));
  return [
    for (final id in ids)
      if (read.contains(id))
        NovelSeenMark.read
      else if (seen.contains(id))
        NovelSeenMark.seen
      else if (familiar)
        NovelSeenMark.fresh
      else
        NovelSeenMark.none,
  ];
}

/// Remembers every novel that was shown fully on screen in search results, so
/// a later visit to the same or another search can tell what is new.
class NovelSeenStore {
  NovelSeenStore({Future<Database> Function()? openDb})
    : _openDb = openDb ?? _openDefault;

  static const _table = 'novel_seen';

  final Future<Database> Function() _openDb;
  final Set<int> _ids = {};
  Future<Database>? _db;
  Future<void>? _loaded;

  static Future<Database> _openDefault() async {
    final path = join(await getDatabasesPath(), 'novel_seen.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) => db.execute(
        'create table $_table (novel_id integer primary key, '
        'seen_at integer not null)',
      ),
    );
  }

  Future<Database> get _database => _db ??= _openDb();

  /// Reads the stored ids once; later calls return the same future.
  Future<void> load() {
    return _loaded ??= () async {
      final rows = await (await _database).query(_table, columns: ['novel_id']);
      for (final row in rows) {
        _ids.add(row['novel_id'] as int);
      }
    }();
  }

  /// The ids seen so far. Empty until [load] completes.
  Set<int> get ids => _ids;

  Future<void> markSeen(Iterable<int> ids) async {
    await load();
    final added = ids.where(_ids.add).toList();
    if (added.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = (await _database).batch();
    for (final id in added) {
      batch.insert(_table, {
        'novel_id': id,
        'seen_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }
}

final NovelSeenStore novelSeenStore = NovelSeenStore();
