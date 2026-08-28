import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/page/novel/viewer/novel_links.dart';

void main() {
  test('parses pixvel-style novel jump URLs', () {
    expect(parsePixivNovelId('pixiv://novels/12345'), 12345);
    expect(
      parsePixivNovelId('https://www.pixiv.net/novel/show.php?id=67890'),
      67890,
    );
    expect(parsePixivNovelId('https://www.pixiv.net/novel/111'), 111);
    expect(parsePixivNovelId('https://example.test/not-pixiv/222'), isNull);
    expect(parsePixivNovelId('https://www.pixiv.net/artworks/333'), isNull);
  });
}
