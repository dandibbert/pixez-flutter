import 'package:flutter_test/flutter_test.dart';
import 'package:pixez/component/app_thread_stats.dart';

void main() {
  group('cpuPercentBetween', () {
    test('one core fully busy for the whole window reads as 100%', () {
      expect(
        AppThreadStats.cpuPercentBetween(10, 12, const Duration(seconds: 2)),
        closeTo(100, 0.001),
      );
    });

    test('more than one core reads above 100%', () {
      // Two threads pegged for two seconds burn four CPU-seconds.
      expect(
        AppThreadStats.cpuPercentBetween(0, 4, const Duration(seconds: 2)),
        closeTo(200, 0.001),
      );
    });

    test('an idle process reads near zero', () {
      expect(
        AppThreadStats.cpuPercentBetween(10, 10.004, const Duration(seconds: 2)),
        closeTo(0.2, 0.001),
      );
    });

    test('a counter that did not move or went backwards reads as zero', () {
      expect(
        AppThreadStats.cpuPercentBetween(10, 10, const Duration(seconds: 2)),
        0,
      );
      expect(
        AppThreadStats.cpuPercentBetween(10, 9, const Duration(seconds: 2)),
        0,
      );
    });

    test('a zero-length window cannot divide by zero', () {
      expect(AppThreadStats.cpuPercentBetween(0, 5, Duration.zero), 0);
    });
  });

  group('parseSample', () {
    test('reads the busiest threads in order', () {
      final sample = AppThreadStats.parseSample(const {
        'cpuSeconds': 41.5,
        'threads': [
          {'name': 'tokio-runtime-w', 'cpu': 96.5},
          {'name': 'io.flutter.raster', 'cpu': 12.0},
          {'name': 'io.flutter.ui', 'cpu': 3.0},
        ],
      });

      expect(sample.cpuSeconds, 41.5);
      expect(sample.threads, 3);
      expect(sample.busiest.first.name, 'tokio-runtime-w');
      expect(sample.busiest.first.cpuPercent, 96.5);
    });

    test('survives a platform that returns nothing useful', () {
      final sample = AppThreadStats.parseSample(const {});
      expect(sample.cpuSeconds, 0);
      expect(sample.threads, 0);
      expect(sample.busiest, isEmpty);
    });

    test('tolerates malformed entries rather than throwing', () {
      final sample = AppThreadStats.parseSample(const {
        'cpuSeconds': 1,
        'threads': [
          {'name': 'ok', 'cpu': 5},
          'not a map',
          {'cpu': 2},
        ],
      });
      expect(sample.busiest, hasLength(2));
      expect(sample.busiest.first.name, 'ok');
      expect(sample.busiest.last.name, 'thread');
    });
  });
}
