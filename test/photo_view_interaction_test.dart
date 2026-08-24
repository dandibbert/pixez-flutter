import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:pixez/component/mouse_drag_scroll_configuration.dart';
import 'package:pixez/component/photo_view_interaction.dart';

void main() {
  group('按宽度缩放计算', () {
    test('竖图和横图都只以视口宽度为准', () {
      expect(
        calculateFitWidthScale(
          imageSize: const Size(200, 800),
          viewportWidth: 400,
        ),
        2,
      );
      expect(
        calculateFitWidthScale(
          imageSize: const Size(800, 200),
          viewportWidth: 400,
        ),
        0.5,
      );
    });

    test('拒绝无效宽度', () {
      expect(
        () => calculateFitWidthScale(
          imageSize: const Size(0, 800),
          viewportWidth: 400,
        ),
        throwsArgumentError,
      );
      expect(
        () => calculateFitWidthScale(
          imageSize: const Size(200, 800),
          viewportWidth: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  testWidgets('按宽铺满后从顶部开始，滚轮纵移且不影响横向翻页', (tester) async {
    const imageSize = Size(200, 800);
    const viewportSize = Size(400, 300);
    final controllers = List.generate(2, (_) => PhotoViewController());
    var currentPage = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox.fromSize(
            size: viewportSize,
            child: Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  scrollPhotoViewVertically(
                    controller: controllers[currentPage],
                    imageSize: imageSize,
                    viewportSize: viewportSize,
                    scrollDelta: event.scrollDelta.dy,
                  );
                }
              },
              child: MouseDragScrollConfiguration(
                child: PhotoViewGallery.builder(
                  itemCount: controllers.length,
                  onPageChanged: (index) => currentPage = index,
                  builder: (context, index) =>
                      PhotoViewGalleryPageOptions.customChild(
                        childSize: imageSize,
                        controller: controllers[index],
                        initialScale: PhotoViewComputedScale.contained,
                        child: ColoredBox(
                          color: index == 0 ? Colors.red : Colors.blue,
                        ),
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    fitPhotoViewToWidth(
      controller: controllers.first,
      imageSize: imageSize,
      viewportSize: viewportSize,
    );
    await tester.pump();

    expect(controllers.first.scale, 2);
    expect(controllers.first.position, const Offset(0, 650));

    final galleryCenter = tester.getCenter(find.byType(PhotoViewGallery));
    await tester.sendEventToBinding(
      PointerScrollEvent(
        position: galleryCenter,
        scrollDelta: const Offset(0, 120),
        kind: PointerDeviceKind.mouse,
      ),
    );
    await tester.pump();
    expect(controllers.first.position.dy, 530);
    expect(currentPage, 0);

    scrollPhotoViewVertically(
      controller: controllers.first,
      imageSize: imageSize,
      viewportSize: viewportSize,
      scrollDelta: 10000,
    );
    expect(controllers.first.position.dy, -650);
    scrollPhotoViewVertically(
      controller: controllers.first,
      imageSize: imageSize,
      viewportSize: viewportSize,
      scrollDelta: -10000,
    );
    expect(controllers.first.position.dy, 650);

    expect(currentPage, 0);
    expect(controllers[1].scale, isNot(2));

    await tester.pumpWidget(const SizedBox.shrink());
    for (final controller in controllers) {
      controller.dispose();
    }
  });
}
