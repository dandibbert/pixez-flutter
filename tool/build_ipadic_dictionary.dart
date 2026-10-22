// Compiles mecab-ipadic into the binary dictionary the novel TTS
// morphological analyzer loads (`assets/tts/ipadic.bin`).
//
// Input: mecab-ipadic 2.7.0-20070801 source converted to UTF-8, i.e. every
// `*.csv` plus `matrix.def`, `char.def` and `unk.def`, for example
//
//   for f in *.csv *.def; do iconv -f EUC-JP -t UTF-8 "$f" > utf8/"$f"; done
//
// Usage:
//
//   dart run tool/build_ipadic_dictionary.dart <utf8-ipadic-dir> [out]
//
// The analyzer reproduces MeCab's lattice search over this data, so the file
// keeps exactly what MeCab uses to choose a path: every surface with its
// context ids and cost, the connection matrix, and the character classes and
// unknown-word templates. Readings and base forms are dropped; the TTS
// pipeline only needs boundaries and part of speech.
//
// IPADIC is distributed by the Nara Institute of Science and Technology under
// the terms recorded in third_party/ipadic/COPYING.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const magic = 0x434d5850; // 'PXMC'
const version = 1;

class _Entry {
  _Entry(this.left, this.right, this.cost, this.pos);
  final int left;
  final int right;
  final int cost;
  final int pos;
}

class _Category {
  _Category(this.id, this.name, this.invoke, this.group, this.length);
  final int id;
  final String name;
  final int invoke;
  final int group;
  final int length;
}

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'usage: dart run tool/build_ipadic_dictionary.dart <utf8-ipadic-dir> '
      '[assets/tts/ipadic.bin]',
    );
    exit(64);
  }
  final dir = Directory(args[0]);
  final out = File(args.length > 1 ? args[1] : 'assets/tts/ipadic.bin');

  final posIds = <String, int>{};
  int posOf(List<String> fields) {
    final key = fields.join(',');
    return posIds.putIfAbsent(key, () => posIds.length);
  }

  // Surfaces keep the order MeCab sees them: files in name order, then lines
  // in file order. Ties between equal-cost paths are broken by that order.
  final bySurface = <String, List<_Entry>>{};
  final csvs =
      dir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.csv'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  var entryCount = 0;
  for (final file in csvs) {
    for (final line in file.readAsLinesSync()) {
      if (line.isEmpty) continue;
      final fields = line.split(',');
      bySurface
          .putIfAbsent(fields[0], () => [])
          .add(
            _Entry(
              int.parse(fields[1]),
              int.parse(fields[2]),
              int.parse(fields[3]),
              posOf(fields.sublist(4, 10)),
            ),
          );
      entryCount++;
    }
  }
  final surfaces = bySurface.keys.toList()..sort(_compareUnits);

  // Connection matrix.
  final matrixLines = File('${dir.path}/matrix.def').readAsLinesSync();
  final header = matrixLines.first.trim().split(RegExp(r'\s+'));
  final lsize = int.parse(header[0]);
  final rsize = int.parse(header[1]);
  final matrix = Int16List(lsize * rsize);
  for (final line in matrixLines.skip(1)) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length < 3) continue;
    final l = int.parse(parts[0]);
    final r = int.parse(parts[1]);
    matrix[l + lsize * r] = int.parse(parts[2]);
  }

  // Character classes, compiled the way MeCab's char_property does.
  final categories = <String, _Category>{};
  final ranges = <(int, int, List<String>)>[];
  for (final raw in File('${dir.path}/char.def').readAsLinesSync()) {
    final line = raw.split('#').first.trim();
    if (line.isEmpty) continue;
    final parts = line.split(RegExp(r'\s+'));
    if (parts[0].startsWith('0x')) {
      final bounds = parts[0].split('..');
      final low = int.parse(bounds[0].substring(2), radix: 16);
      final high = bounds.length > 1
          ? int.parse(bounds[1].substring(2), radix: 16)
          : low;
      ranges.add((low, high, parts.sublist(1)));
    } else {
      categories[parts[0]] = _Category(
        categories.length,
        parts[0],
        int.parse(parts[1]),
        int.parse(parts[2]),
        int.parse(parts[3]),
      );
    }
  }
  int encode(List<String> names) {
    var mask = 0;
    for (final name in names) {
      mask |= 1 << categories[name]!.id;
    }
    return mask | (categories[names.first]!.id << 24);
  }

  final charTable = Uint32List(0x10000);
  charTable.fillRange(0, charTable.length, encode(const ['DEFAULT']));
  for (final (low, high, names) in ranges) {
    final value = encode(names);
    for (var code = low; code <= high && code < 0x10000; code++) {
      charTable[code] = value;
    }
  }

  // Unknown-word templates per category.
  final unknown = <String, List<_Entry>>{};
  for (final line in File('${dir.path}/unk.def').readAsLinesSync()) {
    if (line.isEmpty) continue;
    final fields = line.split(',');
    unknown
        .putIfAbsent(fields[0], () => [])
        .add(
          _Entry(
            int.parse(fields[1]),
            int.parse(fields[2]),
            int.parse(fields[3]),
            posOf([...fields.sublist(4, 10)]),
          ),
        );
  }

  final w = _Writer();
  w.u32(magic);
  w.u32(version);
  w.u32(lsize);
  w.u32(rsize);
  w.int16s(matrix);

  final posNames = List<String>.filled(posIds.length, '');
  posIds.forEach((name, id) => posNames[id] = name);
  w.blob(utf8.encode(posNames.join('\n')));

  final ordered = categories.values.toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  w.blob(utf8.encode(ordered.map((c) => c.name).join('\n')));
  w.u32(ordered.length);
  for (final category in ordered) {
    w.u32(category.invoke | category.group << 8 | category.length << 16);
  }
  w.uint32s(charTable);
  for (final category in ordered) {
    final entries = unknown[category.name] ?? const [];
    w.u32(entries.length);
    for (final entry in entries) {
      w.entry(entry);
    }
  }

  final surfaceOffsets = Uint32List(surfaces.length + 1);
  final units = <int>[];
  final entryOffsets = Uint32List(surfaces.length + 1);
  var entryIndex = 0;
  for (var i = 0; i < surfaces.length; i++) {
    surfaceOffsets[i] = units.length;
    units.addAll(surfaces[i].codeUnits);
    entryOffsets[i] = entryIndex;
    entryIndex += bySurface[surfaces[i]]!.length;
  }
  surfaceOffsets[surfaces.length] = units.length;
  entryOffsets[surfaces.length] = entryIndex;
  w.u32(surfaces.length);
  w.uint32s(surfaceOffsets);
  w.uint16s(Uint16List.fromList(units));
  w.uint32s(entryOffsets);
  w.u32(entryIndex);
  for (final surface in surfaces) {
    for (final entry in bySurface[surface]!) {
      w.entry(entry);
    }
  }

  out.parent.createSync(recursive: true);
  out.writeAsBytesSync(w.bytes());
  stdout.writeln(
    'wrote ${out.path}: ${surfaces.length} surfaces, $entryCount entries, '
    '${posIds.length} POS, ${out.lengthSync()} bytes',
  );
}

