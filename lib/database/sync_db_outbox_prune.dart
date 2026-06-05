part of 'sync_db.dart';

/// Retention pruning for the outbox `sent` ledger: the unbounded
/// one-shot [pruneSentOutboxItems] and the chunked variant that yields
/// the writer lock between batches.
mixin _SyncDbOutboxPrune on _$SyncDatabase {
  /// Prune outbox rows with `status = sent` whose `updated_at` is older
  /// than [retention]. `updated_at` is the send time (set by `markSent`);
  /// `created_at` is the enqueue time, which can be days older for rows
  /// that were stuck pending. Using send time means "7 days retained as
  /// sent" regardless of how long the row waited in pending — and it
  /// matches the same send-time definition used by the outbox volume
  /// view in the UI.
  ///
  /// Error rows (`status = error`) are deliberately kept regardless of
  /// age so a human can still inspect persistently failed sends;
  /// pending and sending rows are live state and are never considered
  /// for pruning.
  ///
  /// Without this, the outbox grows unbounded (observed: 395k rows on
  /// desktop, 265k on mobile). Every outbox enqueue pays the table-size
  /// cost on indexed writes, WAL checkpoints get heavier, and backups
  /// balloon. A week of kept-forever sent rows is already far more
  /// than the `outbox_entry_id` dedup path requires (dedup only
  /// matters for in-flight edits — a message already sent more than a
  /// minute ago will never be re-deduped).
  ///
  /// Returns the number of rows deleted.
  Future<int> pruneSentOutboxItems({
    required Duration retention,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final cutoff = effectiveNow.subtract(retention);
    return (delete(outbox)..where(
          (t) =>
              t.status.equals(OutboxStatus.sent.index) &
              t.updatedAt.isSmallerThanValue(cutoff),
        ))
        .go();
  }

  /// Same retention semantics as [pruneSentOutboxItems], but deletes in
  /// bounded chunks so the writer lock is released between batches and
  /// concurrent enqueue/claim/watch can interleave. Required for one-shot
  /// cleanup on devices where the table has accumulated hundreds of
  /// thousands of `sent` rows — a single unbounded DELETE on that volume
  /// holds the writer for many seconds and stalls the whole sync pipeline.
  ///
  /// Each pass deletes up to [chunkSize] rows, then awaits a microtask
  /// (or the supplied [yieldDelay]) to let other queued statements run.
  /// Loop terminates when a pass deletes fewer than [chunkSize] rows.
  ///
  /// When [vacuumWhenDone] is true and at least one row was deleted, runs
  /// `VACUUM` after the loop to reclaim disk space — VACUUM rewrites the
  /// whole DB file, so it is opt-in and only worth running after a large
  /// purge.
  ///
  /// [onProgress] receives the running deletion total after each chunk;
  /// callers (UI, periodic timer) can emit traces or update progress UI.
  Future<int> pruneSentOutboxItemsChunked({
    required Duration retention,
    int chunkSize = 5000,
    Duration yieldDelay = Duration.zero,
    bool vacuumWhenDone = false,
    DateTime? now,
    void Function(int deletedSoFar)? onProgress,
  }) async {
    // A non-positive `chunkSize` would wedge the loop:
    // - `chunkSize == 0` → `LIMIT 0` deletes nothing, `n == 0`,
    //   `n < chunkSize` is `0 < 0` → false → infinite spin.
    // - `chunkSize < 0` → SQLite treats `LIMIT -1` as "no limit"
    //   so the first pass deletes every eligible row, but the
    //   termination check still fails (e.g. `n < -1`).
    // Mirror the same short-circuit `_retireInPages` uses for
    // `pageSize <= 0` so a misconfigured caller cannot stall the
    // writer.
    if (chunkSize <= 0) return 0;
    final effectiveNow = now ?? DateTime.now();
    final cutoff = effectiveNow.subtract(retention);
    final sentStatus = OutboxStatus.sent.index;
    var total = 0;
    while (true) {
      // Subquery on `id` lets us bound a single statement's row count via
      // LIMIT — drift's `delete(...).where(...)` does not expose LIMIT
      // directly. The inner SELECT walks
      // `idx_outbox_status_priority_created_at` (status leading column) so
      // it is index-bounded, not a scan.
      final n = await customUpdate(
        'DELETE FROM outbox WHERE id IN '
        '(SELECT id FROM outbox '
        'WHERE status = ? AND updated_at < ? '
        'LIMIT ?)',
        variables: [
          Variable.withInt(sentStatus),
          Variable.withDateTime(cutoff),
          Variable.withInt(chunkSize),
        ],
        updates: {outbox},
      );
      total += n;
      onProgress?.call(total);
      if (n < chunkSize) break;
      // Yield the writer so other statements queued behind the chunk can
      // run before we ask for another delete batch.
      await Future<void>.delayed(yieldDelay);
    }
    if (vacuumWhenDone && total > 0) {
      await customStatement('VACUUM');
    }
    return total;
  }
}
