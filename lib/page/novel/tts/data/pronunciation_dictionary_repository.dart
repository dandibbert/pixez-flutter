import 'dart:convert';

import 'package:pixez/page/novel/tts/pronunciation/pronunciation_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PronunciationDictionaryRepository {
  static const preferencesKey = 'novel_tts_pronunciation_dictionary_v1';
  Future<List<PronunciationRule>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(preferencesKey);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw) as List;
    return List.unmodifiable(
      decoded.map(
        (entry) =>
            PronunciationRule.fromJson(Map<String, dynamic>.from(entry as Map)),
      ),
    );
  }

  Future<void> save(List<PronunciationRule> rules) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      preferencesKey,
      jsonEncode(rules.map((rule) => rule.toJson()).toList()),
    );
  }

  Future<void> upsert(PronunciationRule rule) async {
    final rules = (await load()).toList();
    final index = rules.indexWhere((item) => item.id == rule.id);
    if (index < 0) {
      rules.add(rule);
    } else {
      rules[index] = rule;
    }
    await save(rules);
  }

  Future<void> delete(String id) async {
    final rules = (await load()).where((rule) => rule.id != id).toList();
    await save(rules);
  }
}
