import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/page/novel/tts/novel_tts_diagnostics.dart';
import 'package:pixez/page/novel/tts/novel_tts_engine.dart';
import 'package:pixez/page/novel/tts/novel_tts_preview.dart';
import 'package:pixez/page/novel/tts/novel_tts_settings.dart';

void main() {
  test('request view uses actual encoded URL and preserves POST body bytes', () {
    final settings = NovelTtsSettings(
      customUrl: 'https://example.test/tts?text={text}&speaker={speaker_id}',
      customVariables: {'speaker_id': 'A&B + 雨'},
    );
    final request = buildNovelTtsRequest(settings, 'Hello, {speaker_id}');
    expect(request.uri.queryParameters, {
      'text': 'Hello, {speaker_id}', 'speaker': 'A&B + 雨',
    });
    expect(describeNovelTtsRequest(request), 'GET ${request.uri}\n');
    final post = buildNovelTtsRequest(settings.copyWith(
      customUrl: 'https://example.test/tts',
      customMethod: 'POST',
      customContentType: 'text/plain',
      customBody: '{speaker_id}: {text}  \n',
    ), 'Hello');
    expect(describeNovelTtsRequest(post), endsWith(utf8.decode(post.body!)));
  });

  test('credentials are hidden by default and revealed only on request', () {
    final request = buildNovelTtsRequest(const NovelTtsSettings(
      customUrl: 'https://example.test/tts?text={text}&key={access}',
      customMethod: 'POST',
      customVariables: {'access': 'private-query'},
      customHeaders: 'Authorization: Bearer private-header\ncontent-type: application/json',
      customBody: '{"text":"{text}","api_key":"private-body"}',
    ), 'Hello');
    final masked = describeNovelTtsRequest(request);
    expect(masked, contains('Hello'));
    expect(masked, isNot(contains('private-')));
    expect(masked, contains('[redacted]'));
    final full = describeNovelTtsRequest(request, revealSecrets: true);
    expect(full, contains('private-query'));
    expect(full, contains('private-header'));
    expect(full, contains('private-body'));
    expect(request.headers.keys.where((name) => name.toLowerCase() == 'content-type'), hasLength(1));
    expect(request.headers['content-type'], 'application/json');
  });

  test('error detail keeps phase, status and server explanation', () {
    const settings = NovelTtsSettings(
      customUrl: 'https://example.test/tts?text={text}&api_key={access}',
      customVariables: {'access': 'server-secret'},
      customHeaders: 'Authorization: Bearer header-secret',
      customMethod: 'POST',
      customContentType: 'application/json',
      customBody: '{"text":"{text}","api_key":"body-secret"}',
      openaiApiKey: '  trimmed-secret  ',
    );
    const failure = NovelTtsPreviewException(
      NovelTtsPreviewStage.synthesis,
      NovelTtsSynthException('HTTP 401: unknown speaker, api_key=server-secret; header-secret; trimmed-secret; body-secret'),
    );
    final masked = describeNovelTtsError(failure, settings);
    expect(masked, contains('synthesis'));
    expect(masked, contains('HTTP 401: unknown speaker'));
    expect(masked, isNot(contains('server-secret')));
    expect(masked, isNot(contains('header-secret')));
    expect(masked, isNot(contains('trimmed-secret')));
    expect(masked, isNot(contains('body-secret')));
    expect(describeNovelTtsError(failure, settings, revealSecrets: true), failure.toString());
  });
}
