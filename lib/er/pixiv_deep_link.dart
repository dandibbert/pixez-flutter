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

enum PixivSearchTarget { illust, novel }

/// A keyword search requested by a link.
class PixivSearchLink {
  const PixivSearchLink(this.word, this.target);

  final String word;
  final PixivSearchTarget target;

  @override
  bool operator ==(Object other) =>
      other is PixivSearchLink && other.word == word && other.target == target;

  @override
  int get hashCode => Object.hash(word, target);

  @override
  String toString() => 'PixivSearchLink($word, ${target.name})';
}

/// Returns the search a link asks for, or null when it is not a search link.
///
/// App links: pixez://search?word=猫 (illusts), pixez://search/novel?word=猫,
/// also under pixev:// and pixiv://. Pixiv web tag pages are searches too:
/// https://www.pixiv.net/tags/猫/artworks and .../tags/猫/novels.
PixivSearchLink? pixivSearchLink(Uri link) {
  final scheme = link.scheme.toLowerCase();
  final host = link.host.toLowerCase();
  final path = link.pathSegments.where((s) => s.isNotEmpty).toList();

  if (const {'pixez', 'pixev', 'pixiv'}.contains(scheme) && host == 'search') {
    final word = (link.queryParameters['word'] ?? link.queryParameters['q'])
        ?.trim();
    if (word == null || word.isEmpty || path.length > 1) return null;
    final target = switch (path.firstOrNull?.toLowerCase()) {
      null || 'illust' || 'illusts' || 'artworks' => PixivSearchTarget.illust,
      'novel' || 'novels' => PixivSearchTarget.novel,
      _ => null,
    };
    return target == null ? null : PixivSearchLink(word, target);
  }

  const schemes = {'http', 'https', 'pixez', 'pixev'};
  if (!schemes.contains(scheme) ||
      !const {'pixiv.net', 'www.pixiv.net', 'm.pixiv.net'}.contains(host) ||
      path.length < 2 ||
      path.length > 3 ||
      path.first != 'tags') {
    return null;
  }
  final word = path[1].trim();
  if (word.isEmpty) return null;
  final target = switch (path.length == 3 ? path[2] : null) {
    null ||
    'artworks' ||
    'illustrations' ||
    'manga' => PixivSearchTarget.illust,
    'novels' => PixivSearchTarget.novel,
    _ => null,
  };
  return target == null ? null : PixivSearchLink(word, target);
}
