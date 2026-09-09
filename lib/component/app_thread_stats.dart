import 'dart:io';

import 'package:flutter/services.dart';

/// One thread of this process and what it was doing when sampled.
class AppThread {
  const AppThread({required this.name, required this.cpuPercent});

  final String name;

  /// Share of a single core, so several busy threads can sum past 100.
  final double cpuPercent;
}

/// A reading of this process's own CPU use.
class AppCpuSample {
  const AppCpuSample({
    required this.cpuSeconds,
    required this.threads,
    required this.busiest,
  });

  /// CPU time burned since launch, across every thread including exited ones.
  final double cpuSeconds;
  final int threads;
  final List<AppThread> busiest;
}

/// Reads this process's CPU usage per thread.
///
/// Dart can only see its own isolate, so an app that looks asleep while the
/// device warms up gives it nothing to go on. This reaches the threads Dart
/// never runs on: the raster thread, plugin queues, and the Rust HTTP runtime.
class AppThreadStats {
  static const MethodChannel _channel = MethodChannel('com.perol.dev/threads');

  static Future<AppCpuSample?> Function()? debugSampler;

  static bool get supported => Platform.isIOS || Platform.isMacOS;

  static Future<AppCpuSample?> sample() async {
    final override = debugSampler;
    if (override != null) return override();
    if (!supported) return null;
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('sample');
      if (raw == null) return null;
      return parseSample(raw);
    } catch (_) {
      return null;
    }
  }

  static AppCpuSample parseSample(Map<String, dynamic> raw) {
    final threads = <AppThread>[];
    final list = raw['threads'];
    if (list is List) {
      for (final entry in list) {
        if (entry is Map) {
          threads.add(
            AppThread(
              name: '${entry['name'] ?? 'thread'}',
              cpuPercent: (entry['cpu'] as num?)?.toDouble() ?? 0,
            ),
          );
        }
      }
    }
    return AppCpuSample(
      cpuSeconds: (raw['cpuSeconds'] as num?)?.toDouble() ?? 0,
      threads: threads.length,
      busiest: threads,
    );
  }

  /// Turns two cumulative readings into a percentage of one core. Values above
  /// 100 mean more than one core's worth of work, which is what a runaway
  /// background thread looks like.
  static double cpuPercentBetween(
    double previousSeconds,
    double currentSeconds,
    Duration elapsed,
  ) {
    final seconds = elapsed.inMicroseconds / 1000000;
    if (seconds <= 0) return 0;
    final burned = currentSeconds - previousSeconds;
    if (burned <= 0) return 0;
    return burned / seconds * 100;
  }
}
