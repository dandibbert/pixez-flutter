import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/main.dart';
import 'package:pixez/models/novel_recom_response.dart';
import 'package:pixez/models/novel_web_response.dart';
import 'package:pixez/page/novel/viewer/image_text.dart';
import 'package:pixez/page/novel/viewer/novel_reader_background.dart';
import 'package:pixez/page/novel/viewer/novel_reader_widgets.dart';
import 'package:pixez/page/novel/viewer/novel_store.dart';
import 'package:pixez/page/novel/viewer/novel_viewer.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';

Novel buildNovel() => Novel.fromJson({
      'id': 1,
      'title': 'Winter Story',
      'caption': '',
      'restrict': 0,
      'x_restrict': 0,
      'is_original': true,
      'image_urls': {
        'square_medium': 'https://example.invalid/s.jpg',
        'medium': 'https://example.invalid/m.jpg',
        'large': 'https://example.invalid/l.jpg',
      },
      'create_date': '2024-01-01T00:00:00+09:00',
      'tags': <dynamic>[],
      'page_count': 1,
      'text_length': 100,
      'user': {
        'id': 7,
        'name': 'Author',
        'account': 'author',
        'profile_image_urls': {'medium': 'https://example.invalid/p.jpg'},
        'is_followed': false,
      },
      'series': <String, dynamic>{},
      'is_bookmarked': false,
      'total_bookmarks': 0,
      'total_view': 0,
      'visible': true,
      'total_comments': 0,
      'is_muted': false,
      'is_mypixiv_only': false,
      'is_x_restricted': false,
      'novel_ai_type': 0,
    });

NovelWebResponse buildWebResponse(String text) => NovelWebResponse(
      id: '1',
      title: 'Winter Story',
      seriesId: null,
      seriesTitle: null,
      seriesIsWatched: null,
      userId: '7',
      coverUrl: '',
      tags: const [],
      caption: '',
      cdate: '',
      rating: NovelRating(like: 0, bookmark: 0, view: 0),
      text: text,
      marker: null,
      illusts: null,
      images: null,
      seriesNavigation: null,
      glossaryItems: null,
      replaceableItemIds: null,
      aiType: 0,
      isOriginal: true,
    );

/// OLED panels draw current per lit subpixel, so panel power tracks the
/// gamma-decoded intensity of what is on screen. Blue subpixels are the least
/// efficient. Approximate, but enough to rank backgrounds.
double oledCost(Color color) {
  double linear(double channel) => math.pow(channel, 2.2).toDouble();
  return linear(color.r) * 0.27 + linear(color.g) * 0.27 + linear(color.b) * 0.46;
}

double _luminance(Color color) => Color(color.toARGB32()).computeLuminance();

double contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  final base = ColorScheme.fromSeed(seedColor: Colors.blue.shade400);

  setUp(resetNovelReaderSchemeCache);

  test('system leaves the app palette untouched', () {
    expect(
      resolveNovelReaderScheme(base, NovelReaderBackground.system),
      same(base),
    );
  });

  test('each background repaints the surfaces the reader uses', () {
    for (final background in NovelReaderBackground.values) {
      if (background == NovelReaderBackground.system) continue;
      final scheme = resolveNovelReaderScheme(base, background);
      expect(scheme.surface, isNot(base.surface), reason: '$background');
      expect(
        scheme.surfaceContainerHighest,
        isNot(base.surfaceContainerHighest),
        reason: '$background',
      );
    }
  });

  test('black is pure black so OLED pixels switch off', () {
    final scheme = resolveNovelReaderScheme(base, NovelReaderBackground.black);
    expect(scheme.surface, const Color(0xFF000000));
    expect(oledCost(scheme.surface), 0);
  });

  test('backgrounds rank by OLED cost, and dark is far below light', () {
    double cost(NovelReaderBackground background) =>
        oledCost(resolveNovelReaderScheme(base, background).surface);

    final paper = cost(NovelReaderBackground.paper);
    final sepia = cost(NovelReaderBackground.sepia);
    final dark = cost(NovelReaderBackground.dark);
    final black = cost(NovelReaderBackground.black);

    expect(black, lessThan(dark));
    expect(dark, lessThan(sepia));
    expect(sepia, lessThan(paper));

    // The whole point: a dark reading page costs a tiny fraction of a light
    // one on an OLED panel.
    expect(dark, lessThan(paper * 0.05));
  });

  test('body text stays legible on every background', () {
    for (final background in NovelReaderBackground.values) {
      if (background == NovelReaderBackground.system) continue;
      final scheme = resolveNovelReaderScheme(base, background);
      expect(
        contrastRatio(scheme.onSurface, scheme.surface),
        greaterThanOrEqualTo(4.5),
        reason: '$background body text contrast',
      );
      expect(
        contrastRatio(scheme.onSurfaceVariant, scheme.surface),
        greaterThanOrEqualTo(3.0),
        reason: '$background secondary text contrast',
      );
    }
  });

  test('a dark reading page keeps the app accent usable', () {
    final scheme = resolveNovelReaderScheme(base, NovelReaderBackground.black);
    expect(contrastRatio(scheme.primary, scheme.surface), greaterThan(3.0));
  });

  test('a dark reading page recolours text and icons, not just surfaces', () {
    // A light app theme carries a near-black text and icon theme. Swapping the
    // colour scheme alone leaves the reader title and header icons invisible.
    final lightApp = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: base,
    );
    final reader = applyNovelReaderTheme(lightApp, NovelReaderBackground.black);

    expect(reader.brightness, Brightness.dark);
    expect(reader.scaffoldBackgroundColor, const Color(0xFF000000));
    expect(
      contrastRatio(reader.iconTheme.color!, reader.colorScheme.surface),
      greaterThanOrEqualTo(4.5),
    );
    for (final style in [
      reader.textTheme.titleSmall,
      reader.textTheme.bodyMedium,
      reader.textTheme.labelSmall,
    ]) {
      expect(
        contrastRatio(style!.color!, reader.colorScheme.surface),
        greaterThanOrEqualTo(4.5),
        reason: 'header/body text must stay readable on black',
      );
    }
  });

  test('following the app theme returns the theme untouched', () {
    final app = ThemeData(useMaterial3: true, colorScheme: base);
    expect(
      applyNovelReaderTheme(app, NovelReaderBackground.system),
      same(app),
    );
  });

  test('unknown stored names fall back to following the app theme', () {
    expect(novelReaderBackgroundFromName(null), NovelReaderBackground.system);
    expect(
      novelReaderBackgroundFromName('nonsense'),
      NovelReaderBackground.system,
    );
    expect(novelReaderBackgroundFromName('sepia'), NovelReaderBackground.sepia);
  });

  testWidgets('the reader paints the chosen background', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    addTearDown(
      () => userSetting.novelReaderBackground = NovelReaderBackground.system,
    );

    Future<Color> surfaceFor(NovelReaderBackground background) async {
      userSetting.novelReaderBackground = background;
      final store = NovelStore(1, buildNovel());
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en', 'US'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NovelViewerPage(id: 1, novelStore: store),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      store.novelTextResponse = buildWebResponse('静かな夜だった。\n' * 40);
      store.spans = NovelSpansGenerator().buildSpans(store.novelTextResponse!);
      store.errorMessage = null;
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final article = tester.widget<ColoredBox>(
        find.byKey(novelReaderArticleKey),
      );
      return article.color;
    }

    expect(await surfaceFor(NovelReaderBackground.black), const Color(0xFF000000));
    expect(await surfaceFor(NovelReaderBackground.sepia), const Color(0xFFF4ECD8));

    final systemSurface = await surfaceFor(NovelReaderBackground.system);
    expect(systemSurface, isNot(const Color(0xFF000000)));
  });

  testWidgets('settings sheet reports the chosen background', (tester) async {
    NovelReaderBackground? picked;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: NovelReaderSettingsSheet(
            fontSize: 16,
            lineHeight: 1.8,
            fontFamily: '',
            background: NovelReaderBackground.system,
            onBackgroundChanged: (value) => picked = value,
            onFontSizeChanged: (_) {},
            onLineHeightChanged: (_) {},
            onFontFamilyChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.byKey(novelReaderBackgroundKey), findsOneWidget);
    for (final background in NovelReaderBackground.values) {
      expect(
        find.byKey(novelReaderBackgroundChipKey(background)),
        findsOneWidget,
        reason: '$background chip',
      );
    }

    await tester.tap(
      find.byKey(novelReaderBackgroundChipKey(NovelReaderBackground.black)),
    );
    await tester.pumpAndSettle();
    expect(picked, NovelReaderBackground.black);

    final chip = tester.widget<ChoiceChip>(
      find.byKey(novelReaderBackgroundChipKey(NovelReaderBackground.black)),
    );
    expect(chip.selected, isTrue);
  });
}
