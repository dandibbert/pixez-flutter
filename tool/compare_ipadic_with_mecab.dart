// Checks the Dart IPADIC analyzer against MeCab on a corpus and reports
// timing.
//
//   mecab -b 1000000 -F '%m\t%f[0],%f[1],%f[2],%f[3],%f[4],%f[5]\n' \
//     -E 'EOS\n' corpus.txt > mecab.out
//   dart run tool/compare_ipadic_with_mecab.dart corpus.txt mecab.out
//
// MeCab prints `*` fields as empty, so they are compared that way. Lines
// are analysed independently, as MeCab does with one sentence per line.

import 'dart:io';
import 'dart:typed_data';

import 'package:pixez/page/novel/tts/pronunciation/morphology/ipadic_tokenizer.dart';

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln(
      'usage: dart run tool/compare_ipadic_with_mecab.dart '
      '<corpus.txt> <mecab.out> [dictionary.bin.gz]',
    );
    exit(64);
  }
  final load = Stopwatch()..start();
  final compressed = File(
    args.length > 2 ? args[2] : ipadicAssetPath,
  ).readAsBytesSync();
  final inflated = gzip.decode(compressed);
  final tokenizer = IpadicTokenizer(
    IpadicDictionary.fromBytes(Uint8List.fromList(inflated)),
  );
  load.stop();

  final expected = File(args[1]).readAsStringSync().split('EOS\n');
  final lines = File(args[0]).readAsLinesSync();
  final timings = <int>[];
  var tokens = 0;
  var mismatched = 0;
  var characters = 0;
  final watch = Stopwatch();
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    characters += line.length;
    watch
      ..reset()
      ..start();
    final result = tokenizer.tokenize(line);
    watch.stop();
    timings.add(watch.elapsedMicroseconds);
    final actual = [
      for (final token in result)
        '${line.substring(token.start, token.end)}\t'
            '${token.pos.map((part) => part == '*' ? '' : part).join(',')}',
    ];
    final wanted = i < expected.length
        ? expected[i].split('\n').where((row) => row.isNotEmpty).toList()
        : const <String>[];
    tokens += wanted.length;
    if (actual.join('\n') != wanted.join('\n')) {
      mismatched++;
      if (mismatched <= 10) {
        final head = line.length > 40 ? '${line.substring(0, 40)}…' : line;
        stdout.writeln('line ${i + 1}: $head');
      }
    }
  }
  final total = timings.fold<int>(0, (sum, t) => sum + t);
  stdout
    ..writeln(
      'dictionary: ${compressed.length} B compressed, '
      '${inflated.length} B inflated, loaded in ${load.elapsedMilliseconds} ms',
    )
    ..writeln(
      'lines: ${lines.length}, MeCab tokens: $tokens, '
      'lines that differ: $mismatched',
    )
    ..writeln(
      'analysed $characters UTF-16 units in ${total ~/ 1000} ms '
      '(${(total / characters).toStringAsFixed(2)} µs per unit)',
    );
}
