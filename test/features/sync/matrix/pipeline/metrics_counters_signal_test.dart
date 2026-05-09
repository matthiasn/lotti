import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/matrix/pipeline/metrics_counters.dart';

enum _GeneratedMetricsOperationKind {
  incProcessedWithType,
  bumpProcessedType,
  bumpDroppedType,
  incSkipped,
  incFailures,
  incCatchupBatches,
  incRetriesScheduled,
  incCircuitOpens,
  incSignalClientStream,
  incSignalTimelineCallbacks,
  incSignalTimelineNewEvent,
  incSignalTimelineInsert,
  incSignalFirstStreamCatchupTriggers,
  incSignalCatchupDeferred,
  incSignalCatchupCoalesce,
  incSignalLiveScanDeferredInitialCatchupIncomplete,
  incSignalLiveScanDeferredCatchupInFlight,
  incSignalLiveScanDeferredInFlight,
  incSignalNoTimeline,
  incWakeDetections,
  incSignalConnectivity,
  recordSignalLatency,
  incTrailingCatchups,
  incLiveScanDeferred,
  incLiveScanCoalesce,
  incLiveScanTrailingScheduled,
  incDbApplied,
  incDbIgnoredByVectorClock,
  incConflictsCreated,
  incDbMissingBase,
  incDbEntryLinkNoop,
  incStaleAttachmentPurges,
  incSelfEventsSuppressed,
  addLastIgnored,
}

class _GeneratedMetricsOperation {
  const _GeneratedMetricsOperation({
    required this.kind,
    required this.valueSlot,
  });

  final _GeneratedMetricsOperationKind kind;
  final int valueSlot;

  int get latencyMs => valueSlot * 25;

  String get ignoredEntry => 'ignored-$valueSlot';

  String? get syncRuntimeType {
    switch (valueSlot % 5) {
      case 0:
        return null;
      case 1:
        return '';
      case 2:
        return 'journalEntity';
      case 3:
        return 'entryLink';
      case 4:
        return 'task';
    }
    throw StateError('unsupported value slot $valueSlot');
  }

  @override
  String toString() {
    return '_GeneratedMetricsOperation('
        'kind: $kind, '
        'valueSlot: $valueSlot'
        ')';
  }
}

class _GeneratedMetricsScenario {
  const _GeneratedMetricsScenario({
    required this.collect,
    required this.lastIgnoredMax,
    required this.operations,
  });

  final bool collect;
  final int lastIgnoredMax;
  final List<_GeneratedMetricsOperation> operations;

  @override
  String toString() {
    return '_GeneratedMetricsScenario('
        'collect: $collect, '
        'lastIgnoredMax: $lastIgnoredMax, '
        'operations: $operations'
        ')';
  }
}

class _ExpectedMetricsModel {
  _ExpectedMetricsModel({
    required this.collect,
    required this.lastIgnoredMax,
  });

  final bool collect;
  final int lastIgnoredMax;
  final Map<String, int> counters = <String, int>{
    'processed': 0,
    'skipped': 0,
    'failures': 0,
    'catchupBatches': 0,
    'retriesScheduled': 0,
    'circuitOpens': 0,
    'dbApplied': 0,
    'dbIgnoredByVectorClock': 0,
    'conflictsCreated': 0,
    'dbMissingBase': 0,
    'dbEntryLinkNoop': 0,
    'staleAttachmentPurges': 0,
    'selfEventsSuppressed': 0,
    'signalClientStream': 0,
    'signalTimelineCallbacks': 0,
    'signalTimelineNewEvent': 0,
    'signalTimelineInsert': 0,
    'signalFirstStreamCatchupTriggers': 0,
    'signalCatchupDeferredCount': 0,
    'signalCatchupCoalesceCount': 0,
    'signalLiveScanDeferredInitialCatchupIncomplete': 0,
    'signalLiveScanDeferredCatchupInFlight': 0,
    'signalLiveScanDeferredInFlight': 0,
    'signalNoTimelineCount': 0,
    'wakeDetections': 0,
    'signalConnectivity': 0,
    'signalLatencyLastMs': 0,
    'signalLatencyMinMs': 0,
    'signalLatencyMaxMs': 0,
    'trailingCatchups': 0,
    'liveScanDeferredCount': 0,
    'liveScanCoalesceCount': 0,
    'liveScanTrailingScheduled': 0,
  };
  final Map<String, int> processedByType = <String, int>{};
  final Map<String, int> droppedByType = <String, int>{};
  final List<String> lastIgnored = <String>[];
  var _hasSignalLatency = false;

