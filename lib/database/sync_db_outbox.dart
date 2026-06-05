part of 'sync_db.dart';

final int _outboxSendingStatus = OutboxStatus.sending.index;

/// Outbox queue engine for [SyncDatabase]: enqueue, claim/lease,
/// mark-sent, watch/list surfaces, and counts.
///
/// Pruning lives in [_SyncDbOutboxPrune]; dedup lookups and volume/health
/// stats live in [_SyncDbOutboxDedup].
mixin _SyncDbOutbox on _$SyncDatabase {
  Future<int> updateOutboxItem(OutboxCompanion item) {
    return (update(
      outbox,
    )..where((t) => t.id.equals(item.id.value))).write(item);
  }

  Future<int> addOutboxItem(OutboxCompanion entry) {
    return into(outbox).insert(entry);
  }

  Future<List<OutboxItem>> get allOutboxItems => select(outbox).get();

  /// Get a single outbox item by its ID.
  /// Used to re-read an item before sending to ensure we have the latest
  /// message after potential merges.
  Future<OutboxItem?> getOutboxItemById(int id) {
    return (select(outbox)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<List<OutboxItem>> oldestOutboxItems(int limit) {
    return (select(outbox)
          ..where((t) => const CustomExpression<bool>('status = 0'))
          ..orderBy([
            (t) => OrderingTerm(expression: t.priority),
            (t) => OrderingTerm(expression: t.createdAt),
            (t) => OrderingTerm(expression: t.id),
          ])
          ..limit(limit))
        .get();
  }

  Future<OutboxItem?> claimNextOutboxItem({
    Duration leaseDuration = const Duration(minutes: 1),
    DateTime? now,
  }) async {
    final claimed = await claimNextOutboxBatch(
      maxSize: 1,
      leaseDuration: leaseDuration,
      now: now,
    );
    return claimed.isEmpty ? null : claimed.first;
  }

  /// Atomically claim a batch of consecutive outbox rows in priority, then
  /// createdAt order, transitioning each from `pending` (or an expired
  /// `sending` lease) to `sending` under one transaction.
  ///
  /// Boundary rule for `OutboxProcessor` bundling:
  ///  - If the head row has `filePath != null` (media attachment), the
  ///    returned list contains only that row. Media attachments always
  ///    travel alone.
  ///  - Otherwise, the returned list is the maximal prefix of consecutive
  ///    rows whose `filePath` is null, capped at [maxSize]. The walk stops
  ///    at the first media attachment, so the returned slice can be sent
  ///    as a single bundle envelope.
  ///
  /// If a CAS race causes any per-row update to fail mid-batch, the walk
  /// stops there. The returned list is always a contiguous prefix of the
  /// query order — never a non-contiguous gap, which would otherwise
  /// violate priority/createdAt send ordering.
  Future<List<OutboxItem>> claimNextOutboxBatch({
    required int maxSize,
    Duration leaseDuration = const Duration(minutes: 1),
    DateTime? now,
  }) async {
    if (maxSize <= 0) return const <OutboxItem>[];
    final effectiveNow = now ?? DateTime.now();
    final reclaimWindow = effectiveNow.subtract(leaseDuration);

    return transaction(() async {
      // Split the original `status = pending OR (status = sending AND
      // updated_at < cutoff)` into two indexed seeks. The combined
      // predicate prevented the planner from matching either of the
      // existing outbox indices and forced a SCAN (218 ms in the
      // super-slow log). Each branch is now a clean equality on
      // `status`. The merge in Dart is bounded by `2 × maxSize` rows;
      // trivial. The shared order matches
      // `OutboxRepository.claimNextBatch`: priority first, then
      // creation time, then id for stable media-boundary decisions.
      final pendingRows =
          await (select(outbox)
                ..where(
                  (t) => const CustomExpression<bool>('status = 0'),
                )
                ..orderBy([
                  (t) => OrderingTerm(expression: t.priority),
                  (t) => OrderingTerm(expression: t.createdAt),
                  (t) => OrderingTerm(expression: t.id),
                ])
                ..limit(maxSize))
              .get();
      final expiredSendingRows =
          await (select(outbox)
                ..where(
                  (t) =>
                      const CustomExpression<bool>('status = 3') &
                      t.updatedAt.isSmallerThanValue(reclaimWindow),
                )
                ..orderBy([
                  (t) => OrderingTerm(expression: t.priority),
                  (t) => OrderingTerm(expression: t.createdAt),
                  (t) => OrderingTerm(expression: t.id),
                ])
                ..limit(maxSize))
              .get();
      final candidates = <OutboxItem>[...pendingRows, ...expiredSendingRows]
        ..sort((a, b) {
          final priority = a.priority.compareTo(b.priority);
          if (priority != 0) return priority;
          final created = a.createdAt.compareTo(b.createdAt);
          if (created != 0) return created;
          return a.id.compareTo(b.id);
        });
      if (candidates.length > maxSize) {
        candidates.removeRange(maxSize, candidates.length);
      }

      if (candidates.isEmpty) return const <OutboxItem>[];

      final List<OutboxItem> selected;
      if (candidates.first.filePath != null) {
        selected = [candidates.first];
      } else {
        final stopAt = candidates.indexWhere(
          (row) => row.filePath != null,
        );
        selected = stopAt == -1 ? candidates : candidates.sublist(0, stopAt);
      }

      final claimed = <OutboxItem>[];
      for (final candidate in selected) {
        final updated =
            await (update(outbox)..where(
                  (t) =>
                      t.id.equals(candidate.id) &
                      t.status.equals(candidate.status) &
                      (candidate.status == _outboxSendingStatus
                          ? t.updatedAt.equals(candidate.updatedAt)
                          : const Constant(true)),
                ))
                .write(
                  OutboxCompanion(
                    status: Value(_outboxSendingStatus),
                    updatedAt: Value(effectiveNow),
                  ),
                );
        if (updated != 1) {
          break;
        }
        claimed.add(
          candidate.copyWith(
            status: _outboxSendingStatus,
            updatedAt: effectiveNow,
          ),
        );
      }

      return claimed;
    });
  }

  /// Bulk-set every row whose id is in [ids] to `sent`, stamping
  /// `updatedAt = now`. Single SQL `UPDATE … WHERE id IN (…)` instead of N
  /// per-row writes — used by `OutboxRepository.markSentBatch` after a
  /// bundle send succeeds.
  Future<void> markOutboxItemsSent({
    required List<int> ids,
    DateTime? now,
  }) async {
    if (ids.isEmpty) return;
    await (update(outbox)..where((t) => t.id.isIn(ids))).write(
      OutboxCompanion(
        status: Value(OutboxStatus.sent.index),
        updatedAt: Value(now ?? DateTime.now()),
      ),
    );
  }

  SimpleSelectStatement<$OutboxTable, OutboxItem> _outboxItemsQuery({
    required int limit,
    required List<OutboxStatus> statuses,
  }) {
    return select(outbox)
      ..where(
        (t) => t.status.isIn(
          statuses.map((OutboxStatus status) => status.index),
        ),
      )
      ..orderBy([
        // Actionable items (pending/sending) appear before completed ones
        // so they are never pushed outside the query limit by old sent rows.
        (t) => OrderingTerm(
          expression: CustomExpression<int>(
            'CASE WHEN status IN '
            '(${OutboxStatus.pending.index}, $_outboxSendingStatus) THEN 0 '
            'WHEN status = ${OutboxStatus.error.index} THEN 1 '
            'ELSE 2 END',
          ),
        ),
        (t) => OrderingTerm(expression: t.priority),
        (t) => OrderingTerm(
          expression: t.createdAt,
          mode: OrderingMode.desc,
        ),
        // Deterministic tie-breaker — without this, rows near the
        // limit boundary can swap places between refreshes when
        // priority and createdAt match. Matches the id tie-break used
        // in claimNextOutboxBatch().
        (t) => OrderingTerm(
          expression: t.id,
          mode: OrderingMode.desc,
        ),
      ])
      ..limit(limit);
  }

  Stream<List<OutboxItem>> watchOutboxItems({
    int limit = 1000,
    List<OutboxStatus> statuses = const [
      OutboxStatus.pending,
      OutboxStatus.sending,
      OutboxStatus.error,
      OutboxStatus.sent,
    ],
  }) {
    return _outboxItemsQuery(limit: limit, statuses: statuses).watch();
  }

  /// One-shot fetch with the same shape and ordering as [watchOutboxItems].
  /// Used by surfaces that explicitly opt out of the live watcher (e.g.
  /// the outbox monitor page, which would otherwise re-run a temp-B-tree
  /// sort on every sync write).
  Future<List<OutboxItem>> getOutboxItems({
    int limit = 1000,
    List<OutboxStatus> statuses = const [
      OutboxStatus.pending,
      OutboxStatus.sending,
      OutboxStatus.error,
      OutboxStatus.sent,
    ],
  }) {
    return _outboxItemsQuery(limit: limit, statuses: statuses).get();
  }

  /// Watches the count of actionable (pending + in-flight) outbox items.
  /// Used by the badge to show how many items still need to be sent.
  Stream<int> watchOutboxCount() {
    return customSelect(
      'SELECT COUNT(id) AS cnt FROM outbox '
      'WHERE status IN (?, ?)',
      variables: [
        Variable.withInt(OutboxStatus.pending.index),
        Variable.withInt(_outboxSendingStatus),
      ],
      readsFrom: {outbox},
    ).watchSingle().map((row) => row.read<int>('cnt'));
  }

  /// Delete a single outbox item by its ID.
  Future<int> deleteOutboxItemById(int id) {
    return (delete(outbox)..where((t) => t.id.equals(id))).go();
  }
}
