/// Resolves the exact OpenAI-compatible speech endpoint. Explicit speech paths
/// are preserved, including services whose endpoint omits the `/v1` prefix.
String resolveNovelTtsOpenaiEndpoint(String raw) {
  final base = raw.trim().replaceFirst(RegExp(r'/+$'), '');
  if (base.endsWith('/audio/speech')) return base;
  if (base.endsWith('/v1')) return '$base/audio/speech';
  return '$base/v1/audio/speech';
}
