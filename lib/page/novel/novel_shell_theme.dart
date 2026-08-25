import 'dart:io';

import 'package:material_ui/material_ui.dart';

String? novelShellFontFamily() {
  if (Platform.isMacOS || Platform.isIOS) {
    return 'PingFang SC';
  }
  if (Platform.isWindows) {
    return 'Microsoft YaHei UI';
  }
  return null;
}

ThemeData applyNovelShellTheme(ThemeData theme) {
  final family = novelShellFontFamily();
  if (family == null) {
    return theme;
  }
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamily: family),
    primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: family),
  );
}
