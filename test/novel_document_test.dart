import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/page/novel/viewer/novel_pages.dart';
import 'package:pixez/page/novel/viewer/novel_spans.dart';
import 'package:pixez/page/novel/viewer/novel_store.dart';

/// Rough shape of a pixiv novel page: a lot of chrome markup plus one inline
/// script holding the novel payload.
String buildNovelPage(String body) {
  final novelJson = jsonEncode({
    'id': '1',
    'title': 'Winter Story',
    'seriesId': null,
    'seriesTitle': null,
    'seriesIsWatched': null,
    'userId': '7',
    'coverUrl': '',
    'tags': <String>[],
    'caption': '',
    'cdate': '',
    'rating': {'like': 0, 'bookmark': 0, 'view': 0},
    'text': body,
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
      '<script>window.dataLayer = [{"a":1}];</script></head>'
      '<body>$chrome'
      '<script>window.pixiv = {timestamp:"x",novel:$novelJson};</script>'
      '</body></html>';
}

String longBody(int chars) {
  const line = '彼女は静寂の中でゆっくりと呼吸を整え、窓の外に降りしきる雪を眺めていた。\n';
  final buffer = StringBuffer();
  while (buffer.length < chars) {
    buffer.write(line);
  }
  return buffer.toString().substring(0, chars);
}

void main() {
  test('parseNovelDocument returns the model and the reader spans', () {
    final document = parseNovelDocument(
      buildNovelPage('冒頭。[newpage][chapter:第二章]彼は[[rb:走>はし]]った。'),
    );

    expect(document.webResponse.title, 'Winter Story');
    expect(document.webResponse.userId, '7');

    final types = document.spans.map((span) => span.type).toList();
    expect(types, contains(NovelSpansType.newPage));
    expect(types, contains(NovelSpansType.chapter));
    expect(types, contains(NovelSpansType.rb));

    final pages = splitNovelSpanPages(document.spans);
    expect(pages, hasLength(2));
    expect(pages.first.single.text, '冒頭。');
  });

  test('a page whose script has no novel payload is reported, not silent', () {
    expect(
      () => parseNovelDocument('<html><body><p>nothing here</p></body></html>'),
      throwsA(isA<FormatException>()),
    );
  });

  test('a long chapter parses in well under a frame budget', () {
    // The old character-by-character parser was quadratic: an 80k-character
    // chapter cost over half a second of CPU and gigabytes of string copying,
    // every time a chapter was opened. Guard the linear behaviour end to end.
    final page = buildNovelPage(longBody(80000));
    parseNovelDocument(page); // warm up

    final watch = Stopwatch()..start();
    final document = parseNovelDocument(page);
    watch.stop();

    expect(document.spans, isNotEmpty);
    expect(
      watch.elapsedMilliseconds,
      lessThan(250),
      reason: 'took ${watch.elapsedMilliseconds}ms',
    );
  }, timeout: const Timeout(Duration(minutes: 5)));
}
