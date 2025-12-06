/// Stats for backfill status per host.
class BackfillHostStats {
  const BackfillHostStats({
    required this.hostId,
    required this.receivedCount,
    required this.missingCount,
    required this.requestedCount,
    required this.backfilledCount,
    required this.deletedCount,
    required this.latestCounter,
    this.lastSeenAt,
  });

  final String hostId;
  final int receivedCount;
  final int missingCount;
  final int requestedCount;
  final int backfilledCount;
  final int deletedCount;
  final int latestCounter;
  final DateTime? lastSeenAt;

  int get totalCount =>
      receivedCount +
      missingCount +
      requestedCount +
      backfilledCount +
      deletedCount;

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
  });

  factory BackfillStats.fromHostStats(List<BackfillHostStats> stats) {
    return BackfillStats(
      hostStats: stats,
      totalReceived: stats.fold(0, (sum, s) => sum + s.receivedCount),
      totalMissing: stats.fold(0, (sum, s) => sum + s.missingCount),
      totalRequested: stats.fold(0, (sum, s) => sum + s.requestedCount),
      totalBackfilled: stats.fold(0, (sum, s) => sum + s.backfilledCount),
      totalDeleted: stats.fold(0, (sum, s) => sum + s.deletedCount),
    );
  }

  final List<BackfillHostStats> hostStats;
  final int totalReceived;
  final int totalMissing;
  final int totalRequested;
  final int totalBackfilled;
  final int totalDeleted;

  int get totalPending => totalMissing + totalRequested;
  int get totalEntries =>
      totalReceived +
      totalMissing +
      totalRequested +
      totalBackfilled +
      totalDeleted;
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

  // Historical windows
  static const int catchupPreContextCount = 80;
  static const int catchupMaxLookback =
      10000; // Increased from 1000 to handle larger backlogs
  static const int liveScanSteadyTail = 30;

  // Backfill tuning - self-healing sync for missing entries
  static const Duration backfillRequestInterval = Duration(minutes: 5);
  static const int backfillMaxRequestCount = 10;

  // Maximum entries to query and include per backfill request message
  static const int backfillBatchSize = 100;

  // Default limits for automatic backfill (prevents unbounded historical sync)
  // Only request entries from the last day OR 250 entries per host, whichever
  // is more restrictive. Deeper historical backfill requires manual trigger.
  static const Duration defaultBackfillMaxAge = Duration(days: 1);
  static const int defaultBackfillMaxEntriesPerHost = 250;

  // Backoff for retry requests - 12 hours minimum between retries
  // First request is immediate, then 12h wait before any retry.
  // This prevents hammering the network on slow/metered connections.
  static const Duration backfillMinRetryInterval = Duration(hours: 12);

  /// Calculate backoff duration based on request count.
  /// First request (requestCount=0) is immediate.
  /// All retries (requestCount>=1) wait 12 hours minimum.
  static Duration calculateBackoff(int requestCount) {
    if (requestCount <= 0) return Duration.zero;
    return backfillMinRetryInterval;
  }
}
