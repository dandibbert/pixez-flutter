import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/component/pixiv_image_status.dart';

void main() {
  testWidgets('loading placeholder is a checkerboard with a spinner', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 200,
          height: 280,
          child: PixivImageLoadingPlaceholder(width: 200, height: 280),
        ),
      ),
    );

    expect(find.byKey(pixivImageLoadingKey), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('error placeholder is not a flat dark fill and can retry', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 240,
          height: 320,
          child: PixivImageErrorPlaceholder(
            width: 240,
            height: 320,
            onRetry: () {
              retried = true;
            },
          ),
        ),
      ),
    );

    expect(find.byKey(pixivImageErrorKey), findsOneWidget);
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    await tester.tap(find.byKey(pixivImageErrorKey));
    expect(retried, isTrue);
  });

  testWidgets('dark artwork fill does not look like the loading chrome', (
    tester,
  ) async {
    const darkArtworkKey = Key('dark-artwork');
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: ColoredBox(key: darkArtworkKey, color: Colors.black),
            ),
            SizedBox(
              width: 120,
              height: 120,
              child: PixivImageLoadingPlaceholder(width: 120, height: 120),
            ),
          ],
        ),
      ),
    );

    expect(find.byKey(darkArtworkKey), findsOneWidget);
    expect(find.byKey(pixivImageLoadingKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(darkArtworkKey),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(pixivImageLoadingKey),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(pixivImageLoadingKey),
        matching: find.byType(CustomPaint),
      ),
      findsWidgets,
    );
  });
}