int _compareUnits(String a, String b) {
  final n = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    final d = a.codeUnitAt(i) - b.codeUnitAt(i);
    if (d != 0) return d;
  }
  return a.length - b.length;
}

class _Writer {
  final _builder = BytesBuilder(copy: false);
  var _length = 0;

  void _add(List<int> bytes) {
    _builder.add(bytes);
    _length += bytes.length;
  }

  void _align() {
    final pad = (4 - _length % 4) % 4;
    if (pad > 0) _add(Uint8List(pad));
  }

  void u32(int value) {
    final data = ByteData(4)..setUint32(0, value, Endian.little);
    _add(data.buffer.asUint8List());
  }

  void entry(_Entry entry) {
    final data = ByteData(8)
      ..setUint16(0, entry.left, Endian.little)
      ..setUint16(2, entry.right, Endian.little)
      ..setInt16(4, entry.cost, Endian.little)
      ..setUint16(6, entry.pos, Endian.little);
    _add(data.buffer.asUint8List());
  }

  void blob(List<int> bytes) {
    u32(bytes.length);
    _add(bytes);
    _align();
  }

  void int16s(Int16List values) {
    final data = ByteData(values.length * 2);
    for (var i = 0; i < values.length; i++) {
      data.setInt16(i * 2, values[i], Endian.little);
    }
    _add(data.buffer.asUint8List());
    _align();
  }

  void uint16s(Uint16List values) {
    u32(values.length);
    final data = ByteData(values.length * 2);
    for (var i = 0; i < values.length; i++) {
      data.setUint16(i * 2, values[i], Endian.little);
    }
    _add(data.buffer.asUint8List());
    _align();
  }

  void uint32s(Uint32List values) {
    final data = ByteData(values.length * 4);
    for (var i = 0; i < values.length; i++) {
      data.setUint32(i * 4, values[i], Endian.little);
    }
    _add(data.buffer.asUint8List());
  }

  Uint8List bytes() => _builder.toBytes();
}
