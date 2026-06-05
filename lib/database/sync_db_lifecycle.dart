part of 'sync_db.dart';

/// Retire/reset lifecycle for stuck sequence-log rows: promoting
/// exhausted or aged-out `missing`/`requested` rows to `unresolvable`
/// (so the watermark can advance) and the user-initiated resets that
/// reopen them for another backfill sweep.
mixin _SyncDbSequenceLifecycle on _$SyncDatabase, _SyncDbSequenceWatermarks {
  /// Retire missing/requested rows whose request_count has reached the cap
  /// by flipping their status to `unresolvable`. Rows in `missing`/`requested`
  /// block the contiguous-prefix watermark in [getLastCounterForHost]; once
  /// a row has been asked for more than [maxRequestCount] times without
  /// resolving, the counter it points to is almost certainly unobtainable
  /// (pre-history entry, purged payload, or permanently VC-behind mapping).
  /// Promoting it to the terminal `unresolvable` state lets the watermark
  /// advance and stops every incoming event from paying the gap-detection
  /// cost for the same stuck range.
  ///
  /// A row is only retired when its most-recent request is older than
  /// [now] minus [grace], so a backfill request still queued in the outbox
  /// or in flight to a peer gets a fair chance to resolve before we flip
  /// the row terminal. Rows without a recorded `last_requested_at` (never
  /// requested, yet still past the count cap — unusual) are not retired.
  ///
  /// Returns the number of rows retired.
  ///
  /// Paginated: each [pageSize] batch flips in its own transaction so
  /// the writer lock is released between pages instead of being held
  /// for the full set. On a real desktop a single un-paginated UPDATE
  /// over a backlog of stuck rows held the lock for ~1.9 s and
  /// starved concurrent journal reads (slow_queries log,
  /// 2026-05-02). Smaller pages bound the worst-case lock hold to one
  /// page's worth of writes.
  Future<int> retireExhaustedRequestedEntries({
    int maxRequestCount = 10,
    Duration grace = const Duration(minutes: 5),
    DateTime? now,
    int pageSize = 500,
  }) async {
    final unresolvable = SyncSequenceStatus.unresolvable.index;
    final effectiveNow = now ?? DateTime.now();
    final cutoff = effectiveNow.subtract(grace);

    // `status IN (1, 2)` is inlined as a literal so the SQLite planner
    // can prove this query's WHERE is implied by the partial index's
    // WHERE (`idx_sync_sequence_log_actionable_status_last_requested_at`,
    // declared with the same literal `WHERE status IN (1, 2)`). The
    // earlier `(status = ? OR status = ?)` form bound the status values
    // as parameters; the planner couldn't see them at plan time, the
    // partial index match failed, and the predicate fell back to a full
    // table scan (slow_queries log on the 2026-05-09 desktop: 403 hits
    // in the 200–999 ms band, sum 122 s/day). The literals here mirror
    // `SyncSequenceStatus.missing.index = 1` and `.requested.index = 2`
    // — same enum-order assumption already baked into the migrations.
    return _retireInPages(
      pageSize: pageSize,
      selectKeysSql:
          'SELECT host_id, counter FROM sync_sequence_log '
          'WHERE status IN (1, 2) '
          '  AND request_count >= ? '
          '  AND last_requested_at IS NOT NULL '
          '  AND last_requested_at < ? '
          'LIMIT ?',
      selectVariables: [
        Variable.withInt(maxRequestCount),
        Variable.withDateTime(cutoff),
      ],
      newStatus: unresolvable,
      effectiveNow: effectiveNow,
    );
  }

  /// Retire `missing`/`requested` rows whose `updated_at` is older than
  /// [amnestyWindow] by flipping their status to `unresolvable`,
  /// regardless of `request_count` or `last_requested_at`.
  ///
  /// The age check is against `updated_at` (the most recent status
  /// transition), not `created_at`, because the "Ask peers for
  /// unresolvable entries" action flips rows back to `missing` and
  /// refreshes `updated_at`. Using `created_at` would let the next
  /// sweep immediately re-retire rows the user just reopened —
  /// defeating the purpose of the peer-reask action.
  ///
  /// [retireExhaustedRequestedEntries] only retires rows that have been
  /// actively requested and hit the count cap. That leaves a failure
  /// mode where a row can slip into `requested` via
  /// `SyncSequenceLogService.handleBackfillResponse`'s hint-insertion
  /// path (which creates a row with status=`requested` but never sets
  /// `last_requested_at`), OR a row in `missing` accumulates a
  /// low `request_count` and then ages out of
  /// [_SyncDbBackfill.getMissingEntriesWithLimits]'s `maxAge` window
  /// before hitting
  /// the cap. Either way, the row stays in a non-terminal status
  /// forever, blocking the contiguous-prefix watermark in
  /// [getLastCounterForHost] and causing every new event on the same
  /// host to re-emit the same gap range through gap detection.
  ///
  /// This method is the amnesty half of the retire pair: any
  /// `missing`/`requested` row older than [amnestyWindow] is treated as
  /// unresolvable. `amnestyWindow` should be wider than the active
  /// backfill-request window ([SyncTuning.defaultBackfillMaxAge]) so
  /// rows have a fair chance to be requested before being retired, but
  /// narrow enough that truly stuck rows do not accumulate
  /// indefinitely.
  ///
  /// Returns the number of rows retired.
  ///
  /// Paginated for the same lock-hold reason as
  /// [retireExhaustedRequestedEntries].
  Future<int> retireAgedOutRequestedEntries({
    Duration amnestyWindow = const Duration(days: 7),
    DateTime? now,
    int pageSize = 500,
  }) async {
    final unresolvable = SyncSequenceStatus.unresolvable.index;
    final effectiveNow = now ?? DateTime.now();
    final cutoff = effectiveNow.subtract(amnestyWindow);

    // Same `IN (1, 2)` literal trick as
    // [retireExhaustedRequestedEntries] — needed so the planner can
    // match the partial index
    // `idx_sync_sequence_log_actionable_status_updated_at` (declared
    // `WHERE status IN (1, 2)`). 2026-05-09 desktop slow_queries log
    // showed this shape at 406 hits/day in the 200–999 ms band before
    // the rewrite.
    return _retireInPages(
      pageSize: pageSize,
      selectKeysSql:
          'SELECT host_id, counter FROM sync_sequence_log '
          'WHERE status IN (1, 2) '
          '  AND updated_at < ? '
          'LIMIT ?',
      selectVariables: [
        Variable.withDateTime(cutoff),
      ],
      newStatus: unresolvable,
      effectiveNow: effectiveNow,
    );
  }

  /// Shared paginator for the retire-* methods. Reads up to [pageSize]
  /// (host_id, counter) keys matching [selectKeysSql], then UPDATEs
  /// exactly those rows by primary key inside a transaction. Loops
  /// until a page comes back empty. Each page is one short writer
  /// transaction, capping the worst-case lock hold to one page worth
  /// of work regardless of backlog size.
  ///
  /// [selectVariables] must match [selectKeysSql] without the trailing
  /// `LIMIT ?` placeholder — the paginator binds [pageSize] for that
  /// itself.
  Future<int> _retireInPages({
    required int pageSize,
    required String selectKeysSql,
    required List<Variable<Object>> selectVariables,
    required int newStatus,
    required DateTime effectiveNow,
  }) async {
    if (pageSize <= 0) return 0;
    var totalRetired = 0;
    while (true) {
      final affectedHosts = <String>{};
      final pageRetired = await transaction(() async {
        final rows = await customSelect(
          selectKeysSql,
          variables: [...selectVariables, Variable.withInt(pageSize)],
          readsFrom: {syncSequenceLog},
        ).get();
        if (rows.isEmpty) return 0;
        for (final row in rows) {
          affectedHosts.add(row.read<String>('host_id'));
        }
        final placeholders = List<String>.generate(
          rows.length,
          (_) => '(?, ?)',
        ).join(', ');
        final updateVars = <Variable<Object>>[
          Variable.withInt(newStatus),
          Variable.withDateTime(effectiveNow),
          for (final row in rows) ...[
            Variable.withString(row.read<String>('host_id')),
            Variable.withInt(row.read<int>('counter')),
          ],
        ];
        final updated = await customUpdate(
          'UPDATE sync_sequence_log '
          'SET status = ?, updated_at = ? '
          'WHERE (host_id, counter) IN (VALUES $placeholders)',
          variables: updateVars,
          updates: {syncSequenceLog},
        );
        await _refreshSequenceWatermarksAfterBulkResolved(affectedHosts);
        return updated;
      });
      totalRetired += pageRetired;
      if (pageRetired < pageSize) break;
    }
    return totalRetired;
  }

  /// Reset every unresolvable row back to `missing`, regardless of whether
  /// it has a known `entry_id`. Use this when the user explicitly wants to
  /// ask peers again for a host's entries — [resetUnresolvableWithKnownPayload]
  /// only covers rows that the local store has since repopulated, which
  /// excludes the common "dead originating host, but a currently-alive
  /// peer has the payload" case where the local row was flipped to
  /// `unresolvable` without ever receiving a hint.
  ///
  /// `request_count` is reset to 0 and `last_requested_at` cleared so the
  /// row rejoins the active backfill sweep; response processing will then
  /// fill in `entry_id` + flip status to `received`/`backfilled` if any
  /// peer answers.
  ///
  /// Returns the number of rows reset.
  Future<int> resetAllUnresolvableEntries() async {
    return transaction(() async {
      final affectedHosts = await _hostsForSequenceStatus(
        SyncSequenceStatus.unresolvable.index,
      );
      final updated = await customUpdate(
        'UPDATE sync_sequence_log '
        'SET status = ?, request_count = 0, '
        'last_requested_at = NULL, updated_at = ? '
        'WHERE status = ?',
        variables: [
          Variable.withInt(SyncSequenceStatus.missing.index),
          Variable.withDateTime(DateTime.now()),
          Variable.withInt(SyncSequenceStatus.unresolvable.index),
        ],
        updates: {syncSequenceLog},
      );
      await _rebuildSequenceWatermarksForHosts(affectedHosts);
      return updated;
    });
  }

  /// Reset entries that were incorrectly marked as unresolvable back to
  /// "missing" so they can be re-requested. Only resets entries that have
  /// a known payload (entryId IS NOT NULL), meaning repopulation found them.
  /// Returns the number of entries reset.
  Future<int> resetUnresolvableWithKnownPayload() async {
    return transaction(() async {
      final affectedHosts = await _hostsForSequenceStatus(
        SyncSequenceStatus.unresolvable.index,
        extraWhere: 'AND entry_id IS NOT NULL',
      );
      final updated = await customUpdate(
        'UPDATE sync_sequence_log '
        'SET status = ?, request_count = 0, '
        'last_requested_at = NULL, updated_at = ? '
        'WHERE status = ? AND entry_id IS NOT NULL',
        variables: [
          Variable.withInt(SyncSequenceStatus.missing.index),
          Variable.withDateTime(DateTime.now()),
          Variable.withInt(SyncSequenceStatus.unresolvable.index),
        ],
        updates: {syncSequenceLog},
      );
      await _rebuildSequenceWatermarksForHosts(affectedHosts);
      return updated;
    });
  }

  Future<Set<String>> _hostsForSequenceStatus(
    int status, {
    String extraWhere = '',
  }) async {
    final rows = await customSelect(
      'SELECT DISTINCT host_id FROM sync_sequence_log '
      'WHERE status = ? $extraWhere',
      variables: [Variable.withInt(status)],
      readsFrom: {syncSequenceLog},
    ).get();
    return {for (final row in rows) row.read<String>('host_id')};
  }
}
