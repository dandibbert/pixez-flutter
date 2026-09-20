import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/er/prefer.dart';
import 'package:pixez/page/novel/tts/novel_tts_page.dart';
import 'package:pixez/page/novel/tts/novel_tts_settings.dart';
import 'package:pixez/src/generated/i18n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Prefer.init();
  });
  setUp(() async => Prefer.remove(NovelTtsSettings.prefKey));

  Widget app(NovelTtsSettings settings, {bool dark = false, double scale = 1}) =>
      MaterialApp(
        locale: const Locale('en', 'US'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          brightness: dark ? Brightness.dark : Brightness.light,
          fontFamily: 'TtsTestLatin',
          fontFamilyFallback: const ['TtsTestCjk'],
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: NovelTtsPage(initial: settings),
      );

  testWidgets('saved voices switch parameters without changing the connection', (tester) async {
    var settings = const NovelTtsSettings(
      customUrl: 'https://speech.example/tts?t={text}&v={voice}',
      customHeaders: 'Authorization: retained',
      customVoice: 'voice-a',
      customSpeed: '1',
    ).saveVoicePreset('Narrator');
    settings = settings.copyWith(customVoice: 'voice-b', customSpeed: '0.8')
        .saveVoicePreset('Calm');
    await tester.pumpWidget(app(settings));
    await tester.ensureVisible(find.widgetWithText(InputChip, 'Narrator'));
    await tester.tap(find.widgetWithText(InputChip, 'Narrator'));
    await tester.pumpAndSettle();
    expect(NovelTtsSettings.load().customVoice, 'voice-a');
    expect(NovelTtsSettings.load().customSpeed, '1');
    expect(NovelTtsSettings.load().customHeaders, 'Authorization: retained');
    expect(NovelTtsSettings.load().customUrl, settings.customUrl);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a named voice can be saved and survives leaving during debounce', (tester) async {
    await tester.pumpWidget(app(const NovelTtsSettings(customVoice: 'narrator')));
    await tester.ensureVisible(find.byKey(novelTtsSaveVoiceKey));
    await tester.tap(find.byKey(novelTtsSaveVoiceKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(novelTtsVoiceNameKey), 'Morning');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(NovelTtsSettings.load().activeVoicePresets.single.name, 'Morning');
    await tester.ensureVisible(find.byKey(novelTtsCustomVoiceKey));
    await tester.enterText(find.byKey(novelTtsCustomVoiceKey), 'changed');
    // Dispose before the 350 ms debounce to exercise the final flush.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(NovelTtsSettings.load().customVoice, 'changed');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a closing settings page does not overwrite a newer bar selection', (tester) async {
    final initial = const NovelTtsSettings(customVoice: 'a').saveVoicePreset('A')
        .copyWith(customVoice: 'b').saveVoicePreset('B');
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      locale: const Locale('en', 'US'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: SizedBox.shrink()),
    ));
    navigatorKey.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => NovelTtsPage(initial: initial),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(novelTtsCustomVoiceKey));
    await tester.enterText(find.byKey(novelTtsCustomVoiceKey), 'edited');
    navigatorKey.currentState!.pop();
    await tester.pump();
    final pending = NovelTtsSettings.load();
    final selected = pending.selectVoicePreset(pending.activeVoicePresets.first);
    var saved = false;
    Object? saveError;
    selected.save().then<void>(
      (_) { saved = true; },
      onError: (Object error) { saveError = error; },
    );
    // Drive fake-clock microtasks while the reverse route transition disposes
    // the old page. Awaiting the queued write before pumping can deadlock the
    // test; asserting its completion also makes a stuck queue fail explicitly.
    await tester.pumpAndSettle();
    expect(saveError, isNull);
    expect(saved, isTrue, reason: 'The newer settings write must finish');
    expect(NovelTtsSettings.load().customVoice, 'a');
    expect(tester.takeException(), isNull);
  });

  testWidgets('split size visibly clamps to supported bounds on submission', (tester) async {
    await tester.pumpWidget(app(const NovelTtsSettings()));
    await tester.ensureVisible(find.byKey(novelTtsSplitCharsFieldKey));
    await tester.enterText(find.byKey(novelTtsSplitCharsFieldKey), '9999');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(NovelTtsSettings.load().splitChars, 800);
    expect(tester.widget<TextField>(find.byKey(novelTtsSplitCharsFieldKey))
        .controller!.text, '800');
  });

  testWidgets('preview reports invalid configuration without starting playback', (tester) async {
    await tester.pumpWidget(app(const NovelTtsSettings(customUrl: 'invalid')));
    await tester.ensureVisible(find.byKey(novelTtsPreviewVoiceKey));
    await tester.tap(find.byKey(novelTtsPreviewVoiceKey));
    await tester.pumpAndSettle();
    expect(find.text('Preview failed. Check the service address, credentials and voice settings, then try again.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow dark settings support large text without overflow', (tester) async {
    await _loadScreenshotFonts(tester);
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundaryKey = GlobalKey();
    final settings = const NovelTtsSettings(customVoice: 'narrator')
        .saveVoicePreset('Narrator · calm and clear');
    await tester.pumpWidget(RepaintBoundary(
      key: boundaryKey,
      child: app(settings, dark: true, scale: 1.6),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _capture(tester, boundaryKey, 'tts_settings_narrow_dark_service');
    await tester.ensureVisible(find.byKey(novelTtsVoicePresetsKey));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _capture(tester, boundaryKey, 'tts_settings_narrow_dark_voices');
    await tester.ensureVisible(find.byKey(novelTtsSplitCharsFieldKey));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('/opt/cursor/artifacts/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

Future<void> _loadScreenshotFonts(WidgetTester tester) async {
  await tester.runAsync(() async {
    final fonts = <String, String>{
      'TtsTestLatin': '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
      'TtsTestCjk': '/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf',
    };
    for (final font in fonts.entries) {
      final file = File(font.value);
      if (await file.exists()) {
        final loader = FontLoader(font.key);
        loader.addFont(file.readAsBytes().then(ByteData.sublistView));
        await loader.load();
      }
    }
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
}
