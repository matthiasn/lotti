class SyncMetrics {
  const SyncMetrics({
    required this.processed,
    required this.skipped,
    required this.failures,
    required this.flushes,
    required this.catchupBatches,
    required this.skippedByRetryLimit,
    required this.retriesScheduled,
    required this.circuitOpens,
    this.processedPerAppliedPct = 0,
    this.processedByType = const <String, int>{},
    this.droppedByType = const <String, int>{},
    this.dbApplied = 0,
    this.dbIgnoredByVectorClock = 0,
    this.conflictsCreated = 0,
    this.dbMissingBase = 0,
    this.dbEntryLinkNoop = 0,
    this.staleAttachmentPurges = 0,
    this.selfEventsSuppressed = 0,
    // Signal-driven ingestion observability
    this.signalClientStream = 0,
    this.signalTimelineCallbacks = 0,
    this.signalTimelineNewEvent = 0,
    this.signalTimelineInsert = 0,
    this.signalFirstStreamCatchupTriggers = 0,
    this.signalCatchupDeferredCount = 0,
    this.signalCatchupCoalesceCount = 0,
    this.signalLiveScanDeferredInitialCatchupIncomplete = 0,
    this.signalLiveScanDeferredCatchupInFlight = 0,
    this.signalLiveScanDeferredInFlight = 0,
    this.signalNoTimelineCount = 0,
    this.wakeDetections = 0,
    this.signalConnectivity = 0,
    this.signalLatencyLastMs = 0,
    this.signalLatencyMinMs = 0,
    this.signalLatencyMaxMs = 0,
    // Coalescing/trailing
    this.trailingCatchups = 0,
    this.liveScanDeferredCount = 0,
    this.liveScanCoalesceCount = 0,
    this.liveScanTrailingScheduled = 0,
    // Queue ledger (Phase 3). Populated by MatrixService when the
    // queue pipeline is active; zero otherwise.
    this.queueActive = 0,
    this.queueApplied = 0,
    this.queueAbandoned = 0,
    this.queueRetrying = 0,
  });

  factory SyncMetrics.fromMap(Map<String, dynamic> map) {
    final typed = <String, int>{};
    final dropped = <String, int>{};
    for (final entry in map.entries) {
      final k = entry.key;
      if (k.startsWith('processed.')) {
        typed[k.substring('processed.'.length)] = (entry.value ?? 0) as int;
      } else if (k.startsWith('droppedByType.')) {
        dropped[k.substring('droppedByType.'.length)] =
            (entry.value ?? 0) as int;
      }
    }
    return SyncMetrics(
      processed: (map['processed'] ?? 0) as int,
      skipped: (map['skipped'] ?? 0) as int,
      failures: (map['failures'] ?? 0) as int,
      flushes: (map['flushes'] ?? 0) as int,
      catchupBatches: (map['catchupBatches'] ?? 0) as int,
      skippedByRetryLimit: (map['skippedByRetryLimit'] ?? 0) as int,
      retriesScheduled: (map['retriesScheduled'] ?? 0) as int,
      circuitOpens: (map['circuitOpens'] ?? 0) as int,
      processedPerAppliedPct: (map['processedPerAppliedPct'] ?? 0) as int,
      dbApplied: (map['dbApplied'] ?? 0) as int,
      dbIgnoredByVectorClock: (map['dbIgnoredByVectorClock'] ?? 0) as int,
      conflictsCreated: (map['conflictsCreated'] ?? 0) as int,
      dbMissingBase: (map['dbMissingBase'] ?? 0) as int,
      dbEntryLinkNoop: (map['dbEntryLinkNoop'] ?? 0) as int,
      staleAttachmentPurges: (map['staleAttachmentPurges'] ?? 0) as int,
      selfEventsSuppressed: (map['selfEventsSuppressed'] ?? 0) as int,
      signalClientStream: (map['signalClientStream'] ?? 0) as int,
      signalTimelineCallbacks: (map['signalTimelineCallbacks'] ?? 0) as int,
      signalTimelineNewEvent: (map['signalTimelineNewEvent'] ?? 0) as int,
      signalTimelineInsert: (map['signalTimelineInsert'] ?? 0) as int,
      signalFirstStreamCatchupTriggers:
          (map['signalFirstStreamCatchupTriggers'] ?? 0) as int,
      signalCatchupDeferredCount:
          (map['signalCatchupDeferredCount'] ?? 0) as int,
      signalCatchupCoalesceCount:
          (map['signalCatchupCoalesceCount'] ?? 0) as int,
      signalLiveScanDeferredInitialCatchupIncomplete:
          (map['signalLiveScanDeferredInitialCatchupIncomplete'] ?? 0) as int,
      signalLiveScanDeferredCatchupInFlight:
          (map['signalLiveScanDeferredCatchupInFlight'] ?? 0) as int,
      signalLiveScanDeferredInFlight:
          (map['signalLiveScanDeferredInFlight'] ?? 0) as int,
      signalNoTimelineCount: (map['signalNoTimelineCount'] ?? 0) as int,
      wakeDetections: (map['wakeDetections'] ?? 0) as int,
      signalConnectivity: (map['signalConnectivity'] ?? 0) as int,
      signalLatencyLastMs: (map['signalLatencyLastMs'] ?? 0) as int,
      signalLatencyMinMs: (map['signalLatencyMinMs'] ?? 0) as int,
      signalLatencyMaxMs: (map['signalLatencyMaxMs'] ?? 0) as int,
      trailingCatchups: (map['trailingCatchups'] ?? 0) as int,
      liveScanDeferredCount: (map['liveScanDeferredCount'] ?? 0) as int,
      liveScanCoalesceCount: (map['liveScanCoalesceCount'] ?? 0) as int,
      liveScanTrailingScheduled: (map['liveScanTrailingScheduled'] ?? 0) as int,
      queueActive: (map['queueActive'] ?? 0) as int,
      queueApplied: (map['queueApplied'] ?? 0) as int,
      queueAbandoned: (map['queueAbandoned'] ?? 0) as int,
      queueRetrying: (map['queueRetrying'] ?? 0) as int,
      processedByType: typed,
      droppedByType: dropped,
    );
  }

  final int processed;
  final int skipped;
  final int failures;
  final int flushes;
  final int catchupBatches;
  final int skippedByRetryLimit;
  final int retriesScheduled;
  final int circuitOpens;
  final int processedPerAppliedPct;
  final Map<String, int> processedByType;
  final Map<String, int> droppedByType;
  final int dbApplied;
  final int dbIgnoredByVectorClock;
  final int conflictsCreated;
  final int dbMissingBase;
  final int dbEntryLinkNoop;
  final int staleAttachmentPurges;
  final int selfEventsSuppressed;
  // Signal-driven ingestion observability
  final int signalClientStream;
  final int signalTimelineCallbacks;
  final int signalTimelineNewEvent;
  final int signalTimelineInsert;
  final int signalFirstStreamCatchupTriggers;
  final int signalCatchupDeferredCount;
  final int signalCatchupCoalesceCount;
  final int signalLiveScanDeferredInitialCatchupIncomplete;
  final int signalLiveScanDeferredCatchupInFlight;
  final int signalLiveScanDeferredInFlight;
  final int signalNoTimelineCount;
  final int wakeDetections;
  final int signalConnectivity;
  final int signalLatencyLastMs;
  final int signalLatencyMinMs;
  final int signalLatencyMaxMs;
  // Coalescing/trailing
  final int trailingCatchups;
  final int liveScanDeferredCount;
  final int liveScanCoalesceCount;
  final int liveScanTrailingScheduled;

  /// Count of rows still waiting in the queue (enqueued + leased +
  /// retrying). Zero when the queue pipeline is disabled.
  final int queueActive;

  /// Count of `applied` ledger rows — successful commits that the
  /// queue has retained for traceability.
  final int queueApplied;

  /// Count of `abandoned` ledger rows — events the worker gave up
  /// on. A non-zero number here is the signal to surface the
  /// "Skipped events" UI.
  final int queueAbandoned;

  /// Count of currently `retrying` rows (subset of `queueActive`).
  final int queueRetrying;

  Map<String, int> toMap() =>
      <String, int>{
          'processed': processed,
          'skipped': skipped,
          'failures': failures,
          'flushes': flushes,
          'catchupBatches': catchupBatches,
          'skippedByRetryLimit': skippedByRetryLimit,
          'retriesScheduled': retriesScheduled,
          'circuitOpens': circuitOpens,
          'processedPerAppliedPct': processedPerAppliedPct,
        }
        ..addEntries(
          processedByType.entries.map(
            (e) => MapEntry('processed.${e.key}', e.value),
          ),
        )
        ..addEntries(
          droppedByType.entries.map(
            (e) => MapEntry('droppedByType.${e.key}', e.value),
          ),
        )
        ..addEntries(<MapEntry<String, int>>[
          MapEntry('dbApplied', dbApplied),
          MapEntry('dbIgnoredByVectorClock', dbIgnoredByVectorClock),
          MapEntry('conflictsCreated', conflictsCreated),
          MapEntry('dbMissingBase', dbMissingBase),
          MapEntry('dbEntryLinkNoop', dbEntryLinkNoop),
          MapEntry('staleAttachmentPurges', staleAttachmentPurges),
          MapEntry('selfEventsSuppressed', selfEventsSuppressed),
          // Signals
          MapEntry('signalClientStream', signalClientStream),
          MapEntry('signalTimelineCallbacks', signalTimelineCallbacks),
          MapEntry('signalTimelineNewEvent', signalTimelineNewEvent),
          MapEntry('signalTimelineInsert', signalTimelineInsert),
          MapEntry(
            'signalFirstStreamCatchupTriggers',
            signalFirstStreamCatchupTriggers,
          ),
          MapEntry('signalCatchupDeferredCount', signalCatchupDeferredCount),
          MapEntry('signalCatchupCoalesceCount', signalCatchupCoalesceCount),
          MapEntry(
            'signalLiveScanDeferredInitialCatchupIncomplete',
            signalLiveScanDeferredInitialCatchupIncomplete,
          ),
          MapEntry(
            'signalLiveScanDeferredCatchupInFlight',
            signalLiveScanDeferredCatchupInFlight,
          ),
          MapEntry(
            'signalLiveScanDeferredInFlight',
            signalLiveScanDeferredInFlight,
          ),
          MapEntry('signalNoTimelineCount', signalNoTimelineCount),
          MapEntry('wakeDetections', wakeDetections),
          MapEntry('signalConnectivity', signalConnectivity),
          MapEntry('signalLatencyLastMs', signalLatencyLastMs),
          MapEntry('signalLatencyMinMs', signalLatencyMinMs),
          MapEntry('signalLatencyMaxMs', signalLatencyMaxMs),
          MapEntry('trailingCatchups', trailingCatchups),
          MapEntry('liveScanDeferredCount', liveScanDeferredCount),
          MapEntry('liveScanCoalesceCount', liveScanCoalesceCount),
          MapEntry('liveScanTrailingScheduled', liveScanTrailingScheduled),
          MapEntry('queueActive', queueActive),
          MapEntry('queueApplied', queueApplied),
          MapEntry('queueAbandoned', queueAbandoned),
          MapEntry('queueRetrying', queueRetrying),
        ]);
}
