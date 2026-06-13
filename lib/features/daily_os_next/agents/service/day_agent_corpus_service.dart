import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_reconcile_models.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_helpers.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_reads.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';

/// FTS corpus matching + corpus-snapshot logic for the day-agent capture
/// flow. The capture service keeps thin delegators so mocks of the service
/// still intercept the public methods.
class DayAgentCorpusService {
  /// Creates the corpus collaborator.
  DayAgentCorpusService({
    required this.journalDb,
    required this.fts5Db,
    required this.reads,
  });

  /// Maximum number of tasks embedded in a corpus snapshot.
  static const maxCorpusTasks = 200;

  /// Maximum number of match candidates returned by [matchToCorpus].
  static const maxMatchCandidates = 8;

  /// Journal DB used for task reads.
  final JournalDb journalDb;

  /// FTS index used by `match_to_corpus`.
  final Fts5Db fts5Db;

  /// Shared agent-identity resolution.
  final DayAgentCaptureReads reads;

  /// Build the bounded task corpus embedded in capture-triggered wakes.
  Future<List<Map<String, Object?>>> buildTaskCorpusSnapshot({
    required Set<String> allowedCategoryIds,
    required DateTime day,
    int limit = maxCorpusTasks,
  }) async {
    final dayStart = localDay(day);
    final openTasks = await journalDb.getOpenTasksForDayAgentCorpus(
      categoryIds: allowedCategoryIds,
      limit: limit,
    );
    final overdueAndToday = await journalDb.getTasksDueOnOrBefore(dayStart);

    final byId = <String, Task>{};
    for (final task in [...overdueAndToday, ...openTasks]) {
      if (isClosedTask(task)) continue;
      if (!categoryAllowed(
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
  Future<List<DayAgentCorpusMatch>> matchToCorpus({
    required String agentId,
    required String phrase,
    String? categoryHint,
  }) async {
    final identity = await reads.requireIdentity(agentId);
    final trimmed = phrase.trim();
    if (trimmed.isEmpty) {
      throw const DayAgentCaptureException('phrase must not be empty');
    }

    final categoryFilter = _categoryFilterForHint(
      allowedCategoryIds: identity.allowedCategoryIds,
      categoryHint: blankToNull(categoryHint),
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
        if (entity is Task && !isClosedTask(entity)) entity.id: entity,
    };

    final matches = <DayAgentCorpusMatch>[];
    for (var i = 0; i < ids.length; i++) {
      final task = taskById[ids[i]];
      if (task == null) continue;
      if (!categoryAllowed(
        task.meta.categoryId,
        categoryFilter,
      )) {
        continue;
      }
      matches.add(corpusMatchFromTask(task, 1 / (i + 1)));
      if (matches.length >= maxMatchCandidates) break;
    }
    return matches;
  }

  Set<String>? _categoryFilterForHint({
    required Set<String> allowedCategoryIds,
    required String? categoryHint,
  }) {
    if (categoryHint == null) {
      return allowedCategoryIds.isEmpty ? null : allowedCategoryIds;
    }
    if (allowedCategoryIds.isNotEmpty &&
        !allowedCategoryIds.contains(categoryHint)) {
      return const <String>{};
    }
    return {categoryHint};
  }
}
