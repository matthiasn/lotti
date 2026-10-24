import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';

/// Outcome the apply step reports for one queue entry.
enum ApplyOutcome {
  applied,
  retriable,
  missingBase,
  decryptionPending,

  /// An ordered protocol barrier is waiting for older active queue rows.
  pendingBarrier,

  /// The entry's attachment JSON (descriptor or agent-entity payload)
  /// has not arrived on disk yet. Distinct from [retriable] because
  /// attachment deliveries can lag the sync event by many seconds /
  /// minutes, and capping retries at the generic attempt cap here can
  /// abandon a row before the descriptor had a reasonable chance to arrive.
  /// Retried with a longer ladder and a hard wall-clock deadline; the queue
  /// also wakes these rows immediately when `AttachmentIndex` observes a new
  /// attachment so the event applies as soon as the descriptor is available.
  pendingAttachment,

  /// Exact descriptor lookup or download is unavailable. Retry periodically
  /// without an age/attempt cap: a past descriptor need not reappear live.
  pendingDescriptor,
  permanentSkip,

  /// The event does not decode as a sync message this build knows — a
  /// value or field from a newer sender, say. Skipped like
  /// [permanentSkip], but under its own reason, so the queue can try it
  /// again at its next start: a build that has since learned the message
  /// applies it then, without the sender having to send it again.
  undecodable,
}

/// The skip reason of an [ApplyOutcome.undecodable] event, which the queue
/// resurrects at its start.
const undecodableReason = 'undecodable';

/// One queue entry and how applying it went — what the apply side hands back
/// to whoever owns the queue (ADR 0142: the acknowledgement).
final class InboundEntryOutcome {
  const InboundEntryOutcome(this.entry, this.outcome);

  final InboundQueueEntry entry;
  final ApplyOutcome outcome;
}

/// Turns apply outcomes into the queue's next state: `applied`, a retry on
/// the reason's backoff ladder, or `abandoned` once a budget is spent.
///
/// This is the rule book both queue owners share — the UI isolate's
/// `InboundWorker` when sync runs in-process, and the sync isolate when it
/// owns the queue (ADR 0142) — so an acknowledgement means the same thing
/// whichever side records it.
class InboundQueueSettlement {
  InboundQueueSettlement({
    required this._queue,
    this._initialBackoff = const Duration(milliseconds: 500),
    this._maxBackoff = const Duration(seconds: 30),
    this._maxAttempts = 10,
  });

  final InboundQueue _queue;
  final Duration _initialBackoff;
  final Duration _maxBackoff;
  final int _maxAttempts;

  /// Records every outcome in one `sync_db` transaction, so a batch performs
  /// one commit instead of one per entry. Returns how many were applied.
  Future<int> settle(List<InboundEntryOutcome> outcomes) {
    return _queue.runInTransaction(() async {
      var applied = 0;
      for (final InboundEntryOutcome(:entry, :outcome) in outcomes) {
        switch (outcome) {
          case ApplyOutcome.applied:
            await _queue.commitApplied(entry);
            applied++;
          case ApplyOutcome.retriable:
            await _maybeRetry(entry, RetryReason.retriable);
          case ApplyOutcome.missingBase:
            await _maybeRetry(entry, RetryReason.missingBase);
          case ApplyOutcome.decryptionPending:
            await _maybeRetry(entry, RetryReason.decryptionPending);
          case ApplyOutcome.pendingBarrier:
            await _maybeRetry(entry, RetryReason.pendingBarrier);
          case ApplyOutcome.pendingDescriptor:
            await _maybeRetry(entry, RetryReason.pendingDescriptor);
          case ApplyOutcome.pendingAttachment:
            await _maybeRetry(entry, RetryReason.pendingAttachment);
          case ApplyOutcome.permanentSkip:
            await _queue.markSkipped(entry, reason: 'permanentSkip');
          case ApplyOutcome.undecodable:
            await _queue.markSkipped(entry, reason: undecodableReason);
        }
      }
      return applied;
    });
  }

