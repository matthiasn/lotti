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

  /// Atomically claim a contiguous batch of pending rows for bundling.
  ///
  /// Returns `[]` when the queue is empty. When the head row is a media
  /// attachment (`filePath != null`) the returned list is `[head]` — media
  /// attachments always travel alone. Otherwise the returned list is the
  /// maximal prefix of consecutive text-only rows in
  /// `(priority, createdAt)` order, capped at [maxSize], stopping at the
  /// first media attachment.
  ///
  /// The single-row [claim] method remains the primary entry point when
  /// bundling is disabled — `claimNextBatch(maxSize: 1)` is equivalent.
  Future<List<OutboxItem>> claimNextBatch({
    required int maxSize,
    Duration? leaseDuration,
  });

  /// Peek whether at least one pending row remains, without transitioning
  /// status. Used to decide whether the processor should schedule another
  /// drain pass after a successful send.
  Future<bool> hasMorePending();

  Future<void> markSent(OutboxItem item);

  /// Mark every row in [items] as sent in a single transaction.
  /// Used after a bundle send succeeds.
  Future<void> markSentBatch(List<OutboxItem> items);

  Future<void> markRetry(OutboxItem item);

  /// Apply [markRetry] semantics to every row in [items] in a single
  /// transaction. Used after a bundle send fails: each row's `retries`
  /// counter is incremented and the row flips back to pending — or to
  /// error once it crosses `maxRetries` (per-row, exactly as for
  /// individual sends).
  Future<void> markRetryBatch(List<OutboxItem> items);

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
  Future<List<OutboxItem>> claimNextBatch({
    required int maxSize,
    Duration? leaseDuration,
  }) {
    return _database.claimNextOutboxBatch(
      maxSize: maxSize,
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
  Future<void> markSentBatch(List<OutboxItem> items) async {
    if (items.isEmpty) return;
    // Single SQL UPDATE keyed by `id IN (…)` instead of N per-row writes.
    // Every row in the batch transitions to the same `sent` status, so the
    // operation collapses into one bulk statement.
    await _database.markOutboxItemsSent(
      ids: items.map((item) => item.id).toList(growable: false),
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
  Future<void> markRetryBatch(List<OutboxItem> items) async {
    if (items.isEmpty) return;
    final now = DateTime.now();
    await _database.transaction(() async {
      for (final item in items) {
        final retries = item.retries + 1;
        final newStatus = retries < maxRetries
            ? OutboxStatus.pending.index
            : OutboxStatus.error.index;
        await _database.updateOutboxItem(
          OutboxCompanion(
            id: Value(item.id),
            status: Value(newStatus),
            retries: Value(retries),
            updatedAt: Value(now),
          ),
        );
      }
    });
  }

  @override
  Future<int> pruneSentOutboxItems({
    required Duration retention,
  }) {
    return _database.pruneSentOutboxItems(retention: retention);
  }
}
