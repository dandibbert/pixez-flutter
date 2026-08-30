import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/page/novel/tts/cache/tts_cache.dart';

void main() {
  test(
    'disk cache removes least recently used complete files and ignores parts',
    () async {
      final dir = await Directory.systemTemp.createTemp('tts-lru');
      addTearDown(() => dir.delete(recursive: true));
      final old = File('${dir.path}/old.mp3');
      final recent = File('${dir.path}/recent.mp3');
      final part = File('${dir.path}/active.mp3.part');
      await old.writeAsBytes(List.filled(8, 1));
      await recent.writeAsBytes(List.filled(8, 2));
      await part.writeAsBytes(List.filled(20, 3));
      await old.setLastModified(DateTime(2020));
      await recent.setLastModified(DateTime(2021));
      final removed = await TtsDiskCache(
        directory: dir,
        maximumBytes: 8,
      ).prune(pinned: {recent.path});
      expect(removed.map((f) => f.path), contains(old.path));
      expect(await old.exists(), isFalse);
      expect(await recent.exists(), isTrue);
      expect(await part.exists(), isTrue);
    },
  );
}
