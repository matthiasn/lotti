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
  /// newest interaction first.
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
