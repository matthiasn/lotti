part of 'database.dart';

/// Relationship query surface for [JournalDb]: relationship lists and
/// check-in resolution via the denormalized `subtype` column (which carries
/// the owning relationship id for `CheckIn` rows, the habit-completion
/// precedent — no schema change, ADR 0038 decision 4).
mixin _JournalDbRelationshipQueries on _$JournalDb, _JournalDbConfigFlags {
  /// Returns all non-deleted relationships, newest tracking start first.
  Future<List<RelationshipEntry>> getRelationships() async {
    final rows = await _queryWithPrivateFilter(
      allPrivate: () => _relationshipRows().get(),
      filtered: (statuses) =>
          _relationshipRows(privateStatuses: statuses).get(),
    );
    return rows.map(fromDbEntity).whereType<RelationshipEntry>().toList();
  }

  /// Returns all non-deleted check-ins belonging to [relationshipId],
  /// newest interaction first. Respects the private-entry filter — this is a
  /// display query. A *mutation* over the same set must use
  /// [getAllCheckInsForRelationship] instead.
  Future<List<CheckInEntry>> getCheckInsForRelationship(
    String relationshipId,
  ) async {
    final rows = await _queryWithPrivateFilter(
      allPrivate: () => _checkInRows(relationshipId).get(),
      filtered: (statuses) =>
          _checkInRows(relationshipId, privateStatuses: statuses).get(),
    );
    return rows.map(fromDbEntity).whereType<CheckInEntry>().toList();
  }

  /// Every non-deleted check-in belonging to [relationshipId], private ones
  /// included — the delete cascade's view of the person's data.
  ///
  /// Deliberately NOT private-filtered: "Show private entries" is a display
  /// preference, and scoping a deletion by it would tombstone the person
  /// while leaving their private check-ins live and syncing, with no live
  /// relationship left to reach them from (ADR 0037 §5).
  Future<List<CheckInEntry>> getAllCheckInsForRelationship(
    String relationshipId,
  ) async {
    final rows = await _checkInRows(relationshipId).get();
    return rows.map(fromDbEntity).whereType<CheckInEntry>().toList();
  }

  /// The most recent non-deleted check-in time per relationship id — one
  /// `GROUP BY subtype` aggregate over the denormalized check-in rows, so
  /// list recency ordering needs no per-relationship queries. Respects the
  /// private-entry filter: hidden check-ins don't leak into recency.
  Future<Map<String, DateTime>> latestCheckInTimes() async {
    final latest = journal.dateFrom.max();

    Future<List<TypedResult>> run({List<bool>? privateStatuses}) {
      var predicate =
          journal.type.equals('CheckIn') & journal.deleted.equals(false);
      if (privateStatuses != null) {
        predicate = predicate & journal.private.isIn(privateStatuses);
      }
      final query = selectOnly(journal)
        ..addColumns([journal.subtype, latest])
        ..where(predicate)
        ..groupBy([journal.subtype]);
      return query.get();
    }

    final rows = await _queryWithPrivateFilter(
      allPrivate: run,
      filtered: (statuses) => run(privateStatuses: statuses),
    );
    return {
      for (final row in rows)
        if (row.read(journal.subtype) != null && row.read(latest) != null)
          row.read(journal.subtype)!: row.read(latest)!,
    };
  }

  /// The live tasks among [ids], for resolving a relationship's linked
  /// tasks. Relationship → check-in and relationship → task links share the
  /// `RelationshipLink` type, so the caller cannot tell them apart from the
  /// link rows alone; filtering on the indexed `type` column here means a
  /// person's whole check-in history is never deserialized only to be
  /// discarded. Respects the private-entry filter.
  Future<List<Task>> getLiveTasksByIds(Set<String> ids) async {
    if (ids.isEmpty) return const [];
    final idList = ids.toList(growable: false);

    Future<List<JournalDbEntity>> run({List<bool>? privateStatuses}) {
      return (select(journal)..where((t) {
            var predicate =
                t.id.isIn(idList) &
                t.type.equals('Task') &
                t.task.equals(true) &
                t.deleted.equals(false);
            if (privateStatuses != null) {
              predicate = predicate & t.private.isIn(privateStatuses);
            }
            return predicate;
          }))
          .get();
    }

    final rows = await _queryWithPrivateFilter(
      allPrivate: run,
      filtered: (statuses) => run(privateStatuses: statuses),
    );
    return rows.map(fromDbEntity).whereType<Task>().toList();
  }

  SimpleSelectStatement<Journal, JournalDbEntity> _relationshipRows({
    List<bool>? privateStatuses,
  }) {
    return select(journal)
      ..where((t) {
        var predicate = t.type.equals('Relationship') & t.deleted.equals(false);
        if (privateStatuses != null) {
          predicate = predicate & t.private.isIn(privateStatuses);
        }
        return predicate;
      })
      ..orderBy([(t) => OrderingTerm.desc(t.dateFrom)]);
  }

  SimpleSelectStatement<Journal, JournalDbEntity> _checkInRows(
    String relationshipId, {
    List<bool>? privateStatuses,
  }) {
    return select(journal)
      ..where((t) {
        var predicate =
            t.type.equals('CheckIn') &
            t.subtype.equals(relationshipId) &
            t.deleted.equals(false);
        if (privateStatuses != null) {
          predicate = predicate & t.private.isIn(privateStatuses);
        }
        return predicate;
      })
      ..orderBy([(t) => OrderingTerm.desc(t.dateFrom)]);
  }
}
