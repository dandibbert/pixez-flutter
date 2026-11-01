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

  group('Pixiv search deep links', () {
    const illust = PixivSearchTarget.illust;
    const novel = PixivSearchTarget.novel;
    final supported = {
      'pixez://search?word=%E7%8C%AB': const PixivSearchLink('猫', illust),
      'pixev://search/illust?word=blue%20sky': const PixivSearchLink(
        'blue sky',
        illust,
      ),
      'pixez://search/novel?word=%E6%8E%A2%E5%81%B5': const PixivSearchLink(
        '探偵',
        novel,
      ),
      'pixiv://search/novels?q=mystery': const PixivSearchLink(
        'mystery',
        novel,
      ),
      'https://www.pixiv.net/tags/%E7%8C%AB/artworks': const PixivSearchLink(
        '猫',
        illust,
      ),
      'https://www.pixiv.net/tags/%E7%8C%AB': const PixivSearchLink(
        '猫',
        illust,
      ),
      'https://www.pixiv.net/tags/%E7%8C%AB/novels': const PixivSearchLink(
        '猫',
        novel,
      ),
      'pixev://www.pixiv.net/tags/%E7%8C%AB/manga': const PixivSearchLink(
        '猫',
        illust,
      ),
    };
    supported.forEach((url, expected) {
      test('searches $url', () {
        expect(pixivSearchLink(Uri.parse(url)), expected);
      });
    });

    final ignored = [
      'pixez://search',
      'pixez://search?word=%20',
      'pixez://search/user?word=a',
      'https://www.pixiv.net/artworks/1',
      'https://www.pixiv.net/tags/a/users',
      'https://example.com/tags/a',
      'pixez://novel/1',
    ];
    for (final url in ignored) {
      test('ignores $url', () {
        expect(pixivSearchLink(Uri.parse(url)), isNull);
      });
    }
  });
}
