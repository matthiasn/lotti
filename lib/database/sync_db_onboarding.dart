part of 'sync_db.dart';

/// Durable onboarding-round leases and authoritative terminal-counter
/// convergence. Protocol orchestration lives in `OnboardingSyncService`; this
/// mixin keeps its persistence and sequence mutations atomic.
mixin _SyncDbOnboarding on _$SyncDatabase, _SyncDbSequenceWatermarks {
  /// Highest resolved sequence counter known for every origin host. These
  /// bounds describe the history snapshot being staged during onboarding;
  /// gaps inside a bound are repaired after the bounded suppression ends.
  Future<Map<String, int>> resolvedSequenceUpperBounds() async {
    final rows = await customSelect(
      'SELECT host_id, MAX(counter) AS upper_bound '
      'FROM sync_sequence_log '
      'WHERE status IN (?, ?, ?, ?, ?) '
      'GROUP BY host_id',
      variables: [
        Variable<int>(SyncSequenceStatus.received.index),
        Variable<int>(SyncSequenceStatus.backfilled.index),
        Variable<int>(SyncSequenceStatus.deleted.index),
        Variable<int>(SyncSequenceStatus.unresolvable.index),
        Variable<int>(SyncSequenceStatus.burned.index),
      ],
      readsFrom: {syncSequenceLog},
    ).get();
    return {
      for (final row in rows)
        if (row.read<String>('host_id').isNotEmpty)
          row.read<String>('host_id'): row.read<int>('upper_bound'),
    };
  }

  Future<int> upsertOnboardingSyncRound(
    OnboardingSyncRoundsCompanion round,
  ) {
    return into(onboardingSyncRounds).insertOnConflictUpdate(round);
  }

  Future<OnboardingSyncRoundItem?> onboardingSyncRound(String roundId) {
    return (select(
      onboardingSyncRounds,
    )..where((t) => t.roundId.equals(roundId))).getSingleOrNull();
  }

  Future<int> updateOnboardingSyncRound(
    String roundId,
    OnboardingSyncRoundsCompanion changes,
  ) {
    return (update(
      onboardingSyncRounds,
    )..where((t) => t.roundId.equals(roundId))).write(changes);
  }

  Future<bool> hasActiveInboundOnboardingSyncPreflight({
    required DateTime now,
  }) async {
    final row =
        await (select(onboardingSyncRounds)
              ..where(
                (t) =>
                    t.direction.equals('inbound') &
                    t.state.equals('awaitingBegin') &
                    t.expiresAt.isBiggerThanValue(now),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  Future<int> adoptInboundOnboardingSyncPreflights({
    required String recipientUserId,
    required DateTime now,
  }) {
    return (update(onboardingSyncRounds)..where(
          (t) =>
              t.direction.equals('inbound') &
              t.state.equals('awaitingBegin') &
              t.recipientUserId.equals(recipientUserId) &
              t.expiresAt.isBiggerThanValue(now),
        ))
        .write(
          OnboardingSyncRoundsCompanion(
            state: const Value('adopted'),
            updatedAt: Value(now),
          ),
        );
  }

  /// Installs the sender's bounded range lease and closes any provisional
  /// receiver gate in one transaction. This prevents a restart between those
  /// mutations from leaving a blanket preflight active after the range lease
  /// has already completed.
  Future<void> installInboundOnboardingSyncRound({
    required OnboardingSyncRoundsCompanion round,
    required String recipientUserId,
    required DateTime now,
  }) async {
    await transaction(() async {
      await into(onboardingSyncRounds).insertOnConflictUpdate(round);
      await adoptInboundOnboardingSyncPreflights(
        recipientUserId: recipientUserId,
        now: now,
      );
    });
  }

  Future<List<OnboardingSyncRoundItem>> activeInboundOnboardingSyncRounds({
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    return (select(onboardingSyncRounds)
          ..where(
            (t) =>
                t.direction.equals('inbound') &
                t.state.isIn(const ['active', 'aborted']) &
                t.expiresAt.isBiggerThanValue(effectiveNow),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.startedAt)]))
        .get();
  }

  Future<List<OnboardingSyncRoundItem>> activeOutboundOnboardingSyncRounds({
    required String recipientHostId,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    return (select(onboardingSyncRounds)..where(
          (t) =>
              t.direction.equals('outbound') &
              t.state.isIn(const ['active', 'ending', 'aborted']) &
              t.recipientHostId.equals(recipientHostId) &
              t.expiresAt.isBiggerThanValue(effectiveNow),
        ))
        .get();
  }

  Future<List<int>> burnedSequenceCountersForHost({
    required String hostId,
    required int upperBound,
  }) async {
    if (upperBound < 0) return const [];
    final rows =
        await (select(syncSequenceLog)
              ..where(
                (t) =>
                    t.hostId.equals(hostId) &
                    t.status.equals(SyncSequenceStatus.burned.index) &
                    t.counter.isSmallerOrEqualValue(upperBound),
              )
              ..orderBy([(t) => OrderingTerm(expression: t.counter)]))
            .get();
    return [for (final row in rows) row.counter];
  }

  /// Apply an originator's authoritative burned-counter manifest in one
  /// transaction. Payload-backed terminal states win over a contradictory
  /// burn; missing/requested/receiver-unresolvable rows become burned.
  Future<void> applyAuthoritativeBurnedCounters({
    required String hostId,
    required Iterable<int> counters,
    DateTime? now,
  }) async {
    final uniqueCounters = counters.toSet().toList()..sort();
    if (uniqueCounters.isEmpty) return;
    final timestamp = now ?? DateTime.now();
    final timestampSeconds = timestamp.millisecondsSinceEpoch ~/ 1000;

    await transaction(() async {
      await batch((b) {
        for (final counter in uniqueCounters) {
          b.customStatement(
            'INSERT INTO sync_sequence_log ( '
            'host_id, counter, entry_id, payload_type, originating_host_id, '
            'status, created_at, updated_at, request_count, '
            'last_requested_at, json_path '
            ') VALUES (?, ?, NULL, ?, ?, ?, ?, ?, 0, NULL, NULL) '
            'ON CONFLICT(host_id, counter) DO UPDATE SET '
            'entry_id = NULL, '
            'payload_type = excluded.payload_type, '
            'originating_host_id = excluded.originating_host_id, '
            'status = excluded.status, '
            'updated_at = excluded.updated_at '
            'WHERE sync_sequence_log.status NOT IN (?, ?, ?, ?)',
            [
              hostId,
              counter,
              SyncSequencePayloadType.journalEntity.index,
              hostId,
              SyncSequenceStatus.burned.index,
              timestampSeconds,
              timestampSeconds,
              SyncSequenceStatus.received.index,
              SyncSequenceStatus.backfilled.index,
              SyncSequenceStatus.deleted.index,
              SyncSequenceStatus.burned.index,
            ],
            [TableUpdate.onTable(syncSequenceLog, kind: UpdateKind.update)],
          );
        }
      });
      await _refreshSequenceWatermarksAfterBulkResolved({hostId});
    });
  }
}
