part of 'database.dart';

/// Goal query surface for [JournalDb].
///
/// Goals and their immutable spec snapshots share the `Goal` row type and are
/// told apart by the denormalized `subtype` column: empty on a goal, the owning
/// goal's id on a snapshot (the habit-completion precedent, no schema change).
/// Both queries therefore ride the existing `idx_journal_type_subtype` index.
mixin _JournalDbGoalQueries on _$JournalDb, _JournalDbConfigFlags {
  /// Every non-deleted goal, newest first. Spec snapshots are excluded — they
  /// are the version history of a goal, not goals in their own right.
  Future<List<GoalEntry>> getGoals() async {
    final rows = await _queryWithPrivateFilter(
      allPrivate: () => _goalRows().get(),
      filtered: (statuses) => _goalRows(privateStatuses: statuses).get(),
    );
    return rows.map(fromDbEntity).whereType<GoalEntry>().toList();
  }

  /// The immutable spec snapshots belonging to [goalId], newest version first.
  Future<List<GoalEntry>> getSpecSnapshotsForGoal(String goalId) async {
    final rows = await _queryWithPrivateFilter(
      allPrivate: () => _goalSnapshotRows(goalId).get(),
      filtered: (statuses) =>
          _goalSnapshotRows(goalId, privateStatuses: statuses).get(),
    );
    return rows.map(fromDbEntity).whereType<GoalEntry>().toList();
  }

  SimpleSelectStatement<Journal, JournalDbEntity> _goalRows({
    List<bool>? privateStatuses,
  }) {
    return select(journal)
      ..where((t) {
        var predicate =
            t.type.equals('Goal') &
            // A goal carries no subtype; a snapshot carries its goal's id.
            t.subtype.equals('') &
            t.deleted.equals(false);
        if (privateStatuses != null) {
          predicate = predicate & t.private.isIn(privateStatuses);
        }
        return predicate;
      })
      ..orderBy([(t) => OrderingTerm.desc(t.dateFrom)]);
  }

  SimpleSelectStatement<Journal, JournalDbEntity> _goalSnapshotRows(
    String goalId, {
    List<bool>? privateStatuses,
  }) {
    return select(journal)
      ..where((t) {
        var predicate =
            t.type.equals('Goal') &
            t.subtype.equals(goalId) &
            t.deleted.equals(false);
        if (privateStatuses != null) {
          predicate = predicate & t.private.isIn(privateStatuses);
        }
        return predicate;
      })
      ..orderBy([(t) => OrderingTerm.desc(t.dateFrom)]);
  }
}
