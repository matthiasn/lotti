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

  // Live-scan / Catch-up coalescing
  static const Duration minLiveScanGap = Duration(seconds: 1);
  static const Duration trailingLiveScanDebounce = Duration(milliseconds: 120);
  static const Duration minCatchupGap = Duration(seconds: 1);
  static const Duration trailingCatchupDelay = Duration(seconds: 1);

  // Historical windows
  static const int catchupPreContextCount = 80;
  static const int catchupMaxLookback = 1000;
  static const int liveScanSteadyTail = 30;
}
