import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pixez/component/perf_probe.dart';

PerfSample sample({
  int frames = 0,
  int pointerEvents = 0,
  double dutyPercent = 0,
  double refreshRate = 60,
  double avgBuildMs = 0,
  double maxBuildMs = 0,
  double avgRasterMs = 0,
  double maxRasterMs = 0,
  int requests = 0,
  int totalRequests = 0,
  int errors = 0,
  int imageRequests = 0,
  int totalImageRequests = 0,
  int downloadQueued = 0,
  int downloadRunning = 0,
  double lagMs = 0,
  int cpuMicros = 0,
  int liveImages = 0,
  double imageCacheMb = 0,
  double rssMb = 0,
}) {
  return PerfSample(
    window: const Duration(seconds: 2),
    historyWindow: const Duration(seconds: 30),
    refreshRate: refreshRate,
    frames: frames,
    pointerEvents: pointerEvents,
    dutyPercent: dutyPercent,
    avgBuildMs: avgBuildMs,
    maxBuildMs: maxBuildMs,
    avgRasterMs: avgRasterMs,
    maxRasterMs: maxRasterMs,
    requests: requests,
    totalRequests: totalRequests,
    errors: errors,
    imageRequests: imageRequests,
    totalImageRequests: totalImageRequests,
    downloadQueued: downloadQueued,
    downloadRunning: downloadRunning,
    lagMs: lagMs,
    cpuMicros: cpuMicros,
    liveImages: liveImages,
    imageCacheMb: imageCacheMb,
    rssMb: rssMb,
  );
}

void main() {
  setUp(PerfCounters.reset);

  test('an app that stopped drawing reads as idle', () {
    // The probe repaints once per window, so a sleeping app still reports a
    // frame or two. That must not read as activity.
    expect(sample(frames: 0).activity, PerfActivity.idle);
    expect(sample(frames: 1).activity, PerfActivity.idle);
    expect(sample(frames: 2).activity, PerfActivity.idle);
  });

  test('scrolling reads as active, not as never sleeping', () {
    // The reading from the device: 17 frames in 2s while a finger was moving.
    // Drawing to scroll is unavoidable and must not look like a runaway.
    final scrolling = sample(frames: 17, pointerEvents: 42);
    expect(scrolling.activity, PerfActivity.active);
    expect(scrolling.drawsUntouched, isFalse);
    expect(scrolling.lines.first, contains('ACTIVE'));
  });

  test('drawing every vsync reads as pegged', () {
    final pegged = sample(frames: 120, pointerEvents: 40);
    expect(pegged.activity, PerfActivity.pegged);
    expect(pegged.fps, closeTo(60, 0.001));
    expect(pegged.lines.first, contains('PEGGED'));
  });

  test('a 120Hz display is not mistaken for a runaway at 60fps', () {
    final half = sample(frames: 120, refreshRate: 120);
    expect(half.activity, PerfActivity.active);
    expect(sample(frames: 240, refreshRate: 120).activity, PerfActivity.pegged);
  });

  test('frames with nobody touching the screen are called out', () {
    expect(sample(frames: 120, pointerEvents: 0).drawsUntouched, isTrue);
    expect(sample(frames: 120, pointerEvents: 1).drawsUntouched, isFalse);
    // A couple of stray frames while idle is the probe itself, not the app.
    expect(sample(frames: 2, pointerEvents: 0).drawsUntouched, isFalse);
    expect(
      sample(frames: 120, pointerEvents: 0).lines[1],
      contains('UNTOUCHED'),
    );
  });

  test('the readout names every signal it collects', () {
    final lines = sample(
      frames: 120,
      pointerEvents: 7,
      dutyPercent: 98.4,
      avgBuildMs: 3.25,
      maxBuildMs: 11.5,
      avgRasterMs: 6.5,
      maxRasterMs: 22.25,
      requests: 47,
      totalRequests: 1503,
      errors: 3,
      imageRequests: 12,
      totalImageRequests: 908,
      downloadQueued: 5,
      downloadRunning: 2,
      lagMs: 12.5,
      cpuMicros: 214,
      liveImages: 84,
      imageCacheMb: 61.5,
      rssMb: 412.25,
    ).lines;
    final text = lines.join('\n');

    expect(text, contains('120'));
    expect(text, contains('60.0fps'));
    expect(text, contains('@60Hz'));
    expect(text, contains('98%'));
    expect(text, contains('touch 7'));
    expect(text, contains('3.3'));
    expect(text, contains('22.3'));
    expect(text, contains('47 req'));
    expect(text, contains('1503 all'));
    expect(text, contains('3 err'));
    expect(text, contains('12 req'));
    expect(text, contains('908 all'));
    expect(text, contains('5 queued'));
    expect(text, contains('2 running'));
    expect(text, contains('12.5ms'));
    expect(text, contains('214us'));
    expect(text, contains('84 live'));
    expect(text, contains('412.3MB'));
  });

  test('image traffic is counted apart from the API', () {
    const api = PerfCountingInterceptor();
    const images = PerfCountingInterceptor(images: true);
    final options = RequestOptions(path: '/x');

    api.onRequest(options, RequestInterceptorHandler());
    images.onRequest(options, RequestInterceptorHandler());
    images.onRequest(options, RequestInterceptorHandler());

    expect(PerfCounters.requests, 1);
    expect(PerfCounters.imageRequests, 2);
  });

  test('download queue reads through whatever the fetcher registered', () {
    var queued = 4;
    PerfCounters.downloadQueued = () => queued;
    PerfCounters.downloadRunning = () => 1;
    addTearDown(() {
      PerfCounters.downloadQueued = null;
      PerfCounters.downloadRunning = null;
    });

    expect(PerfCounters.downloadQueued!(), 4);
    queued = 0;
    expect(PerfCounters.downloadQueued!(), 0);
    expect(PerfCounters.downloadRunning!(), 1);
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

  testWidgets('the probe sees touches without swallowing them', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PerfProbe(
            window: const Duration(seconds: 2),
            child: Center(
              child: GestureDetector(
                onTap: () => taps++,
                child: const Text('page'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('page'));
    await tester.pump(const Duration(seconds: 2));

    expect(taps, 1, reason: 'the probe must not consume input');
    final overlay = tester.widget<DecoratedBox>(find.byKey(perfProbeKey));
    expect(overlay, isNotNull);
    expect(
      find.textContaining('touch 0'),
      findsNothing,
      reason: 'the tap should have been counted',
    );
  });
}
