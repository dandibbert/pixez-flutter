import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pixez/page/novel/tts/pronunciation/models/morphology_token.dart';
import 'package:pixez/page/novel/tts/pronunciation/morphology/ipadic_tokenizer.dart';
import 'package:pixez/page/novel/tts/pronunciation/morphology/japanese_morphology_analyzer.dart';

/// Morphological analysis with the full IPADIC, reproducing MeCab's lattice
/// search (see `docs/tts-pronunciation-benchmark.md`).
///
/// The user's name aliases are added to the lattice as given names, so the
/// analyzer itself decides where `五条悟` or `悟以外` splits instead of a list
/// of suffixes guessing it.
class IpadicJapaneseAnalyzer implements JapaneseMorphologyAnalyzer {
  IpadicJapaneseAnalyzer({Future<Uint8List> Function()? loadCompressed})
    : _loadCompressed = loadCompressed ?? _loadAsset;

  static const assetPath = ipadicAssetPath;

  /// The dictionary is ~12 MB once inflated, so every analyzer in the process
  /// shares one copy.
  static Future<IpadicTokenizer>? _shared;

  final Future<Uint8List> Function() _loadCompressed;
  IpadicTokenizer? _tokenizer;

  static Future<Uint8List> _loadAsset() async {
    final data = await rootBundle.load(assetPath);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  @override
  String get analyzerId => 'ipadic-viterbi';

  @override
  String get analyzerVersion => 'mecab-ipadic-2.7.0-20070801';

  @override
  bool get supportsPartOfSpeech => true;

  @override
  String get capability => 'ipadic-lattice';

  /// Set once [_shared] completes, so later analyzers start without waiting
  /// on another zone's future.
  static IpadicTokenizer? _loaded;

  @override
  Future<void> warmUp() async {
    if (_tokenizer != null) {
      return;
    }
    final loaded = _loaded;
    if (loaded != null) {
      _tokenizer = loaded;
      return;
    }
    _tokenizer = await (_shared ??= _load(_loadCompressed).then(
      (tokenizer) => _loaded = tokenizer,
      onError: (Object error) {
        _shared = null;
        throw error;
      },
    ));
  }

  static Future<IpadicTokenizer> _load(
    Future<Uint8List> Function() loadCompressed,
  ) async {
    final compressed = await loadCompressed();
    // Inflating 12 MB would drop frames on the UI isolate.
    final bytes = await Isolate.run(
      () => Uint8List.fromList(gzip.decode(compressed)),
    );
    return IpadicTokenizer(IpadicDictionary.fromBytes(bytes));
  }

  @override
  Future<MorphologyResult> analyze(
    String text, {
    required String requestId,
    Iterable<String> userWords = const [],
  }) async {
    await warmUp();
    return MorphologyResult(
      tokens: tokenize(text, userWords: userWords),
      exactBoundaries: true,
    );
  }

  List<MorphologyToken> tokenize(
    String text, {
    Iterable<String> userWords = const [],
  }) {
    final tokenizer = _tokenizer;
    if (tokenizer == null) {
      throw StateError('IPADIC analyzer used before warmUp');
    }
    return [
      for (final token in tokenizer.tokenize(
        text,
        userWords: [for (final word in userWords) IpadicUserWord(word)],
      ))
        MorphologyToken(
          start: token.start,
          end: token.end,
          surface: text.substring(token.start, token.end),
          partOfSpeech: [
            for (final part in token.pos.take(4))
              if (part != '*') part,
          ],
          conjugationType: token.pos[4] == '*' ? null : token.pos[4],
          conjugationForm: token.pos[5] == '*' ? null : token.pos[5],
          isUserWord: token.isUserWord,
        ),
    ];
  }

  @override
  Future<void> dispose() async {}
}