  void apply(_GeneratedMetricsOperation operation) {
    switch (operation.kind) {
      case _GeneratedMetricsOperationKind.incProcessedWithType:
        if (!collect) return;
        _bump('processed');
        _bumpType(processedByType, operation.syncRuntimeType);
      case _GeneratedMetricsOperationKind.bumpProcessedType:
        if (!collect) return;
        _bumpType(processedByType, operation.syncRuntimeType);
      case _GeneratedMetricsOperationKind.bumpDroppedType:
        if (!collect) return;
        _bumpType(droppedByType, operation.syncRuntimeType);
      case _GeneratedMetricsOperationKind.incSkipped:
        _bumpCollected('skipped');
      case _GeneratedMetricsOperationKind.incFailures:
        _bumpCollected('failures');
      case _GeneratedMetricsOperationKind.incCatchupBatches:
        _bumpCollected('catchupBatches');
      case _GeneratedMetricsOperationKind.incRetriesScheduled:
        _bumpCollected('retriesScheduled');
      case _GeneratedMetricsOperationKind.incCircuitOpens:
        _bumpCollected('circuitOpens');
      case _GeneratedMetricsOperationKind.incSignalClientStream:
        _bumpCollected('signalClientStream');
      case _GeneratedMetricsOperationKind.incSignalTimelineCallbacks:
        _bumpCollected('signalTimelineCallbacks');
      case _GeneratedMetricsOperationKind.incSignalTimelineNewEvent:
        _bumpCollected('signalTimelineNewEvent');
      case _GeneratedMetricsOperationKind.incSignalTimelineInsert:
        _bumpCollected('signalTimelineInsert');
      case _GeneratedMetricsOperationKind.incSignalFirstStreamCatchupTriggers:
        _bumpCollected('signalFirstStreamCatchupTriggers');
      case _GeneratedMetricsOperationKind.incSignalCatchupDeferred:
        _bumpCollected('signalCatchupDeferredCount');
      case _GeneratedMetricsOperationKind.incSignalCatchupCoalesce:
        _bumpCollected('signalCatchupCoalesceCount');
      case _GeneratedMetricsOperationKind
          .incSignalLiveScanDeferredInitialCatchupIncomplete:
        _bumpCollected('signalLiveScanDeferredInitialCatchupIncomplete');
      case _GeneratedMetricsOperationKind
          .incSignalLiveScanDeferredCatchupInFlight:
        _bumpCollected('signalLiveScanDeferredCatchupInFlight');
      case _GeneratedMetricsOperationKind.incSignalLiveScanDeferredInFlight:
        _bumpCollected('signalLiveScanDeferredInFlight');
      case _GeneratedMetricsOperationKind.incSignalNoTimeline:
        _bumpCollected('signalNoTimelineCount');
      case _GeneratedMetricsOperationKind.incWakeDetections:
        _bumpCollected('wakeDetections');
      case _GeneratedMetricsOperationKind.incSignalConnectivity:
        _bumpCollected('signalConnectivity');
      case _GeneratedMetricsOperationKind.recordSignalLatency:
        if (!collect) return;
        final latencyMs = operation.latencyMs;
        counters['signalLatencyLastMs'] = latencyMs;
        if (!_hasSignalLatency || latencyMs < counters['signalLatencyMinMs']!) {
          counters['signalLatencyMinMs'] = latencyMs;
        }
        if (!_hasSignalLatency || latencyMs > counters['signalLatencyMaxMs']!) {
          counters['signalLatencyMaxMs'] = latencyMs;
        }
        _hasSignalLatency = true;
      case _GeneratedMetricsOperationKind.incTrailingCatchups:
        _bumpCollected('trailingCatchups');
      case _GeneratedMetricsOperationKind.incLiveScanDeferred:
        _bumpCollected('liveScanDeferredCount');
      case _GeneratedMetricsOperationKind.incLiveScanCoalesce:
        _bumpCollected('liveScanCoalesceCount');
      case _GeneratedMetricsOperationKind.incLiveScanTrailingScheduled:
        _bumpCollected('liveScanTrailingScheduled');
      case _GeneratedMetricsOperationKind.incDbApplied:
        _bump('dbApplied');
      case _GeneratedMetricsOperationKind.incDbIgnoredByVectorClock:
        _bump('dbIgnoredByVectorClock');
      case _GeneratedMetricsOperationKind.incConflictsCreated:
        _bump('conflictsCreated');
      case _GeneratedMetricsOperationKind.incDbMissingBase:
        _bump('dbMissingBase');
      case _GeneratedMetricsOperationKind.incDbEntryLinkNoop:
        _bump('dbEntryLinkNoop');
      case _GeneratedMetricsOperationKind.incStaleAttachmentPurges:
        _bump('staleAttachmentPurges');
      case _GeneratedMetricsOperationKind.incSelfEventsSuppressed:
        _bump('selfEventsSuppressed');
      case _GeneratedMetricsOperationKind.addLastIgnored:
        lastIgnored.add(operation.ignoredEntry);
        if (lastIgnored.length > lastIgnoredMax) {
          lastIgnored.removeAt(0);
        }
    }
  }

