import 'dart:convert';
import 'dart:typed_data';

/// Where the app bundles the compressed dictionary.
const ipadicAssetPath = 'assets/tts/ipadic.bin.gz';

/// The compiled IPADIC written by `tool/build_ipadic_dictionary.dart`.
class IpadicDictionary {
  IpadicDictionary._({
    required this.leftSize,
    required this.matrix,
    required this.posNames,
    required this.categoryNames,
    required this.categoryFlags,
    required this.charTable,
    required this.unknown,
    required this.surfaceOffsets,
    required this.units,
    required this.entryOffsets,
    required this.entries,
  });

  static const _magic = 0x434d5850;

  final int leftSize;
  final Int16List matrix;
  final List<String> posNames;
  final List<String> categoryNames;

  /// invoke | group << 8 | length << 16, per category.
  final List<int> categoryFlags;

  /// Category mask in the low 24 bits, default category in the high 8.
  final Uint32List charTable;

  /// Unknown-word templates per category, four u16 per entry.
  final List<Uint16List> unknown;
  final Uint32List surfaceOffsets;
  final Uint16List units;
  final Uint32List entryOffsets;

  /// Four u16 per entry: left id, right id, cost (as int16), POS id.
  final Uint16List entries;

  int get surfaceCount => surfaceOffsets.length - 1;

  factory IpadicDictionary.fromBytes(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    var offset = 0;
    int u32() {
      final value = data.getUint32(offset, Endian.little);
      offset += 4;
      return value;
    }

    void align() => offset = (offset + 3) & ~3;

    // Typed views need aligned offsets; a copy is made only if the buffer
    // itself is misaligned.
    Uint8List slice(int length) {
      final start = bytes.offsetInBytes + offset;
      offset += length;
      if (start % 4 == 0) {
        return bytes.buffer.asUint8List(start, length);
      }
      return Uint8List.fromList(bytes.buffer.asUint8List(start, length));
    }

    String blob() {
      final length = u32();
      final text = utf8.decode(slice(length));
      align();
      return text;
    }

    if (u32() != _magic) {
      throw const FormatException('not a pixez IPADIC dictionary');
    }
    final version = u32();
    if (version != 1) {
      throw FormatException('unsupported IPADIC dictionary version $version');
    }
    final lsize = u32();
    final rsize = u32();
    final matrixRaw = slice(lsize * rsize * 2);
    final matrix = matrixRaw.buffer.asInt16List(
      matrixRaw.offsetInBytes,
      lsize * rsize,
    );
    align();
    final posNames = blob().split('\n');
    final categoryNames = blob().split('\n');
    final categoryCount = u32();
    final flags = [for (var i = 0; i < categoryCount; i++) u32()];
    final charBytes = slice(0x10000 * 4);
    final charTable = charBytes.buffer.asUint32List(
      charBytes.offsetInBytes,
      0x10000,
    );
    final unknown = <Uint16List>[];
    for (var i = 0; i < categoryCount; i++) {
      final count = u32();
      final raw = slice(count * 8);
      unknown.add(raw.buffer.asUint16List(raw.offsetInBytes, count * 4));
    }
    final surfaceCount = u32();
    final offsetsRaw = slice((surfaceCount + 1) * 4);
    final surfaceOffsets = offsetsRaw.buffer.asUint32List(
      offsetsRaw.offsetInBytes,
      surfaceCount + 1,
    );
    final unitCount = u32();
    final unitsRaw = slice(unitCount * 2);
    final units = unitsRaw.buffer.asUint16List(
      unitsRaw.offsetInBytes,
      unitCount,
    );
    align();
    final entryOffsetsRaw = slice((surfaceCount + 1) * 4);
    final entryOffsets = entryOffsetsRaw.buffer.asUint32List(
      entryOffsetsRaw.offsetInBytes,
      surfaceCount + 1,
    );
    final entryCount = u32();
    final entriesRaw = slice(entryCount * 8);
    final entries = entriesRaw.buffer.asUint16List(
      entriesRaw.offsetInBytes,
      entryCount * 4,
    );
    return IpadicDictionary._(
      leftSize: lsize,
      matrix: matrix,
      posNames: posNames,
      categoryNames: categoryNames,
      categoryFlags: flags,
      charTable: charTable,
      unknown: unknown,
      surfaceOffsets: surfaceOffsets,
      units: units,
      entryOffsets: entryOffsets,
      entries: entries,
    );
  }

  int connection(int previousRight, int nextLeft) =>
      matrix[previousRight + leftSize * nextLeft];

