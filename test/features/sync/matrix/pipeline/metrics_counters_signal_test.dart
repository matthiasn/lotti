import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/matrix/pipeline/metrics_counters.dart';
import 'metrics_counters_signal_test_helpers.dart';

void main() {
  group('MetricsCounters – core counters', () {
    test('non-DB counters respect the collect flag', () {
      // collect=false: incProcessedWithType/incSkipped/incFailures/etc are
      // intentional no-ops to keep steady-state overhead near zero.
      final off = MetricsCounters()
        ..incProcessedWithType('journalEntity')
        ..incSkipped()
        ..incFailures()
        ..incCatchupBatches()
        ..incRetriesScheduled()
        ..incCircuitOpens();
      final offSnap = off.snapshot();
      expect(offSnap['processed'], 0);
      expect(offSnap['skipped'], 0);
      expect(offSnap['failures'], 0);
      expect(offSnap['catchupBatches'], 0);
      expect(offSnap['retriesScheduled'], 0);
      expect(offSnap['circuitOpens'], 0);
      expect(offSnap.containsKey('processed.journalEntity'), isFalse);

      final on = MetricsCounters(collect: true)
        ..incProcessedWithType('journalEntity')
        ..incProcessedWithType('journalEntity')
        ..incSkipped()
        ..incFailures()
        ..incCatchupBatches()
        ..incRetriesScheduled()
        ..incCircuitOpens();
      final onSnap = on.snapshot();
      expect(onSnap['processed'], 2);
      expect(onSnap['skipped'], 1);
      expect(onSnap['failures'], 1);
      expect(onSnap['catchupBatches'], 1);
      expect(onSnap['retriesScheduled'], 1);
      expect(onSnap['circuitOpens'], 1);
      expect(onSnap['processed.journalEntity'], 2);
    });

    test('DB counters are tracked even when collect is false', () {
      // DB metrics deliberately bypass the collect gate — they record
      // persistence outcomes that matter for diagnostics regardless of the
      // verbose-metrics flag.
      final m = MetricsCounters()
        ..incDbApplied()
        ..incDbApplied()
        ..incDbIgnoredByVectorClock()
        ..incConflictsCreated()
        ..incDbMissingBase()
        ..incDbEntryLinkNoop()
        ..incStaleAttachmentPurges()
        ..incSelfEventsSuppressed();
      final snap = m.snapshot();
      expect(snap['dbApplied'], 2);
      expect(snap['dbIgnoredByVectorClock'], 1);
      expect(snap['conflictsCreated'], 1);
      expect(snap['dbMissingBase'], 1);
      expect(snap['dbEntryLinkNoop'], 1);
      expect(snap['staleAttachmentPurges'], 1);
      expect(snap['selfEventsSuppressed'], 1);
    });

    test(
      'processedByType / droppedByType ignore null and empty runtime types',
      () {
        final m = MetricsCounters(collect: true)
          ..bumpProcessedType(null)
          ..bumpProcessedType('')
          ..bumpProcessedType('task')
          ..bumpProcessedType('task')
          ..bumpDroppedType(null)
          ..bumpDroppedType('')
          ..bumpDroppedType('entryLink');
        final snap = m.snapshot();
        expect(snap['processed.task'], 2);
        expect(snap['droppedByType.entryLink'], 1);
        // Null/empty runtime types must not produce 'processed.' / '.' keys.
        expect(snap.containsKey('processed.'), isFalse);
        expect(snap.containsKey('droppedByType.'), isFalse);
      },
    );

    test('lastIgnored is a bounded ring buffer with serialized lengths', () {
      final m = MetricsCounters(collect: true, lastIgnoredMax: 2)
        ..addLastIgnored('a')
        ..addLastIgnored('bb')
        ..addLastIgnored('ccc');
      final snap = m.snapshot();
      // Only the most recent `lastIgnoredMax` entries are retained; the
      // snapshot serializes each retained entry's *length* under a 1-based key.
      expect(snap['lastIgnoredCount'], 2);
      expect(snap['lastIgnored.1'], 'bb'.length);
      expect(snap['lastIgnored.2'], 'ccc'.length);
      expect(snap.containsKey('lastIgnored.3'), isFalse);
    });

    test('addLastIgnored records regardless of the collect flag', () {
      // ringBufferAdd in addLastIgnored has no collect gate, so entries are
      // captured even when collect=false (diagnostics ring is always live).
      final m = MetricsCounters()..addLastIgnored('only');
      final snap = m.snapshot();
      expect(snap['lastIgnoredCount'], 1);
      expect(snap['lastIgnored.1'], 'only'.length);
    });
  });

  group('MetricsCounters – signal counters', () {
    test('incSignalClientStream increments counter when collect=true', () {
      final m = MetricsCounters(collect: true)..incSignalClientStream();
      final snap = m.snapshot();
      expect(snap['signalClientStream'], 1);
    });

    test('incSignalTimelineCallbacks increments counter when collect=true', () {
      final m = MetricsCounters(collect: true)..incSignalTimelineCallbacks();
      final snap = m.snapshot();
      expect(snap['signalTimelineCallbacks'], 1);
    });

    test('incSignalConnectivity increments counter when collect=true', () {
      final m = MetricsCounters(collect: true)..incSignalConnectivity();
      final snap = m.snapshot();
      expect(snap['signalConnectivity'], 1);
    });

    test('signal counters respect collect flag', () {
      final m = MetricsCounters()
        ..incSignalClientStream()
        ..incSignalTimelineCallbacks()
        ..incSignalConnectivity();
      final snap = m.snapshot();
      expect(snap['signalClientStream'], 0);
      expect(snap['signalTimelineCallbacks'], 0);
      expect(snap['signalConnectivity'], 0);
    });

    test('timeline callback subtypes increment independently', () {
      final m = MetricsCounters(collect: true)
        ..incSignalTimelineNewEvent()
        ..incSignalTimelineNewEvent()
        ..incSignalTimelineInsert();
      final snap = m.snapshot();
      expect(snap['signalTimelineNewEvent'], 2);
      expect(snap['signalTimelineInsert'], 1);
    });

    test('timeline callback subtypes respect collect flag', () {
      final m = MetricsCounters()
        ..incSignalTimelineNewEvent()
        ..incSignalTimelineInsert();
      final snap = m.snapshot();
      expect(snap['signalTimelineNewEvent'], 0);
      expect(snap['signalTimelineInsert'], 0);
    });

    test('catchup signal counters increment when collect=true', () {
      final m = MetricsCounters(collect: true)
        ..incSignalFirstStreamCatchupTriggers()
        ..incSignalCatchupDeferred()
        ..incSignalCatchupDeferred()
        ..incSignalCatchupCoalesce();
      final snap = m.snapshot();
      expect(snap['signalFirstStreamCatchupTriggers'], 1);
      expect(snap['signalCatchupDeferredCount'], 2);
      expect(snap['signalCatchupCoalesceCount'], 1);
    });

    test('live-scan deferred counters increment when collect=true', () {
      final m = MetricsCounters(collect: true)
        ..incSignalLiveScanDeferredInitialCatchupIncomplete()
        ..incSignalLiveScanDeferredCatchupInFlight()
        ..incSignalLiveScanDeferredInFlight();
      final snap = m.snapshot();
      expect(snap['signalLiveScanDeferredInitialCatchupIncomplete'], 1);
      expect(snap['signalLiveScanDeferredCatchupInFlight'], 1);
      expect(snap['signalLiveScanDeferredInFlight'], 1);
    });

    test('incSignalNoTimeline and incWakeDetections increment', () {
      final m = MetricsCounters(collect: true)
        ..incSignalNoTimeline()
        ..incSignalNoTimeline()
        ..incWakeDetections();
      final snap = m.snapshot();
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
      final snap = m.snapshot();
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
      final snap = m.snapshot();
      expect(snap['signalLatencyLastMs'], 200);
      expect(snap['signalLatencyMinMs'], 80);
      expect(snap['signalLatencyMaxMs'], 200);
    });

    test('recordSignalLatencyMs handles first recording (min=0 case)', () {
      final m = MetricsCounters(collect: true)..recordSignalLatencyMs(120);
      final snap = m.snapshot();
      expect(snap['signalLatencyLastMs'], 120);
      expect(snap['signalLatencyMinMs'], 120);
      expect(snap['signalLatencyMaxMs'], 120);
    });

    test('recordSignalLatencyMs respects collect flag', () {
      final m = MetricsCounters()..recordSignalLatencyMs(100);
      final snap = m.snapshot();
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
      final snap = m.snapshot();
      expect(snap['signalClientStream'], 1);
      expect(snap['signalTimelineCallbacks'], 1);
      expect(snap['signalTimelineNewEvent'], 1);
      expect(snap['signalTimelineInsert'], 1);
      expect(snap.containsKey('signalTimelineChange'), isFalse);
      expect(snap.containsKey('signalTimelineRemove'), isFalse);
      expect(snap.containsKey('signalTimelineUpdate'), isFalse);
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

    glados.Glados(
      glados.any.metricsScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test(
      'generated operation sequences keep counters, latency, and logs bounded',
      (scenario) {
        final counters = MetricsCounters(
          collect: scenario.collect,
          lastIgnoredMax: scenario.lastIgnoredMax,
        );
        final model = ExpectedMetricsModel(
          collect: scenario.collect,
          lastIgnoredMax: scenario.lastIgnoredMax,
        );

        for (final operation in scenario.operations) {
          switch (operation.kind) {
            case GeneratedMetricsOperationKind.incProcessedWithType:
              counters.incProcessedWithType(operation.syncRuntimeType);
            case GeneratedMetricsOperationKind.bumpProcessedType:
              counters.bumpProcessedType(operation.syncRuntimeType);
            case GeneratedMetricsOperationKind.bumpDroppedType:
              counters.bumpDroppedType(operation.syncRuntimeType);
            case GeneratedMetricsOperationKind.incSkipped:
              counters.incSkipped();
            case GeneratedMetricsOperationKind.incFailures:
              counters.incFailures();
            case GeneratedMetricsOperationKind.incCatchupBatches:
              counters.incCatchupBatches();
            case GeneratedMetricsOperationKind.incRetriesScheduled:
              counters.incRetriesScheduled();
            case GeneratedMetricsOperationKind.incCircuitOpens:
              counters.incCircuitOpens();
            case GeneratedMetricsOperationKind.incSignalClientStream:
              counters.incSignalClientStream();
            case GeneratedMetricsOperationKind.incSignalTimelineCallbacks:
              counters.incSignalTimelineCallbacks();
            case GeneratedMetricsOperationKind.incSignalTimelineNewEvent:
              counters.incSignalTimelineNewEvent();
            case GeneratedMetricsOperationKind.incSignalTimelineInsert:
              counters.incSignalTimelineInsert();
            case GeneratedMetricsOperationKind
                .incSignalFirstStreamCatchupTriggers:
              counters.incSignalFirstStreamCatchupTriggers();
            case GeneratedMetricsOperationKind.incSignalCatchupDeferred:
              counters.incSignalCatchupDeferred();
            case GeneratedMetricsOperationKind.incSignalCatchupCoalesce:
              counters.incSignalCatchupCoalesce();
            case GeneratedMetricsOperationKind
                .incSignalLiveScanDeferredInitialCatchupIncomplete:
              counters.incSignalLiveScanDeferredInitialCatchupIncomplete();
            case GeneratedMetricsOperationKind
                .incSignalLiveScanDeferredCatchupInFlight:
              counters.incSignalLiveScanDeferredCatchupInFlight();
            case GeneratedMetricsOperationKind
                .incSignalLiveScanDeferredInFlight:
              counters.incSignalLiveScanDeferredInFlight();
            case GeneratedMetricsOperationKind.incSignalNoTimeline:
              counters.incSignalNoTimeline();
            case GeneratedMetricsOperationKind.incWakeDetections:
              counters.incWakeDetections();
            case GeneratedMetricsOperationKind.incSignalConnectivity:
              counters.incSignalConnectivity();
            case GeneratedMetricsOperationKind.recordSignalLatency:
              counters.recordSignalLatencyMs(operation.latencyMs);
            case GeneratedMetricsOperationKind.incTrailingCatchups:
              counters.incTrailingCatchups();
            case GeneratedMetricsOperationKind.incLiveScanDeferred:
              counters.incLiveScanDeferred();
            case GeneratedMetricsOperationKind.incLiveScanCoalesce:
              counters.incLiveScanCoalesce();
            case GeneratedMetricsOperationKind.incLiveScanTrailingScheduled:
              counters.incLiveScanTrailingScheduled();
            case GeneratedMetricsOperationKind.incDbApplied:
              counters.incDbApplied();
            case GeneratedMetricsOperationKind.incDbIgnoredByVectorClock:
              counters.incDbIgnoredByVectorClock();
            case GeneratedMetricsOperationKind.incConflictsCreated:
              counters.incConflictsCreated();
            case GeneratedMetricsOperationKind.incDbMissingBase:
              counters.incDbMissingBase();
            case GeneratedMetricsOperationKind.incDbEntryLinkNoop:
              counters.incDbEntryLinkNoop();
            case GeneratedMetricsOperationKind.incStaleAttachmentPurges:
              counters.incStaleAttachmentPurges();
            case GeneratedMetricsOperationKind.incSelfEventsSuppressed:
              counters.incSelfEventsSuppressed();
            case GeneratedMetricsOperationKind.addLastIgnored:
              counters.addLastIgnored(operation.ignoredEntry);
          }
          model.apply(operation);
        }

        final snapshot = counters.snapshot();
        for (final entry in model.counters.entries) {
          expect(
            snapshot[entry.key],
            entry.value,
            reason: '$scenario\n${entry.key}',
          );
        }
        for (final entry in model.processedByType.entries) {
          expect(snapshot['processed.${entry.key}'], entry.value);
        }
        for (final entry in model.droppedByType.entries) {
          expect(snapshot['droppedByType.${entry.key}'], entry.value);
        }
        expect(snapshot['lastIgnoredCount'], model.lastIgnored.length);
        for (var index = 0; index < model.lastIgnored.length; index++) {
          expect(
            snapshot['lastIgnored.${index + 1}'],
            model.lastIgnored[index].length,
          );
        }
      },
      tags: 'glados',
    );
  });
}
