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
    this.lookBehindMerges = 0,
    this.lastLookBehindTail = 0,
    this.processedByType = const <String, int>{},
    this.droppedByType = const <String, int>{},
    this.dbApplied = 0,
    this.dbIgnoredByVectorClock = 0,
    this.conflictsCreated = 0,
    this.dbMissingBase = 0,
    this.dbEntryLinkNoop = 0,
    this.staleAttachmentPurges = 0,
    // Signal-driven ingestion observability
    this.signalClientStream = 0,
    this.signalTimelineCallbacks = 0,
    this.signalConnectivity = 0,
    this.signalLatencyLastMs = 0,
    this.signalLatencyMinMs = 0,
    this.signalLatencyMaxMs = 0,
    // Coalescing/trailing
    this.trailingCatchups = 0,
    this.liveScanDeferredCount = 0,
    this.liveScanCoalesceCount = 0,
    this.liveScanTrailingScheduled = 0,
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
      lookBehindMerges: (map['lookBehindMerges'] ?? 0) as int,
      lastLookBehindTail: (map['lastLookBehindTail'] ?? 0) as int,
      dbApplied: (map['dbApplied'] ?? 0) as int,
      dbIgnoredByVectorClock: (map['dbIgnoredByVectorClock'] ?? 0) as int,
      conflictsCreated: (map['conflictsCreated'] ?? 0) as int,
      dbMissingBase: (map['dbMissingBase'] ?? 0) as int,
      dbEntryLinkNoop: (map['dbEntryLinkNoop'] ?? 0) as int,
      staleAttachmentPurges: (map['staleAttachmentPurges'] ?? 0) as int,
      signalClientStream: (map['signalClientStream'] ?? 0) as int,
      signalTimelineCallbacks: (map['signalTimelineCallbacks'] ?? 0) as int,
      signalConnectivity: (map['signalConnectivity'] ?? 0) as int,
      signalLatencyLastMs: (map['signalLatencyLastMs'] ?? 0) as int,
      signalLatencyMinMs: (map['signalLatencyMinMs'] ?? 0) as int,
      signalLatencyMaxMs: (map['signalLatencyMaxMs'] ?? 0) as int,
      trailingCatchups: (map['trailingCatchups'] ?? 0) as int,
      liveScanDeferredCount: (map['liveScanDeferredCount'] ?? 0) as int,
      liveScanCoalesceCount: (map['liveScanCoalesceCount'] ?? 0) as int,
      liveScanTrailingScheduled: (map['liveScanTrailingScheduled'] ?? 0) as int,
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
  final int lookBehindMerges;
  final int lastLookBehindTail;
  final Map<String, int> processedByType;
  final Map<String, int> droppedByType;
  final int dbApplied;
  final int dbIgnoredByVectorClock;
  final int conflictsCreated;
  final int dbMissingBase;
  final int dbEntryLinkNoop;
  final int staleAttachmentPurges;
  // Signal-driven ingestion observability
  final int signalClientStream;
  final int signalTimelineCallbacks;
  final int signalConnectivity;
  final int signalLatencyLastMs;
  final int signalLatencyMinMs;
  final int signalLatencyMaxMs;
  // Coalescing/trailing
  final int trailingCatchups;
  final int liveScanDeferredCount;
  final int liveScanCoalesceCount;
  final int liveScanTrailingScheduled;

  Map<String, int> toMap() => <String, int>{
        'processed': processed,
        'skipped': skipped,
        'failures': failures,
        'flushes': flushes,
        'catchupBatches': catchupBatches,
        'skippedByRetryLimit': skippedByRetryLimit,
        'retriesScheduled': retriesScheduled,
        'circuitOpens': circuitOpens,
        'lookBehindMerges': lookBehindMerges,
        'lastLookBehindTail': lastLookBehindTail,
      }
        ..addEntries(processedByType.entries.map(
          (e) => MapEntry('processed.${e.key}', e.value),
        ))
        ..addEntries(droppedByType.entries.map(
          (e) => MapEntry('droppedByType.${e.key}', e.value),
        ))
        ..addEntries(<MapEntry<String, int>>[
          MapEntry('dbApplied', dbApplied),
          MapEntry('dbIgnoredByVectorClock', dbIgnoredByVectorClock),
          MapEntry('conflictsCreated', conflictsCreated),
          MapEntry('dbMissingBase', dbMissingBase),
          MapEntry('dbEntryLinkNoop', dbEntryLinkNoop),
          MapEntry('staleAttachmentPurges', staleAttachmentPurges),
          // Signals
          MapEntry('signalClientStream', signalClientStream),
          MapEntry('signalTimelineCallbacks', signalTimelineCallbacks),
          MapEntry('signalConnectivity', signalConnectivity),
          MapEntry('signalLatencyLastMs', signalLatencyLastMs),
          MapEntry('signalLatencyMinMs', signalLatencyMinMs),
          MapEntry('signalLatencyMaxMs', signalLatencyMaxMs),
          MapEntry('trailingCatchups', trailingCatchups),
          MapEntry('liveScanDeferredCount', liveScanDeferredCount),
          MapEntry('liveScanCoalesceCount', liveScanCoalesceCount),
          MapEntry('liveScanTrailingScheduled', liveScanTrailingScheduled),
        ]);
}
