part of 'sync_db.dart';

/// Contiguous-prefix watermark maintenance for the sync sequence log.
///
/// The watermark caches, per host, the highest counter `N` such that every
/// counter `1..N` is resolved (see [SyncSequenceStatusX.isResolved]). It is
/// persisted in the `sync_sequence_watermarks` side table so the hot-path
/// read in [getLastCounterForHost] is a primary-key lookup instead of the
/// full window-function CTE.
mixin _SyncDbSequenceWatermarks on _$SyncDatabase {
  /// Get the highest contiguous resolved counter for a given host, starting
  /// from counter `1`.
  ///
  /// Returns:
  /// - `null` when the host is entirely unknown to this device
  /// - `0` when the host is known but counter `1` is still unresolved
  /// - `N > 0` when every counter `1..N` is resolved or terminal
  ///
  /// This is intentionally not `MAX(counter)`. Gap detection must not advance
  /// past unresolved earlier counters just because a sparse newer row exists.
  Future<int?> getLastCounterForHost(String hostId) async {
    final cached = await _readSequenceWatermark(hostId);
    if (cached != null) return cached;

    // Older databases upgrade with an empty watermark table by design:
    // backfilling every host during migration would put the long CTE on the
    // first launch's critical path. Lazily compute a host once, persist it,
    // and keep subsequent hot-path reads to a primary-key lookup.
    // Pure backfill: this path runs only because no watermark row exists, so
    // it must not overwrite one a concurrent writer created meanwhile.
    return _rebuildSequenceWatermarkForHost(hostId, onlyIfAbsent: true);
  }

  Future<int?> _readSequenceWatermark(String hostId) async {
    final row = await customSelect(
      'SELECT last_counter FROM sync_sequence_watermarks WHERE host_id = ?',
      variables: [Variable.withString(hostId)],
      readsFrom: {syncSequenceLog},
    ).getSingleOrNull();
    return row?.read<int>('last_counter');
  }

  /// Persists [lastCounter] for [hostId].
  ///
  /// [onlyIfAbsent] makes the write a pure backfill: if a row already exists it
  /// is left alone. The lazy rebuild path needs that. It runs only when the
  /// watermark was missing, and both of its reads may be served by a read-pool
  /// isolate from a snapshot taken before a concurrent sequence-write
  /// transaction committed. Without this guard its unconditional upsert could
  /// land *after* that transaction and overwrite a newer watermark with the
  /// stale value it computed — e.g. persist 0 over a freshly resolved 1, after
  /// which gap detection re-requests counters already in hand.
  Future<void> _writeSequenceWatermark({
    required String hostId,
    required int lastCounter,
    bool onlyIfAbsent = false,
  }) async {
    await customUpdate(
      'INSERT INTO sync_sequence_watermarks '
      '(host_id, last_counter, updated_at) '
      'VALUES (?, ?, ?) '
      '${onlyIfAbsent ? 'ON CONFLICT(host_id) DO NOTHING' : 'ON CONFLICT(host_id) DO UPDATE SET '
                'last_counter = excluded.last_counter, '
                'updated_at = excluded.updated_at'}',
      variables: [
        Variable.withString(hostId),
        Variable.withInt(lastCounter),
        Variable.withInt(DateTime.now().millisecondsSinceEpoch ~/ 1000),
      ],
      updates: {syncSequenceLog},
    );
  }

  /// Recomputes the contiguous resolved prefix for [hostId] from the log.
  ///
  /// Two callers with opposite needs:
  ///
  /// - [getLastCounterForHost] uses [onlyIfAbsent] — it runs only when no
  ///   watermark row exists, so it is a backfill and must not clobber a row a
  ///   concurrent writer created in the meantime.
  /// - [_refreshSequenceWatermark] runs it *because* a previously resolved row
  ///   was reopened, which legitimately **lowers** the watermark, so it must
  ///   overwrite.
  Future<int?> _rebuildSequenceWatermarkForHost(
    String hostId, {
    bool onlyIfAbsent = false,
  }) async {
    // One-time compatibility path for existing rows that predate the
    // persisted watermark. Normal operation advances from the stored value
    // with [_advanceSequenceWatermarkForHost] instead of re-running this CTE.
    final row = await customSelect(
      '''
      WITH resolved_prefix AS (
        SELECT
          counter,
          ROW_NUMBER() OVER (ORDER BY counter) AS rn
        FROM sync_sequence_log
        WHERE host_id = ?
          AND status IN (0, 3, 4, 5, 8)
      )
      SELECT CASE
        WHEN NOT EXISTS (
          SELECT 1 FROM sync_sequence_log WHERE host_id = ? LIMIT 1
        ) THEN NULL
        ELSE COALESCE(
          (
            SELECT MAX(counter)
            FROM resolved_prefix
            WHERE counter = rn
          ),
          0
        )
      END AS last_counter
      ''',
      variables: [
        Variable.withString(hostId),
        Variable.withString(hostId),
      ],
      readsFrom: {syncSequenceLog},
    ).getSingle();

    final watermark = row.readNullable<int>('last_counter');
    if (watermark == null) return null;

    await _writeSequenceWatermark(
      onlyIfAbsent: onlyIfAbsent,
      hostId: hostId,
      lastCounter: watermark,
    );
    if (!onlyIfAbsent) return watermark;
    // Read back rather than returning the computed value: if a concurrent
    // sequence write persisted a watermark while this rebuild was running, the
    // backfill above deliberately left it alone, and that stored value is the
    // fresher of the two. The read is a primary-key lookup.
    return await _readSequenceWatermark(hostId) ?? watermark;
  }

  Future<void> _refreshSequenceWatermarkAfterMutation(
    SyncSequenceLogCompanion entry,
  ) async {
    if (!entry.hostId.present || !entry.counter.present) return;

    final hostId = entry.hostId.value;
    final counter = entry.counter.value;
    final status = entry.status.present
        ? entry.status.value
        : SyncSequenceStatus.received.index;
    await _refreshSequenceWatermark(
      hostId: hostId,
      counter: counter,
      status: status,
    );
  }

  Future<void> _refreshSequenceWatermark({
    required String hostId,
    required int counter,
    required int status,
  }) async {
    final current = await _readSequenceWatermark(hostId);
    if (current == null) {
      await _rebuildSequenceWatermarkForHost(hostId);
      return;
    }

    if (_isResolvedSequenceStatusIndex(status)) {
      if (counter == current + 1) {
        await _advanceSequenceWatermarkForHost(hostId, current);
      }
      return;
    }

    if (counter <= current) {
      await _rebuildSequenceWatermarkForHost(hostId);
    }
  }

  Future<void> _advanceSequenceWatermarkForHost(
    String hostId,
    int current,
  ) async {
    final row = await customSelect(
      '''
      WITH resolved_after AS (
        SELECT
          counter,
          ROW_NUMBER() OVER (ORDER BY counter) AS rn
        FROM sync_sequence_log
        WHERE host_id = ?
          AND counter > ?
          AND status IN (0, 3, 4, 5, 8)
      )
      SELECT COALESCE(
        (
          SELECT MAX(counter)
          FROM resolved_after
          WHERE counter = ? + rn
        ),
        ?
      ) AS last_counter
      ''',
      variables: [
        Variable.withString(hostId),
        Variable.withInt(current),
        Variable.withInt(current),
        Variable.withInt(current),
      ],
      readsFrom: {syncSequenceLog},
    ).getSingle();
    final next = row.read<int>('last_counter');
    if (next != current) {
      await _writeSequenceWatermark(hostId: hostId, lastCounter: next);
    }
  }

  Future<void> _refreshSequenceWatermarksAfterBulkResolved(
    Iterable<String> hostIds,
  ) async {
    for (final hostId in hostIds) {
      final current = await _readSequenceWatermark(hostId);
      if (current == null) {
        await _rebuildSequenceWatermarkForHost(hostId);
      } else {
        await _advanceSequenceWatermarkForHost(hostId, current);
      }
    }
  }

  Future<void> _rebuildSequenceWatermarksForHosts(
    Iterable<String> hostIds,
  ) async {
    for (final hostId in hostIds) {
      await _rebuildSequenceWatermarkForHost(hostId);
    }
  }
}
