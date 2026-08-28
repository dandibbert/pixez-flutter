/// Pixvel-style novel URL detection for `[[jumpuri:...]]`.
int? parsePixivNovelId(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;

  final pixivScheme = RegExp(r'^pixiv://novels/(\d+)', caseSensitive: false);
  final schemeMatch = pixivScheme.firstMatch(value);
  if (schemeMatch != null) {
    return int.tryParse(schemeMatch.group(1)!);
  }

  final uri = Uri.tryParse(value);
  if (uri == null) return null;
  final host = uri.host.toLowerCase();
  final isPixivHost = host.contains('pixiv.net') || host == 'pixiv.me';
  if (!isPixivHost) return null;

  final showId = uri.queryParameters['id'];
  if (showId != null && uri.path.contains('novel')) {
    return int.tryParse(showId);
  }

  final pathMatch = RegExp(r'/novel(?:/show\.php)?/(\d+)').firstMatch(uri.path);
  if (pathMatch != null) {
    return int.tryParse(pathMatch.group(1)!);
  }
  return null;
}