  void _bumpCollected(String key) {
    if (collect) _bump(key);
  }

  void _bump(String key) {
    counters.update(key, (value) => value + 1);
  }

  void _bumpType(Map<String, int> target, String? runtimeType) {
    if (runtimeType == null || runtimeType.isEmpty) return;
    target.update(runtimeType, (value) => value + 1, ifAbsent: () => 1);
  }
}

extension _AnyGeneratedMetricsScenario on glados.Any {
  glados.Generator<_GeneratedMetricsOperationKind> get metricsOperationKind =>
      glados.AnyUtils(this).choose(_GeneratedMetricsOperationKind.values);

  glados.Generator<_GeneratedMetricsOperation> get metricsOperation =>
      glados.CombinableAny(this).combine2(
        metricsOperationKind,
        glados.IntAnys(this).intInRange(0, 9),
        (
          _GeneratedMetricsOperationKind kind,
          int valueSlot,
        ) => _GeneratedMetricsOperation(
          kind: kind,
          valueSlot: valueSlot,
        ),
      );

  glados.Generator<_GeneratedMetricsScenario> get metricsScenario =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(0, 2),
        glados.IntAnys(this).intInRange(0, 6),
        glados.ListAnys(this).listWithLengthInRange(1, 36, metricsOperation),
        (
          int collectSlot,
          int lastIgnoredMax,
          List<_GeneratedMetricsOperation> operations,
        ) => _GeneratedMetricsScenario(
          collect: collectSlot == 1,
          lastIgnoredMax: lastIgnoredMax,
          operations: operations,
        ),
      );
}

