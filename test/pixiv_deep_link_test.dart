import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/er/pixiv_deep_link.dart';

void main() {
  group('Pixiv novel deep links', () {
    const id = 29465094;
    final supported = [
      'https://www.pixiv.net/novel/show.php?id=$id',
      'https://www.pixiv.net/novel/$id',
      'pixev://www.pixiv.net/novel/show.php?id=$id',
      'pixev://www.pixiv.net/novel/$id',
      'pixez://www.pixiv.net/novel/show.php?id=$id',
      'pixez://novel/$id',
      'pixev://novel/$id',
      'pixiv://novel/$id',
      'pixev://m.pixiv.net/novel/show.php?id=$id&lang=ja',
    ];

    for (final url in supported) {
      test('opens $url', () {
        expect(pixivNovelId(Uri.parse(url)), id);
      });
    }

    final ignored = [
      'pixev://www.pixiv.net/novel/series/$id',
      'pixev://www.pixiv.net/artworks/$id',
      'pixev://www.pixiv.net/novel/show.php?id=bad',
      'pixev://novel/-1',
      'pixev://example.com/novel/show.php?id=$id',
      'other://novel/$id',
    ];
    for (final url in ignored) {
      test('does not treat $url as a novel', () {
        expect(pixivNovelId(Uri.parse(url)), isNull);
      });
    }
  });
}
