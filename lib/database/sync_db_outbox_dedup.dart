part of 'sync_db.dart';

/// Outbox introspection for [SyncDatabase]: merge-dedup lookups
/// ([findPendingByEntryId] / [updateOutboxMessage]), pending backfill
/// request extraction, daily volume aggregation, and health counts.
mixin _SyncDbOutboxDedup on _$SyncDatabase {
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
  /// 2. `subject LIKE 'backfillRequest:%'` — `_enqueueBackfillRequest`
  ///    sets `subject` to `'backfillRequest:batch:N'` for every backfill
  ///    request enqueue, so the prefix is a reliable marker. Without
  ///    this filter we materialise every actionable row and JSON-decode
  ///    each one to find the tiny subset of backfill requests; with it,
  ///    only the matching rows are decoded.
  Future<Set<({String hostId, int counter})>>
  getPendingBackfillEntries() async {
    final pendingItems =
        await (select(outbox)..where(
              (t) =>
                  const CustomExpression<bool>('status IN (0, 3)') &
                  t.subject.like('backfillRequest:%'),
            ))
            .get();

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

  // ============ Outbox Deduplication Methods ============

  /// Find a pending outbox item for a specific entry ID.
  /// Returns the most recent pending item for this entry, or null.
  ///
  /// `created_at` is stored at second granularity, so two rapid edits can
  /// collide on the timestamp; `id DESC` breaks the tie deterministically
  /// in favor of the latest insert so the merge-dedup path always targets
  /// the newest pending row.
  Future<OutboxItem?> findPendingByEntryId(String entryId) {
    return (select(outbox)
          ..where((t) => const CustomExpression<bool>('status = 0'))
          ..where((t) => t.outboxEntryId.equals(entryId))
          ..orderBy([
            (t) => OrderingTerm.desc(t.createdAt),
            (t) => OrderingTerm.desc(t.id),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Update an existing pending outbox item's message and subject.
  ///
  /// Only updates rows that are still [OutboxStatus.pending] to avoid
  /// overwriting in-flight or already-sent items (compare-and-swap on
  /// status). Returns the number of affected rows — 0 means the row was
  /// no longer pending and the caller should insert a fresh row instead.
  Future<int> updateOutboxMessage({
    required int itemId,
    required String newMessage,
    required String newSubject,
    int? payloadSize,
    int? priority,
  }) {
    return (update(outbox)..where(
          (t) =>
              t.id.equals(itemId) & t.status.equals(OutboxStatus.pending.index),
        ))
        .write(
          OutboxCompanion(
            message: Value(newMessage),
            subject: Value(newSubject),
            updatedAt: Value(DateTime.now()),
            payloadSize: payloadSize != null
                ? Value(payloadSize)
                : const Value.absent(),
            priority: priority != null ? Value(priority) : const Value.absent(),
          ),
        );
  }

  /// Get aggregated outbox volume per day for sent items.
  /// Groups by send time (`updated_at`) so items appear on the day they
  /// were actually transmitted, not the day they were created.
  Future<List<OutboxDailyVolume>> getDailyOutboxVolume({
    int days = 7,
    DateTime? now,
  }) async {
    if (days <= 0) return const [];

    final effectiveNow = (now ?? DateTime.now()).toUtc();
    final startOfToday = DateTime.utc(
      effectiveNow.year,
      effectiveNow.month,
      effectiveNow.day,
    );
    final cutoff = startOfToday.subtract(Duration(days: days - 1));

    final cutoffSeconds = cutoff.millisecondsSinceEpoch ~/ 1000;
    final rows = await customSelect(
      "SELECT strftime('%Y-%m-%d', updated_at, 'unixepoch') AS day, "
      'COALESCE(SUM(payload_size), 0) AS total_bytes, '
      'COUNT(*) AS item_count '
      'FROM outbox '
      'WHERE status = ? AND updated_at >= ? '
      'GROUP BY day '
      'ORDER BY day ASC',
      variables: [
        Variable.withInt(OutboxStatus.sent.index),
        Variable.withInt(cutoffSeconds),
      ],
    ).get();

    return rows.map((row) {
      final dayString = row.read<String>('day');
      final parts = dayString.split('-');
      return OutboxDailyVolume(
        date: DateTime.utc(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        ),
        totalBytes: row.read<int>('total_bytes'),
        itemCount: row.read<int>('item_count'),
      );
    }).toList();
  }

  /// Count of pending outbox items (non-stream, single-shot).
  Future<int> getPendingOutboxCount() async {
    final query = selectOnly(outbox)
      ..addColumns([outbox.id.count()])
      ..where(outbox.status.equals(OutboxStatus.pending.index));
    final result = await query.getSingle();
    return result.read(outbox.id.count()) ?? 0;
  }

  /// Count of outbox items with status = sent and updatedAt >= [since].
  Future<int> getSentCountSince(DateTime since) async {
    final query = selectOnly(outbox)
      ..addColumns([outbox.id.count()])
      ..where(
        outbox.status.equals(OutboxStatus.sent.index) &
            outbox.updatedAt.isBiggerOrEqualValue(since),
      );
    final result = await query.getSingle();
    return result.read(outbox.id.count()) ?? 0;
  }
}
