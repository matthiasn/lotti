import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/pipeline/metrics_counters.dart';

void main() {
  group('MetricsCounters – signal counters', () {
    test('incSignalClientStream increments counter when collect=true', () {
      final m = MetricsCounters(collect: true)..incSignalClientStream();
      final snap = m.snapshot(retryStateSize: 0, circuitIsOpen: false);
      expect(snap['signalClientStream'], 1);
    });

    test('incSignalTimelineCallbacks increments counter when collect=true', () {
      final m = MetricsCounters(collect: true)..incSignalTimelineCallbacks();
      final snap = m.snapshot(retryStateSize: 0, circuitIsOpen: false);
      expect(snap['signalTimelineCallbacks'], 1);
    });

    test('incSignalConnectivity increments counter when collect=true', () {
      final m = MetricsCounters(collect: true)..incSignalConnectivity();
      final snap = m.snapshot(retryStateSize: 0, circuitIsOpen: false);
      expect(snap['signalConnectivity'], 1);
    });

    test('signal counters respect collect flag', () {
      final m = MetricsCounters()
        ..incSignalClientStream()
        ..incSignalTimelineCallbacks()
        ..incSignalConnectivity();
      final snap = m.snapshot(retryStateSize: 0, circuitIsOpen: false);
      expect(snap['signalClientStream'], 0);
      expect(snap['signalTimelineCallbacks'], 0);
      expect(snap['signalConnectivity'], 0);
    });
  });

  group('MetricsCounters – signal latency', () {
    test('recordSignalLatencyMs updates last/min/max correctly', () async {
      final m = MetricsCounters(collect: true)
        ..recordSignalLatencyMs(150)
        ..recordSignalLatencyMs(80)
        ..recordSignalLatencyMs(200);
      final snap = m.snapshot(retryStateSize: 0, circuitIsOpen: false);
      expect(snap['signalLatencyLastMs'], 200);
      expect(snap['signalLatencyMinMs'], 80);
      expect(snap['signalLatencyMaxMs'], 200);
    });

    test('recordSignalLatencyMs handles first recording (min=0 case)', () {
      final m = MetricsCounters(collect: true)..recordSignalLatencyMs(120);
      final snap = m.snapshot(retryStateSize: 0, circuitIsOpen: false);
      expect(snap['signalLatencyLastMs'], 120);
      expect(snap['signalLatencyMinMs'], 120);
      expect(snap['signalLatencyMaxMs'], 120);
    });

    test('recordSignalLatencyMs respects collect flag', () {
      final m = MetricsCounters()..recordSignalLatencyMs(100);
      final snap = m.snapshot(retryStateSize: 0, circuitIsOpen: false);
      expect(snap['signalLatencyLastMs'], 0);
      expect(snap['signalLatencyMinMs'], 0);
      expect(snap['signalLatencyMaxMs'], 0);
    });
  });

  group('MetricsCounters – snapshot and logs', () {
    test('snapshot includes all signal metrics', () {
      final m = MetricsCounters(collect: true)
        ..incSignalClientStream()
        ..incSignalTimelineCallbacks()
        ..incSignalConnectivity()
        ..recordSignalLatencyMs(123);
      final snap = m.snapshot(retryStateSize: 0, circuitIsOpen: false);
      expect(snap['signalClientStream'], 1);
      expect(snap['signalTimelineCallbacks'], 1);
      expect(snap['signalConnectivity'], 1);
      expect(snap['signalLatencyLastMs'], 123);
      expect(snap['signalLatencyMinMs'], isNonZero);
      expect(snap['signalLatencyMaxMs'], isNonZero);
    });

    test('buildFlushLog includes signal summary', () {
      final m = MetricsCounters(collect: true)
        ..incSignalClientStream()
        ..incSignalTimelineCallbacks()
        ..incSignalConnectivity()
        ..recordSignalLatencyMs(50);
      final log = m.buildFlushLog(retriesPending: 0);
      expect(log, contains('signals('));
      expect(log, contains('client=1'));
      expect(log, contains('timeline=1'));
      expect(log, contains('net=1'));
      expect(log, contains('lat=50ms'));
    });
  });
}
