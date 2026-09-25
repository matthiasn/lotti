part of 'sync_db.dart';

/// Outbox lookups for [SyncDatabase]: the rows a send collapses
/// ([collapsibleOutboxRows] / [claimOutboxRows]) and pending backfill request
/// extraction.
mixin _SyncDbOutboxDedup on _$SyncDatabase {
  /// Whether an origin already has a pending or leased head announcement.
  /// The sender leaves that immutable row alone and announces a newer head
  /// on a later tick after it has drained.
  Future<bool> hasPendingSequenceHeadAnnouncement(String hostId) async {
    final row = await customSelect(
      'SELECT 1 FROM outbox INDEXED BY idx_outbox_actionable_subject '
      'WHERE status IN (0, 3) AND subject = ? LIMIT 1',
      variables: [Variable.withString('backfillRequest:head:$hostId')],
      readsFrom: {outbox},
    ).getSingleOrNull();
    return row != null;
  }

  /// Get (hostId, counter) pairs from queued or in-flight backfill request
  /// messages in outbox.
  ///
  /// Used to avoid enqueuing duplicate backfill requests while an older request
  /// is still pending or leased in `sending`.
  ///
  /// Two filters applied at SQL level keep this cheap on devices where the
  /// outbox has accumulated hundreds of thousands of rows:
  /// 1. `status IN (0, 3)` is inlined as a literal SQL fragment via
  ///    `CustomExpression` so the SQLite planner can prove this query's
  ///    WHERE implies the partial index's WHERE clause
  ///    (`idx_outbox_actionable_priority_created_at`, declared with
  ///    `WHERE status IN (0, 3)`). Drift's
  ///    `t.status.isIn([pending, sending])` binds the two status values
  ///    as parameters; the planner can't see them at plan time, the
  ///    partial-index match fails, and the predicate falls back to a
  ///    full table scan. The 2026-05-12 desktop slow_queries log
  ///    captured this shape at 357 hits/day with every plan reading
  ///    `SCAN outbox` (avg 226 ms, max 1.8 s) before the rewrite.
  ///    Literal values mirror `OutboxStatus.pending.index = 0` and
  ///    `_outboxSendingStatus = 3` — the guard test in
  ///    `test/database/sync_db_test.dart` asserts the partial-index
  ///    declaration stays in sync with this assumption.
  /// 2. Subject prefix range — `_enqueueBackfillRequest` sets `subject` to
  ///    `'backfillRequest:batch:N'` for every backfill
  ///    request enqueue, so the prefix is a reliable marker. The SQL uses
  ///    a bounded prefix range (`>= 'backfillRequest:'` and
  ///    `< 'backfillRequest;'`) so SQLite can range-scan
  ///    `idx_outbox_actionable_subject` instead of walking every actionable
  ///    row and testing `LIKE`.
  Future<Set<({String hostId, int counter})>>
  getPendingBackfillEntries() async {
    const prefix = 'backfillRequest:';
    const upperBound = 'backfillRequest;';
    final pendingItems = await customSelect(
      '''
      SELECT *
      FROM outbox INDEXED BY idx_outbox_actionable_subject
      WHERE status IN (0, 3)
        AND subject >= ?
        AND subject < ?
      ''',
      variables: [
        const Variable<String>(prefix),
        const Variable<String>(upperBound),
      ],
      readsFrom: {outbox},
    ).asyncMap(outbox.mapFromRow).get();

    final entries = <({String hostId, int counter})>{};

    for (final item in pendingItems) {
      try {
        final json = jsonDecode(item.message) as Map<String, dynamic>;
        // Defensive: a row whose subject starts with `backfillRequest:`
        // but whose message is some other shape would still be filtered
        // out here. The subject is set adjacent to the JSON encode in
        // `_enqueueBackfillRequest`, so this check is just belt and
        // braces.
        if (json['runtimeType'] != 'backfillRequest') continue;
        final entriesList = json['entries'] as List<dynamic>?;
        if (entriesList == null) continue;
        for (final entry in entriesList) {
          if (entry is Map<String, dynamic>) {
            final hostId = entry['hostId'] as String?;
            final counter = entry['counter'] as int?;
            if (hostId != null && counter != null) {
              entries.add((hostId: hostId, counter: counter));
            }
          }
        }
      } catch (_) {
        // Skip malformed messages
      }
    }

    return entries;
  }

  // ============ Dequeue-time collapse ============

  /// The rows of [entryId] that a send of that entity can collapse: every
  /// `pending` and every `error` row, minus [excludeIds] (the rows already
  /// claimed), in enqueue (id) order.
  ///
  /// Two literal-status queries, so the pending one matches the partial index
  /// `idx_outbox_pending_entry_id_created_at` and the error one only walks the
  /// few failed rows. Error rows are included so a newer send settles a
  /// superseded failure instead of leaving it retryable with a stale value
  /// (ADR 0086).
  Future<List<OutboxItem>> collapsibleOutboxRows(
    String entryId, {
    Set<int> excludeIds = const {},
  }) async {
    final pending =
        await (select(outbox)
              ..where((t) => const CustomExpression<bool>('status = 0'))
              ..where((t) => t.outboxEntryId.equals(entryId)))
            .get();
    final failed =
        await (select(outbox)
              ..where((t) => const CustomExpression<bool>('status = 2'))
              ..where((t) => t.outboxEntryId.equals(entryId)))
            .get();
    return [
        ...pending,
        ...failed,
      ].where((row) => !excludeIds.contains(row.id)).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
  }

  /// Claim [rows] for a send: each moves to `sending` only if it still has the
  /// status it was read with (a compare-and-set, so a row the monitor retried
  /// or removed in between is left alone). Returns the rows claimed, as
  /// `sending`, in the order given.
  Future<List<OutboxItem>> claimOutboxRows(
    List<OutboxItem> rows, {
    DateTime? now,
  }) {
    final effectiveNow = now ?? clock.now();
    return transaction(() async {
      final claimed = <OutboxItem>[];
      for (final row in rows) {
        final updated =
            await (update(outbox)..where(
                  (t) => t.id.equals(row.id) & t.status.equals(row.status),
                ))
                .write(
                  OutboxCompanion(
                    status: Value(OutboxStatus.sending.index),
                    updatedAt: Value(effectiveNow),
                  ),
                );
        if (updated == 1) {
          claimed.add(
            row.copyWith(
              status: OutboxStatus.sending.index,
              updatedAt: effectiveNow,
            ),
          );
        }
      }
      return claimed;
    });
  }
}
