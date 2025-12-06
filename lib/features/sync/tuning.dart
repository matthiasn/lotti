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
  static const int backfillBatchSize = 20;
  static const int backfillMaxRequestCount = 10;

  // Exponential backoff for retry requests
  // Backoff = min(baseBackoff * 2^(requestCount-1), maxBackoff)
  // e.g., 5min, 10min, 20min, 40min, 80min, 120min (capped)
  static const Duration backfillBaseBackoff = Duration(minutes: 5);
  static const Duration backfillMaxBackoff = Duration(hours: 2);

  // Maximum entries per batched backfill request message
  static const int backfillMessageBatchSize = 100;

  /// Calculate backoff duration based on request count using exponential backoff.
  /// Returns the minimum wait time before the next retry.
  static Duration calculateBackoff(int requestCount) {
    if (requestCount <= 0) return Duration.zero;

    // 2^(requestCount-1) multiplier, capped at maxBackoff
    final multiplier = 1 << (requestCount - 1).clamp(0, 10);
    final backoff = backfillBaseBackoff * multiplier;

    return backoff > backfillMaxBackoff ? backfillMaxBackoff : backoff;
  }
}
