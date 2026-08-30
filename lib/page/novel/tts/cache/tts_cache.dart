import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

class TtsCacheInput {
  const TtsCacheInput({
    required this.spokenText,
    required this.ssml,
    required this.provider,
    required this.endpoint,
    required this.voice,
    required this.model,
    required this.speed,
    required this.pitch,
    required this.format,
  });
  final String spokenText;
  final String ssml;
  final String provider;
  final String endpoint;
  final String voice;
  final String model;
  final double speed;
  final double pitch;
  final String format;
  String get key =>
      sha256.convert(utf8.encode(jsonEncode(metadata))).toString();
  Map<String, Object> get metadata => {
    'spokenText': spokenText,
    'ssml': ssml,
    'provider': provider,
    'endpoint': endpoint,
    'voice': voice,
    'model': model,
    'speed': speed,
    'pitch': pitch,
    'format': format,
  };
  TtsCacheInput copyWithApiKeyForTest(String value) => TtsCacheInput(
    spokenText: spokenText,
    ssml: ssml,
    provider: provider,
    endpoint: endpoint,
    voice: voice,
    model: model,
    speed: speed,
    pitch: pitch,
    format: format,
  );
}

class TtsAudioValidator {
  static bool isValid(List<int> bytes) {
    if (bytes.length < 4) return false;
    if (bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) return true;
    if (bytes[0] == 0xff && (bytes[1] & 0xe0) == 0xe0) return true;
    if (bytes.length >= 12 &&
        ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WAVE')
      return true;
    if (ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'OggS')
      return true;
    if (bytes.length >= 8 &&
        ascii.decode(bytes.sublist(4, 8), allowInvalid: true) == 'ftyp')
      return true;
    return false;
  }
}

class TtsAtomicCacheWriter {
  const TtsAtomicCacheWriter();
  Future<File> write({
    required File destination,
    required List<int> bytes,
  }) async {
    await destination.parent.create(recursive: true);
    final part = File('${destination.path}.part');
    if (await part.exists()) await part.delete();
    await part.writeAsBytes(bytes, flush: true);
    final complete = await part.readAsBytes();
    if (!TtsAudioValidator.isValid(complete)) {
      await part.delete();
      throw const FormatException(
        'Synthesized response is not a supported audio file',
      );
    }
    if (await destination.exists()) await destination.delete();
    return part.rename(destination.path);
  }
}

class TtsCacheEntry {
  TtsCacheEntry({
    required this.key,
    required this.path,
    required this.bytes,
    DateTime? lastAccessed,
    this.pinned = false,
  }) : lastAccessed = lastAccessed ?? DateTime.now();
  final String key;
  final String path;
  final int bytes;
  DateTime lastAccessed;
  bool pinned;
}

class TtsLruIndex {
  final Map<String, TtsCacheEntry> _entries = {};
  void put(TtsCacheEntry entry) => _entries[entry.key] = entry;
  TtsCacheEntry? get(String key) {
    final entry = _entries[key];
    if (entry != null) entry.lastAccessed = DateTime.now();
    return entry;
  }

  List<TtsCacheEntry> evictToBytes(int maximum) {
    var total = _entries.values.fold<int>(0, (sum, e) => sum + e.bytes);
    final candidates = _entries.values.where((e) => !e.pinned).toList()
      ..sort((a, b) => a.lastAccessed.compareTo(b.lastAccessed));
    final removed = <TtsCacheEntry>[];
    for (final entry in candidates) {
      if (total <= maximum) break;
      _entries.remove(entry.key);
      total -= entry.bytes;
      removed.add(entry);
    }
    return removed;
  }
}
