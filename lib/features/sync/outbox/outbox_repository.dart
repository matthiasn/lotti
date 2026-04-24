import 'package:drift/drift.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/features/sync/tuning.dart';

abstract class OutboxRepository {
  Future<List<OutboxItem>> fetchPending({int limit = 10});

  /// Atomically claim the next eligible outbox row and transition it from
  /// `pending` (or an expired `sending` lease) to `sending`. Returns the
  /// claimed item, or `null` when the queue is empty or the claim races
  /// another worker.
  ///
  /// Using this instead of `fetchPending` closes the merge-send race:
  /// once the row is `sending`, `updateOutboxMessage` (which matches
  /// `status=pending`) no longer updates it in place, so in-flight merges
  /// fall through to inserting a fresh row and the now-merged content is
  /// still guaranteed to be sent as its own Matrix event.
  Future<OutboxItem?> claim({Duration? leaseDuration});

  /// Peek whether at least one pending row remains, without transitioning
  /// status. Used to decide whether the processor should schedule another
  /// drain pass after a successful send.
  Future<bool> hasMorePending();

  Future<void> markSent(OutboxItem item);

  Future<void> markRetry(OutboxItem item);

  /// Delete rows with `status = sent` older than [retention]. Never
  /// touches `pending`, `sending`, or `error` — error rows are kept
  /// forever so persistent failures remain inspectable.
  /// Returns the number of rows deleted.
  Future<int> pruneSentOutboxItems({
    required Duration retention,
  });
}

class DatabaseOutboxRepository implements OutboxRepository {
  DatabaseOutboxRepository(
    this._database, {
    this.maxRetries = 10,
  });

  final SyncDatabase _database;
  final int maxRetries;

  @override
  Future<List<OutboxItem>> fetchPending({int limit = 10}) {
    return _database.oldestOutboxItems(limit);
  }

  @override
  Future<OutboxItem?> claim({Duration? leaseDuration}) {
    return _database.claimNextOutboxItem(
      leaseDuration: leaseDuration ?? SyncTuning.outboxClaimLease,
    );
  }

  @override
  Future<bool> hasMorePending() async {
    final pending = await _database.oldestOutboxItems(1);
    return pending.isNotEmpty;
  }

  @override
  Future<void> markSent(OutboxItem item) async {
    await _database.updateOutboxItem(
      OutboxCompanion(
        id: Value(item.id),
        status: Value(OutboxStatus.sent.index),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> markRetry(OutboxItem item) async {
    final retries = item.retries + 1;
    final newStatus = retries < maxRetries
        ? OutboxStatus.pending.index
        : OutboxStatus.error.index;

    await _database.updateOutboxItem(
      OutboxCompanion(
        id: Value(item.id),
        status: Value(newStatus),
        retries: Value(retries),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<int> pruneSentOutboxItems({
    required Duration retention,
  }) {
    return _database.pruneSentOutboxItems(retention: retention);
  }
}
