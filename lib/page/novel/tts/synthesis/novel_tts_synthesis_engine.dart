import 'dart:io';
import 'dart:math' as math;

import 'package:characters/characters.dart';
import 'package:dio/dio.dart';
import 'package:pixez/page/novel/tts/cache/tts_cache.dart';
import 'package:pixez/page/novel/tts/domain/novel_tts_document.dart';
import 'package:pixez/page/novel/tts/model/tts_profile.dart';
import 'package:pixez/page/novel/tts/pronunciation/pronunciation_engine.dart';
import 'package:pixez/page/novel/tts/provider/tts_request_builder.dart';
import 'package:pixez/page/novel/tts/provider/tts_template_engine.dart';
import 'package:pixez/page/novel/tts/queue/tts_queue_policy.dart';
import 'package:pixez/page/novel/tts/segmentation/natural_text_segmenter.dart';

abstract interface class TtsHttpExecutor {
  Future<List<int>> execute(TtsHttpRequest request);
}

class DioTtsHttpExecutor implements TtsHttpExecutor {
  DioTtsHttpExecutor({Dio? dio, this.maximumBytes = 25 * 1024 * 1024})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(seconds: 90),
              sendTimeout: const Duration(seconds: 30),
            ),
          );
  final Dio _dio;
  final int maximumBytes;
  @override
  Future<List<int>> execute(TtsHttpRequest request) async {
    final response = await _dio.request<List<int>>(
      request.url,
      data: request.body,
      options: Options(
        method: request.method,
        headers: request.headers,
        responseType: ResponseType.bytes,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty)
      throw const FormatException('TTS provider returned an empty response');
    if (bytes.length > maximumBytes)
      throw const FormatException(
        'TTS provider response exceeds the cache limit',
      );
    return bytes;
  }
}

class NovelTtsSynthesisItem {
  const NovelTtsSynthesisItem({
    required this.id,
    required this.filePath,
    required this.title,
    required this.author,
    required this.displayText,
    required this.spokenText,
    required this.ssml,
    required this.pageNumber,
    required this.chunkIndex,
    required this.chunkCount,
    required this.duration,
  });
  final String id;
  final String filePath;
  final String title;
  final String author;
  final String displayText;
  final String spokenText;
  final String ssml;
  final int pageNumber;
  final int chunkIndex;
  final int chunkCount;
  final Duration duration;
}

class NovelTtsSynthesisEngine {
  NovelTtsSynthesisEngine({
    required this.executor,
    required this.cacheDirectory,
    this.targetLength = 220,
    this.maxLength = 360,
    TtsRequestBuilder? requestBuilder,
    PronunciationEngine? pronunciation,
    TtsAtomicCacheWriter? writer,
  }) : _requestBuilder = requestBuilder ?? TtsRequestBuilder(),
       _pronunciation = pronunciation ?? PronunciationEngine(),
       _writer = writer ?? const TtsAtomicCacheWriter();
  final TtsHttpExecutor executor;
  final Directory cacheDirectory;
  final int targetLength;
  final int maxLength;
  final TtsRequestBuilder _requestBuilder;
  final PronunciationEngine _pronunciation;
  final TtsAtomicCacheWriter _writer;

  Future<List<NovelTtsSynthesisItem>> synthesize({
    required NovelTtsDocument document,
    required TtsProfile profile,
    required List<PronunciationRule> rules,
    required PronunciationContext context,
    required String title,
    required String author,
    Map<String, String> secrets = const {},
    int startPage = 1,
    TtsGenerationGuard? guard,
    TtsGenerationToken? token,
  }) async {
    if (startPage < 1 || startPage > document.pages.length)
      throw RangeError.range(startPage, 1, document.pages.length, 'startPage');
    final result = <NovelTtsSynthesisItem>[];
    for (final page in document.pages.where(
      (page) => page.pageNumber >= startPage,
    )) {
      _ensureCurrent(guard, token);
      final pageProjection = _pronunciation.apply(
        page.displayText,
        rules,
        context,
        ruby: page.ruby,
      );
      final segments =
          NaturalTextSegmenter(
            targetLength: targetLength,
            maxLength: maxLength,
          ).split(
            page.displayText,
            protectedRanges: pageProjection.protectedRanges,
          );
      for (var index = 0; index < segments.length; index++) {
        _ensureCurrent(guard, token);
        final segment = segments[index];
        final ruby = page.ruby
            .where(
              (item) => item.start >= segment.start && item.end <= segment.end,
            )
            .map(
              (item) => PronunciationRuby(
                start: item.start - segment.start,
                end: item.end - segment.start,
                reading: item.reading,
              ),
            )
            .toList();
        final projection = _pronunciation.apply(
          segment.text,
          rules,
          context,
          ruby: ruby,
        );
        final templateContext = TtsTemplateContext(
          displayText: projection.displayText,
          spokenText: projection.spokenText,
          ssml: projection.ssml,
          profile: profile,
          secrets: secrets,
        );
        final request = _requestBuilder.build(profile, templateContext);
        final cacheInput = TtsCacheInput(
          spokenText: projection.spokenText,
          ssml: projection.ssml,
          provider: profile.provider.kind.name,
          endpoint: request.url,
          voice: profile.voice,
          model: profile.model ?? '',
          speed: profile.speed,
          pitch: profile.pitch,
          format: profile.format,
        );
        final destination = File(
          '${cacheDirectory.path}/${cacheInput.key}.${_extension(profile.format)}',
        );
        if (!await _validFile(destination)) {
          final bytes = await executor.execute(request);
          _ensureCurrent(guard, token);
          await _writer.write(destination: destination, bytes: bytes);
        }
        final seconds = math.max(
          1,
          (projection.spokenText.characters.length / (6 * profile.speed))
              .ceil(),
        );
        result.add(
          NovelTtsSynthesisItem(
            id: '${document.novelId}-${page.pageNumber}-$index',
            filePath: destination.path,
            title: title,
            author: author,
            displayText: projection.displayText,
            spokenText: projection.spokenText,
            ssml: projection.ssml,
            pageNumber: page.pageNumber,
            chunkIndex: index,
            chunkCount: segments.length,
            duration: Duration(seconds: seconds),
          ),
        );
      }
    }
    return List.unmodifiable(result);
  }

  Future<bool> _validFile(File file) async {
    if (!await file.exists()) return false;
    final bytes = await file
        .openRead(0, 16)
        .fold<List<int>>(<int>[], (all, chunk) => all..addAll(chunk));
    if (TtsAudioValidator.isValid(bytes)) return true;
    await file.delete();
    return false;
  }

  void _ensureCurrent(TtsGenerationGuard? guard, TtsGenerationToken? token) {
    if (guard != null && (token == null || !guard.accepts(token)))
      throw const TtsSynthesisCancelled();
  }

  String _extension(String format) {
    final lower = format.toLowerCase();
    if (lower.contains('wav') ||
        lower.contains('riff') ||
        lower.contains('pcm'))
      return 'wav';
    if (lower.contains('ogg') || lower.contains('opus')) return 'ogg';
    if (lower.contains('aac') || lower.contains('m4a')) return 'm4a';
    return 'mp3';
  }
}

class TtsSynthesisCancelled implements Exception {
  const TtsSynthesisCancelled();
}
