class SyncMetrics {
  const SyncMetrics({
    required this.processed,
    required this.skipped,
    required this.failures,
    required this.prefetch,
    required this.flushes,
    required this.catchupBatches,
    required this.skippedByRetryLimit,
    required this.retriesScheduled,
    required this.circuitOpens,
    this.processedByType = const <String, int>{},
    this.droppedByType = const <String, int>{},
    this.dbApplied = 0,
    this.dbIgnoredByVectorClock = 0,
    this.conflictsCreated = 0,
    this.staleAttachmentPurges = 0,
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
      prefetch: (map['prefetch'] ?? 0) as int,
      flushes: (map['flushes'] ?? 0) as int,
      catchupBatches: (map['catchupBatches'] ?? 0) as int,
      skippedByRetryLimit: (map['skippedByRetryLimit'] ?? 0) as int,
      retriesScheduled: (map['retriesScheduled'] ?? 0) as int,
      circuitOpens: (map['circuitOpens'] ?? 0) as int,
      dbApplied: (map['dbApplied'] ?? 0) as int,
      dbIgnoredByVectorClock: (map['dbIgnoredByVectorClock'] ?? 0) as int,
      conflictsCreated: (map['conflictsCreated'] ?? 0) as int,
      staleAttachmentPurges: (map['staleAttachmentPurges'] ?? 0) as int,
      processedByType: typed,
      droppedByType: dropped,
    );
  }

  final int processed;
  final int skipped;
  final int failures;
  final int prefetch;
  final int flushes;
  final int catchupBatches;
  final int skippedByRetryLimit;
  final int retriesScheduled;
  final int circuitOpens;
  final Map<String, int> processedByType;
  final Map<String, int> droppedByType;
  final int dbApplied;
  final int dbIgnoredByVectorClock;
  final int conflictsCreated;
  final int staleAttachmentPurges;

  Map<String, int> toMap() => <String, int>{
        'processed': processed,
        'skipped': skipped,
        'failures': failures,
        'prefetch': prefetch,
        'flushes': flushes,
        'catchupBatches': catchupBatches,
        'skippedByRetryLimit': skippedByRetryLimit,
        'retriesScheduled': retriesScheduled,
        'circuitOpens': circuitOpens,
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
          MapEntry('staleAttachmentPurges', staleAttachmentPurges),
        ]);
}
