import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_helpers.dart'
    as msh;
import 'package:lotti/features/sync/matrix/pipeline/metrics_utils.dart';

/// Mutable counters used for lightweight in-memory metrics. When `collect` is
/// false, most counters are no-ops to avoid overhead outside diagnostics runs.
class MetricsCounters {
  MetricsCounters({
    this.collect = false,
    this.lastIgnoredMax = 10,
  });

  final bool collect;
  final int lastIgnoredMax;

  int processed = 0;
  int skipped = 0;
  int failures = 0;
  int flushes = 0;
  int catchupBatches = 0;
  int skippedByRetryLimit = 0;
  int retriesScheduled = 0;
  int circuitOpens = 0;

  int dbApplied = 0;
  int dbIgnoredByVectorClock = 0;
  int conflictsCreated = 0;
  int dbMissingBase = 0;
  int dbEntryLinkNoop = 0;
  int staleAttachmentPurges = 0;
  int selfEventsSuppressed = 0;

  // Signal-driven ingestion observability
  /// Number of signals received from the client stream listener for the active
  /// room (after filtering).
  int signalClientStream = 0;

  /// Number of signals received from live timeline callbacks (onNewEvent,
  /// onInsert, onChange, onRemove, onUpdate).
  int signalTimelineCallbacks = 0;

  /// Number of connectivity-driven nudges recorded by MatrixService when
  /// connectivity resumes.
  int signalConnectivity = 0;

  /// Signal→scan latency in milliseconds (last/min/max) recorded at the start
  /// of `_scanLiveTimeline()` if a prior signal timestamp was captured.
  int signalLatencyLastMs = 0;
  int signalLatencyMinMs = 0;
  int signalLatencyMaxMs = 0;

  // Coalescing/trailing metrics
  int trailingCatchups = 0;
  int liveScanDeferredCount = 0;
  int liveScanCoalesceCount = 0;
  int liveScanTrailingScheduled = 0;

  final Map<String, int> processedByType = <String, int>{};
  final Map<String, int> droppedByType = <String, int>{};

  final List<String> lastIgnored = <String>[];

  void incProcessedWithType(String? rt) {
    if (!collect) return;
    processed++;
    bumpProcessedType(rt);
  }

  void bumpProcessedType(String? rt) {
    if (!collect) return;
    if (rt == null || rt.isEmpty) return;
    processedByType.update(rt, (v) => v + 1, ifAbsent: () => 1);
  }

  void bumpDroppedType(String? rt) {
    if (!collect) return;
    if (rt == null || rt.isEmpty) return;
    droppedByType.update(rt, (v) => v + 1, ifAbsent: () => 1);
  }

  void incSkipped() {
    if (!collect) return;
    skipped++;
  }

  void incFailures() {
    if (!collect) return;
    failures++;
  }

  void incCatchupBatches() {
    if (!collect) return;
    catchupBatches++;
  }

  void incRetriesScheduled() {
    if (!collect) return;
    retriesScheduled++;
  }

  void incCircuitOpens() {
    if (!collect) return;
    circuitOpens++;
  }

  void incSignalClientStream() {
    if (!collect) return;
    signalClientStream++;
  }

  void incSignalTimelineCallbacks() {
    if (!collect) return;
    signalTimelineCallbacks++;
  }

  void incSignalConnectivity() {
    if (!collect) return;
    signalConnectivity++;
  }

  /// Records the end-to-end latency from signal scheduling to scan start.
  void recordSignalLatencyMs(int ms) {
    if (!collect) return;
    signalLatencyLastMs = ms;
    if (signalLatencyMinMs == 0 || ms < signalLatencyMinMs) {
      signalLatencyMinMs = ms;
    }
    if (ms > signalLatencyMaxMs) {
      signalLatencyMaxMs = ms;
    }
  }

  void incTrailingCatchups() {
    if (!collect) return;
    trailingCatchups++;
  }

  void incLiveScanDeferred() {
    if (!collect) return;
    liveScanDeferredCount++;
  }

  void incLiveScanCoalesce() {
    if (!collect) return;
    liveScanCoalesceCount++;
  }

  void incLiveScanTrailingScheduled() {
    if (!collect) return;
    liveScanTrailingScheduled++;
  }

  // DB metrics are tracked regardless of collect
  void incDbApplied() => dbApplied++;
  void incDbIgnoredByVectorClock() => dbIgnoredByVectorClock++;
  void incConflictsCreated() => conflictsCreated++;
  void incDbMissingBase() => dbMissingBase++;
  void incDbEntryLinkNoop() => dbEntryLinkNoop++;
  void incStaleAttachmentPurges() => staleAttachmentPurges++;
  void incSelfEventsSuppressed() => selfEventsSuppressed++;

  void addLastIgnored(String entry) {
    msh.ringBufferAdd(lastIgnored, entry, lastIgnoredMax);
  }

  Map<String, int> snapshot({
    required int retryStateSize,
    required bool circuitIsOpen,
  }) {
    final base = MetricsUtils.buildSnapshot(
      processed: processed,
      skipped: skipped,
      failures: failures,
      flushes: flushes,
      catchupBatches: catchupBatches,
      skippedByRetryLimit: skippedByRetryLimit,
      retriesScheduled: retriesScheduled,
      circuitOpens: circuitOpens,
      processedByType: processedByType,
      droppedByType: droppedByType,
      dbApplied: dbApplied,
      dbIgnoredByVectorClock: dbIgnoredByVectorClock,
      conflictsCreated: conflictsCreated,
      lastIgnored: lastIgnored,
      retryStateSize: retryStateSize,
      circuitOpen: circuitIsOpen,
    )
      ..putIfAbsent('dbMissingBase', () => dbMissingBase)
      ..putIfAbsent('dbEntryLinkNoop', () => dbEntryLinkNoop)
      ..putIfAbsent('staleAttachmentPurges', () => staleAttachmentPurges)
      ..putIfAbsent('selfEventsSuppressed', () => selfEventsSuppressed)
      // Signal ingestion metrics
      ..putIfAbsent('signalClientStream', () => signalClientStream)
      ..putIfAbsent('signalTimelineCallbacks', () => signalTimelineCallbacks)
      ..putIfAbsent('signalConnectivity', () => signalConnectivity)
      ..putIfAbsent('signalLatencyLastMs', () => signalLatencyLastMs)
      ..putIfAbsent('signalLatencyMinMs', () => signalLatencyMinMs)
      ..putIfAbsent('signalLatencyMaxMs', () => signalLatencyMaxMs)
      // Coalescing/trailing
      ..putIfAbsent('trailingCatchups', () => trailingCatchups)
      ..putIfAbsent('liveScanDeferredCount', () => liveScanDeferredCount)
      ..putIfAbsent('liveScanCoalesceCount', () => liveScanCoalesceCount)
      ..putIfAbsent(
          'liveScanTrailingScheduled', () => liveScanTrailingScheduled);
    return base;
  }
}
