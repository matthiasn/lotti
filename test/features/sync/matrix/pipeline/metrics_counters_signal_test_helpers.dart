import 'package:glados/glados.dart' as glados;

enum GeneratedMetricsOperationKind {
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

class GeneratedMetricsOperation {
  const GeneratedMetricsOperation({
    required this.kind,
    required this.valueSlot,
  });

  final GeneratedMetricsOperationKind kind;
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
    return 'GeneratedMetricsOperation('
        'kind: $kind, '
        'valueSlot: $valueSlot'
        ')';
  }
}

class GeneratedMetricsScenario {
  const GeneratedMetricsScenario({
    required this.collect,
    required this.lastIgnoredMax,
    required this.operations,
  });

  final bool collect;
  final int lastIgnoredMax;
  final List<GeneratedMetricsOperation> operations;

  @override
  String toString() {
    return 'GeneratedMetricsScenario('
        'collect: $collect, '
        'lastIgnoredMax: $lastIgnoredMax, '
        'operations: $operations'
        ')';
  }
}

class ExpectedMetricsModel {
  ExpectedMetricsModel({
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

  void apply(GeneratedMetricsOperation operation) {
    switch (operation.kind) {
      case GeneratedMetricsOperationKind.incProcessedWithType:
        if (!collect) return;
        hBump('processed');
        hBumpType(processedByType, operation.syncRuntimeType);
      case GeneratedMetricsOperationKind.bumpProcessedType:
        if (!collect) return;
        hBumpType(processedByType, operation.syncRuntimeType);
      case GeneratedMetricsOperationKind.bumpDroppedType:
        if (!collect) return;
        hBumpType(droppedByType, operation.syncRuntimeType);
      case GeneratedMetricsOperationKind.incSkipped:
        hBumpCollected('skipped');
      case GeneratedMetricsOperationKind.incFailures:
        hBumpCollected('failures');
      case GeneratedMetricsOperationKind.incCatchupBatches:
        hBumpCollected('catchupBatches');
      case GeneratedMetricsOperationKind.incRetriesScheduled:
        hBumpCollected('retriesScheduled');
      case GeneratedMetricsOperationKind.incCircuitOpens:
        hBumpCollected('circuitOpens');
      case GeneratedMetricsOperationKind.incSignalClientStream:
        hBumpCollected('signalClientStream');
      case GeneratedMetricsOperationKind.incSignalTimelineCallbacks:
        hBumpCollected('signalTimelineCallbacks');
      case GeneratedMetricsOperationKind.incSignalTimelineNewEvent:
        hBumpCollected('signalTimelineNewEvent');
      case GeneratedMetricsOperationKind.incSignalTimelineInsert:
        hBumpCollected('signalTimelineInsert');
      case GeneratedMetricsOperationKind.incSignalFirstStreamCatchupTriggers:
        hBumpCollected('signalFirstStreamCatchupTriggers');
      case GeneratedMetricsOperationKind.incSignalCatchupDeferred:
        hBumpCollected('signalCatchupDeferredCount');
      case GeneratedMetricsOperationKind.incSignalCatchupCoalesce:
        hBumpCollected('signalCatchupCoalesceCount');
      case GeneratedMetricsOperationKind
          .incSignalLiveScanDeferredInitialCatchupIncomplete:
        hBumpCollected('signalLiveScanDeferredInitialCatchupIncomplete');
      case GeneratedMetricsOperationKind
          .incSignalLiveScanDeferredCatchupInFlight:
        hBumpCollected('signalLiveScanDeferredCatchupInFlight');
      case GeneratedMetricsOperationKind.incSignalLiveScanDeferredInFlight:
        hBumpCollected('signalLiveScanDeferredInFlight');
      case GeneratedMetricsOperationKind.incSignalNoTimeline:
        hBumpCollected('signalNoTimelineCount');
      case GeneratedMetricsOperationKind.incWakeDetections:
        hBumpCollected('wakeDetections');
      case GeneratedMetricsOperationKind.incSignalConnectivity:
        hBumpCollected('signalConnectivity');
      case GeneratedMetricsOperationKind.recordSignalLatency:
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
      case GeneratedMetricsOperationKind.incTrailingCatchups:
        hBumpCollected('trailingCatchups');
      case GeneratedMetricsOperationKind.incLiveScanDeferred:
        hBumpCollected('liveScanDeferredCount');
      case GeneratedMetricsOperationKind.incLiveScanCoalesce:
        hBumpCollected('liveScanCoalesceCount');
      case GeneratedMetricsOperationKind.incLiveScanTrailingScheduled:
        hBumpCollected('liveScanTrailingScheduled');
      case GeneratedMetricsOperationKind.incDbApplied:
        hBump('dbApplied');
      case GeneratedMetricsOperationKind.incDbIgnoredByVectorClock:
        hBump('dbIgnoredByVectorClock');
      case GeneratedMetricsOperationKind.incConflictsCreated:
        hBump('conflictsCreated');
      case GeneratedMetricsOperationKind.incDbMissingBase:
        hBump('dbMissingBase');
      case GeneratedMetricsOperationKind.incDbEntryLinkNoop:
        hBump('dbEntryLinkNoop');
      case GeneratedMetricsOperationKind.incStaleAttachmentPurges:
        hBump('staleAttachmentPurges');
      case GeneratedMetricsOperationKind.incSelfEventsSuppressed:
        hBump('selfEventsSuppressed');
      case GeneratedMetricsOperationKind.addLastIgnored:
        lastIgnored.add(operation.ignoredEntry);
        if (lastIgnored.length > lastIgnoredMax) {
          lastIgnored.removeAt(0);
        }
    }
  }

  void hBumpCollected(String key) {
    if (collect) hBump(key);
  }

  void hBump(String key) {
    counters.update(key, (value) => value + 1);
  }

  void hBumpType(Map<String, int> target, String? runtimeType) {
    if (runtimeType == null || runtimeType.isEmpty) return;
    target.update(runtimeType, (value) => value + 1, ifAbsent: () => 1);
  }
}

extension AnyGeneratedMetricsScenario on glados.Any {
  glados.Generator<GeneratedMetricsOperationKind> get metricsOperationKind =>
      glados.AnyUtils(this).choose(GeneratedMetricsOperationKind.values);

  glados.Generator<GeneratedMetricsOperation> get metricsOperation =>
      glados.CombinableAny(this).combine2(
        metricsOperationKind,
        glados.IntAnys(this).intInRange(0, 9),
        (
          GeneratedMetricsOperationKind kind,
          int valueSlot,
        ) => GeneratedMetricsOperation(
          kind: kind,
          valueSlot: valueSlot,
        ),
      );

  glados.Generator<GeneratedMetricsScenario> get metricsScenario =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(0, 2),
        glados.IntAnys(this).intInRange(0, 6),
        glados.ListAnys(this).listWithLengthInRange(1, 36, metricsOperation),
        (
          int collectSlot,
          int lastIgnoredMax,
          List<GeneratedMetricsOperation> operations,
        ) => GeneratedMetricsScenario(
          collect: collectSlot == 1,
          lastIgnoredMax: lastIgnoredMax,
          operations: operations,
        ),
      );
}
