import 'dart:io';

/// Android/iOS keep the original swipeable novel tabs.
/// Desktop must not place a horizontal [PageView] under the same click that
/// opened 小说; that gesture fight beachballs macOS.
bool novelRailUsesSwipeablePages({
  bool? isAndroid,
  bool? isIOS,
}) {
  return (isAndroid ?? Platform.isAndroid) || (isIOS ?? Platform.isIOS);
}
