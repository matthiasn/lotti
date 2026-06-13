part of 'database.dart';

/// Task list query surface for [JournalDb]: filtered task lists (by
/// status, category, label, priority, starred, FTS ids), due-date
/// ordering, task counts, and the filtered-count/id helpers.
///
/// Due-date *range* reads and day-agent selects live in
/// [_JournalDbTaskDueQueries].
mixin _JournalDbTaskQueries
    on _$JournalDb, _JournalDbConfigFlags, _JournalDbTaskQueriesBuilders {
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
