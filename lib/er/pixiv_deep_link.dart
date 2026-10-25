/// Returns the novel ID from a Pixiv URL, including PixEz/Pixev deep links.
///
/// Supports links produced by changing an HTTPS Pixiv URL's scheme:
/// https://www.pixiv.net/novel/show.php?id=123
/// pixev://www.pixiv.net/novel/show.php?id=123
/// and the shorter pixev://novel/123 / pixez://novel/123 forms.
int? pixivNovelId(Uri link) {
  final scheme = link.scheme.toLowerCase();
  const schemes = {'http', 'https', 'pixez', 'pixev', 'pixiv'};
  if (!schemes.contains(scheme)) return null;

  final host = link.host.toLowerCase();
  final path = link.pathSegments;
  if (const {'pixez', 'pixev', 'pixiv'}.contains(scheme) &&
      host == 'novel' &&
      path.length == 1) {
    return _positiveId(path.single);
  }

  if (!const {'pixiv.net', 'www.pixiv.net', 'm.pixiv.net'}.contains(host)) {
    return null;
  }
  if (path.length != 2 || path.first != 'novel') return null;
  if (path.last == 'show.php') {
    return _positiveId(link.queryParameters['id']);
  }
  return _positiveId(path.last);
}

int? _positiveId(String? value) {
  final id = int.tryParse(value ?? '');
  return id != null && id > 0 ? id : null;
}
