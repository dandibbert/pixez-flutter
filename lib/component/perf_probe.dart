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

  static void reset() {
    requests = 0;
    responses = 0;
    errors = 0;
  }
}

class PerfCountingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    PerfCounters.requests++;
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    PerfCounters.responses++;
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    PerfCounters.errors++;
    handler.next(err);
  }
}

/// One window of measurements. Pure data so the formatting can be tested.
class PerfSample {
  const PerfSample({
    required this.window,
    required this.frames,
    required this.avgBuildMs,
    required this.maxBuildMs,
    required this.avgRasterMs,
    required this.maxRasterMs,
    required this.requests,
    required this.errors,
    required this.lagMs,
    required this.liveImages,
    required this.imageCacheMb,
    required this.rssMb,
  });

  final Duration window;
  final int frames;
  final double avgBuildMs;
  final double maxBuildMs;
  final double avgRasterMs;
  final double maxRasterMs;
  final int requests;
  final int errors;
  final double lagMs;
  final int liveImages;
  final double imageCacheMb;
  final double rssMb;

  double get fps => frames / window.inMilliseconds * 1000;

  /// The probe itself repaints once per window, so anything near that is an
  /// app that is genuinely asleep. A steady 60 means it never stops drawing.
  bool get idle => frames <= 2;

  List<String> get lines {
    String n(double value) => value.toStringAsFixed(1);
    return [
      'frames ${frames.toString().padLeft(3)} / ${window.inSeconds}s'
          '   ${n(fps)} fps   ${idle ? 'IDLE' : 'DRAWING'}',
      'build  avg ${n(avgBuildMs)}ms  max ${n(maxBuildMs)}ms',
      'raster avg ${n(avgRasterMs)}ms  max ${n(maxRasterMs)}ms',
      'net    $requests req  $errors err   loop lag ${n(lagMs)}ms',
      'images $liveImages live  ${n(imageCacheMb)}MB   rss ${n(rssMb)}MB',
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
  });

  final Widget child;
  final Duration window;

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
  double _lagMs = 0;
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

  void _publish() {
    if (!mounted) return;
    final frames = _frames;
    final imageCache = PaintingBinding.instance.imageCache;
    final sample = PerfSample(
      window: widget.window,
      frames: frames,
      avgBuildMs: frames == 0 ? 0 : _buildTotal / frames,
      maxBuildMs: _buildMax,
      avgRasterMs: frames == 0 ? 0 : _rasterTotal / frames,
      maxRasterMs: _rasterMax,
      requests: PerfCounters.requests - _requestsAtWindowStart,
      errors: PerfCounters.errors - _errorsAtWindowStart,
      lagMs: _lagMs,
      liveImages: imageCache.liveImageCount,
      imageCacheMb: imageCache.currentSizeBytes / (1024 * 1024),
      rssMb: _rssMb(),
    );
    _frames = 0;
    _buildTotal = 0;
    _buildMax = 0;
    _rasterTotal = 0;
    _rasterMax = 0;
    _requestsAtWindowStart = PerfCounters.requests;
    _errorsAtWindowStart = PerfCounters.errors;
    setState(() => _sample = sample);
  }

  @override
  Widget build(BuildContext context) {
    final sample = _sample;
    return Stack(
      children: [
        widget.child,
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
