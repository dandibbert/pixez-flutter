import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:pixez/component/mouse_drag_scroll_configuration.dart';
import 'package:pixez/component/photo_view_interaction.dart';

void main() {
  testWidgets('保留默认拖动设备并启用鼠标拖动', (tester) async {
    late Set<PointerDeviceKind> dragDevices;

    await tester.pumpWidget(
      MaterialApp(
        home: MouseDragScrollConfiguration(
          child: Builder(
            builder: (context) {
              dragDevices = ScrollConfiguration.of(context).dragDevices;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );

    expect(dragDevices, contains(PointerDeviceKind.touch));
    expect(dragDevices, contains(PointerDeviceKind.mouse));
  });

  testWidgets('鼠标横向拖动可以切换 PageView', (tester) async {
    var currentPage = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: MouseDragScrollConfiguration(
          child: PageView(
            onPageChanged: (index) => currentPage = index,
            children: const [
              ColoredBox(color: Colors.red),
              ColoredBox(color: Colors.blue),
            ],
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      const Offset(700, 300),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(-600, 0));
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));

    expect(currentPage, 1);
  });

  testWidgets('鼠标横向拖动可以切换真实 PhotoViewGallery', (tester) async {
    var currentPage = 0;
    final controllers = List.generate(2, (_) => PhotoViewController());
    final image = MemoryImage(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MouseDragScrollConfiguration(
          child: PhotoViewGallery.builder(
            itemCount: 2,
            onPageChanged: (index) => currentPage = index,
            builder: (context, index) => PhotoViewGalleryPageOptions(
              imageProvider: image,
              initialScale: PhotoViewComputedScale.contained,
              controller: controllers[index],
            ),
          ),
        ),
      ),
    );

    fitPhotoViewToWidth(
      controller: controllers.first,
      imageSize: const Size(1, 1),
      viewportSize: const Size(800, 600),
    );
    await tester.pump();

    final gesture = await tester.startGesture(
      const Offset(700, 300),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(-600, 0));
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));

    expect(currentPage, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    for (final controller in controllers) {
      controller.dispose();
    }
  });
}
