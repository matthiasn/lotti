import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';

/// Pure scheduling helpers for the outbox send pipeline: row-level priority
/// classification and the backoff-gate / enqueue-delay arithmetic.
///
/// These are deliberately free of any `OutboxService` state — every input is
/// passed explicitly — so they can be reasoned about and tested in isolation
/// from the runner's timers, subscriptions, and database.

/// Row-level dispatch priority (`OutboxPriority.index`) for [message].
///
/// Journal entities and their links jump ahead of everything else; entity
/// definitions, AI config, and node-profile presence sit at the back so they
/// never queue-jump user writes; the rest is normal priority.
///
/// [SyncOutboxBundle] is never enqueued in production — the enqueue dispatch
/// switch rejects it first — but it maps to a benign normal priority so the
/// lookup stays total and side-effect-free for any future caller.
int priorityForMessage(SyncMessage message) {
  return switch (message) {
    SyncJournalEntity() => OutboxPriority.high.index,
    SyncEntryLink() => OutboxPriority.high.index,
    SyncBackfillRequest() => OutboxPriority.normal.index,
    SyncBackfillResponse() => OutboxPriority.normal.index,
    SyncAgentEntity() => OutboxPriority.normal.index,
    SyncAgentLink() => OutboxPriority.normal.index,
    SyncNotification() => OutboxPriority.normal.index,
    SyncNotificationStateUpdate() => OutboxPriority.normal.index,
    SyncAgentBundle() => OutboxPriority.normal.index,
    SyncThemingSelection() => OutboxPriority.normal.index,
    SyncEntityDefinition() => OutboxPriority.low.index,
    SyncAiConfig() => OutboxPriority.low.index,
    SyncAiConfigDelete() => OutboxPriority.low.index,
    SyncConfigFlag() => OutboxPriority.normal.index,
    SyncOutboxBundle() => OutboxPriority.normal.index,
    SyncSyncNodeProfile() => OutboxPriority.low.index,
  };
}

/// The effective enqueue delay given a [requested] delay, the current backoff
/// gate [nextAllowedAt], and the current time [now].
///
/// Negative requests clamp to zero. When the backoff gate is in the future the
/// delay is stretched to land no earlier than the gate; otherwise the
/// (clamped) request stands.
Duration resolveEnqueueDelay({
  required Duration requested,
  required DateTime? nextAllowedAt,
  required DateTime now,
}) {
  final adjusted = requested < Duration.zero ? Duration.zero : requested;
  if (nextAllowedAt == null || !nextAllowedAt.isAfter(now)) return adjusted;
  final backoffDelay = nextAllowedAt.difference(now);
  return backoffDelay > adjusted ? backoffDelay : adjusted;
}

/// The backoff gate after requesting [delay] from [now], given the [current]
/// gate.
///
/// Monotonic: the gate never moves earlier. A non-positive [delay] leaves the
/// gate unchanged; otherwise the gate advances to `now + delay` only when that
/// is later than the existing gate.
DateTime? extendBackoffGate({
  required Duration delay,
  required DateTime? current,
  required DateTime now,
}) {
  if (delay <= Duration.zero) return current;
  final candidate = now.add(delay);
  if (current == null || candidate.isAfter(current)) return candidate;
  return current;
}
