part of 'database.dart';

typedef ProjectTaskRollupCounts = ({
  int totalTaskCount,
  int completedTaskCount,
  int blockedTaskCount,
});

/// Project query surface for [JournalDb]: project lists, task↔project
/// resolution via the denormalized `project_id` column, and rollup
/// aggregates.
mixin _JournalDbProjectQueries
    on _$JournalDb, _JournalDbConfigFlags, _JournalDbJournalQueries {
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
                  t.task.equals(true) &
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
    final idList = taskIds.toList(growable: false);
    final projectIds = <String>{};
    // Chunked so an arbitrarily large task-id intersection set cannot
    // exceed SQLite's bind-variable cap.
    for (var i = 0; i < idList.length; i += _sqliteInListChunk) {
      final end = (i + _sqliteInListChunk).clamp(0, idList.length);
      final chunk = idList.sublist(i, end);
      final rows =
          await (selectOnly(journal)
                ..addColumns([journal.projectId])
                ..where(
                  journal.id.isIn(chunk) &
                      journal.type.equals('Task') &
                      journal.task.equals(true) &
                      journal.deleted.equals(false) &
                      journal.projectId.isNotNull(),
                ))
              .get();
      projectIds.addAll(
        rows.map((row) => row.read(journal.projectId)).whereType<String>(),
      );
    }
    return projectIds;
  }

  /// Maps each id in [taskIds] to its denormalized `project_id`, omitting
  /// tasks with no project association.
  ///
  /// Reads the `idx_journal_project_id` partial index via a plain id-IN
  /// lookup, chunked to stay under SQLite's bind-variable cap. Unlike
  /// [getProjectIdsForTaskIds] (which flattens to a deduplicated set), this
  /// preserves the per-task mapping needed to resolve each task's project.
  Future<Map<String, String>> getProjectIdMapForTasks(
    Set<String> taskIds,
  ) async {
    if (taskIds.isEmpty) return const <String, String>{};
    final idList = taskIds.toList(growable: false);
    final result = <String, String>{};
    for (var i = 0; i < idList.length; i += _sqliteInListChunk) {
      final end = (i + _sqliteInListChunk).clamp(0, idList.length);
      final chunk = idList.sublist(i, end);
      final rows =
          await (selectOnly(journal)
                ..addColumns([journal.id, journal.projectId])
                ..where(journal.id.isIn(chunk) & journal.projectId.isNotNull()))
              .get();
      for (final row in rows) {
        final id = row.read(journal.id);
        final projectId = row.read(journal.projectId);
        if (id != null && projectId != null) {
          result[id] = projectId;
        }
      }
    }
    return result;
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

  // Microtask-coalescing state for `getProjectForTask`. The
  // `projectForTaskProvider` Riverpod `FutureProvider.autoDispose.family`
  // mounts one provider per visible task row, so a task list fans out one
  // project lookup per row. In the super-slow log this showed up as a
  // cluster of `journal ⋈ linked_entries … ORDER BY … LIMIT 1` selects
  // (each carrying a `USE TEMP B-TREE FOR ORDER BY`) queued behind one
  // another. The coalescer merges every concurrent caller in one microtask
  // wave into a single denormalized `project_id` lookup plus one bulk
  // project fetch; each caller pulls its task's project out of the map.
  _PendingProjectForTaskWave? _pendingProjectForTaskWave;

  /// Single-shot fetch executed by the project-for-task coalescer: resolves
  /// `taskId → project_id` from the denormalized column, then loads the
  /// distinct projects through the private-status-filtered bulk read.
  ///
  /// Extracted as a protected seam so tests can count DB round-trips and
  /// assert that concurrent callers collapse into one wave.
  @protected
  @visibleForTesting
  Future<Map<String, ProjectEntry>> runProjectForTaskFetch(
    Set<String> taskIds,
  ) async {
    final projectIdByTask = await getProjectIdMapForTasks(taskIds);
    if (projectIdByTask.isEmpty) return const <String, ProjectEntry>{};
    final projects = await getJournalEntitiesForIdsUnordered(
      projectIdByTask.values.toSet(),
    );
    final projectById = <String, ProjectEntry>{
      for (final project in projects)
        if (project is ProjectEntry) project.meta.id: project,
    };
    return <String, ProjectEntry>{
      for (final entry in projectIdByTask.entries)
        entry.key: ?projectById[entry.value],
    };
  }

  Future<ProjectEntry?> _coalesceProjectForTask(String taskId) {
    final wave = _pendingProjectForTaskWave ??= _PendingProjectForTaskWave();
    wave.mergedIds.add(taskId);
    if (!wave.scheduled) {
      wave.scheduled = true;
      scheduleMicrotask(() async {
        _pendingProjectForTaskWave = null;
        try {
          wave.completer.complete(await runProjectForTaskFetch(wave.mergedIds));
        } catch (error, stack) {
          wave.completer.completeError(error, stack);
        }
      });
    }
    return wave.completer.future.then((map) => map[taskId]);
  }

  /// Returns the project linked to a task, or null if unlinked.
  ///
  /// Resolves through the denormalized, indexed `journal.project_id` column
  /// — kept in lock-step with the latest non-hidden ProjectLink by
  /// `upsertEntryLink` and `upsertJournalDbEntity` via `_projectIdSubquery`,
  /// the same ordering the old `journal ⋈ linked_entries` join used — and
  /// coalesces concurrent per-row callers into one wave (see
  /// [_pendingProjectForTaskWave]). The project's own private flag is still
  /// honored: a project hidden by the private gate resolves to null because
  /// the bulk read filters it out.
  Future<ProjectEntry?> getProjectForTask(String taskId) {
    return _coalesceProjectForTask(taskId);
  }

  /// Returns the existing ProjectLink for a task, or null.
  Future<EntryLink?> getProjectLinkForTask(String taskId) async {
    final res = await projectLinkForTask(taskId).get();
    if (res.isEmpty) return null;
    return entryLinkFromLinkedDbEntry(res.first);
  }
}

/// In-flight coalescing wave for `getProjectForTask`. Concurrent callers
/// within the same microtask merge their task ids; the wave fires one
/// denormalized `project_id` lookup plus one bulk project fetch, and each
/// caller pulls its task's project out of the returned map.
class _PendingProjectForTaskWave {
  final Set<String> mergedIds = <String>{};
  bool scheduled = false;
  final Completer<Map<String, ProjectEntry>> completer =
      Completer<Map<String, ProjectEntry>>.sync();
}
