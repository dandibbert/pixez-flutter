import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/page/novel/viewer/novel_store.dart';

/// Rough shape of a pixiv novel page: a lot of chrome markup plus one big
/// inline script holding the novel JSON.
String buildHtml(int bodyChars) {
  const line = '彼女は静寂の中でゆっくりと呼吸を整え、窓の外に降りしきる雪を眺めていた。\\n';
  final body = StringBuffer();
  while (body.length < bodyChars) {
    body.write(line);
  }
  final novelJson = jsonEncode({
    'id': '1',
    'title': 'title',
    'seriesId': null,
    'seriesTitle': null,
    'seriesIsWatched': null,
    'userId': '1',
    'coverUrl': '',
    'tags': <String>[],
    'caption': '',
    'cdate': '',
    'rating': {'like': 0, 'bookmark': 0, 'view': 0},
    'text': body.toString(),
    'marker': null,
    'seriesNavigation': null,
    'glossaryItems': <dynamic>[],
    'replaceableItemIds': <dynamic>[],
    'aiType': 0,
    'isOriginal': true,
  });

  final chrome = StringBuffer();
  for (var i = 0; i < 1500; i++) {
    chrome.write(
      '<div class="sc-$i wrapper" data-index="$i">'
      '<span class="label">item $i</span>'
      '<a href="/artworks/$i">link $i</a></div>',
    );
  }

  return '<!DOCTYPE html><html><head><title>t</title>'
      '<script>window.dataLayer = [{"a":1}];</script>'
      '</head><body>${chrome.toString()}'
      '<script>window.pixiv = {timestamp:"x",novel:$novelJson};</script>'
      '</body></html>';
}

void main() {
  test('BENCH parseNovelJsonFromHtml', () {
    for (final chars in [10000, 40000, 80000]) {
      final html = buildHtml(chars);
      // warm up
      parseNovelJsonFromHtml(html);
      final watch = Stopwatch()..start();
      final json = parseNovelJsonFromHtml(html);
      watch.stop();
      final decodeWatch = Stopwatch()..start();
      jsonDecode(json!);
      decodeWatch.stop();
      print('BENCH body=${chars.toString().padLeft(6)} chars, '
          'html=${(html.length / 1024).round()}KB -> '
          'htmlParse=${watch.elapsedMilliseconds}ms '
          'jsonDecode=${decodeWatch.elapsedMilliseconds}ms');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
