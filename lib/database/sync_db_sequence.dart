part of 'sync_db.dart';

/// Sync sequence log domain for [SyncDatabase]: recording own/peer
/// counters, reservation/burn lifecycle markers, per-entry lookups,
/// host activity, and bulk inserts.
///
/// Backfill sweep queries and statistics live in [_SyncDbBackfill];
/// watermark maintenance lives in [_SyncDbSequenceWatermarks].
mixin _SyncDbSequenceLog on _$SyncDatabase, _SyncDbSequenceWatermarks {
  // ============ Sync Sequence Log Methods ============

  /// Record or update a sequence log entry.
  /// Uses insertOnConflictUpdate to handle upserts.
  Future<int> recordSequenceEntry(SyncSequenceLogCompanion entry) async {
    return transaction(() async {
      final result = await into(syncSequenceLog).insertOnConflictUpdate(entry);
      await _refreshSequenceWatermarkAfterMutation(entry);
      return result;
    });
  }

  /// Record that this host authoritatively burnt one of its own counters.
  ///
  /// The guard lives in the database layer so the authoritative-row check and
  /// write happen in one transaction. Rows already bound to a payload
  /// ([SyncSequenceStatus.received], [SyncSequenceStatus.backfilled], or
  /// [SyncSequenceStatus.deleted]) — and rows already
  /// [SyncSequenceStatus.burned] — are left untouched (the latter makes a
  /// repeat burn idempotent); other rows are converted to
  /// [SyncSequenceStatus.burned] (the authoritative non-event) with `entry_id`
  /// explicitly cleared. Returns whether a row was written.
  Future<bool> recordOwnUnresolvableSequenceCounter({
    required String hostId,
    required int counter,
    SyncSequencePayloadType payloadType = SyncSequencePayloadType.journalEntity,
    DateTime? now,
  }) async {
    final timestamp = now ?? clock.now();
    return transaction(() async {
      Future<bool> tryUpdateExisting() async {
        final updated =
            await (update(syncSequenceLog)..where(
                  (t) =>
                      t.hostId.equals(hostId) &
                      t.counter.equals(counter) &
                      t.status.isNotIn([
                        SyncSequenceStatus.received.index,
                        SyncSequenceStatus.backfilled.index,
                        SyncSequenceStatus.deleted.index,
                        SyncSequenceStatus.burned.index,
                      ]),
                ))
                .write(
                  SyncSequenceLogCompanion(
                    entryId: const Value(null),
                    payloadType: Value(payloadType.index),
                    status: Value(SyncSequenceStatus.burned.index),
                    updatedAt: Value(timestamp),
                  ),
                );
        if (updated == 0) return false;
        await _refreshSequenceWatermark(
          hostId: hostId,
          counter: counter,
          status: SyncSequenceStatus.burned.index,
        );
        return true;
      }

      if (await tryUpdateExisting()) return true;

      final inserted = await into(syncSequenceLog).insertReturningOrNull(
        SyncSequenceLogCompanion(
          hostId: Value(hostId),
          counter: Value(counter),
          entryId: const Value(null),
          payloadType: Value(payloadType.index),
          status: Value(SyncSequenceStatus.burned.index),
          createdAt: Value(timestamp),
          updatedAt: Value(timestamp),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      if (inserted != null) {
        await _refreshSequenceWatermark(
          hostId: hostId,
          counter: counter,
          status: SyncSequenceStatus.burned.index,
        );
        return true;
      }

      return tryUpdateExisting();
    });
  }

  /// Bind an own-host counter nothing has settled yet (no row, `reserved` or
  /// `burnPending`) to the payload that covers it. A row that is already
  /// bound or burned is left untouched, so a burn can never be reopened by a
  /// racing settlement. Returns whether the row is now bound by this call.
  Future<bool> bindUnsettledOwnSequenceCounter({
    required String hostId,
    required int counter,
    required String entryId,
    required SyncSequencePayloadType payloadType,
    DateTime? now,
  }) async {
    final timestamp = now ?? clock.now();
    return transaction(() async {
      // `insertReturningOrNull`, not `insert`: an ignored insert still reports
      // the connection's last rowid, so only a returned row proves one landed.
      final inserted = await into(syncSequenceLog).insertReturningOrNull(
        SyncSequenceLogCompanion(
          hostId: Value(hostId),
          counter: Value(counter),
          entryId: Value(entryId),
          payloadType: Value(payloadType.index),
          originatingHostId: Value(hostId),
          status: Value(SyncSequenceStatus.received.index),
          createdAt: Value(timestamp),
          updatedAt: Value(timestamp),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      final bound =
          inserted != null ||
          await (update(syncSequenceLog)..where(
                    (t) =>
                        t.hostId.equals(hostId) &
                        t.counter.equals(counter) &
                        t.status.isIn([
                          SyncSequenceStatus.reserved.index,
                          SyncSequenceStatus.burnPending.index,
                        ]),
                  ))
                  .write(
                    SyncSequenceLogCompanion(
                      entryId: Value(entryId),
                      payloadType: Value(payloadType.index),
                      originatingHostId: Value(hostId),
                      status: Value(SyncSequenceStatus.received.index),
                      updatedAt: Value(timestamp),
                    ),
                  ) !=
              0;
      if (bound) {
        await _refreshSequenceWatermark(
          hostId: hostId,
          counter: counter,
          status: SyncSequenceStatus.received.index,
        );
      }
      return bound;
    });
  }

  /// Record an own-host VC reservation before the counter is handed to a
  /// caller that may write to another database. The insert is intentionally
  /// `OR IGNORE`: a catch-up reservation must never clobber an already-bound
  /// sequence row if local state has advanced around a previously observed
  /// counter.
  ///
  /// [entryId] and [payloadType] name the payload the counter is for. On a
  /// `reserved` row they are an intent, not a binding: the row stays
  /// unresolved until the outbox binds it or it is settled.
  Future<int> recordReservedSequenceCounter({
    required String hostId,
    required int counter,
    String? entryId,
    SyncSequencePayloadType? payloadType,
    DateTime? now,
  }) async {
    final timestamp = now ?? clock.now();
    return transaction(() async {
      final inserted = await into(syncSequenceLog).insert(
        SyncSequenceLogCompanion(
          hostId: Value(hostId),
          counter: Value(counter),
          entryId: Value(entryId),
          payloadType: Value(
            (payloadType ?? SyncSequencePayloadType.journalEntity).index,
          ),
          status: Value(SyncSequenceStatus.reserved.index),
          createdAt: Value(timestamp),
          updatedAt: Value(timestamp),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      if (inserted != 0) {
        await _refreshSequenceWatermark(
          hostId: hostId,
          counter: counter,
          status: SyncSequenceStatus.reserved.index,
        );
      }
      return inserted;
    });
  }

  /// Return own-host reservations that have not yet been bound to a sync
  /// payload or explicitly released. These rows are diagnostic pre-bind
  /// markers only; startup reconciliation must use
  /// [burnPendingSequenceCountersForHost] for counters that are safe to
  /// convert to terminal unresolvable markers.
  Future<List<int>> reservedSequenceCountersForHost({
    required String hostId,
  }) => _sequenceCountersForHostWithStatus(
    hostId: hostId,
    status: SyncSequenceStatus.reserved,
  );

  /// Mark a released reservation whose settlement is still outstanding.
  /// Unlike [SyncSequenceStatus.reserved], no live write can still land this
  /// counter, so startup reconciliation may settle it: bind and resend it if
  /// its named payload covers the counter, burn it otherwise.
  ///
  /// [entryId] and [payloadType] record the reservation's payload when the row
  /// does not already name one; an existing intent is kept.
  Future<void> markReservedSequenceCounterBurnPending({
    required String hostId,
    required int counter,
    String? entryId,
    SyncSequencePayloadType? payloadType,
    DateTime? now,
  }) async {
    final timestamp = now ?? clock.now();
    await transaction(() async {
      final existing = await getEntryByHostAndCounter(hostId, counter);
      if (existing == null) {
        await into(syncSequenceLog).insert(
          SyncSequenceLogCompanion(
            hostId: Value(hostId),
            counter: Value(counter),
            entryId: Value(entryId),
            payloadType: Value(
              (payloadType ?? SyncSequencePayloadType.journalEntity).index,
            ),
            status: Value(SyncSequenceStatus.burnPending.index),
            createdAt: Value(timestamp),
            updatedAt: Value(timestamp),
          ),
        );
        await _refreshSequenceWatermark(
          hostId: hostId,
          counter: counter,
          status: SyncSequenceStatus.burnPending.index,
        );
        return;
      }

      if (existing.status != SyncSequenceStatus.reserved.index &&
          existing.status != SyncSequenceStatus.burnPending.index) {
        return;
      }

      final updated =
          await (update(syncSequenceLog)..where(
                (t) =>
                    t.hostId.equals(hostId) &
                    t.counter.equals(counter) &
                    t.status.isIn([
                      SyncSequenceStatus.reserved.index,
                      SyncSequenceStatus.burnPending.index,
                    ]),
              ))
              .write(
                SyncSequenceLogCompanion(
                  entryId: existing.entryId == null && entryId != null
                      ? Value(entryId)
                      : const Value.absent(),
                  payloadType: existing.entryId == null && entryId != null
                      ? Value(
                          (payloadType ?? SyncSequencePayloadType.journalEntity)
                              .index,
                        )
                      : const Value.absent(),
                  status: Value(SyncSequenceStatus.burnPending.index),
                  updatedAt: Value(timestamp),
                ),
              );
      if (updated != 0) {
        await _refreshSequenceWatermark(
          hostId: hostId,
          counter: counter,
          status: SyncSequenceStatus.burnPending.index,
        );
      }
    });
  }

  /// Return own-host reservations that were explicitly released but whose
  /// settlement (bind-and-resend or burn broadcast) has not completed.
  Future<List<int>> burnPendingSequenceCountersForHost({
    required String hostId,
  }) => _sequenceCountersForHostWithStatus(
    hostId: hostId,
    status: SyncSequenceStatus.burnPending,
  );

  /// Own-host counters startup reconciliation can settle without the process
  /// that reserved them: every `burnPending` row, and every `reserved` row
  /// that names its payload. An unnamed `reserved` row cannot be proven
  /// either way and is left out. Ascending counter order.
  Future<List<int>> settleableOwnSequenceCountersForHost({
    required String hostId,
  }) async {
    final burnPending = await burnPendingSequenceCountersForHost(
      hostId: hostId,
    );
    final namedReservations = await _sequenceCountersForHostWithStatus(
      hostId: hostId,
      status: SyncSequenceStatus.reserved,
      namedPayloadOnly: true,
    );
    return [...burnPending, ...namedReservations]..sort();
  }

  /// Both audit states are sparse. Prefer sorting that indexed subset over
  /// scanning every historical counter just to obtain counter ordering.
  Future<List<int>> _sequenceCountersForHostWithStatus({
    required String hostId,
    required SyncSequenceStatus status,
    bool namedPayloadOnly = false,
  }) async {
    final payloadFilter = namedPayloadOnly ? 'AND entry_id IS NOT NULL' : '';
    final rows = await customSelect(
      '''
      SELECT counter
      FROM sync_sequence_log INDEXED BY idx_sync_sequence_log_host_status
      WHERE host_id = ?
        AND status = ?
        $payloadFilter
      ORDER BY counter
      ''',
      variables: [
        Variable.withString(hostId),
        Variable.withInt(status.index),
      ],
      readsFrom: {syncSequenceLog},
    ).get();
    return [for (final row in rows) row.read<int>('counter')];
  }

  /// Update the status of a sequence log entry.
  Future<int> updateSequenceStatus(
    String hostId,
    int counter,
    SyncSequenceStatus status,
  ) async {
    return transaction(() async {
      final updated =
          await (update(syncSequenceLog)..where(
                (t) => t.hostId.equals(hostId) & t.counter.equals(counter),
              ))
              .write(
                SyncSequenceLogCompanion(
                  status: Value(status.index),
                  updatedAt: Value(clock.now()),
                ),
              );
      if (updated > 0) {
        await _refreshSequenceWatermark(
          hostId: hostId,
          counter: counter,
          status: status.index,
        );
      }
      return updated;
    });
  }

  /// Get a specific sequence log entry by host ID and counter.
  Future<SyncSequenceLogItem?> getEntryByHostAndCounter(
    String hostId,
    int counter,
  ) {
    return (select(syncSequenceLog)..where(
          (t) => t.hostId.equals(hostId) & t.counter.equals(counter),
        ))
        .getSingleOrNull();
  }

  /// Find the nearest sequence log entry for a host with a counter >= [counter]
  /// that has a locally resolved payload. Used to find covering entries when
  /// the exact counter is not in the sequence log (superseded).
  ///
  /// Only returns rows with `received` or `backfilled` status to avoid
  /// returning hint-only rows (where `entryId` is set but the payload may
  /// not exist locally yet).
  Future<SyncSequenceLogItem?> getNearestCoveringEntry(
    String hostId,
    int counter,
  ) {
    return (select(syncSequenceLog)
          ..where(
            (t) =>
                t.hostId.equals(hostId) &
                t.counter.isBiggerOrEqualValue(counter) &
                t.entryId.isNotNull() &
                (t.status.equals(SyncSequenceStatus.received.index) |
                    t.status.equals(SyncSequenceStatus.backfilled.index)),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.counter)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Get the highest counter sent by [hostId] for a given [entryId].
  /// Returns null when this host has never sent the entry.
  /// Used to build covered vector clocks for already-sent predecessors so
  /// that receivers can resolve intermediate counters without backfill.
  Future<int?> getLastSentCounterForEntry(String hostId, String entryId) async {
    final received = SyncSequenceStatus.received.index;
    final backfilled = SyncSequenceStatus.backfilled.index;
    // ORDER BY counter DESC LIMIT 1 resolves as an index-only scan against
    // `idx_sync_sequence_log_host_entry_status_counter` with early
    // termination on the first match, instead of scanning every row that
    // matches the prefix just to compute MAX(counter).
    final query = customSelect(
      '''
      SELECT counter AS last_counter
      FROM sync_sequence_log
      WHERE host_id = ?
        AND entry_id = ?
        AND status IN (?, ?)
      ORDER BY counter DESC
      LIMIT 1
      ''',
      variables: [
        Variable.withString(hostId),
        Variable.withString(entryId),
        Variable.withInt(received),
        Variable.withInt(backfilled),
      ],
      readsFrom: {syncSequenceLog},
    );
    final result = await query.getSingleOrNull();
    return result?.readNullable<int>('last_counter');
  }

  /// Get all pending (missing/requested) sequence log entries for a given payload.
  /// Used to resolve pending backfill hints when a payload arrives via sync.
  Future<List<SyncSequenceLogItem>> getPendingEntriesByPayloadId({
    required SyncSequencePayloadType payloadType,
    required String payloadId,
  }) {
    return (select(syncSequenceLog)..where(
          (t) =>
              t.entryId.equals(payloadId) &
              t.payloadType.equals(payloadType.index) &
              (t.status.equals(SyncSequenceStatus.missing.index) |
                  t.status.equals(SyncSequenceStatus.requested.index)),
        ))
        .get();
  }

  /// Removes counter-to-payload bindings that [payloadCounters] cannot prove.
  ///
  /// Historical payload/path races could bind a stable payload id to a counter
  /// ahead of the canonical payload's vector clock. Resolved rows are retired
  /// to [SyncSequenceStatus.unresolvable]; actionable rows keep their status so
  /// a genuine payload can still arrive, but lose the contradictory hint.
  /// Every invalid row also drops its `json_path` because that path belonged to
  /// the rejected binding. Returns the number of repaired rows.
  Future<int> retireInvalidPayloadMappings({
    required SyncSequencePayloadType payloadType,
    required String payloadId,
    required Map<String, int> payloadCounters,
    DateTime? now,
  }) async {
    final timestamp = now ?? clock.now();
    return transaction(() async {
      // Own-host `reserved` and `burnPending` rows name their payload as an
      // intent, not a binding. Their counter may be ahead of the payload
      // because the write has not landed yet; clearing the intent would leave
      // the reservation impossible to settle.
      final rows =
          await (select(syncSequenceLog)..where(
                (t) =>
                    t.entryId.equals(payloadId) &
                    t.payloadType.equals(payloadType.index) &
                    t.status.isNotIn([
                      SyncSequenceStatus.reserved.index,
                      SyncSequenceStatus.burnPending.index,
                    ]),
              ))
              .get();
      final invalid = rows
          .where((row) {
            final payloadCounter = payloadCounters[row.hostId];
            return payloadCounter == null || payloadCounter < row.counter;
          })
          .toList(growable: false);
      if (invalid.isEmpty) return 0;

      await batch((batch) {
        for (final row in invalid) {
          final currentStatus = SyncSequenceStatus.values[row.status];
          final repairedStatus = switch (currentStatus) {
            SyncSequenceStatus.received ||
            SyncSequenceStatus.backfilled => SyncSequenceStatus.unresolvable,
            _ => currentStatus,
          };
          batch.update(
            syncSequenceLog,
            SyncSequenceLogCompanion(
              entryId: const Value(null),
              jsonPath: const Value(null),
              status: Value(repairedStatus.index),
              updatedAt: Value(timestamp),
            ),
            where: (t) =>
                t.hostId.equals(row.hostId) & t.counter.equals(row.counter),
          );
        }
      });
      return invalid.length;
    });
  }

  /// Get the total count of entries in the sequence log.
  Future<int> getSequenceLogCount() async {
    final countQuery = selectOnly(syncSequenceLog)
      ..addColumns([syncSequenceLog.hostId.count()]);
    final countResult = await countQuery.getSingle();
    return countResult.read(syncSequenceLog.hostId.count()) ?? 0;
  }

  // ============ Host Activity Methods ============

  /// Update or insert host activity (last seen timestamp).
  Future<int> updateHostActivity(String hostId, DateTime lastSeenAt) {
    return into(hostActivity).insertOnConflictUpdate(
      HostActivityCompanion(
        hostId: Value(hostId),
        lastSeenAt: Value(lastSeenAt),
      ),
    );
  }

  /// Get the last seen timestamp for a host.
  Future<DateTime?> getHostLastSeen(String hostId) async {
    final result = await (select(
      hostActivity,
    )..where((t) => t.hostId.equals(hostId))).getSingleOrNull();
    return result?.lastSeenAt;
  }

  /// Get all existing counters for a specific host.
  /// Used for efficient bulk population to avoid N+1 queries.
  Future<Set<int>> getCountersForHost(String hostId) async {
    final entries = await (select(
      syncSequenceLog,
    )..where((t) => t.hostId.equals(hostId))).map((row) => row.counter).get();
    return entries.toSet();
  }

  /// Get existing counters for a specific host within an inclusive range.
  /// Used to materialize large gaps without doing one lookup per counter.
  Future<Set<int>> getCountersForHostInRange(
    String hostId,
    int startCounter,
    int endCounter,
  ) async {
    if (endCounter < startCounter) return <int>{};
    final entries =
        await (select(syncSequenceLog)..where(
              (t) =>
                  t.hostId.equals(hostId) &
                  t.counter.isBiggerOrEqualValue(startCounter) &
                  t.counter.isSmallerOrEqualValue(endCounter),
            ))
            .map((row) => row.counter)
            .get();
    return entries.toSet();
  }

  /// Batch insert multiple sequence log entries.
  Future<void> batchInsertSequenceEntries(
    List<SyncSequenceLogCompanion> entries,
  ) async {
    final affectedHosts = <String>{};
    for (final entry in entries) {
      if (entry.hostId.present) {
        affectedHosts.add(entry.hostId.value);
      }
    }
    await transaction(() async {
      await batch((b) {
        b.insertAll(syncSequenceLog, entries, mode: InsertMode.insertOrIgnore);
      });
      await _refreshSequenceWatermarksAfterBulkResolved(affectedHosts);
    });
  }
}
