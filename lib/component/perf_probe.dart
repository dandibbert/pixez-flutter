import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

const Key perfProbeKey = Key('perfProbe');

/// Counters the probe reads. Incremented from the network layer, so a page
/// that looks idle but keeps talking to Pixiv still shows up.
class PerfCounters {
  static int requests = 0;
  static int responses = 0;
  static int errors = 0;

  /// Image traffic runs through its own Dio, so it is counted separately.
  /// A quiet API count says nothing about the radio if thumbnails are still
  /// streaming.
  static int imageRequests = 0;
  static int imageErrors = 0;

  /// Speech synthesis talks to its provider over its own `HttpClient`, so it
  /// is invisible to both Dio counters above.
  static int ttsRequests = 0;

  /// Downloads run in their own isolate, which no probe on this isolate can
  /// see. These read the queue the main isolate hands it.
  static int Function()? downloadQueued;
  static int Function()? downloadRunning;

  static void reset() {
    requests = 0;
    responses = 0;
    errors = 0;
    imageRequests = 0;
    imageErrors = 0;
    ttsRequests = 0;
  }
}

class PerfCountingInterceptor extends Interceptor {
  const PerfCountingInterceptor({this.images = false});

  final bool images;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (images) {
      PerfCounters.imageRequests++;
    } else {
      PerfCounters.requests++;
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (!images) PerfCounters.responses++;
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (images) {
      PerfCounters.imageErrors++;
    } else {
      PerfCounters.errors++;
    }
    handler.next(err);
  }
}

/// Whether the app is asleep, redrawing because something is happening, or
/// never stopping. Only the last one drains a battery on its own.
enum PerfActivity { idle, active, pegged }

/// One window of measurements. Pure data so the formatting can be tested.
class PerfSample {
  const PerfSample({
    required this.window,
    required this.historyWindow,
    required this.refreshRate,
    required this.frames,
    required this.pointerEvents,
    required this.dutyPercent,
    required this.avgBuildMs,
    required this.maxBuildMs,
    required this.avgRasterMs,
    required this.maxRasterMs,
    required this.requests,
    required this.totalRequests,
    required this.errors,
    required this.imageRequests,
    required this.totalImageRequests,
    required this.downloadQueued,
    required this.downloadRunning,
    required this.ttsRequests,
    required this.lagMs,
    required this.cpuMicros,
    required this.liveImages,
    required this.imageCacheMb,
    required this.rssMb,
  });

  final Duration window;
  final Duration historyWindow;
  final double refreshRate;
  final int frames;
  final int pointerEvents;

  /// Share of the display's vsyncs the app actually drew, over
  /// [historyWindow]. This is the number that maps to battery: scrolling now
  /// and then is a few percent, never sleeping is ~100.
  final double dutyPercent;
  final double avgBuildMs;
  final double maxBuildMs;
  final double avgRasterMs;
  final double maxRasterMs;
  final int requests;
  final int totalRequests;
  final int errors;
  final int imageRequests;
  final int totalImageRequests;
  final int downloadQueued;
  final int downloadRunning;
  final int ttsRequests;
  final double lagMs;

  /// How long a fixed amount of arithmetic took. Nothing else on this isolate
  /// competes with it, so when this climbs the SoC is loaded or throttling —
  /// which is how work on threads Dart cannot see shows up.
  final int cpuMicros;
  final int liveImages;
  final double imageCacheMb;
  final double rssMb;

  double get fps => frames / window.inMilliseconds * 1000;

  double get expectedFrames => refreshRate * window.inMilliseconds / 1000;

  PerfActivity get activity {
    // The probe repaints once per window, so a sleeping app still reports a
    // frame or two.
    if (frames <= 2) return PerfActivity.idle;
    if (frames >= expectedFrames * 0.85) return PerfActivity.pegged;
    return PerfActivity.active;
  }

  /// Redrawing with nobody touching the screen is the thing worth catching:
  /// scrolling has to draw, sitting still does not.
  bool get drawsUntouched => pointerEvents == 0 && frames > 10;

