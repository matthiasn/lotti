/// What the UI isolate asks of the inbound pipeline's producer side — the
/// catch-up bridge and the queue's resurrections — without holding the
/// coordinator that runs it (ADR 0142).
///
/// In-process the control is `QueuePipelineCoordinator` itself; with
/// `use_isolate_sync` on it is answered by the sync isolate through the
/// `SyncService` proxy. The backfill request service and the backfill
/// settings page are its callers.
abstract interface class SyncQueueControl {
  /// Forces a catch-up bridge pass, as a `limited=true` sync would.
  Future<void> triggerBridge();

  /// Starts the barren-bridge gap recovery when one is recorded; a no-op
  /// otherwise.
  void maybeStartGapRecovery();

  /// True while a bridge walk is in flight: gaps seen now may still close.
  bool get isBridgeInFlight;

  /// Fires once per finished bridge walk.
  void Function()? get onBridgeCompleted;
  set onBridgeCompleted(void Function()? callback);

  /// Re-arms every abandoned queue row, the user's "retry skipped". Returns
  /// how many rows it woke.
  Future<int> retrySkipped();
}
