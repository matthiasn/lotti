/// Stats for backfill status per host.
class BackfillHostStats {
  const BackfillHostStats({
    required this.hostId,
    required this.receivedCount,
    required this.missingCount,
    required this.requestedCount,
    required this.backfilledCount,
    required this.deletedCount,
    required this.unresolvableCount,
    required this.burnedCount,
  });

  /// The host these counters belong to.
  final String hostId;
  final int receivedCount;
  final int missingCount;
  final int requestedCount;
  final int backfilledCount;
  final int deletedCount;
  final int unresolvableCount;

  /// Authoritative non-events (`SyncSequenceStatus.burned`): counters the
  /// originating host confirmed carry no payload. Benign — split out of
  /// [unresolvableCount] so diagnostics don't read voided counters as loss.
  final int burnedCount;

  /// Every counter of this host this device tracks, whatever its status.
  int get trackedCounters =>
      receivedCount +
      missingCount +
      requestedCount +
      backfilledCount +
      deletedCount +
      unresolvableCount +
      burnedCount;
}

/// Aggregate stats across all hosts.
class BackfillStats {
  const BackfillStats({
    required this.hostStats,
    required this.totalReceived,
    required this.totalMissing,
    required this.totalRequested,
    required this.totalBackfilled,
    required this.totalDeleted,
    required this.totalUnresolvable,
    required this.totalBurned,
  });

  factory BackfillStats.fromHostStats(List<BackfillHostStats> stats) {
    return BackfillStats(
      hostStats: stats,
      totalReceived: stats.fold(0, (sum, s) => sum + s.receivedCount),
      totalMissing: stats.fold(0, (sum, s) => sum + s.missingCount),
      totalRequested: stats.fold(0, (sum, s) => sum + s.requestedCount),
      totalBackfilled: stats.fold(0, (sum, s) => sum + s.backfilledCount),
      totalDeleted: stats.fold(0, (sum, s) => sum + s.deletedCount),
      totalUnresolvable: stats.fold(0, (sum, s) => sum + s.unresolvableCount),
      totalBurned: stats.fold(0, (sum, s) => sum + s.burnedCount),
    );
  }

  final List<BackfillHostStats> hostStats;
  final int totalReceived;
  final int totalMissing;
  final int totalRequested;
  final int totalBackfilled;
  final int totalDeleted;
  final int totalUnresolvable;
  final int totalBurned;

  /// Every `(host, counter)` pair this device tracks, whatever its status —
  /// not a record count: a record edited ten times has ten counters on the
  /// device that wrote it, and a device never gap-detects its own host, so
  /// two devices holding the same records track different numbers.
  int get trackedCounters =>
      totalReceived +
      totalMissing +
      totalRequested +
      totalBackfilled +
      totalDeleted +
      totalUnresolvable +
      totalBurned;
}