  /// Calls [onMatch] with the surface index of every dictionary word that
  /// starts at [start] in [text], shortest first.
  void commonPrefixSearch(
    String text,
    int start,
    void Function(int surface, int length) onMatch,
  ) {
    var lo = 0;
    var hi = surfaceCount;
    for (var depth = 0; start + depth < text.length; depth++) {
      final unit = text.codeUnitAt(start + depth);
      // Within [lo, hi) every surface shares the first `depth` units, and the
      // one that is exactly that long (if any) sorts first.
      lo = _lowerBound(lo, hi, depth, unit);
      hi = _upperBound(lo, hi, depth, unit);
      if (lo >= hi) {
        return;
      }
      if (surfaceOffsets[lo + 1] - surfaceOffsets[lo] == depth + 1) {
        onMatch(lo, depth + 1);
      }
    }
  }

  int _unitAt(int surface, int depth) {
    final begin = surfaceOffsets[surface];
    final length = surfaceOffsets[surface + 1] - begin;
    return depth < length ? units[begin + depth] : -1;
  }

  int _lowerBound(int lo, int hi, int depth, int unit) {
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_unitAt(mid, depth) < unit) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  int _upperBound(int lo, int hi, int depth, int unit) {
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_unitAt(mid, depth) <= unit) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }
}

/// One morpheme on the best path. Offsets are UTF-16 units in the analysed
/// text; whitespace MeCab skips before a word is not part of it.
class IpadicToken {
  const IpadicToken({
    required this.start,
    required this.end,
    required this.pos,
    required this.isUnknown,
    required this.isUserWord,
  });

  final int start;
  final int end;

  /// `品詞,細分類1,細分類2,細分類3,活用型,活用形`.
  final List<String> pos;
  final bool isUnknown;
  final bool isUserWord;
}

/// A word the caller adds to the lattice, such as a name from the user's
/// pronunciation dictionary.
class IpadicUserWord {
  const IpadicUserWord(
    this.surface, {
    this.left = personGivenNameId,
    this.right = personGivenNameId,
    this.cost = defaultCost,
  });

  /// IPADIC's context id for `名詞,固有名詞,人名,名`.
  static const personGivenNameId = 1291;

  /// IPADIC's own given names cost 8000–10000. A little cheaper makes a
  /// registered name win a boundary MeCab would otherwise guess, without
  /// beating a real verb or compound written with the same characters.
  static const defaultCost = 7000;

  final String surface;
  final int left;
  final int right;
  final int cost;
}

class _Node {
  _Node({
    required this.begin,
    required this.start,
    required this.end,
    required this.left,
    required this.right,
    required this.wordCost,
    required this.pos,
    this.isUnknown = false,
    this.isUserWord = false,
  });

  /// Where the node begins in the lattice, including skipped whitespace.
  final int begin;
  final int start;
  final int end;
  final int left;
  final int right;
  final int wordCost;
  final int pos;
  final bool isUnknown;
  final bool isUserWord;
  int cost = 0;
  _Node? previous;
}

/// MeCab's lattice search over [IpadicDictionary]: dictionary lookup,
/// unknown-word generation from `char.def`, and the Viterbi best path with
/// the same tie-breaking order, so the result matches `mecab` with IPADIC.
class IpadicTokenizer {
  IpadicTokenizer(this.dictionary)
    : _spaceMask = 1 << dictionary.categoryNames.indexOf('SPACE');

  static const _maxGroupingSize = 24;

  final IpadicDictionary dictionary;
  final int _spaceMask;
  final _posCache = <int, List<String>>{};

  List<String> posOf(int id) =>
      _posCache.putIfAbsent(id, () => dictionary.posNames[id].split(','));

  List<IpadicToken> tokenize(
    String text, {
    Iterable<IpadicUserWord> userWords = const [],
  }) {
    if (text.isEmpty) {
      return const [];
    }
    final users = <int, List<IpadicUserWord>>{};
    for (final word in userWords) {
      if (word.surface.isNotEmpty) {
        users.putIfAbsent(word.surface.codeUnitAt(0), () => []).add(word);
      }
    }
    final length = text.length;
    final endNodes = List<List<_Node>?>.filled(length + 1, null);
    final bos = _Node(
      begin: 0,
      start: 0,
      end: 0,
      left: 0,
      right: 0,
      wordCost: 0,
      pos: -1,
    );
    endNodes[0] = [bos];
    for (var pos = 0; pos < length; pos++) {
      final lefts = endNodes[pos];
      if (lefts == null) {
        continue;
      }
      final rights = _lookup(text, pos, users);
      if (rights.isEmpty) {
        // Only whitespace is left: it belongs to the end of the sentence.
        final tail = endNodes[length] ??= [];
        tail.addAll(lefts);
        continue;
      }
      // MeCab walks both lists newest first and keeps the first minimum.
      for (var r = rights.length - 1; r >= 0; r--) {
        final right = rights[r];
        _Node? best;
        var bestCost = 0x7fffffffffff;
        for (var l = lefts.length - 1; l >= 0; l--) {
          final left = lefts[l];
          final cost =
              left.cost +
              dictionary.connection(left.right, right.left) +
              right.wordCost;
          if (cost < bestCost) {
            bestCost = cost;
            best = left;
          }
        }
        right
          ..cost = bestCost
          ..previous = best;
        (endNodes[right.end] ??= []).add(right);
      }
    }
    final finals = endNodes[length];
    if (finals == null || finals.isEmpty) {
      return const [];
    }
    _Node? best;
    var bestCost = 0x7fffffffffff;
    for (var l = finals.length - 1; l >= 0; l--) {
      final left = finals[l];
      final cost = left.cost + dictionary.connection(left.right, 0);
      if (cost < bestCost) {
        bestCost = cost;
        best = left;
      }
    }
    final path = <IpadicToken>[];
    for (var node = best; node != null && node != bos; node = node.previous) {
      path.add(
        IpadicToken(
          start: node.start,
          end: node.end,
          pos: posOf(node.pos),
          isUnknown: node.isUnknown,
          isUserWord: node.isUserWord,
        ),
      );
    }
    return path.reversed.toList();
  }

