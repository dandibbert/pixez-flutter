import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/page/novel/tts/pronunciation/morphology/ipadic_japanese_analyzer.dart';
import 'package:pixez/page/novel/tts/pronunciation/morphology/ipadic_tokenizer.dart';

void main() {
  late IpadicTokenizer tokenizer;

  setUpAll(() {
    final bytes = gzip.decode(
      File(IpadicJapaneseAnalyzer.assetPath).readAsBytesSync(),
    );
    tokenizer = IpadicTokenizer(
      IpadicDictionary.fromBytes(
        bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
      ),
    );
  });

  String render(String text, {List<IpadicUserWord> userWords = const []}) {
    return [
      for (final token in tokenizer.tokenize(text, userWords: userWords))
        '${text.substring(token.start, token.end)}/'
            '${token.pos.map((part) => part == '*' ? '' : part).join(',')}',
    ].join(' ');
  }

  test('matches MeCab with IPADIC on the golden sentences', () {
    // Regenerate with `mecab -F '%m\t%f[0],%f[1],%f[2],%f[3],%f[4],%f[5]\n'`;
    // tool/compare_ipadic_with_mecab.dart runs the same check on a corpus.
    final lines = File('test/fixtures/ipadic_mecab_golden.txt')
        .readAsLinesSync()
        .where((line) => line.isNotEmpty && !line.startsWith('#'));
    var checked = 0;
    for (final line in lines) {
      final tab = line.indexOf('\t');
      final text = line.substring(0, tab);
      expect(render(text), line.substring(tab + 1), reason: text);
      checked++;
    }
    expect(checked, greaterThan(40));
  });

  test('offsets are UTF-16 ranges in the input, whitespace excluded', () {
    const text = ' 悟は 笑った。';
    final tokens = tokenizer.tokenize(text);
    expect(tokens.first.start, 1);
    expect(
      [for (final t in tokens) text.substring(t.start, t.end)],
      ['悟', 'は', '笑っ', 'た', '。'],
    );
  });

  test('a user word changes the boundary only where the lattice agrees', () {
    const satoru = [IpadicUserWord('悟')];
    // MeCab reads `悟` before `以外` as a verb; the registered name wins.
    expect(render('悟以外').split(' ').first, startsWith('悟/動詞'));
    final named = tokenizer.tokenize('悟以外は帰った。', userWords: satoru);
    expect(named.first.isUserWord, isTrue);
    // A real conjugation still beats the name.
    final verb = tokenizer.tokenize('彼は悟った。', userWords: satoru);
    expect(verb.any((token) => token.isUserWord), isFalse);
    expect(render('彼は悟った。', userWords: satoru), contains('悟っ/動詞'));
  });

  test('characters outside the BMP do not break the lattice', () {
    const text = '𠮷野家で悟が食べた。';
    final tokens = tokenizer.tokenize(text);
    expect(tokens.last.end, text.length);
    for (final token in tokens) {
      expect(token.start, lessThan(token.end));
    }
  });
}
