part of 'ai_input_repository.dart';

/// Time-spent and linked-task context helpers for [AiInputRepository]:
/// batched linked-task context assembly and the related-task comparator.
/// Split from the main file for size; all members are library-private.
extension AiInputLinkedTasks on AiInputRepository {
  /// Calculate the time spent on a task using the provided repository.
  ///
  /// The repository is passed as a parameter to avoid accessing [ref] after
  /// async gaps, which could fail if the provider has been disposed.
  ///
  /// Returns the total duration of work logged against this task.
  Future<Duration> _calculateTimeSpentWithRepo(
    String taskId,
    TaskProgressRepository progressRepository,
  ) async {
    final progressData = await progressRepository.getTaskProgressData(
      id: taskId,
    );
    final timeRanges = progressData?.$2 ?? {};
    return progressRepository
        .getTaskProgress(timeRanges: timeRanges, estimate: progressData?.$1)
        .progress;
  }

  /// Build context objects for multiple tasks using batched database queries.
  ///
  /// **N+1 Query Avoidance**: This method fetches all linked entities for all
  /// tasks in a single database call via [JournalDb.getBulkLinkedEntities],
  /// then asks [TaskSummaryResolver.resolveMany] to batch agent-report lookups
  /// before falling back to the pre-fetched legacy AI summary entries.
  ///
  /// For each task, the method:
  /// 1. Calculates time spent by summing durations of non-Task, non-AiResponse
  ///    linked entities
  /// 2. Finds the latest task summary (agent report or legacy AI response)
  /// 3. Resolves labels via O(1) cache lookups
  Future<List<AiLinkedTaskContext>> _buildLinkedTaskContextsBatched(
    List<Task> tasks,
  ) async {
    if (tasks.isEmpty) return [];

    // Collect all task IDs for bulk fetch
    final taskIds = tasks.map((t) => t.id).toSet();

    // Single bulk query to get all linked entities for all tasks
    final bulkLinkedEntities = await _db.getBulkLinkedEntities(taskIds);
    final summariesByTaskId = await _taskSummaryResolver.resolveMany(
      taskIds,
      linkedEntitiesByTaskId: bulkLinkedEntities,
    );

    // Build context for each task using the pre-fetched data
    final results = <AiLinkedTaskContext>[];
    for (final task in tasks) {
      final linkedEntities = bulkLinkedEntities[task.id] ?? [];

      // Calculate time spent from linked entities (non-Task, non-AiResponseEntry)
      final timeSpent = _calculateTimeSpentFromEntities(linkedEntities);

      // Get latest summary: tries agent report first, then legacy AI response.
      final latestSummary = summariesByTaskId[task.id];

      // Get labels from cache (O(1) per label)
      final labelIds = task.meta.labelIds ?? const <String>[];
      final labels = _buildLabelTuplesFromCache(labelIds);

      results.add(
        AiLinkedTaskContext(
          id: task.id,
          title: task.data.title,
          status: task.data.status.toDbString,
          statusSince: task.data.status.createdAt,
          priority: task.data.priority.short,
          estimate: formatHhMm(task.data.estimate ?? Duration.zero),
          timeSpent: formatHhMm(timeSpent),
          createdAt: task.meta.createdAt,
          labels: labels,
          languageCode: task.data.languageCode,
          latestSummary: latestSummary,
        ),
      );
    }

    return results;
  }

  /// Calculate time spent from a list of pre-fetched linked entities.
  ///
  /// Part of the batched query strategy: operates on entities already fetched
  /// by [_buildLinkedTaskContextsBatched], avoiding additional database calls.
  ///
  /// Delegates to [TaskProgressRepository.sumTimeSpentFromEntities] which is
  /// the canonical implementation of time-spent calculation logic.
  Duration _calculateTimeSpentFromEntities(List<JournalEntity> entities) {
    return TaskProgressRepository.sumTimeSpentFromEntities(entities);
  }

  int _compareRelatedProjectTasks(Task left, Task right) {
    final byUpdatedAt = right.meta.updatedAt.compareTo(left.meta.updatedAt);
    if (byUpdatedAt != 0) {
      return byUpdatedAt;
    }

    final byDateFrom = right.meta.dateFrom.compareTo(left.meta.dateFrom);
    if (byDateFrom != 0) {
      return byDateFrom;
    }

    final byCreatedAt = right.meta.createdAt.compareTo(left.meta.createdAt);
    if (byCreatedAt != 0) {
      return byCreatedAt;
    }

    return right.id.compareTo(left.id);
  }
}