  int _charInfo(String text, int index) {
    final unit = text.codeUnitAt(index);
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      // MeCab's table covers the BMP only; anything beyond is DEFAULT.
      return dictionary.charTable[0];
    }
    return dictionary.charTable[unit];
  }

  int _charLength(String text, int index) {
    final unit = text.codeUnitAt(index);
    if (unit >= 0xD800 &&
        unit <= 0xDBFF &&
        index + 1 < text.length &&
        (text.codeUnitAt(index + 1) & 0xFC00) == 0xDC00) {
      return 2;
    }
    return 1;
  }

  static bool _kindOf(int info, int other) =>
      (info & 0xFFFFFF) & (other & 0xFFFFFF) != 0;

  List<_Node> _lookup(
    String text,
    int begin,
    Map<int, List<IpadicUserWord>> users,
  ) {
    final length = text.length;
    var start = begin;
    while (start < length && _charInfo(text, start) & _spaceMask != 0) {
      start += _charLength(text, start);
    }
    if (start >= length) {
      return const [];
    }
    final info = _charInfo(text, start);
    final category = info >>> 24;
    final flags = dictionary.categoryFlags[category];
    final invoke = flags & 0xFF;
    final group = (flags >> 8) & 0xFF;
    final maxLength = (flags >> 16) & 0xFF;

    final nodes = <_Node>[];
    final entries = dictionary.entries;
    dictionary.commonPrefixSearch(text, start, (surface, size) {
      final from = dictionary.entryOffsets[surface];
      final to = dictionary.entryOffsets[surface + 1];
      for (var e = from; e < to; e++) {
        nodes.add(
          _Node(
            begin: begin,
            start: start,
            end: start + size,
            left: entries[e * 4],
            right: entries[e * 4 + 1],
            wordCost: entries[e * 4 + 2].toSigned(16),
            pos: entries[e * 4 + 3],
          ),
        );
      }
    });
    for (final word
        in users[text.codeUnitAt(start)] ?? const <IpadicUserWord>[]) {
      if (text.startsWith(word.surface, start)) {
        nodes.add(
          _Node(
            begin: begin,
            start: start,
            end: start + word.surface.length,
            left: word.left,
            right: word.right,
            wordCost: word.cost,
            pos: _userPos,
            isUserWord: true,
          ),
        );
      }
    }
    if (nodes.isNotEmpty && invoke == 0) {
      return nodes;
    }

    void addUnknown(int end) {
      final templates = dictionary.unknown[category];
      for (var k = 0; k < templates.length; k += 4) {
        nodes.add(
          _Node(
            begin: begin,
            start: start,
            end: end,
            left: templates[k],
            right: templates[k + 1],
            wordCost: templates[k + 2].toSigned(16),
            pos: templates[k + 3],
            isUnknown: true,
          ),
        );
      }
    }

    final first = _charLength(text, start);
    var cursor = start + first;
    int? groupEnd;
    if (group != 0) {
      var previous = info;
      var run = 0;
      var p = cursor;
      while (p < length) {
        final next = _charInfo(text, p);
        if (!_kindOf(previous, next)) {
          break;
        }
        previous = next;
        p += _charLength(text, p);
        run++;
      }
      if (run <= _maxGroupingSize) {
        addUnknown(p);
      }
      groupEnd = p;
    }
    for (var i = 1; i <= maxLength; i++) {
      // MeCab `continue`s here without advancing, so reaching the grouped
      // span ends the loop.
      if (cursor > length || cursor == groupEnd) {
        break;
      }
      addUnknown(cursor);
      if (cursor >= length || !_kindOf(info, _charInfo(text, cursor))) {
        break;
      }
      cursor += _charLength(text, cursor);
    }
    if (nodes.isEmpty) {
      addUnknown(start + first);
    }
    return nodes;
  }

  int get _userPos => _userPosId ??= _findUserPos();
  int? _userPosId;

  int _findUserPos() {
    final index = dictionary.posNames.indexOf('名詞,固有名詞,人名,名,*,*');
    return index < 0 ? 0 : index;
  }
}
