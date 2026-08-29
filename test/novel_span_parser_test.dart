import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/page/novel/viewer/novel_spans.dart';

/// The original character-by-character tokenizer, kept verbatim as the
/// reference the linear scanner must match. `nowStr` grew one character at a
/// time, which is what made opening a long chapter quadratic.
List<NovelTextToken> referenceTokenize(String source) {
  final result = <NovelTextToken>[];
  var nowStr = '';
  for (var i = 0; i < source.length; i++) {
    final posStr = source[i];
    if (posStr == '[') {
      if (nowStr.isEmpty) {
        nowStr = posStr;
      } else {
        if (nowStr == '[') {
          nowStr += posStr;
        } else {
          result.add(NovelTextToken(nowStr, delimited: false));
          nowStr = posStr;
        }
      }
    } else if (posStr == ']') {
      if (nowStr.startsWith('[[')) {
        if (nowStr.endsWith(']')) {
          nowStr += posStr;
          result.add(NovelTextToken(nowStr, delimited: true));
          nowStr = '';
        } else {
          nowStr += posStr;
        }
      } else {
        nowStr += posStr;
        result.add(NovelTextToken(nowStr, delimited: true));
        nowStr = '';
      }
    } else {
      nowStr += posStr;
    }
  }
  if (nowStr.isNotEmpty) {
    result.add(NovelTextToken(nowStr, delimited: false));
  }
  return result;
}

Matcher _matchesReference(String source) => _MatchesReference(source);

class _MatchesReference extends Matcher {
  const _MatchesReference(this.source);

  final String source;

  List<String> _describeTokens(List<NovelTextToken> tokens) => [
        for (final token in tokens) '${token.delimited ? 'tag' : 'txt'}:${token.text}',
      ];

  @override
  bool matches(dynamic item, Map matchState) {
    final actual = _describeTokens(tokenizeNovelText(source));
    final expected = _describeTokens(referenceTokenize(source));
    matchState['actual'] = actual;
    matchState['expected'] = expected;
    if (actual.length != expected.length) return false;
    for (var i = 0; i < actual.length; i++) {
      if (actual[i] != expected[i]) return false;
    }
    return true;
  }

  @override
  Description describe(Description description) =>
      description.add('tokenizes exactly like the original parser');

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    return mismatchDescription
        .add('source   : ${source.replaceAll('\n', r'\n')}\n')
        .add('expected : ${matchState['expected']}\n')
        .add('actual   : ${matchState['actual']}');
  }
}

void main() {
  group('tokenizeNovelText matches the original parser', () {
    const cases = <String>[
      '',
      'plain text with no markup',
      '[newpage]',
      '[chapter:第一章]',
      'before[newpage]after',
      '[[rb:漢字＞かんじ]]',
      '彼は[[rb:走>はし]]った。',
      '[[jumpuri:pixiv > https://www.pixiv.net/novel/show.php?id=1]]',
      '[uploadedimage:12345]',
      '[pixivimage:123-1]',
      // Malformed / adversarial shapes that must not change meaning.
      '[',
      ']',
      '[]',
      '[[',
      ']]',
      '[[]]',
      '[[]',
      '[]]',
      'a]b',
      'a[b',
      '[chapter:unterminated',
      '[chapter:one[chapter:two]',
      '[[rb:a>b]',
      '[[rb:a>b]]]',
      '[[[rb:a>b]]',
      'text[[rb:a>b]]more[newpage]tail',
      '[[a]][[b]]',
      '[a][b]',
      '\n\n[newpage]\n\n',
    ];

    for (final source in cases) {
      test('case ${source.isEmpty ? '<empty>' : source.replaceAll('\n', r'\n')}',
          () {
        expect(source, _matchesReference(source));
      });
    }

    test('randomised bracket soup', () {
      final random = Random(20260829);
      const alphabet = ['[', ']', 'a', '本', '\n', ':', '>', 'r', 'b'];
      for (var iteration = 0; iteration < 3000; iteration++) {
        final length = random.nextInt(40);
        final buffer = StringBuffer();
        for (var i = 0; i < length; i++) {
          buffer.write(alphabet[random.nextInt(alphabet.length)]);
        }
        expect(buffer.toString(), _matchesReference(buffer.toString()));
      }
    });

    test('randomised realistic novel bodies', () {
      final random = Random(510);
      const fragments = [
        '彼女は静かに息を吐いた。\n',
        '[newpage]',
        '[chapter:第%d章]',
        '[[rb:紅玉＞こうぎょく]]',
        '[[jumpuri:link > https://www.pixiv.net/artworks/1]]',
        '[uploadedimage:99]',
        '[jump:3]',
        '\n',
        'A plain english line.\n',
      ];
      for (var iteration = 0; iteration < 300; iteration++) {
        final buffer = StringBuffer();
        final pieces = random.nextInt(60);
        for (var i = 0; i < pieces; i++) {
          buffer.write(fragments[random.nextInt(fragments.length)]);
        }
        expect(buffer.toString(), _matchesReference(buffer.toString()));
      }
    });
  });

  test('tokens always reconstruct the source exactly', () {
    final random = Random(7);
    const alphabet = ['[', ']', 'x', '。', '\n'];
    for (var iteration = 0; iteration < 2000; iteration++) {
      final buffer = StringBuffer();
      for (var i = 0; i < random.nextInt(30); i++) {
        buffer.write(alphabet[random.nextInt(alphabet.length)]);
      }
      final source = buffer.toString();
      final rebuilt =
          tokenizeNovelText(source).map((token) => token.text).join();
      expect(rebuilt, source);
    }
  });

  test('tokenizing a long chapter scales linearly, not quadratically', () {
    // The old parser grew a String per character, so each doubling of the body
    // quadrupled the work. Guard the linear behaviour: a 16x longer body must
    // stay far below the 256x a quadratic scan would cost.
    const line = '彼女は静寂の中でゆっくりと呼吸を整え、窓の外に降りしきる雪を眺めていた。\n';

    String body(int chars) {
      final buffer = StringBuffer();
      while (buffer.length < chars) {
        buffer.write(line);
      }
      return buffer.toString().substring(0, chars);
    }

    int microsFor(int chars) {
      final source = body(chars);
      // Warm up so the first measurement is not dominated by JIT.
      tokenizeNovelText(source);
      final watch = Stopwatch()..start();
      for (var i = 0; i < 5; i++) {
        tokenizeNovelText(source);
      }
      watch.stop();
      return watch.elapsedMicroseconds;
    }

    final small = microsFor(10000);
    final large = microsFor(160000);
    // 16x the input. Linear would be ~16x the time; allow generous slack for a
    // noisy machine but stay nowhere near the 256x of the quadratic parser.
    expect(
      large,
      lessThan(max(small, 200) * 48),
      reason: 'small=${small}us large=${large}us',
    );
  });
}
