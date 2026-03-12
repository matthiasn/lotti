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

    test('timeline callback subtypes increment independently', () {
      final m = MetricsCounters(collect: true)
        ..incSignalTimelineNewEvent()
        ..incSignalTimelineNewEvent()
        ..incSignalTimelineInsert()
        ..incSignalTimelineChange()
        ..incSignalTimelineRemove()
        ..incSignalTimelineUpdate();
      final snap = m.snapshot(retryStateSize: 0, circuitIsOpen: false);
      expect(snap['signalTimelineNewEvent'], 2);
      expect(snap['signalTimelineInsert'], 1);
      expect(snap['signalTimelineChange'], 1);
      expect(snap['signalTimelineRemove'], 1);
      expect(snap['signalTimelineUpdate'], 1);
    });

    test('timeline callback subtypes respect collect flag', () {
      final m = MetricsCounters()
        ..incSignalTimelineNewEvent()
        ..incSignalTimelineInsert()
        ..incSignalTimelineChange()
        ..incSignalTimelineRemove()
        ..incSignalTimelineUpdate();
      final snap = m.snapshot(retryStateSize: 0, circuitIsOpen: false);
      expect(snap['signalTimelineNewEvent'], 0);
      expect(snap['signalTimelineInsert'], 0);
      expect(snap['signalTimelineChange'], 0);
      expect(snap['signalTimelineRemove'], 0);
      expect(snap['signalTimelineUpdate'], 0);
    });

    test('catchup signal counters increment when collect=true', () {
      final m = MetricsCounters(collect: true)
        ..incSignalFirstStreamCatchupTriggers()
        ..incSignalCatchupDeferred()
        ..incSignalCatchupDeferred()
        ..incSignalCatchupCoalesce();
      final snap = m.snapshot(retryStateSize: 0, circuitIsOpen: false);
      expect(snap['signalFirstStreamCatchupTriggers'], 1);
      expect(snap['signalCatchupDeferredCount'], 2);
      expect(snap['signalCatchupCoalesceCount'], 1);
    });

    test('live-scan deferred counters increment when collect=true', () {
      final m = MetricsCounters(collect: true)
        ..incSignalLiveScanDeferredInitialCatchupIncomplete()
        ..incSignalLiveScanDeferredCatchupInFlight()
        ..incSignalLiveScanDeferredInFlight();
      final snap = m.snapshot(retryStateSize: 0, circuitIsOpen: false);
      expect(snap['signalLiveScanDeferredInitialCatchupIncomplete'], 1);
      expect(snap['signalLiveScanDeferredCatchupInFlight'], 1);
      expect(snap['signalLiveScanDeferredInFlight'], 1);
    });

    test('incSignalNoTimeline and incWakeDetections increment', () {
      final m = MetricsCounters(collect: true)
        ..incSignalNoTimeline()
        ..incSignalNoTimeline()
        ..incWakeDetections();
      final snap = m.snapshot(retryStateSize: 0, circuitIsOpen: false);
      expect(snap['signalNoTimelineCount'], 2);
      expect(snap['wakeDetections'], 1);
    });

    test('all new signal counters respect collect flag', () {
      final m = MetricsCounters()
        ..incSignalFirstStreamCatchupTriggers()
        ..incSignalCatchupDeferred()
        ..incSignalCatchupCoalesce()
        ..incSignalLiveScanDeferredInitialCatchupIncomplete()
        ..incSignalLiveScanDeferredCatchupInFlight()
        ..incSignalLiveScanDeferredInFlight()
        ..incSignalNoTimeline()
        ..incWakeDetections();
      final snap = m.snapshot(retryStateSize: 0, circuitIsOpen: false);
      expect(snap['signalFirstStreamCatchupTriggers'], 0);
      expect(snap['signalCatchupDeferredCount'], 0);
      expect(snap['signalCatchupCoalesceCount'], 0);
      expect(snap['signalLiveScanDeferredInitialCatchupIncomplete'], 0);
      expect(snap['signalLiveScanDeferredCatchupInFlight'], 0);
      expect(snap['signalLiveScanDeferredInFlight'], 0);
      expect(snap['signalNoTimelineCount'], 0);
      expect(snap['wakeDetections'], 0);
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
        ..incSignalTimelineNewEvent()
        ..incSignalTimelineInsert()
        ..incSignalTimelineChange()
        ..incSignalTimelineRemove()
        ..incSignalTimelineUpdate()
        ..incSignalFirstStreamCatchupTriggers()
        ..incSignalCatchupDeferred()
        ..incSignalCatchupCoalesce()
        ..incSignalLiveScanDeferredInitialCatchupIncomplete()
        ..incSignalLiveScanDeferredCatchupInFlight()
        ..incSignalLiveScanDeferredInFlight()
        ..incSignalNoTimeline()
        ..incWakeDetections()
        ..incSignalConnectivity()
        ..recordSignalLatencyMs(123);
      final snap = m.snapshot(retryStateSize: 0, circuitIsOpen: false);
      expect(snap['signalClientStream'], 1);
      expect(snap['signalTimelineCallbacks'], 1);
      expect(snap['signalTimelineNewEvent'], 1);
      expect(snap['signalTimelineInsert'], 1);
      expect(snap['signalTimelineChange'], 1);
      expect(snap['signalTimelineRemove'], 1);
      expect(snap['signalTimelineUpdate'], 1);
      expect(snap['signalFirstStreamCatchupTriggers'], 1);
      expect(snap['signalCatchupDeferredCount'], 1);
      expect(snap['signalCatchupCoalesceCount'], 1);
      expect(snap['signalLiveScanDeferredInitialCatchupIncomplete'], 1);
      expect(snap['signalLiveScanDeferredCatchupInFlight'], 1);
      expect(snap['signalLiveScanDeferredInFlight'], 1);
      expect(snap['signalNoTimelineCount'], 1);
      expect(snap['wakeDetections'], 1);
      expect(snap['signalConnectivity'], 1);
      expect(snap['signalLatencyLastMs'], 123);
      expect(snap['signalLatencyMinMs'], isNonZero);
      expect(snap['signalLatencyMaxMs'], isNonZero);
    });
  });
}
