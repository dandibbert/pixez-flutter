import 'package:material_ui/material_ui.dart';

String? novelShellFontFamily() {
  // Never pin PingFang / CSS generic families on the novel shell. Settings
  // already renders CJK with the default theme; forcing a new family on macOS
  // can stall CoreText while it scans the font registry.
  return null;
}

ThemeData applyNovelShellTheme(ThemeData theme) {
  return theme;
}
