/// Typed snapshot of the sync pipeline's observability counters — DB-apply
/// outcomes, the dropped-by-type breakdown, connectivity nudges, and the
/// inbound-queue ledger. Round-trips through a flat `Map<String, int>` via
/// [SyncMetrics.fromMap]/[toMap] so it can be carried across the metrics
/// snapshot boundary and rendered in the Matrix Stats UI.
///
/// Every field here is fed by a real increment or a live query. The class used
/// to carry a second, larger set of throughput, retry, circuit-breaker and
/// signal-ingestion fields left over from the pre-queue stream-processing
/// architecture; nothing incremented them once the inbound queue became the
/// only receive path, so they rendered as permanent zeros. See the invariant
/// documented on `MetricsCounters` before adding a field back.
class SyncMetrics {
  const SyncMetrics({
    this.droppedByType = const <String, int>{},
    this.dbApplied = 0,
    this.dbIgnoredByVectorClock = 0,
    this.conflictsCreated = 0,
    this.dbMissingBase = 0,
    this.dbEntryLinkNoop = 0,
    this.signalConnectivity = 0,
    // Queue ledger (Phase 3). Populated by MatrixService when the
    // queue pipeline is active; zero otherwise.
    this.queueActive = 0,
    this.queueApplied = 0,
    this.queueAbandoned = 0,
    this.queueRetrying = 0,
  });

  factory SyncMetrics.fromMap(Map<String, dynamic> map) {
    final dropped = <String, int>{};
    for (final entry in map.entries) {
      final k = entry.key;
      if (k.startsWith('droppedByType.')) {
        dropped[k.substring('droppedByType.'.length)] =
            (entry.value ?? 0) as int;
      }
    }
    return SyncMetrics(
      dbApplied: (map['dbApplied'] ?? 0) as int,
      dbIgnoredByVectorClock: (map['dbIgnoredByVectorClock'] ?? 0) as int,
      conflictsCreated: (map['conflictsCreated'] ?? 0) as int,
      dbMissingBase: (map['dbMissingBase'] ?? 0) as int,
      dbEntryLinkNoop: (map['dbEntryLinkNoop'] ?? 0) as int,
      signalConnectivity: (map['signalConnectivity'] ?? 0) as int,
      queueActive: (map['queueActive'] ?? 0) as int,
      queueApplied: (map['queueApplied'] ?? 0) as int,
      queueAbandoned: (map['queueAbandoned'] ?? 0) as int,
      queueRetrying: (map['queueRetrying'] ?? 0) as int,
      droppedByType: dropped,
    );
  }

  /// Per-payload-type tally of events the pipeline dropped, keyed by the
  /// sync message's runtime type.
  final Map<String, int> droppedByType;

  final int dbApplied;
  final int dbIgnoredByVectorClock;
  final int conflictsCreated;
  final int dbMissingBase;
  final int dbEntryLinkNoop;

  /// Connectivity-driven nudges recorded when connectivity resumes.
  final int signalConnectivity;

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

  Map<String, int> toMap() => <String, int>{}
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
      MapEntry('signalConnectivity', signalConnectivity),
      MapEntry('queueActive', queueActive),
      MapEntry('queueApplied', queueApplied),
      MapEntry('queueAbandoned', queueAbandoned),
      MapEntry('queueRetrying', queueRetrying),
    ]);
}
