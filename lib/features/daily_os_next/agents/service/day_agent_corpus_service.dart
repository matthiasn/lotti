part of 'day_agent_capture_service.dart';

/// FTS corpus matching + corpus-snapshot logic of
/// [DayAgentCaptureService]. The class keeps thin delegators so mocks
/// of the service still intercept the public methods.
extension DayAgentCorpusService on DayAgentCaptureService {
  /// Build the bounded task corpus embedded in capture-triggered wakes.
  Future<List<Map<String, Object?>>> buildTaskCorpusSnapshotImpl({
    required Set<String> allowedCategoryIds,
    required DateTime day,
    int limit = DayAgentCaptureService._maxCorpusTasks,
  }) async {
    final dayStart = localDay(day);
    final openTasks = await journalDb.getOpenTasksForDayAgentCorpus(
      categoryIds: allowedCategoryIds,
      limit: limit,
    );
    final overdueAndToday = await journalDb.getTasksDueOnOrBefore(dayStart);

    final byId = <String, Task>{};
    for (final task in [...overdueAndToday, ...openTasks]) {
      if (DayAgentCaptureService._isClosedTask(task)) continue;
      if (!DayAgentCaptureService._categoryAllowed(
        task.meta.categoryId,
        allowedCategoryIds,
      )) {
        continue;
      }
      byId.putIfAbsent(task.id, () => task);
      if (byId.length >= limit) break;
    }

    return [
      for (final task in byId.values)
        {
          'taskId': task.id,
          'title': task.data.title,
          'status': task.data.status.toDbString,
          'categoryId': task.meta.categoryId,
          'due': task.data.due?.toIso8601String(),
          'estimateMinutes': task.data.estimate?.inMinutes,
          'priority': task.data.priority.short,
        },
    ];
  }

  /// Finds existing tasks that may match a capture phrase.
  Future<List<DayAgentCorpusMatch>> matchToCorpusImpl({
    required String agentId,
    required String phrase,
    String? categoryHint,
  }) async {
    final identity = await _requireIdentity(agentId);
    final trimmed = phrase.trim();
    if (trimmed.isEmpty) {
      throw const DayAgentCaptureException('phrase must not be empty');
    }

    final categoryFilter = DayAgentCaptureService._categoryFilterForHint(
      allowedCategoryIds: identity.allowedCategoryIds,
      categoryHint: DayAgentCaptureService._blankToNull(categoryHint),
    );
    if (categoryFilter != null && categoryFilter.isEmpty) {
      return const <DayAgentCorpusMatch>[];
    }

    final ids = await fts5Db.watchFullTextMatches(trimmed).first;
    if (ids.isEmpty) return const <DayAgentCorpusMatch>[];

    final entities = await journalDb.getJournalEntitiesForIdsUnordered(
      ids.toSet(),
    );
    final taskById = {
      for (final entity in entities)
        if (entity is Task && !DayAgentCaptureService._isClosedTask(entity))
          entity.id: entity,
    };

    final matches = <DayAgentCorpusMatch>[];
    for (var i = 0; i < ids.length; i++) {
      final task = taskById[ids[i]];
      if (task == null) continue;
      if (!DayAgentCaptureService._categoryAllowed(
        task.meta.categoryId,
        categoryFilter,
      )) {
        continue;
      }
      matches.add(corpusMatchFromTask(task, 1 / (i + 1)));
      if (matches.length >= DayAgentCaptureService._maxMatchCandidates) break;
    }
    return matches;
  }
}
