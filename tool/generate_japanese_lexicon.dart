// Regenerates the Japanese inflection lexicon used by the novel TTS
// pronunciation pipeline.
//
// Input: mecab-ipadic 2.7.0 CSV files converted to UTF-8, for example
//
//   curl -sSLO https://raw.githubusercontent.com/taku910/mecab/master/mecab-ipadic/Verb.csv
//   iconv -f EUC-JP -t UTF-8 Verb.csv > utf8/Verb.csv
//
// Usage:
//
//   dart run tool/generate_japanese_lexicon.dart <utf8-ipadic-dir>
//
// IPADIC is distributed by the Nara Institute of Science and Technology under
// the terms recorded in third_party/ipadic/COPYING.

import 'dart:convert';
import 'dart:io';

const _inflectedSources = ['Verb.csv', 'Adj.csv'];
const _fixedSources = {
  'Adverb.csv': '副詞',
  'Noun.adverbal.csv': '名詞',
  'Noun.adjv.csv': '名詞',
  'Noun.others.csv': '名詞',
  'Noun.nai.csv': '名詞',
  'Conjunction.csv': '接続詞',
};

/// Classical or colloquial conjugation classes. Their endings collide with
/// modern particles (`思は`, `死に`), so a name alias must not be rejected
/// because of them.
bool _isExcludedClass(String type) {
  return type.startsWith('四段') ||
      type.startsWith('上二') ||
      type.startsWith('下二') ||
      type == 'ラ変' ||
      type == '不変化型';
}

/// Conjugation forms whose surface is colloquial or classical enough that we
/// refuse to treat them as evidence of a verb.
const _skippedForms = {
  '仮定縮約１',
  '仮定縮約２',
  '体言接続特殊',
  '体言接続特殊２',
  '未然特殊',
};

/// Maps an IPADIC conjugation form to the follow-up text it requires.
///
///  * `f` free — the form can end a clause, so no follow-up is needed.
///  * `n` needs a negative/passive/causative auxiliary.
///  * `u` needs the volitional `う`.
///  * `t` needs the past/gerund `た`/`て`.
///  * `b` needs the conditional `ば`.
///  * `g` needs the polite `ございます`.
String? _policyFor(String form) {
  switch (form) {
    case '基本形':
    case '基本形-促音便':
    case '連用形':
    case '連用テ接続':
    case '体言接続':
    case '文語基本形':
    case 'ガル接続':
    case '命令ｅ':
    case '命令ｉ':
    case '命令ｒｏ':
    case '命令ｙｏ':
      return 'f';
    case '未然形':
    case '未然ヌ接続':
    case '未然レル接続':
      return 'n';
    case '未然ウ接続':
      return 'u';
    case '連用タ接続':
      return 't';
    case '仮定形':
      return 'b';
    case '連用ゴザイ接続':
      return 'g';
  }
  return null;
}

const _policyRank = {'f': 0, 't': 1, 'n': 2, 'b': 3, 'u': 4, 'g': 5};

final _kanji = RegExp(r'[\u3005\u3400-\u4DBF\u4E00-\u9FFF\uF900-\uFAFF]');
final _kana = RegExp(r'[\u3040-\u309F\u30A0-\u30FF]');

class _Group {
  _Group(this.lemma, this.type, this.partOfSpeech);