  String get activityLabel => switch (activity) {
    PerfActivity.idle => 'IDLE',
    PerfActivity.active => 'ACTIVE',
    PerfActivity.pegged => 'PEGGED',
  };

  List<String> get lines {
    String n(double value) => value.toStringAsFixed(1);
    return [
      'frames ${frames.toString().padLeft(3)}/${window.inSeconds}s '
          '${n(fps)}fps @${refreshRate.round()}Hz  $activityLabel',
      'duty   ${dutyPercent.round()}% of ${historyWindow.inSeconds}s'
          '  touch $pointerEvents'
          '${drawsUntouched ? '  << UNTOUCHED' : ''}',
      'build  avg ${n(avgBuildMs)}  max ${n(maxBuildMs)} ms',
      'raster avg ${n(avgRasterMs)}  max ${n(maxRasterMs)} ms',
      'api    $requests req ($totalRequests all) $errors err',
      'img    $imageRequests req ($totalImageRequests all)'
          '  $liveImages live ${n(imageCacheMb)}MB',
      'dl     $downloadQueued queued  $downloadRunning running'
          '   tts $ttsRequests req',
      'lag ${n(lagMs)}ms  cpu ${cpuMicros}us  rss ${n(rssMb)}MB',
    ];
  }
}

/// A small always-on readout of where the device's time is going.
///
/// Built for diagnosing battery drain on a sideloaded release build, where
/// neither DevTools nor Instruments is available. It deliberately repaints
/// only once per window so its own cost cannot be mistaken for the app
/// drawing continuously.
class PerfProbe extends StatefulWidget {
  const PerfProbe({
    super.key,
    required this.child,
    this.window = const Duration(seconds: 2),
    this.historyWindow = const Duration(seconds: 30),
  });

  final Widget child;
  final Duration window;
  final Duration historyWindow;

  @override
  State<PerfProbe> createState() => _PerfProbeState();
}

