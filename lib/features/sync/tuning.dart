/// Stats for backfill status per host.
class BackfillHostStats {
  const BackfillHostStats({
    required this.receivedCount,
    required this.missingCount,
    required this.requestedCount,
    required this.backfilledCount,
    required this.deletedCount,
    required this.unresolvableCount,
    this.lastSeenAt,
  });

  final int receivedCount;
  final int missingCount;
  final int requestedCount;
  final int backfilledCount;
  final int deletedCount;
  final int unresolvableCount;
  final DateTime? lastSeenAt;

  int get totalCount =>
      receivedCount +
      missingCount +
      requestedCount +
      backfilledCount +
      deletedCount +
      unresolvableCount;

  int get pendingCount => missingCount + requestedCount;
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
    );
  }

  final List<BackfillHostStats> hostStats;
  final int totalReceived;
  final int totalMissing;
  final int totalRequested;
  final int totalBackfilled;
  final int totalDeleted;
  final int totalUnresolvable;

  int get totalPending => totalMissing + totalRequested;
  int get totalEntries =>
      totalReceived +
      totalMissing +
      totalRequested +
      totalBackfilled +
      totalDeleted +
      totalUnresolvable;
}

/// Sync and Outbox tuning constants, centralized for easy documentation and
/// future adjustments. Values are chosen to balance responsiveness and UI
/// smoothness while preventing redundant work under bursty conditions.
class SyncTuning {
  // Outbox
  static const Duration outboxRetryDelay = Duration(seconds: 5);
  static const Duration outboxErrorDelay = Duration(seconds: 15);
  static const int outboxMaxRetriesDiagnostics = 10; // surface issues w/o loops
  static const Duration outboxSendTimeout = Duration(seconds: 20); // Matrix RTT
  static const Duration outboxWatchdogInterval = Duration(seconds: 10);
  static const Duration outboxDbNudgeDebounce = Duration(milliseconds: 50);
  static const Duration outboxIdleThreshold = Duration(seconds: 3);

  // Live-scan / Catch-up coalescing
  static const Duration minLiveScanGap = Duration(seconds: 1);
  static const Duration trailingLiveScanDebounce = Duration(milliseconds: 120);
  static const Duration minCatchupGap = Duration(seconds: 1);
  static const Duration trailingCatchupDelay = Duration(seconds: 1);

  // Sync wait timeout for catch-up.
  // Time to wait for Matrix SDK to sync with server before running catch-up.
  // Applies to all catch-up scenarios: initial startup, app resume, wake, reconnect.
  // 30s allows for slow networks; if timeout occurs, a follow-up catch-up triggers
  // when sync eventually completes.
  static const Duration catchupSyncWaitTimeout = Duration(seconds: 30);

  // Historical windows
  static const int catchupPreContextCount = 80;
  static const int catchupMaxLookback =
      10000; // Increased from 1000 to handle larger backlogs

  // Backfill tuning - self-healing sync for missing entries
  static const Duration backfillRequestInterval = Duration(minutes: 5);
  static const int backfillMaxRequestCount = 10;

  // Maximum gap size for gap detection - prevents explosion of missing entries
  // when sequence log is corrupted or entries are deleted.
  // Gaps larger than this are logged but only the most recent N entries are created.
  static const int maxGapSize = 100;

  // Maximum entries to process from an incoming backfill request.
  // Prevents a single large request from flooding the outbox.
  static const int maxBackfillResponseBatchSize = 50;

  // Maximum entries to process per processing cycle
  static const int backfillProcessingBatchSize = 50;

  // Default limits for automatic backfill (prevents unbounded historical sync)
  // Only request entries from the last day OR 250 entries per host, whichever
  // is more restrictive. Deeper historical backfill requires manual trigger.
  static const Duration defaultBackfillMaxAge = Duration(days: 1);
  static const int defaultBackfillMaxEntriesPerHost = 250;

  // Exponential backoff for retry requests
  // Base interval that doubles with each attempt, capped at max interval.
  // First request (requestCount=0) is immediate.
  static const Duration backfillBackoffBase = Duration(minutes: 5);
  static const Duration backfillBackoffMax = Duration(hours: 2);
}