  final String lemma;
  final String type;
  final String partOfSpeech;
  final forms = <String, Set<String>>{};
}

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln(
      'usage: dart run tool/generate_japanese_lexicon.dart <utf8-ipadic-dir>',
    );
    exitCode = 64;
    return;
  }
  final dir = Directory(args.single);
  if (!dir.existsSync()) {
    stderr.writeln('no such directory: ${dir.path}');
    exitCode = 66;
    return;
  }

  final groups = <String, _Group>{};
  for (final name in _inflectedSources) {
    for (final row in _rows(dir, name)) {
      final type = row[8];
      if (_isExcludedClass(type)) {
        continue;
      }
      final key = '${row[10]}\u0000$type\u0000${row[4]}';
      final group = groups.putIfAbsent(
        key,
        () => _Group(row[10], type, row[4]),
      );
      group.forms.putIfAbsent(row[0], () => <String>{}).add(row[9]);
    }
  }

  final endings = <String, Map<String, String>>{};
  final stems = <String, Set<String>>{};
  final partOfSpeech = <String, String>{};
  final baseEndings = <String, Map<String, int>>{};
  for (final group in groups.values) {
    final surfaces = {...group.forms.keys, group.lemma};
    final stem = _commonPrefix(surfaces);
    if (stem.isEmpty) {
      continue;
    }
    partOfSpeech[group.type] = group.partOfSpeech;
    final table = endings.putIfAbsent(group.type, () => {});
    final sahen = group.type.startsWith('サ変');
    for (final entry in group.forms.entries) {
      final ending = entry.key.substring(stem.length);
      final policies = <String>[];
      for (final form in entry.value) {
        if (_skippedForms.contains(form)) {
          continue;
        }
        final policy = _policyFor(form);
        if (policy != null) {
          policies.add(sahen ? 'f' : policy);
        }
      }
      if (policies.isEmpty) {
        continue;
      }
      policies.sort((a, b) => _policyRank[a]!.compareTo(_policyRank[b]!));
      final existing = table[ending];
      if (existing == null ||
          _policyRank[policies.first]! < _policyRank[existing]!) {
        table[ending] = policies.first;
      }
    }
    (baseEndings.putIfAbsent(group.type, () => {}))
        .update(
          group.lemma.substring(stem.length),
          (value) => value + 1,
          ifAbsent: () => 1,
        );
    if (_kanji.hasMatch(stem)) {
      stems.putIfAbsent(group.type, () => <String>{}).add(stem);
    }
  }

  final fixed = <String, Set<String>>{};
  for (final entry in _fixedSources.entries) {
    for (final row in _rows(dir, entry.key)) {
      final surface = row[0];
      if (!_kanji.hasMatch(surface) || !_kana.hasMatch(surface)) {
        continue;
      }
      fixed.putIfAbsent(entry.value, () => <String>{}).add(surface);
    }
  }

  final types = stems.keys.toList()
    ..sort((a, b) {
      final size = stems[b]!.length.compareTo(stems[a]!.length);
      return size != 0 ? size : a.compareTo(b);
    });

  final out = StringBuffer()
    ..writeln('// GENERATED FILE. Do not edit by hand.')
    ..writeln('//')
    ..writeln(
      '// Regenerate with `dart run tool/generate_japanese_lexicon.dart '
      '<utf8-ipadic-dir>`.',
    )
    ..writeln(
      '// Derived from mecab-ipadic 2.7.0-20070801 (Nara Institute of Science',
    )
    ..writeln('// and Technology). See third_party/ipadic/COPYING.')
    ..writeln()
    ..writeln(
      "import 'package:pixez/page/novel/tts/pronunciation/morphology/"
      "japanese_inflection_lexicon.dart';",
    )
    ..writeln()
    ..writeln("const japaneseLexiconSource = 'mecab-ipadic-2.7.0-20070801';")
    ..writeln()
    ..writeln('const japaneseInflectionClasses = <JapaneseInflectionClass>[');
  var stemCount = 0;
  for (final type in types) {
    final table = endings[type]!;
    final keys = table.keys.toList()
      ..sort((a, b) {
        final length = b.length.compareTo(a.length);
        return length != 0 ? length : a.compareTo(b);
      });
    final base = baseEndings[type]!;
    final baseEnding = (base.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .first
        .key;
    final sorted = stems[type]!.toList()..sort();
    stemCount += sorted.length;
    out
      ..writeln('  JapaneseInflectionClass(')
      ..writeln("    ${_literal(type)},")
      ..writeln("    ${_literal(partOfSpeech[type]!)},")
      ..writeln("    ${_literal(baseEnding)},")
      ..writeln(
        '    ${_literal([for (final key in keys) '$key:${table[key]}'].join(';'))},',
      )
      ..writeln('    ${_literal(sorted.join('\n'))},')
      ..writeln('  ),');
  }
  out
    ..writeln('];')
    ..writeln()
    ..writeln('const japaneseFixedWords = <JapaneseFixedWordGroup>[');
  final fixedTypes = fixed.keys.toList()..sort();
  var fixedCount = 0;
  for (final type in fixedTypes) {
    final sorted = fixed[type]!.toList()..sort();
    fixedCount += sorted.length;
    out
      ..writeln('  JapaneseFixedWordGroup(')
      ..writeln("    ${_literal(type)},")
      ..writeln('    ${_literal(sorted.join('\n'))},')
      ..writeln('  ),');
  }
  out.writeln('];');

  final target = File(
    'lib/page/novel/tts/pronunciation/morphology/japanese_lexicon_data.dart',
  );
  target.writeAsStringSync(out.toString());
  stdout.writeln(
    'wrote ${target.path}: ${types.length} classes, $stemCount stems, '
    '$fixedCount fixed words, '
    '${(target.lengthSync() / 1024).toStringAsFixed(1)} KiB',
  );
}

Iterable<List<String>> _rows(Directory dir, String name) {
  final file = File('${dir.path}/$name');
  if (!file.existsSync()) {
    throw StateError('missing ${file.path}');
  }
  return file
      .readAsLinesSync(encoding: utf8)
      .map(_splitCsv)
      .where((row) => row.length >= 13);
}

List<String> _splitCsv(String line) {
  final cells = <String>[];
  final buffer = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '"') {
      quoted = !quoted;
      continue;
    }
    if (char == ',' && !quoted) {
      cells.add(buffer.toString());
      buffer.clear();
      continue;
    }
    buffer.write(char);
  }
  cells.add(buffer.toString());
  return cells;
}

String _commonPrefix(Iterable<String> values) {
  final sorted = values.toList()..sort();
  var prefix = sorted.first;
  for (final value in sorted.skip(1)) {
    var i = 0;
    while (i < prefix.length && i < value.length && prefix[i] == value[i]) {
      i++;
    }
    prefix = prefix.substring(0, i);
    if (prefix.isEmpty) {
      break;
    }
  }
  while (prefix.isNotEmpty && _isHighSurrogate(prefix.codeUnitAt(prefix.length - 1))) {
    prefix = prefix.substring(0, prefix.length - 1);
  }
  return prefix;
}

bool _isHighSurrogate(int unit) {
  return unit >= 0xD800 && unit <= 0xDBFF;
}

String _literal(String value) => jsonEncode(value);
