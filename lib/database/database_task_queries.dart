part of 'database.dart';

/// Task list query surface for [JournalDb]: filtered task lists (by
/// status, category, label, priority, starred, FTS ids), due-date
/// ordering, task counts, and the filtered-count/id helpers.
///
/// Due-date *range* reads and day-agent selects live in
/// [_JournalDbTaskDueQueries].
mixin _JournalDbTaskQueries on _$JournalDb, _JournalDbConfigFlags {
  Future<void> updateTaskPriorityColumn({
    required String id,
    required String priority,
    required int rank,
  }) async {
    try {
      await customStatement(
        'UPDATE journal SET task_priority = ?, task_priority_rank = ? WHERE id = ?',
        [priority, rank, id],
      );
    } catch (e) {
      DevLogger.error(
        name: 'JournalDb',
        message: 'updateTaskPriorityColumn error',
        error: e,
      );
    }
  }

  Future<Map<String, Duration?>> getTaskEstimatesByIds(Set<String> ids) async {
    if (ids.isEmpty) {
      return const <String, Duration?>{};
    }

    final idList = ids.toSet().toList(growable: false);
    final placeholders = List.filled(idList.length, '?').join(', ');
    // The planner picks the PK (`sqlite_autoindex_journal_1`) on its
    // own once stats are fresh — we no longer pin it via `INDEXED BY`
    // because the autoindex name is not part of the public SQLite
    // contract. The v42 migration runs `ANALYZE` so installs that
    // pull this branch get accurate planner stats; subsequent
    // `id IN (...)` queries see the PK seek as the cheap path
    // without a hint.
    final rows = await customSelect(
      '''
      SELECT id, json_extract(serialized, '\$.data.estimate') AS estimate_us
      FROM journal
      WHERE id IN ($placeholders)
      AND deleted = FALSE
      AND type = 'Task'
      AND task = 1
      ''',
      variables: [
        for (final id in idList) Variable<String>(id),
      ],
      readsFrom: {journal},
    ).get();

    return <String, Duration?>{
      for (final row in rows)
        row.read<String>('id'): switch (row.readNullable<int>('estimate_us')) {
          final micros? => Duration(microseconds: micros),
          null => null,
        },
    };
  }

  Future<List<JournalEntity>> getTasks({
    required List<bool> starredStatuses,
    required List<String> taskStatuses,
    required List<String> categoryIds,
    List<String>? labelIds,
    List<String>? priorities,
    List<String>? ids,
    bool sortByDate = false,
    int limit = 500,
    int offset = 0,
  }) async {
    final privateStatuses = await _visiblePrivateStatuses();
    final res = await _selectTasks(
      starredStatuses: starredStatuses,
      privateStatuses: privateStatuses,
      taskStatuses: taskStatuses,
      categoryIds: categoryIds,
      labelIds: labelIds,
      priorities: priorities,
      ids: ids,
      sortByDate: sortByDate,
      limit: limit,
      offset: offset,
    ).get();
    return res.map(fromDbEntity).toList();
  }

  /// Like [getTasks] but orders by due date (soonest first, nulls last)
  /// using the denormalized `due_at` column. The partial
  /// `idx_journal_tasks_due_open` covers the open-task subset; closed
  /// tasks stream from the priority/date task indexes since v41
  /// populated `due_at` for every task with a non-null `data.due`
  /// regardless of status.
  ///
  /// Stays as raw SQL because the dynamic filter combinations
  /// (categories, labels, priorities, ids, starred, private) don't map
  /// cleanly onto generated Drift queries.
  Future<List<JournalEntity>> getTasksSortedByDueDate({
    required List<bool> starredStatuses,
    required List<String> taskStatuses,
    required List<String> categoryIds,
    List<String>? labelIds,
    List<String>? priorities,
    List<String>? ids,
    int limit = 500,
    int offset = 0,
  }) async {
    final privateStatuses = await _visiblePrivateStatuses();
    final res = await _buildTasksByDueDateQuery(
      starredStatuses: starredStatuses,
      privateStatuses: privateStatuses,
      taskStatuses: taskStatuses,
      categoryIds: categoryIds,
      labelIds: labelIds,
      priorities: priorities,
      ids: ids,
      limit: limit,
      offset: offset,
    );
    return res.map(fromDbEntity).toList();
  }

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

  Future<int> getWipCount() async {
    final privateStatuses = await _visiblePrivateStatuses();
    return countInProgressTasks(
      privateStatuses,
      ['IN PROGRESS'],
    ).getSingle();
  }

  Future<Map<String, int>> getTaskCountsByCategory() async {
    final rows = await countTasksGroupedByCategory().get();
    return {for (final row in rows) row.category: row.taskCount};
  }

  Future<int> getTasksCount({
    List<String> statuses = const ['IN PROGRESS'],
  }) async {
    final privateStatuses = await _visiblePrivateStatuses();
    final res = await countInProgressTasks(
      privateStatuses,
      statuses.cast<String?>(),
    ).get();
    return res.first;
  }

  /// Counts tasks matching the journal-table-level predicates of a
  /// `TasksFilter`. Project and agent filters are NOT applied here — the
  /// caller is expected to intersect with project / agent ID sets after this
  /// returns the gross count (for the common case both filters are empty
  /// and this number IS the answer).
  Future<int> getFilteredTasksCount({
    required List<String> taskStatuses,
    required List<String> categoryIds,
    List<String>? labelIds,
    List<String>? priorities,
  }) async {
    if (taskStatuses.isEmpty || categoryIds.isEmpty) return 0;
    final p = await _filteredTaskParams(
      taskStatuses: taskStatuses,
      labelIds: labelIds,
      priorities: priorities,
    );
    final res = await countFilteredTasks(
      p.privateStatuses,
      p.taskStatuses,
      categoryIds,
      p.filterByLabels,
      p.labelFilterCount,
      p.effectiveLabelIds,
      p.includeUnlabeled,
      p.filterByPriorities,
      p.priorityFilterCount,
      p.effectivePriorities,
    ).get();
    return res.first;
  }

  /// Same predicate set as [getFilteredTasksCount] but returns task ids so a
  /// caller can intersect with project / agent post-filter id sets.
  Future<List<String>> getFilteredTaskIds({
    required List<String> taskStatuses,
    required List<String> categoryIds,
    List<String>? labelIds,
    List<String>? priorities,
  }) async {
    if (taskStatuses.isEmpty || categoryIds.isEmpty) return const <String>[];
    final p = await _filteredTaskParams(
      taskStatuses: taskStatuses,
      labelIds: labelIds,
      priorities: priorities,
    );
    return selectFilteredTaskIds(
      p.privateStatuses,
      p.taskStatuses,
      categoryIds,
      p.filterByLabels,
      p.labelFilterCount,
      p.effectiveLabelIds,
      p.includeUnlabeled,
      p.filterByPriorities,
      p.priorityFilterCount,
      p.effectivePriorities,
    ).get();
  }

  Future<_FilteredTaskParams> _filteredTaskParams({
    required List<String> taskStatuses,
    List<String>? labelIds,
    List<String>? priorities,
  }) async {
    final selectedLabelIds = labelIds ?? const <String>[];
    final includeUnlabeled = selectedLabelIds.contains('');
    final filteredLabelIds = selectedLabelIds
        .where((id) => id.isNotEmpty)
        .toList();
    final labelFilterCount = filteredLabelIds.length;
    final selectedPriorities = priorities ?? const <String>[];
    final filterByPriorities = selectedPriorities.isNotEmpty;
    // Drift rejects empty IN lists; supply unreachable sentinels when the
    // predicate is gated off so the query stays well-formed.
    return _FilteredTaskParams(
      privateStatuses: await _visiblePrivateStatuses(),
      taskStatuses: taskStatuses.cast<String?>(),
      filterByLabels: includeUnlabeled || labelFilterCount > 0,
      labelFilterCount: labelFilterCount,
      effectiveLabelIds: labelFilterCount == 0
          ? const <String>['__no_label__']
          : filteredLabelIds,
      includeUnlabeled: includeUnlabeled,
      filterByPriorities: filterByPriorities,
      priorityFilterCount: selectedPriorities.length,
      effectivePriorities: filterByPriorities
          ? selectedPriorities.cast<String?>()
          : const <String?>['__no_priority__'],
    );
  }
}

class _FilteredTaskParams {
  _FilteredTaskParams({
    required this.privateStatuses,
    required this.taskStatuses,
    required this.filterByLabels,
    required this.labelFilterCount,
    required this.effectiveLabelIds,
    required this.includeUnlabeled,
    required this.filterByPriorities,
    required this.priorityFilterCount,
    required this.effectivePriorities,
  });

  final List<bool> privateStatuses;
  final List<String?> taskStatuses;
  final bool filterByLabels;
  final int labelFilterCount;
  final List<String> effectiveLabelIds;
  final bool includeUnlabeled;
  final bool filterByPriorities;
  final int priorityFilterCount;
  final List<String?> effectivePriorities;
}
