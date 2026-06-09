part of 'database.dart';

/// Heavy task-query builders for [JournalDb] (split from
/// [_JournalDbTaskQueries] for file size): the due-date query assembly and
/// the main filtered task SELECT. Kept as a sibling mixin so the public task
/// query methods can call into them via the `on` clause.
mixin _JournalDbTaskQueriesBuilders on _$JournalDb, _JournalDbConfigFlags {
  Future<List<JournalDbEntity>> _buildTasksByDueDateQuery({
    required List<bool> starredStatuses,
    required List<bool> privateStatuses,
    required List<String> taskStatuses,
    required List<String> categoryIds,
    List<String>? labelIds,
    List<String>? priorities,
    List<String>? ids,
    int limit = 500,
    int offset = 0,
  }) {
    if (taskStatuses.isEmpty ||
        categoryIds.isEmpty ||
        (ids != null && ids.isEmpty)) {
      return Future.value([]);
    }

    final variables = <Variable<Object>>[];
    final buf = StringBuffer()
      // No INDEXED BY pin: with the denormalized `due_at` column the
      // planner reliably picks `idx_journal_tasks_due_open` for the
      // open-task subset and otherwise streams from the priority/date
      // task indexes. Pinning here is no longer necessary.
      ..write('SELECT * FROM journal ')
      ..write("WHERE type = 'Task' AND task = 1 AND deleted = 0 ")
      // Task statuses
      ..write('AND task_status IN (');
    for (var i = 0; i < taskStatuses.length; i++) {
      if (i > 0) buf.write(', ');
      variables.add(Variable<String>(taskStatuses[i]));
      buf.write('?${variables.length}');
    }
    buf
      ..write(') ')
      // Categories
      ..write('AND category IN (');
    for (var i = 0; i < categoryIds.length; i++) {
      if (i > 0) buf.write(', ');
      variables.add(Variable<String>(categoryIds[i]));
      buf.write('?${variables.length}');
    }
    buf.write(') ');

    // Starred
    final matchesAllStarred =
        starredStatuses.length == 2 &&
        starredStatuses.contains(true) &&
        starredStatuses.contains(false);
    if (!matchesAllStarred) {
      buf.write('AND starred IN (');
      for (var i = 0; i < starredStatuses.length; i++) {
        if (i > 0) buf.write(', ');
        variables.add(Variable<bool>(starredStatuses[i]));
        buf.write('?${variables.length}');
      }
      buf.write(') ');
    }

    // Private
    final matchesAllPrivate = _matchesAllPrivateStates(privateStatuses);
    if (!matchesAllPrivate) {
      buf.write('AND private IN (');
      for (var i = 0; i < privateStatuses.length; i++) {
        if (i > 0) buf.write(', ');
        variables.add(Variable<bool>(privateStatuses[i]));
        buf.write('?${variables.length}');
      }
      buf.write(') ');
    }

    // FTS ids filter
    if (ids != null && ids.isNotEmpty) {
      buf.write('AND id IN (');
      for (var i = 0; i < ids.length; i++) {
        if (i > 0) buf.write(', ');
        variables.add(Variable<String>(ids[i]));
        buf.write('?${variables.length}');
      }
      buf.write(') ');
    }

    // Labels (via the labeled join table, matching _selectTasks semantics)
    final selectedLabelIds = labelIds ?? <String>[];
    final includeUnlabeled = selectedLabelIds.contains('');
    final filteredLabelIds = selectedLabelIds
        .where((id) => id.isNotEmpty)
        .toList();
    if (includeUnlabeled || filteredLabelIds.isNotEmpty) {
      final conditions = <String>[];
      if (includeUnlabeled) {
        conditions.add(
          'NOT EXISTS (SELECT 1 FROM labeled '
          'WHERE journal_id = journal.id)',
        );
      }
      if (filteredLabelIds.isNotEmpty) {
        final placeholders = <String>[];
        for (final id in filteredLabelIds) {
          variables.add(Variable<String>(id));
          placeholders.add('?${variables.length}');
        }
        conditions.add(
          'EXISTS (SELECT 1 FROM labeled '
          'WHERE journal_id = journal.id '
          'AND label_id IN (${placeholders.join(", ")}))',
        );
      }
      buf.write('AND (${conditions.join(" OR ")}) ');
    }

    // Priorities
    if (priorities != null && priorities.isNotEmpty) {
      buf.write('AND task_priority IN (');
      for (var i = 0; i < priorities.length; i++) {
        if (i > 0) buf.write(', ');
        variables.add(Variable<String>(priorities[i]));
        buf.write('?${variables.length}');
      }
      buf.write(') ');
    }

    // Order: due date ASC (nulls last), then date_from DESC as tiebreaker.
    // Reads `due_at` directly — the v41 backfill populated the column for
    // every task with a non-null `data.due`, regardless of status, so
    // closed-task ordering is correct from the moment the migration
    // completes.
    buf
      ..write(
        'ORDER BY CASE WHEN due_at IS NULL THEN 1 ELSE 0 END, '
        'due_at ASC, '
        'date_from DESC ',
      )
      ..write('LIMIT ')
      ..write(limit)
      ..write(' OFFSET ')
      ..write(offset);

    return customSelect(
      buf.toString(),
      variables: variables,
      readsFrom: {journal, labeled},
    ).asyncMap(journal.mapFromRow).get();
  }

  Selectable<JournalDbEntity> _selectTasks({
    required List<bool> starredStatuses,
    required List<bool> privateStatuses,
    required List<String> taskStatuses,
    required List<String> categoryIds,
    List<String>? labelIds,
    List<String>? priorities,
    List<String>? ids,
    bool sortByDate = false,
    int limit = 500,
    int offset = 0,
  }) {
    if (taskStatuses.isEmpty || categoryIds.isEmpty) {
      return emptyJournalSelection();
    }

    final matchesAllStarredStates =
        starredStatuses.length == 2 &&
        starredStatuses.contains(true) &&
        starredStatuses.contains(false);
    final matchesAllPrivateStates = _matchesAllPrivateStates(privateStatuses);
    final selectedLabelIds = labelIds ?? <String>[];
    final includeUnlabeled = selectedLabelIds.contains('');
    final filteredLabelIds = selectedLabelIds
        .where((id) => id.isNotEmpty)
        .toList();
    final labelFilterCount = filteredLabelIds.length;
    final filterByLabels = includeUnlabeled || labelFilterCount > 0;
    final dbTaskStatuses = taskStatuses.cast<String?>();
    final selectedPriorities = priorities ?? <String>[];
    final filterByPriorities = selectedPriorities.isNotEmpty;
    final dbSelectedPriorities = selectedPriorities.cast<String?>();

    if (ids == null && matchesAllPrivateStates && matchesAllStarredStates) {
      if (!filterByLabels) {
        if (sortByDate) {
          return filterByPriorities
              ? filteredTasksByDateFastAllPrivateAllStarredWithPriorities(
                  dbTaskStatuses,
                  categoryIds,
                  dbSelectedPriorities,
                  limit,
                  offset,
                )
              : filteredTasksByDateFastAllPrivateAllStarred(
                  dbTaskStatuses,
                  categoryIds,
                  limit,
                  offset,
                );
        }

        return filterByPriorities
            ? filteredTasksFastAllPrivateAllStarredWithPriorities(
                dbTaskStatuses,
                categoryIds,
                dbSelectedPriorities,
                limit,
                offset,
              )
            : filteredTasksFastAllPrivateAllStarred(
                dbTaskStatuses,
                categoryIds,
                limit,
                offset,
              );
      }

      final effectiveLabelIds = labelFilterCount == 0
          ? <String>['__no_label__']
          : filteredLabelIds;
      final effectivePriorities = filterByPriorities
          ? selectedPriorities
          : <String>['__no_priority__'];
      final dbPriorities = effectivePriorities.cast<String?>();

      return sortByDate
          ? filteredTasksByDateAllPrivateAllStarred(
              dbTaskStatuses,
              categoryIds,
              filterByLabels,
              labelFilterCount,
              effectiveLabelIds,
              includeUnlabeled,
              filterByPriorities,
              selectedPriorities.length,
              dbPriorities,
              limit,
              offset,
            )
          : filteredTasksAllPrivateAllStarred(
              dbTaskStatuses,
              categoryIds,
              filterByLabels,
              labelFilterCount,
              effectiveLabelIds,
              includeUnlabeled,
              filterByPriorities,
              selectedPriorities.length,
              dbPriorities,
              limit,
              offset,
            );
    }

    if (ids == null && !filterByLabels) {
      if (sortByDate) {
        return filterByPriorities
            ? filteredTasksByDateFastWithPriorities(
                privateStatuses,
                starredStatuses,
                dbTaskStatuses,
                categoryIds,
                dbSelectedPriorities,
                limit,
                offset,
              )
            : filteredTasksByDateFast(
                privateStatuses,
                starredStatuses,
                dbTaskStatuses,
                categoryIds,
                limit,
                offset,
              );
      }

      return filterByPriorities
          ? filteredTasksFastWithPriorities(
              privateStatuses,
              starredStatuses,
              dbTaskStatuses,
              categoryIds,
              dbSelectedPriorities,
              limit,
              offset,
            )
          : filteredTasksFast(
              privateStatuses,
              starredStatuses,
              dbTaskStatuses,
              categoryIds,
              limit,
              offset,
            );
    }

    // Avoid passing an empty list to the SQL `IN (:labelIds)` clause.
    // SQLite (and SQL generally) does not allow an empty `IN ()`, so we
    // substitute a dummy value when no label IDs are selected. The query
    // never matches this magic string; it only keeps the SQL valid.
    final effectiveLabelIds = labelFilterCount == 0
        ? <String>['__no_label__']
        : filteredLabelIds;
    // Keep the generated SQL valid when no priorities are selected. Drift
    // still expands list parameters even when the CASE guard disables the
    // priority branch, so passing an empty list would yield `IN ()`.
    final effectivePriorities = filterByPriorities
        ? selectedPriorities
        : <String>['__no_priority__'];
    final dbPriorities = effectivePriorities.cast<String?>();

    if (ids != null) {
      // Use date-sorted or priority-sorted query based on sortByDate flag
      return sortByDate
          ? filteredTasksByDate2(
              ids,
              privateStatuses,
              starredStatuses,
              dbTaskStatuses,
              categoryIds,
              filterByLabels,
              labelFilterCount,
              effectiveLabelIds,
              includeUnlabeled,
              filterByPriorities,
              selectedPriorities.length,
              dbPriorities,
              limit,
              offset,
            )
          : filteredTasks2(
              ids,
              privateStatuses,
              starredStatuses,
              dbTaskStatuses,
              categoryIds,
              filterByLabels,
              labelFilterCount,
              effectiveLabelIds,
              includeUnlabeled,
              filterByPriorities,
              selectedPriorities.length,
              dbPriorities,
              limit,
              offset,
            );
    } else {
      // Use date-sorted or priority-sorted query based on sortByDate flag
      return sortByDate
          ? filteredTasksByDate(
              privateStatuses,
              starredStatuses,
              dbTaskStatuses,
              categoryIds,
              filterByLabels,
              labelFilterCount,
              effectiveLabelIds,
              includeUnlabeled,
              filterByPriorities,
              selectedPriorities.length,
              dbPriorities,
              limit,
              offset,
            )
          : filteredTasks(
              privateStatuses,
              starredStatuses,
              dbTaskStatuses,
              categoryIds,
              filterByLabels,
              labelFilterCount,
              effectiveLabelIds,
              includeUnlabeled,
              filterByPriorities,
              selectedPriorities.length,
              dbPriorities,
              limit,
              offset,
            );
    }
  }
}
