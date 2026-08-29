import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/component/perf_probe.dart';

PerfSample sample({
  int frames = 0,
  double avgBuildMs = 0,
  double maxBuildMs = 0,
  double avgRasterMs = 0,
  double maxRasterMs = 0,
  int requests = 0,
  int errors = 0,
  double lagMs = 0,
  int liveImages = 0,
  double imageCacheMb = 0,
  double rssMb = 0,
}) {
  return PerfSample(
    window: const Duration(seconds: 2),
    frames: frames,
    avgBuildMs: avgBuildMs,
    maxBuildMs: maxBuildMs,
    avgRasterMs: avgRasterMs,
    maxRasterMs: maxRasterMs,
    requests: requests,
    errors: errors,
    lagMs: lagMs,
    liveImages: liveImages,
    imageCacheMb: imageCacheMb,
    rssMb: rssMb,
  );
}

void main() {
  setUp(PerfCounters.reset);

  test('an app that stopped drawing reads as idle', () {
    // The probe repaints once per window, so a sleeping app still reports a
    // frame or two. That must not read as "drawing".
    expect(sample(frames: 0).idle, isTrue);
    expect(sample(frames: 1).idle, isTrue);
    expect(sample(frames: 2).idle, isTrue);
  });

  test('an app drawing every vsync does not read as idle', () {
    final drawing = sample(frames: 120);
    expect(drawing.idle, isFalse);
    expect(drawing.fps, closeTo(60, 0.001));
    expect(drawing.lines.first, contains('DRAWING'));
  });

  test('the readout names every signal it collects', () {
    final lines = sample(
      frames: 120,
      avgBuildMs: 3.25,
      maxBuildMs: 11.5,
      avgRasterMs: 6.5,
      maxRasterMs: 22.25,
      requests: 47,
      errors: 3,
      lagMs: 12.5,
      liveImages: 84,
      imageCacheMb: 61.5,
      rssMb: 412.25,
    ).lines;
    final text = lines.join('\n');

    expect(text, contains('120'));
    expect(text, contains('60.0 fps'));
    expect(text, contains('3.3ms'));
    expect(text, contains('22.3ms'));
    expect(text, contains('47 req'));
    expect(text, contains('3 err'));
    expect(text, contains('12.5ms'));
    expect(text, contains('84 live'));
    expect(text, contains('412.3MB'));
  });

  test('the interceptor counts requests, responses and failures', () async {
    final interceptor = PerfCountingInterceptor();
    final options = RequestOptions(path: '/v1/novel');

    interceptor.onRequest(options, RequestInterceptorHandler());
    interceptor.onResponse(
      Response(requestOptions: options),
      ResponseInterceptorHandler(),
    );
    // Passing an error along completes the handler with an error that nothing
    // here awaits; absorb it rather than failing the test.
    await runZonedGuarded(() async {
      interceptor.onError(
        DioException(requestOptions: options),
        ErrorInterceptorHandler(),
      );
      await Future<void>.delayed(Duration.zero);
    }, (_, __) {});

    expect(PerfCounters.requests, 1);
    expect(PerfCounters.responses, 1);
    expect(PerfCounters.errors, 1);
  });

  testWidgets('the probe shows a readout without drawing continuously', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PerfProbe(
            window: Duration(seconds: 2),
            child: Center(child: Text('page')),
          ),
        ),
      ),
    );

    // Nothing published yet, so the overlay stays out of the way.
    expect(find.byKey(perfProbeKey), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(perfProbeKey), findsOneWidget);
    expect(find.text('page'), findsOneWidget);

    // A probe that kept the app awake would defeat its own purpose: over the
    // next window it must ask for at most its own repaint.
    var busy = 0;
    for (var i = 0; i < 100; i++) {
      if (tester.binding.hasScheduledFrame) busy++;
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(busy, lessThanOrEqualTo(2), reason: 'probe drew $busy frames');
  });
}