void main() {
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
        final model = _ExpectedMetricsModel(
          collect: scenario.collect,
          lastIgnoredMax: scenario.lastIgnoredMax,
        );

        for (final operation in scenario.operations) {
          switch (operation.kind) {
            case _GeneratedMetricsOperationKind.incProcessedWithType:
              counters.incProcessedWithType(operation.syncRuntimeType);
            case _GeneratedMetricsOperationKind.bumpProcessedType:
              counters.bumpProcessedType(operation.syncRuntimeType);
            case _GeneratedMetricsOperationKind.bumpDroppedType:
              counters.bumpDroppedType(operation.syncRuntimeType);
            case _GeneratedMetricsOperationKind.incSkipped:
              counters.incSkipped();
            case _GeneratedMetricsOperationKind.incFailures:
              counters.incFailures();
            case _GeneratedMetricsOperationKind.incCatchupBatches:
              counters.incCatchupBatches();
            case _GeneratedMetricsOperationKind.incRetriesScheduled:
              counters.incRetriesScheduled();
            case _GeneratedMetricsOperationKind.incCircuitOpens:
              counters.incCircuitOpens();
            case _GeneratedMetricsOperationKind.incSignalClientStream:
              counters.incSignalClientStream();
            case _GeneratedMetricsOperationKind.incSignalTimelineCallbacks:
              counters.incSignalTimelineCallbacks();
            case _GeneratedMetricsOperationKind.incSignalTimelineNewEvent:
              counters.incSignalTimelineNewEvent();
            case _GeneratedMetricsOperationKind.incSignalTimelineInsert:
              counters.incSignalTimelineInsert();
            case _GeneratedMetricsOperationKind
                .incSignalFirstStreamCatchupTriggers:
              counters.incSignalFirstStreamCatchupTriggers();
            case _GeneratedMetricsOperationKind.incSignalCatchupDeferred:
              counters.incSignalCatchupDeferred();
            case _GeneratedMetricsOperationKind.incSignalCatchupCoalesce:
              counters.incSignalCatchupCoalesce();
            case _GeneratedMetricsOperationKind
                .incSignalLiveScanDeferredInitialCatchupIncomplete:
              counters.incSignalLiveScanDeferredInitialCatchupIncomplete();
            case _GeneratedMetricsOperationKind
                .incSignalLiveScanDeferredCatchupInFlight:
              counters.incSignalLiveScanDeferredCatchupInFlight();
            case _GeneratedMetricsOperationKind
                .incSignalLiveScanDeferredInFlight:
              counters.incSignalLiveScanDeferredInFlight();
            case _GeneratedMetricsOperationKind.incSignalNoTimeline:
              counters.incSignalNoTimeline();
            case _GeneratedMetricsOperationKind.incWakeDetections:
              counters.incWakeDetections();
            case _GeneratedMetricsOperationKind.incSignalConnectivity:
              counters.incSignalConnectivity();
            case _GeneratedMetricsOperationKind.recordSignalLatency:
              counters.recordSignalLatencyMs(operation.latencyMs);
            case _GeneratedMetricsOperationKind.incTrailingCatchups:
              counters.incTrailingCatchups();
            case _GeneratedMetricsOperationKind.incLiveScanDeferred:
              counters.incLiveScanDeferred();
            case _GeneratedMetricsOperationKind.incLiveScanCoalesce:
              counters.incLiveScanCoalesce();
            case _GeneratedMetricsOperationKind.incLiveScanTrailingScheduled:
              counters.incLiveScanTrailingScheduled();
            case _GeneratedMetricsOperationKind.incDbApplied:
              counters.incDbApplied();
            case _GeneratedMetricsOperationKind.incDbIgnoredByVectorClock:
              counters.incDbIgnoredByVectorClock();
            case _GeneratedMetricsOperationKind.incConflictsCreated:
              counters.incConflictsCreated();
            case _GeneratedMetricsOperationKind.incDbMissingBase:
              counters.incDbMissingBase();
            case _GeneratedMetricsOperationKind.incDbEntryLinkNoop:
              counters.incDbEntryLinkNoop();
            case _GeneratedMetricsOperationKind.incStaleAttachmentPurges:
              counters.incStaleAttachmentPurges();
            case _GeneratedMetricsOperationKind.incSelfEventsSuppressed:
              counters.incSelfEventsSuppressed();
            case _GeneratedMetricsOperationKind.addLastIgnored:
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
    );
  });
}