class _PerfProbeState extends State<PerfProbe> {
  int _frames = 0;
  double _buildTotal = 0;
  double _buildMax = 0;
  double _rasterTotal = 0;
  double _rasterMax = 0;
  int _requestsAtWindowStart = 0;
  int _errorsAtWindowStart = 0;
  int _imageRequestsAtWindowStart = 0;
  int _pointerEvents = 0;
  final List<int> _frameHistory = <int>[];
  double _lagMs = 0;
  int _cpuMicros = 0;
  Timer? _ticker;
  Timer? _lagTimer;
  DateTime _lagScheduledFor = DateTime.now();
  PerfSample? _sample;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    _ticker = Timer.periodic(widget.window, (_) => _publish());
    _scheduleLagProbe();
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    _ticker?.cancel();
    _lagTimer?.cancel();
    super.dispose();
  }

  /// A timer that should fire on time. If the isolate is busy with work that
  /// never produces a frame, this is what reveals it.
  void _scheduleLagProbe() {
    const period = Duration(milliseconds: 250);
    _lagScheduledFor = DateTime.now().add(period);
    _lagTimer = Timer(period, () {
      final late = DateTime.now().difference(_lagScheduledFor).inMicroseconds;
      _lagMs = (late / 1000).clamp(0, 100000).toDouble();
      _scheduleLagProbe();
    });
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _frames++;
      final build = timing.buildDuration.inMicroseconds / 1000;
      final raster = timing.rasterDuration.inMicroseconds / 1000;
      _buildTotal += build;
      _rasterTotal += raster;
      if (build > _buildMax) _buildMax = build;
      if (raster > _rasterMax) _rasterMax = raster;
    }
  }

  double _rssMb() {
    try {
      return ProcessInfo.currentRss / (1024 * 1024);
    } catch (_) {
      return 0;
    }
  }

  /// Times a fixed amount of arithmetic. On an unloaded, cool device this is
  /// stable; when other threads saturate the SoC or it starts throttling, the
  /// same work takes measurably longer. That is the only handle Dart has on
  /// load it cannot otherwise observe.
  void _measureCpu() {
    final watch = Stopwatch()..start();
    var accumulator = 0;
    for (var i = 1; i <= 50000; i++) {
      accumulator += i % 7;
    }
    watch.stop();
    // Reading the sum keeps the loop from being optimised away.
    _cpuMicros = accumulator == 0 ? 0 : watch.elapsedMicroseconds;
  }

  double _refreshRate() {
    try {
      final rate = WidgetsBinding
          .instance
          .platformDispatcher
          .views
          .first
          .display
          .refreshRate;
      if (rate.isFinite && rate > 0) return rate;
    } catch (_) {}
    return 60;
  }

  void _publish() {
    if (!mounted) return;
    final frames = _frames;
    final refreshRate = _refreshRate();
    _measureCpu();

    final historyLength =
        (widget.historyWindow.inMilliseconds / widget.window.inMilliseconds)
            .round()
            .clamp(1, 600);
    _frameHistory.add(frames);
    while (_frameHistory.length > historyLength) {
      _frameHistory.removeAt(0);
    }
    final drawn = _frameHistory.fold<int>(0, (sum, value) => sum + value);
    final possible =
        refreshRate *
        widget.window.inMilliseconds /
        1000 *
        _frameHistory.length;

    final imageCache = PaintingBinding.instance.imageCache;
    final sample = PerfSample(
      window: widget.window,
      historyWindow: widget.window * _frameHistory.length,
      refreshRate: refreshRate,
      frames: frames,
      pointerEvents: _pointerEvents,
      dutyPercent: possible <= 0 ? 0 : (drawn / possible * 100).clamp(0, 100),
      avgBuildMs: frames == 0 ? 0 : _buildTotal / frames,
      maxBuildMs: _buildMax,
      avgRasterMs: frames == 0 ? 0 : _rasterTotal / frames,
      maxRasterMs: _rasterMax,
      requests: PerfCounters.requests - _requestsAtWindowStart,
      totalRequests: PerfCounters.requests,
      errors: PerfCounters.errors - _errorsAtWindowStart,
      imageRequests: PerfCounters.imageRequests - _imageRequestsAtWindowStart,
      totalImageRequests: PerfCounters.imageRequests,
      downloadQueued: PerfCounters.downloadQueued?.call() ?? 0,
      downloadRunning: PerfCounters.downloadRunning?.call() ?? 0,
      ttsRequests: PerfCounters.ttsRequests,
      lagMs: _lagMs,
      cpuMicros: _cpuMicros,
      liveImages: imageCache.liveImageCount,
      imageCacheMb: imageCache.currentSizeBytes / (1024 * 1024),
      rssMb: _rssMb(),
    );
    _frames = 0;
    _buildTotal = 0;
    _buildMax = 0;
    _rasterTotal = 0;
    _rasterMax = 0;
    _pointerEvents = 0;
    _requestsAtWindowStart = PerfCounters.requests;
    _errorsAtWindowStart = PerfCounters.errors;
    _imageRequestsAtWindowStart = PerfCounters.imageRequests;
    setState(() => _sample = sample);
  }

  @override
  Widget build(BuildContext context) {
    final sample = _sample;
    return Stack(
      children: [
        // Sits above the whole app on the hit path, so it sees every pointer
        // without consuming any. Frames with no pointer events are frames
        // nobody asked for.
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _pointerEvents++,
          onPointerMove: (_) => _pointerEvents++,
          onPointerUp: (_) => _pointerEvents++,
          onPointerSignal: (_) => _pointerEvents++,
          child: widget.child,
        ),
        if (sample != null)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 4,
            right: 8,
            child: IgnorePointer(
              child: DecoratedBox(
                key: perfProbeKey,
                decoration: BoxDecoration(
                  color: const Color(0xE6000000),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final line in sample.lines)
                        Text(
                          line,
                          style: const TextStyle(
                            color: Color(0xFF7CFF7C),
                            fontSize: 10,
                            height: 1.35,
                            fontFamily: 'monospace',
                            fontFamilyFallback: ['Menlo', 'Courier'],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
