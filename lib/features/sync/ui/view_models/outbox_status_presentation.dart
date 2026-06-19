import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:meta/meta.dart';

/// The plain-language status a single outbox row presents, decoupled from the
/// raw [OutboxStatus] index. The widget layer maps each value to a localized
/// label and a design-system tone; this stays pure so it can be unit-tested.
enum OutboxPresentationStatus { waiting, sending, failed, sent }

OutboxPresentationStatus presentationStatusOf(OutboxStatus status) =>
    switch (status) {
      OutboxStatus.pending => OutboxPresentationStatus.waiting,
      OutboxStatus.sending => OutboxPresentationStatus.sending,
      OutboxStatus.error => OutboxPresentationStatus.failed,
      OutboxStatus.sent => OutboxPresentationStatus.sent,
    };

/// Default automatic-retry cap (mirrors `SyncTuning.outboxMaxRetriesDiagnostics`).
const int kOutboxMaxRetries = 10;

/// Whether a failed row has exhausted its automatic retries, so only a manual
/// retry will move it again.
bool retryCapReached(int retries, {int maxRetries = kOutboxMaxRetries}) =>
    retries >= maxRetries;

/// The single, plain-language state of the whole outbox — drives the summary
/// header so the user sees "Everything's synced" / "Sending…" / "Couldn't
/// send" / "Not signed in" instead of having to read the raw queue.
enum QueueState { synced, waiting, sending, failed, offline }

@immutable
class QueueSummary {
  const QueueSummary({
    required this.state,
    required this.activeCount,
    required this.failedCount,
  });

  final QueueState state;

  /// Items still trying to leave the device (pending + sending).
  final int activeCount;

  /// Items that gave up after exhausting retries.
  final int failedCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueueSummary &&
          other.state == state &&
          other.activeCount == activeCount &&
          other.failedCount == failedCount;

  @override
  int get hashCode => Object.hash(state, activeCount, failedCount);

  @override
  String toString() =>
      'QueueSummary(${state.name}, active: $activeCount, failed: $failedCount)';
}

/// Collapses the queue counts into one user-facing [QueueSummary].
///
/// When sync is on but the device is not signed in, stranded work is framed as
/// [QueueState.offline] ("will send when you reconnect") rather than failure,
/// so an offline user is reassured instead of alarmed. The page supplies its
/// own banner for the sync-disabled case; this assumes a sync-enabled context.
///
/// Invariant: the state is [QueueState.synced] exactly when there is no work
/// (`pending + sending == 0 && failed == 0`), regardless of sign-in.
QueueSummary summarizeOutbox({
  required int pendingCount,
  required int sendingCount,
  required int failedCount,
  required bool syncEnabled,
  required bool signedIn,
}) {
  final active = pendingCount + sendingCount;
  final hasWork = active > 0 || failedCount > 0;

  final QueueState state;
  if (syncEnabled && !signedIn && hasWork) {
    state = QueueState.offline;
  } else if (failedCount > 0) {
    state = QueueState.failed;
  } else if (sendingCount > 0) {
    state = QueueState.sending;
  } else if (active > 0) {
    state = QueueState.waiting;
  } else {
    state = QueueState.synced;
  }

  return QueueSummary(
    state: state,
    activeCount: active,
    failedCount: failedCount,
  );
}
