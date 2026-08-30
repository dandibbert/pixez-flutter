import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every supported locale defines the complete TTS message set', () {
    final directory = Directory('lib/l10n');
    final files =
        directory
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.arb'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    final template = _messages(File('lib/l10n/intl_en_US.arb'));
    final ttsKeys = template.keys
        .where((key) => key.startsWith('tts_'))
        .toSet();

    expect(ttsKeys.length, 85);
    for (final file in files) {
      final messages = _messages(file);
      final missing = ttsKeys.difference(messages.keys.toSet());
      expect(missing, isEmpty, reason: file.path + ' is missing TTS messages');
      for (final key in ttsKeys) {
        expect(
          _placeholders(messages[key]!),
          _placeholders(template[key]!),
          reason: file.path + ': ' + key + ' has mismatched placeholders',
        );
      }
    }
  });

  test('non-English locale catalogs translate the TTS interface', () {
    final template = _messages(File('lib/l10n/intl_en_US.arb'));
    final ttsKeys = template.keys
        .where((key) => key.startsWith('tts_'))
        .toList();
    final localeFiles = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where(
          (file) =>
              file.path.endsWith('.arb') &&
              !file.path.endsWith('intl_en.arb') &&
              !file.path.endsWith('intl_en_US.arb'),
        );

    for (final file in localeFiles) {
      final messages = _messages(file);
      expect(
        messages.keys,
        containsAll(ttsKeys),
        reason: file.path + ' must define every TTS message before review',
      );
      final unchanged = ttsKeys
          .where((key) => messages[key] == template[key])
          .toList();
      expect(
        unchanged.length,
        lessThan(20),
        reason:
            file.path +
            ' still falls back to English for: ' +
            unchanged.join(', '),
      );
    }
  });
}

Map<String, String> _messages(File file) {
  final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final entry in decoded.entries)
      if (!entry.key.startsWith('@') && entry.value is String)
        entry.key: entry.value as String,
  };
}

Set<String> _placeholders(String value) => RegExp(
  r'\{([A-Za-z_][A-Za-z0-9_]*)\}',
).allMatches(value).map((match) => match.group(1)!).toSet();
