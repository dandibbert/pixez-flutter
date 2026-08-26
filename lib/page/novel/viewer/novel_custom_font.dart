import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class NovelImportedFont {
  final String family;
  final String filePath;

  const NovelImportedFont({required this.family, required this.filePath});
}

class NovelCustomFont {
  static const String familyPrefix = 'pixez__';
  static final Set<String> _loaded = <String>{};

  static bool isImportedFamily(String family) =>
      family.startsWith(familyPrefix);

  static String displayName(String family) {
    if (isImportedFamily(family)) {
      return family.substring(familyPrefix.length);
    }
    return family;
  }

  static String familyFromFileName(String fileName) {
    final base = p.basenameWithoutExtension(fileName).trim();
    final safe = base.replaceAll(RegExp(r'[^\w\-\.\u0080-\uFFFF]+'), '_');
    final name = safe.isEmpty ? 'custom' : safe;
    return '$familyPrefix$name';
  }

  static Future<void> ensureLoaded(String family, String? filePath) async {
    if (filePath == null ||
        filePath.isEmpty ||
        family.isEmpty ||
        _loaded.contains(family)) {
      return;
    }
    final file = File(filePath);
    if (!await file.exists()) {
      return;
    }
    final bytes = await file.readAsBytes();
    final loader = FontLoader(family);
    loader.addFont(
      Future<ByteData>.value(
        ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes),
      ),
    );
    try {
      await loader.load();
    } catch (_) {
      // Flutter only allows a family to be registered once per process.
    }
    _loaded.add(family);
  }

  static Future<NovelImportedFont?> importPickedFile() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const <String>['ttf', 'otf', 'ttc', 'otc'],
    );
    if (picked == null) {
      return null;
    }
    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty) {
      return null;
    }
    return importBytes(fileName: picked.name, bytes: bytes);
  }

  static Future<NovelImportedFont> importBytes({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final family = familyFromFileName(fileName);
    final support = await getApplicationSupportDirectory();
    final directory = Directory(p.join(support.path, 'novel_fonts'));
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final extension = p.extension(fileName).isEmpty
        ? '.ttf'
        : p.extension(fileName);
    final dest = File(p.join(directory.path, '$family$extension'));
    await dest.writeAsBytes(bytes, flush: true);
    _loaded.remove(family);
    await ensureLoaded(family, dest.path);
    return NovelImportedFont(family: family, filePath: dest.path);
  }
}
