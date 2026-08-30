import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/page/novel/tts/pronunciation/pronunciation_engine.dart';
import 'package:pixez/page/novel/tts/segmentation/natural_text_segmenter.dart';

void main() {
  test('uses natural punctuation boundaries before hard cuts', () {
    final chunks = NaturalTextSegmenter(
      targetLength: 8,
      maxLength: 12,
    ).split('第一文です。第二文です！第三文です。');
    expect(chunks.map((e) => e.text), ['第一文です。', '第二文です！', '第三文です。']);
  });
  test('hard cuts are grapheme safe for emoji and combining characters', () {
    final text = 'A👨‍👩‍👧‍👦éBCD';
    final chunks = NaturalTextSegmenter(
      targetLength: 2,
      maxLength: 2,
    ).split(text);
    expect(chunks.map((e) => e.text).join(), text);
    expect(
      chunks.any(
        (e) => e.text.contains('👨') && !e.text.contains('👨‍👩‍👧‍👦'),
      ),
      isFalse,
    );
    expect(chunks.any((e) => e.text == '́'), isFalse);
  });
  test('never cuts through a protected dictionary token', () {
    const text = '前今日中後です。';
    final chunks = NaturalTextSegmenter(
      targetLength: 2,
      maxLength: 4,
    ).split(text, protectedRanges: const [PronunciationRange(1, 4)]);
    expect(chunks.any((e) => e.text.contains('今日中')), isTrue);
    expect(chunks.map((e) => e.text).join(), text);
  });
}
