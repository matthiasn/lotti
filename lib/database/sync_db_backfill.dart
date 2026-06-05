part of 'sync_db.dart';

/// Backfill sweep queries and statistics over the sync sequence log:
/// eligible `missing`/`requested` row selection (with age and per-host
/// limits), request-count bookkeeping, the actionable-row probe, and
/// per-host status aggregation.
mixin _SyncDbBackfill on _$SyncDatabase {
  /// Get entries with status 'missing' or 'requested' that haven't
  /// exceeded maxRequestCount, ordered by creation time (oldest first).
  /// Return rows in `missing` / `requested` state that are still eligible
  /// for a backfill request.
  ///
  /// [minAge] holds rows freshly detected as missing back for a grace window,
  /// so a short-lived gap caused by out-of-order priority messages resolves
  /// naturally via the standard sync path before backfill fires. Only rows
  /// whose `created_at` is at or before `now - minAge` are returned. Pass
  /// `Duration.zero` to disable (manual / "request now" paths).
  Future<List<SyncSequenceLogItem>> getMissingEntries({
    int limit = 50,
    int maxRequestCount = 10,
    int offset = 0,
    Duration minAge = Duration.zero,
    DateTime? now,
  }) {
    final cutoff = (now ?? DateTime.now()).subtract(minAge);
    return (select(syncSequenceLog)
          ..where(
            (t) =>
                (t.status.equals(SyncSequenceStatus.missing.index) |
                    t.status.equals(SyncSequenceStatus.requested.index)) &
                t.requestCount.isSmallerThanValue(maxRequestCount) &
                t.createdAt.isSmallerOrEqualValue(cutoff),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)])
          ..limit(limit, offset: offset))
        .get();
  }

  /// Batch increment request counts for multiple entries.
  /// Uses batch operations for efficiency while maintaining atomic increments.
  Future<void> batchIncrementRequestCounts(
    List<({String hostId, int counter})> entries,
  ) async {
    if (entries.isEmpty) return;

    final now = DateTime.now();
    // Drift's default `dateTime()` column encodes values as Unix seconds
    // (see the `store_date_time_values_as_text` guide). Anything written
    // via raw `customStatement` bindings must match that encoding, or
    // later comparisons like `retireExhaustedRequestedEntries`' cutoff
    // (bound via `Variable.withDateTime(...)`) will compare milliseconds
    // against seconds and silently never match.
    final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
    await batch((b) {
      for (final entry in entries) {
        b.customStatement(
          'UPDATE sync_sequence_log '
          'SET request_count = request_count + 1, '
          'status = ?, '
          'updated_at = ?, '
          'last_requested_at = ? '
          'WHERE host_id = ? AND counter = ?',
          [
            SyncSequenceStatus.requested.index,
            nowSeconds,
            nowSeconds,
            entry.hostId,
            entry.counter,
          ],
        );
      }
    });
  }

  /// Get backfill statistics grouped by host.
  /// Returns counts of entries in each status per host.
  ///
  /// Implementation note: the previous `SUM(CASE WHEN status=…)`
  /// formulation forced a full table scan of `sync_sequence_log`
  /// (700 k+ rows on production devices, 858 s of cumulative DB time
  /// per day on a real desktop). With the v15
  /// `idx_sync_sequence_log_host_status` covering index, GROUP BY
  /// `(host_id, status)` is an index-only scan that emits ~80 rows
  /// (≈ hosts × statuses), and the per-host pivot happens cheaply in
  /// Dart.
  Future<BackfillStats> getBackfillStats() async {
    final hostStatusCounts = await customSelect(
      '''
      SELECT host_id, status, COUNT(*) AS cnt
      FROM sync_sequence_log
      GROUP BY host_id, status
      ''',
      readsFrom: {syncSequenceLog},
    ).get();

    if (hostStatusCounts.isEmpty) {
      return BackfillStats.fromHostStats(const []);
    }

    final perHost = <String, Map<int, int>>{};
    for (final row in hostStatusCounts) {
      final host = row.read<String>('host_id');
      final status = row.read<int>('status');
      final count = row.read<int>('cnt');
      perHost.putIfAbsent(host, () => <int, int>{})[status] = count;
    }

    final received = SyncSequenceStatus.received.index;
    final missing = SyncSequenceStatus.missing.index;
    final requested = SyncSequenceStatus.requested.index;
    final backfilled = SyncSequenceStatus.backfilled.index;
    final deleted = SyncSequenceStatus.deleted.index;
    final unresolvable = SyncSequenceStatus.unresolvable.index;
    final burned = SyncSequenceStatus.burned.index;

    final hostIds = perHost.keys.toList()..sort();
    final hostStats = [
      for (final host in hostIds)
        BackfillHostStats(
          receivedCount: perHost[host]![received] ?? 0,
          missingCount: perHost[host]![missing] ?? 0,
          requestedCount: perHost[host]![requested] ?? 0,
          backfilledCount: perHost[host]![backfilled] ?? 0,
          deletedCount: perHost[host]![deleted] ?? 0,
          unresolvableCount: perHost[host]![unresolvable] ?? 0,
          burnedCount: perHost[host]![burned] ?? 0,
        ),
    ];

    return BackfillStats.fromHostStats(hostStats);
  }

  /// Get entries with status 'requested' for re-requesting.
  /// These are entries that were requested but never received.
  /// Ignores maxRequestCount to allow re-requesting stuck entries.
  Future<List<SyncSequenceLogItem>> getRequestedEntries({
    int limit = 50,
    int offset = 0,
  }) {
    return (select(syncSequenceLog)
          ..where(
            (t) => t.status.equals(SyncSequenceStatus.requested.index),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)])
          ..limit(limit, offset: offset))
        .get();
  }

  /// Reset request count and last requested time for specified entries.
  /// This allows them to be re-requested as if they were new.
  /// Uses batch operations for efficiency.
  Future<void> resetRequestCounts(
    List<({String hostId, int counter})> entries,
  ) async {
    if (entries.isEmpty) return;

    final now = DateTime.now();
    await batch((b) {
      for (final entry in entries) {
        b.update(
          syncSequenceLog,
          SyncSequenceLogCompanion(
            requestCount: const Value(0),
            lastRequestedAt: const Value(null),
            updatedAt: Value(now),
          ),
          where: (t) =>
              t.hostId.equals(entry.hostId) & t.counter.equals(entry.counter),
        );
      }
    });
  }

  /// Cheap existence probe for any actionable (`missing` or `requested`) row.
  ///
  /// Used as the gate for the periodic backfill timer: when the table holds
  /// no actionable rows, the timer body can skip both retire passes and the
  /// `_loadNextUnqueuedMissingBatch` work entirely. The slow-query log on
  /// 2026-05-12 showed `processBackfillRequests` ticking 347 times against
  /// an empty actionable set, each pass running 5 sync_db queries — one
  /// of which (`getPendingBackfillEntries`) hit the outbox at 226 ms avg.
  ///
  /// `status IN (1, 2)` is inlined as a literal SQL fragment via
  /// `CustomExpression` so the SQLite planner can prove this query's WHERE
  /// implies the partial index
  /// `idx_sync_sequence_log_actionable_status_created_at`'s WHERE clause
  /// (`WHERE status IN (1, 2)`). With a `LIMIT 1` the planner short-circuits
  /// on the first matching index row, so this is effectively O(log n) on the
  /// partial index even with hundreds of thousands of historical rows
  /// already in `received`/`backfilled`/`unresolvable`.
  Future<bool> hasActionableEntries() async {
    final row = await customSelect(
      'SELECT 1 FROM sync_sequence_log WHERE status IN (1, 2) LIMIT 1',
      readsFrom: {syncSequenceLog},
    ).getSingleOrNull();
    return row != null;
  }

  /// Get missing entries with age and per-host limits for automatic backfill.
  /// [maxAge] - Only include entries created within this duration
  /// [minAge] - Debounce window: rows freshly flagged as missing are held back
  ///           until their `created_at` is at or before `now - minAge`. This
  ///           lets short-lived gaps caused by out-of-order priority messages
  ///           resolve via the standard sync path before backfill fires. Pass
  ///           `Duration.zero` to disable (default).
  /// [maxPerHost] - Maximum entries to include per host
  Future<List<SyncSequenceLogItem>> getMissingEntriesWithLimits({
    int limit = 50,
    int maxRequestCount = 10,
    Duration? maxAge,
    Duration minAge = Duration.zero,
    int? maxPerHost,
    DateTime? now,
    int offset = 0,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final minAgeCutoff = effectiveNow.subtract(minAge);
    // All three time/count gates (`minAge`, `maxAge`, `maxRequestCount`) are
    // pushed into the SQL WHERE so we never materialise rows we'd
    // immediately discard. The per-host cap is still post-processed because
    // SQLite plain selects don't have a window-function-free way to
    // express "top N rows per host"; that post-processing runs on the
    // bounded result set below.
    final baseQuery = select(syncSequenceLog)
      ..where((t) {
        // `status IN (1, 2)` is inlined as a literal SQL fragment via
        // `CustomExpression` so the SQLite planner can prove it implies
        // the partial index's WHERE
        // (`idx_sync_sequence_log_actionable_status_created_at`,
        // declared with `WHERE status IN (1, 2)`). Drift's
        // `t.status.equals(?) | t.status.equals(?)` and
        // `t.status.isIn([?, ?])` both bind the values as parameters
        // unknown at plan time; the partial-index match fails and the
        // predicate falls back to a full table scan. The 2026-05-09
        // desktop slow_queries log captured this shape at 399 hits/day
        // in the 200–999 ms band before the rewrite. Literal values
        // mirror `SyncSequenceStatus.missing.index = 1` and
        // `.requested.index = 2`, matching the migration's enum-order
        // assumption.
        var predicate =
            const CustomExpression<bool>('status IN (1, 2)') &
            t.requestCount.isSmallerThanValue(maxRequestCount) &
            t.createdAt.isSmallerOrEqualValue(minAgeCutoff);
        if (maxAge != null) {
          final maxAgeCutoff = effectiveNow.subtract(maxAge);
          predicate = predicate & t.createdAt.isBiggerThanValue(maxAgeCutoff);
        }
        return predicate;
      })
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]);

    // Cap the SQL fetch so a pathologically large missing-row backlog does
    // not blow up memory. Without `maxPerHost` the tight `offset + limit`
    // bound is exactly what the caller wants. With `maxPerHost`, the Dart
    // post-filter needs to see enough rows per host to pick the first N
    // per host while still honouring `offset + limit` across hosts — so
    // we fall back to a generous fixed cap. At production tuning
    // (`backfillProcessingBatchSize = 100`, `defaultBackfillMaxEntriesPerHost
    // = 250`), this cap is >> any realistic per-cycle working set; if it
    // ever saturates, the next periodic cycle picks up the remainder.
    const perHostFetchCap = 10000;
    final sqlFetchLimit = maxPerHost != null ? perHostFetchCap : offset + limit;
    baseQuery.limit(sqlFetchLimit);

    var entries = await baseQuery.get();

    // Apply per-host limit if specified
    if (maxPerHost != null) {
      final byHost = <String, List<SyncSequenceLogItem>>{};
      for (final entry in entries) {
        byHost.putIfAbsent(entry.hostId, () => []).add(entry);
      }
      entries = byHost.values.expand((list) => list.take(maxPerHost)).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    return entries.skip(offset).take(limit).toList();
  }

  // ============ Sync Health Query Helpers ============

  /// Count of sequence log entries matching the given [status].
  Future<int> _countSequenceByStatus(SyncSequenceStatus status) async {
    final query = selectOnly(syncSequenceLog)
      ..addColumns([syncSequenceLog.hostId.count()])
      ..where(syncSequenceLog.status.equals(status.index));
    final result = await query.getSingle();
    return result.read(syncSequenceLog.hostId.count()) ?? 0;
  }

  /// Count of sequence log entries with status = missing.
  Future<int> getMissingSequenceCount() =>
      _countSequenceByStatus(SyncSequenceStatus.missing);

  /// Count of sequence log entries with status = requested.
  Future<int> getRequestedSequenceCount() =>
      _countSequenceByStatus(SyncSequenceStatus.requested);
}
