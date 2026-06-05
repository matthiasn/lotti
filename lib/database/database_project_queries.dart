part of 'database.dart';

typedef ProjectTaskRollupCounts = ({
  int totalTaskCount,
  int completedTaskCount,
  int blockedTaskCount,
});

/// Project query surface for [JournalDb]: project lists, task↔project
/// resolution via the denormalized `project_id` column, and rollup
/// aggregates.
mixin _JournalDbProjectQueries on _$JournalDb, _JournalDbConfigFlags {
  /// Updates the denormalized `project_id` column for a task row.
  ///
  /// Pass [projectId] = null to clear the project association.
  Future<void> updateProjectIdColumn(String taskId, String? projectId) async {
    try {
      await customStatement(
        'UPDATE journal SET project_id = ? WHERE id = ?',
        [projectId, taskId],
      );
    } catch (e) {
      DevLogger.error(
        name: 'JournalDb',
        message: 'updateProjectIdColumn error',
        error: e,
      );
    }
  }

  /// Returns the IDs of all non-deleted tasks whose `project_id` is in
  /// [projectIds]. Uses the `idx_journal_project_id` partial index.
  Future<Set<String>> getTaskIdsForProjects(Set<String> projectIds) async {
    if (projectIds.isEmpty) return {};
    final rows =
        await (select(journal)..where(
              (t) =>
                  t.projectId.isIn(projectIds.toList()) &
                  t.type.equals('Task') &
                  t.deleted.equals(false),
            ))
            .get();
    return rows.map((r) => r.id).toSet();
  }

  /// Returns the subset of [projectIds] that still resolve to live projects.
  Future<Set<String>> getExistingProjectIds(Set<String> projectIds) async {
    if (projectIds.isEmpty) return {};
    final rows =
        await (selectOnly(journal)
              ..addColumns([journal.id])
              ..where(
                journal.id.isIn(projectIds.toList()) &
                    journal.type.equals('Project') &
                    journal.deleted.equals(false),
              ))
            .get();
    return rows.map((row) => row.read(journal.id)).whereType<String>().toSet();
  }

  /// Returns project IDs for any live task in [taskIds] that is linked to a
  /// project via the denormalized `project_id` column.
  Future<Set<String>> getProjectIdsForTaskIds(Set<String> taskIds) async {
    if (taskIds.isEmpty) return {};
    final rows =
        await (selectOnly(journal)
              ..addColumns([journal.projectId])
              ..where(
                journal.id.isIn(taskIds.toList()) &
                    journal.type.equals('Task') &
                    journal.deleted.equals(false) &
                    journal.projectId.isNotNull(),
              ))
            .get();
    return rows
        .map((row) => row.read(journal.projectId))
        .whereType<String>()
        .toSet();
  }

  /// Returns all visible, non-deleted projects across categories.
  Future<List<ProjectEntry>> getVisibleProjects() async {
    final privateStatuses = await _visiblePrivateStatuses();
    final matchesAllPrivateStates = _matchesAllPrivateStates(privateStatuses);

    var predicate =
        journal.type.equals('Project') & journal.deleted.equals(false);
    if (!matchesAllPrivateStates) {
      predicate = predicate & journal.private.isIn(privateStatuses);
    }

    final rows =
        await (select(journal)
              ..where((_) => predicate)
              ..orderBy([
                (table) => OrderingTerm(
                  expression: table.dateFrom,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();

    return rows.map(fromDbEntity).whereType<ProjectEntry>().toList();
  }

  /// Returns aggregate task counts for all [projectIds] in one query.
  Future<Map<String, ProjectTaskRollupCounts>> getProjectTaskRollups(
    Set<String> projectIds,
  ) async {
    if (projectIds.isEmpty) {
      return const <String, ProjectTaskRollupCounts>{};
    }

    final privateStatuses = await _visiblePrivateStatuses();
    final matchesAllPrivateStates = _matchesAllPrivateStates(privateStatuses);
    final projectPlaceholders = List.filled(projectIds.length, '?').join(', ');
    final privateClause = matchesAllPrivateStates
        ? ''
        : ' AND private IN (${List.filled(privateStatuses.length, '?').join(', ')})';

    // `task = 1` is logically implied by `type = 'Task'` and is set on
    // every Task write, but the planner cannot deduce that from the
    // schema. The v40 covering partial `idx_journal_project_task_status`
    // declares `WHERE type = 'Task' AND task = 1 AND deleted = FALSE
    // AND project_id IS NOT NULL`; without `task = 1` in this query's
    // WHERE the planner falls back to `idx_journal_browse` plus a
    // TEMP B-TREE for the GROUP BY (327 ms in the 2026-05-10 super-slow
    // log). Adding the redundant `task = 1` lets the planner match the
    // partial and stream the aggregate directly from index entries.
    final rows = await customSelect(
      '''
        SELECT
          project_id,
          COUNT(*) AS total_count,
          SUM(CASE WHEN task_status = 'DONE' THEN 1 ELSE 0 END) AS completed_count,
          SUM(CASE WHEN task_status = 'BLOCKED' THEN 1 ELSE 0 END) AS blocked_count
        FROM journal
        WHERE project_id IN ($projectPlaceholders)
          AND deleted = FALSE
          AND type = 'Task'
          AND task = 1
          $privateClause
        GROUP BY project_id
      ''',
      variables: [
        ...projectIds.map(Variable.withString),
        if (!matchesAllPrivateStates) ...privateStatuses.map(Variable.withBool),
      ],
      readsFrom: {journal},
    ).get();

    return {
      for (final row in rows)
        row.read<String>('project_id'): (
          totalTaskCount: row.read<int>('total_count'),
          completedTaskCount: row.read<int>('completed_count'),
          blockedTaskCount: row.read<int>('blocked_count'),
        ),
    };
  }

  /// Returns all non-deleted projects for a category.
  Future<List<ProjectEntry>> getProjectsForCategory(
    String categoryId,
  ) async {
    final res = await _queryWithPrivateFilter(
      allPrivate: () => projectsForCategory(categoryId).get(),
      filtered: (s) =>
          projectsForCategoryByPrivateStatuses(categoryId, s).get(),
    );
    return res.map(fromDbEntity).whereType<ProjectEntry>().toList();
  }

  /// Returns all non-deleted tasks linked to a project via ProjectLink.
  Future<List<Task>> getTasksForProject(String projectId) async {
    final res = await _queryWithPrivateFilter(
      allPrivate: () => tasksForProject(projectId).get(),
      filtered: (s) => tasksForProjectByPrivateStatuses(projectId, s).get(),
    );
    return res.map(fromDbEntity).whereType<Task>().toList();
  }

  /// Returns the project linked to a task, or null if unlinked.
  Future<ProjectEntry?> getProjectForTask(String taskId) async {
    final privateStatuses = await _visiblePrivateStatuses();
    final res = await projectForTask(taskId).get();
    if (res.isEmpty) return null;
    final entity = fromDbEntity(res.first);
    if (entity is! ProjectEntry) return null;
    if (!privateStatuses.contains(entity.meta.private ?? false)) return null;
    return entity;
  }

  /// Returns the existing ProjectLink for a task, or null.
  Future<EntryLink?> getProjectLinkForTask(String taskId) async {
    final res = await projectLinkForTask(taskId).get();
    if (res.isEmpty) return null;
    return entryLinkFromLinkedDbEntry(res.first);
  }
}