  Future<void> _maybeRetry(InboundQueueEntry entry, RetryReason reason) async {
    final nextAttempts = entry.attempts + 1;
    if (reason == RetryReason.pendingDescriptor &&
        entry.descriptorAttempts + 1 >= _minPendingDescriptorAttempts &&
        clock.now().millisecondsSinceEpoch - entry.enqueuedAt >=
            _maxPendingDescriptorWait.inMilliseconds) {
      await _queue.markSkipped(entry, reason: 'pendingDescriptorTimeout');
      return;
    }
    if (reason == RetryReason.pendingBarrier ||
        reason == RetryReason.pendingDescriptor) {
      await _queue.scheduleRetry(
        entry,
        _backoff(entry.attempts, reason),
        reason: reason,
      );
      return;
    }
    if (reason == RetryReason.pendingAttachment) {
      final elapsed = Duration(
        milliseconds: clock.now().millisecondsSinceEpoch - entry.enqueuedAt,
      );
      if (elapsed >= _maxPendingAttachmentWait) {
        await _queue.markSkipped(entry, reason: 'pendingAttachmentTimeout');
        return;
      }

      final remainingWait = _maxPendingAttachmentWait - elapsed;
      final backoff = _backoff(entry.attempts, reason);
      await _queue.scheduleRetry(
        entry,
        backoff < remainingWait ? backoff : remainingWait,
        reason: reason,
      );
      return;
    }

    if (nextAttempts >= _maxAttempts) {
      await _queue.markSkipped(entry, reason: 'maxAttempts(${reason.name})');
      return;
    }
    await _queue.scheduleRetry(
      entry,
      _backoff(entry.attempts, reason),
      reason: reason,
    );
  }

  Duration _backoff(int attempts, RetryReason reason) {
    // Per-reason ladders:
    //  - `decryptionPending`: Megolm session keys usually arrive in
    //    a few seconds; start at 250 ms.
    //  - `pendingAttachment`: attachment uploads + downloads are on
    //    a human-scale timeline. Start at 30 s and let the curve cap
    //    out at `_maxPendingAttachmentBackoff`; `_maybeRetry` also
    //    caps each scheduled delay to the remaining wall-clock wait
    //    so the row is abandoned promptly at `_maxPendingAttachmentWait`.
    //  - everything else (network, missing-base, generic
    //    retriable): standard exponential capped at `_maxBackoff`.
    switch (reason) {
      case RetryReason.decryptionPending:
        final base = const Duration(milliseconds: 250).inMilliseconds;
        final millis = base * math.pow(2, attempts).toInt();
        return Duration(
          milliseconds: math.min(millis, _maxBackoff.inMilliseconds),
        );
      case RetryReason.pendingAttachment:
        final base = _pendingAttachmentInitialBackoff.inMilliseconds;
        final millis = base * math.pow(2, attempts).toInt();
        return Duration(
          milliseconds: math.min(
            millis,
            _maxPendingAttachmentBackoff.inMilliseconds,
          ),
        );
      case RetryReason.pendingDescriptor:
        return _pendingAttachmentInitialBackoff;
      case RetryReason.pendingBarrier:
        return _pendingBarrierRetryInterval;
      case RetryReason.retriable:
      case RetryReason.missingBase:
        final base = _initialBackoff.inMilliseconds;
        final millis = base * math.pow(2, attempts).toInt();
        return Duration(
          milliseconds: math.min(millis, _maxBackoff.inMilliseconds),
        );
    }
  }

  // Long ladder for attachment-waiting rows. Tuned to retry ~3-4
  // times during the lifetime of a typical attachment download.
  // `AttachmentIndex.pathRecorded` wakes the row the instant the
  // descriptor lands; if it still has not landed by the hard wait
  // deadline, the row is abandoned instead of retrying forever.
  static const Duration _pendingAttachmentInitialBackoff = Duration(
    seconds: 30,
  );
  static const Duration _pendingBarrierRetryInterval = Duration(seconds: 5);
  // Backstop for descriptors that never become available. Exact-descriptor
  // recovery must survive restarts and offline stretches, so the row is only
  // abandoned once BOTH a day has passed since it was queued AND a day's
  // worth of 30 s descriptor retries has actually run — counted apart from
  // generic and barrier retries, which also bump the row's `attempts`. Wall
  // clock alone would drop rows the moment an app closed for a week reopens
  // offline; attempts alone would drop them after one long offline day.
  // Abandoned rows stay durable and resurrectable, so a descriptor that
  // does arrive later still applies.
  static const Duration _maxPendingDescriptorWait = Duration(hours: 24);
  static final int _minPendingDescriptorAttempts =
      _maxPendingDescriptorWait.inSeconds ~/
      _pendingAttachmentInitialBackoff.inSeconds;
  static const Duration _maxPendingAttachmentWait = Duration(minutes: 10);
  // Bounded by the wait deadline: a single backoff at the cap exhausts
  // the entire grace window, so capping the backoff above the deadline
  // would be wasted retry budget.
  static const Duration _maxPendingAttachmentBackoff =
      _maxPendingAttachmentWait;
}
