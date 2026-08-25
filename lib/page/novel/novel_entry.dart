import 'dart:io';

/// Settings → 小说 should match マンガ: one recommend page, not the Android
/// [NovelRail] shell. The rail builds ranking/search/settings on a PageView
/// and previously pinned a custom UI font, which can freeze macOS on tap.
bool usesCompactNovelHome({bool? isAndroid}) {
  return !(isAndroid ?? Platform.isAndroid);
}
