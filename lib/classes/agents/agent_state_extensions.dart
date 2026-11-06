part of 'agent_domain_entity.dart';

extension AgentStateReportFreshness on AgentStateEntity {
  /// Whether a relevant task change is not reflected in the latest successful
  /// report wake.
  bool get isReportStale {
    final staleAt = reportStaleAt;
    if (staleAt == null) return false;
    final freshAt = reportFreshAt;
    return freshAt == null || !staleAt.isBefore(freshAt);
  }

  /// Whether the latest report is behind the task as of [now]: either
  /// [isReportStale], or a change is already queued behind a throttle
  /// deadline ([nextWakeAt]) that has not yet fired.
  ///
  /// A queued change does not move [reportStaleAt] — the countdown is its
  /// only trace — yet the report is just as out of date while it runs.
  bool isReportBehindAt(DateTime now) =>
      isReportStale || (nextWakeAt?.isAfter(now) ?? false);
}

extension AgentStateWakeOutcome on AgentStateEntity {
  /// Whether the last wake that ended failed and nothing newer completed:
  /// `lastWakeFailedAt` is newer than `lastWakeAt`. Both are watermarks
  /// merged by latest instant, so every device answers this the same way
  /// once their writes have met (ADR 0115). False for a row no failed wake
  /// has stamped, including one written before the watermark existed.
  bool get lastWakeFailed {
    final failedAt = lastWakeFailedAt;
    if (failedAt == null) return false;
    final completedAt = lastWakeAt;
    return completedAt == null || failedAt.isAfter(completedAt);
  }

  /// [lastWakeFailed], read conservatively for a reader that only shortens
  /// a retry's deadline, where a stale answer is harmless: a row no failed
  /// wake has stamped since the watermark existed — written by the code
  /// before ADR 0115 (1.1.35), or by a device still running it — counts as
  /// failed while its failure count is above zero. Never a face: the count
  /// is last-writer-wins with the row, and one device's stale count must
  /// not show *failed* beside another's good briefing.
  bool get lastWakeMayHaveFailed =>
      lastWakeFailedAt == null ? consecutiveFailureCount > 0 : lastWakeFailed;
}

/// Reads the unmet-request flag: the agent's "I could not do what you asked"
/// that stands on the task card until the user clears it.
extension AgentStateUnmetRequest on AgentStateEntity {
  /// Whether the agent's latest unmet-request flag is still standing: it was
  /// raised after the user's last clear, or has never been cleared. Both
  /// stamps are watermarks merged by latest instant, so every device answers
  /// the same once their writes have met. A flag raised in the same instant
  /// as a clear counts as cleared.
  bool get hasOpenUnmetRequest {
    final raisedAt = slots.unmetRequestAt;
    if (raisedAt == null) return false;
    final clearedAt = slots.unmetRequestClearedAt;
    return clearedAt == null || raisedAt.isAfter(clearedAt);
  }
}
