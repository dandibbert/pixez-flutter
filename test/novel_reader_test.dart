import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/models/novel_web_response.dart';
import 'package:pixez/page/novel/novel_shell_theme.dart';
import 'package:pixez/page/novel/viewer/novel_pages.dart';
import 'package:pixez/page/novel/viewer/novel_spans.dart';

void main() {
  test('splits [newpage] markers into reader pages', () {
    final pages = splitNovelSpanPages([
      NovelSpansData(NovelSpansType.normal, 'page one'),
      NovelSpansData(NovelSpansType.newPage, ''),
      NovelSpansData(NovelSpansType.chapter, 'chapter'),
      NovelSpansData(NovelSpansType.normal, 'page two'),
      NovelSpansData(NovelSpansType.newPage, ''),
      NovelSpansData(NovelSpansType.normal, 'page three'),
    ]);

    expect(pages, hasLength(3));
    expect(pages[0].single.text, 'page one');
    expect(pages[1].first.type, NovelSpansType.chapter);
    expect(pages[2].single.text, 'page three');
  });

  test('drops empty pages created by consecutive newpage markers', () {
    final pages = splitNovelSpanPages([
      NovelSpansData(NovelSpansType.normal, 'keep'),
      NovelSpansData(NovelSpansType.newPage, ''),
      NovelSpansData(NovelSpansType.normal, '   '),
      NovelSpansData(NovelSpansType.newPage, ''),
      NovelSpansData(NovelSpansType.normal, 'after'),
    ]);

    expect(pages, hasLength(2));
    expect(pages.first.single.text, 'keep');
    expect(pages.last.single.text, 'after');
  });

  test('restores a booked page and ignores old scroll offsets', () {
    expect(
      restoreNovelPage(bookedOffset: 3, totalPages: 8),
      3,
    );
    expect(
      restoreNovelPage(bookedOffset: 2400, totalPages: 8),
      1,
    );
    expect(restoreNovelPage(bookedOffset: 0, totalPages: 8), 1);
  });

  test('turns first/last page into series navigation when available', () {
    final prev = PrevNovel(
      id: 11,
      viewable: true,
      contentOrder: '1',
      title: 'prev',
      coverUrl: null,
    );
    final next = PrevNovel(
      id: 22,
      viewable: true,
      contentOrder: '3',
      title: 'next',
      coverUrl: null,
    );

    final first = resolveNovelReaderNavigation(
      direction: 'prev',
      currentPage: 1,
      totalPages: 4,
      prevNovel: prev,
      nextNovel: next,
    );
    expect(first.kind, NovelReaderNavKind.series);
    expect(first.seriesNovelId, 11);

    final last = resolveNovelReaderNavigation(
      direction: 'next',
      currentPage: 4,
      totalPages: 4,
      prevNovel: prev,
      nextNovel: next,
    );
    expect(last.kind, NovelReaderNavKind.series);
    expect(last.seriesNovelId, 22);

    final middle = resolveNovelReaderNavigation(
      direction: 'next',
      currentPage: 2,
      totalPages: 4,
      prevNovel: prev,
      nextNovel: next,
    );
    expect(middle.kind, NovelReaderNavKind.page);
  });

  test('page nav state disables arrows at the ends without series', () {
    final state = resolveNovelPageNavState(
      currentPage: 1,
      totalPages: 3,
      hasPrevSeries: false,
      hasNextSeries: false,
    );
    expect(state.isPrevDisabled, isTrue);
    expect(state.isNextDisabled, isFalse);
    expect(state.canJumpPrevSeries, isFalse);
  });

  test('splits a long novel body into virtualized paragraph blocks', () {
    final lines = List<String>.generate(80, (index) => '段落$index の本文です。');
    final blocks = splitNovelReaderBlocks([
      NovelSpansData(NovelSpansType.normal, lines.join('\n')),
      NovelSpansData(NovelSpansType.chapter, '章'),
      NovelSpansData(NovelSpansType.normal, 'あとがき'),
    ]);

    expect(blocks, hasLength(82));
    expect(blocks[0].text, '段落0 の本文です。');
    expect(blocks[80].type, NovelSpansType.chapter);
    expect(blocks.last.text, 'あとがき');
    expect(
      blocks.every((block) => block.text.length <= novelReaderBlockMaxChars),
      isTrue,
    );
  });

  test('chunks a single huge line so layout stays bounded', () {
    final huge = 'あ' * 5000;
    final blocks = splitNovelReaderBlocks([
      NovelSpansData(NovelSpansType.normal, huge),
    ]);
    expect(blocks.length, greaterThan(3));
    expect(
      blocks.every((block) => block.text.length <= novelReaderBlockMaxChars),
      isTrue,
    );
    expect(blocks.map((block) => block.text).join(), huge);
  });

  test('novel shell theme does not use generic CSS font families', () {
    expect(novelShellFontFamily(), isNot(equals('serif')));
    expect(novelShellFontFamily(), isNot(equals('sans-serif')));
    final theme = ThemeData(useMaterial3: true);
    expect(applyNovelShellTheme(theme), same(theme));
  });
}
