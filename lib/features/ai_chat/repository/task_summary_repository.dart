import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/ai/repository/task_summary_resolver.dart';
import 'package:lotti/features/ai_chat/models/task_summary_tool.dart';
import 'package:lotti/get_it.dart';

/// Provides the [TaskSummaryRepository], wiring in the journal DB and a
/// [TaskSummaryResolver] backed by the agent database when one is registered
/// (the resolver prefers agent reports, falling back to legacy summaries).
final Provider<TaskSummaryRepository> taskSummaryRepositoryProvider =
    Provider.autoDispose<TaskSummaryRepository>(
      taskSummaryRepository,
      name: 'taskSummaryRepositoryProvider',
    );
TaskSummaryRepository taskSummaryRepository(Ref ref) {
  return TaskSummaryRepository(
    journalDb: getIt<JournalDb>(),
    taskSummaryResolver: TaskSummaryResolver(
      getIt.isRegistered<AgentDatabase>()
          ? AgentRepository(getIt<AgentDatabase>())
          : null,
    ),
  );
}

/// Resolves AI task summaries for a category and local date range, the data
/// source behind the `get_task_summaries` chat tool.
class TaskSummaryRepository {
  TaskSummaryRepository({
    required this.journalDb,
    required this.taskSummaryResolver,
  });

  final JournalDb journalDb;
  final TaskSummaryResolver taskSummaryResolver;

  /// Returns task summaries for [categoryId] whose linked work entries fall in
  /// the requested local date range.
  ///
  /// Date strings must be strict `YYYY-MM-DD` (throws [FormatException] on bad
  /// format, impossible calendar dates, or end-before-start); they are
  /// interpreted as local start/end-of-day and converted to UTC for querying.
  /// The pipeline is: work entries in range → tasks that link to them →
  /// resolved summaries (agent report, then legacy fallback), sorted newest
  /// first and capped at [TaskSummaryRequest.limit] (clamped to 1..100). Bulk
  /// queries avoid per-task fan-out.
  Future<List<TaskSummaryResult>> getTaskSummaries({
    required String categoryId,
    required TaskSummaryRequest request,
  }) async {
    // Parse and validate date-only strings (YYYY-MM-DD) as local dates,
    // then convert to UTC instants for DB querying.
    DateTime parseLocalStartOfDay(String date) {
      final strict = RegExp(r'^\d{4}-\d{2}-\d{2}$');
      if (!strict.hasMatch(date)) {
        throw FormatException(
          'Invalid date format for "$date". Please send YYYY-MM-DD only; no time or timezone.',
        );
      }
      final parts = date.split('-').map(int.parse).toList();
      final dt = DateTime(parts[0], parts[1], parts[2]);
      // Reject impossible calendar dates (e.g., 2024-02-31)
      if (dt.year != parts[0] || dt.month != parts[1] || dt.day != parts[2]) {
        throw FormatException('Invalid calendar date: "$date"');
      }
      return dt;
    }

    DateTime parseLocalEndOfDay(String date) {
      final strict = RegExp(r'^\d{4}-\d{2}-\d{2}$');
      if (!strict.hasMatch(date)) {
        throw FormatException(
          'Invalid date format for "$date". Please send YYYY-MM-DD only; no time or timezone.',
        );
      }
      final parts = date.split('-').map(int.parse).toList();
      final dt = DateTime(parts[0], parts[1], parts[2], 23, 59, 59, 999);
      // Verify date did not overflow to another month/day
      if (dt.year != parts[0] || dt.month != parts[1] || dt.day != parts[2]) {
        throw FormatException('Invalid calendar date: "$date"');
      }
      return dt;
    }

    final startLocal = parseLocalStartOfDay(request.startDate);
    final endLocal = parseLocalEndOfDay(request.endDate);

    if (endLocal.isBefore(startLocal)) {
      throw const FormatException(
        'Invalid date range: end_date is before start_date. Please correct and retry.',
      );
    }

    // Clamp limit to reasonable bounds
    final clampedLimit = math.max(1, math.min(request.limit, 100));

    // Step 1: Get work entries using database-level filtering for performance
    final journalTypes = ['JournalEntry', 'JournalAudio'];
    final workEntries = await journalDb
        .workEntriesInDateRange(
          journalTypes,
          [categoryId],
          startLocal.toUtc(),
          endLocal.toUtc(),
        )
        .get();

    if (workEntries.isEmpty) {
      return [];
    }

    // Step 2: Collect all entry IDs
    final entryIds = workEntries.map((e) => e.id).toSet();

    // Step 3: Get all links TO these entries (where work entries are the target)
    // We need to find tasks that link TO our work entries
    final allLinks = await journalDb.linksForEntryIds(entryIds);

    // Collect all unique task IDs (the from_id when work entry is to_id)
    final linkedTaskIds = <String>{};
    for (final link in allLinks) {
      linkedTaskIds.add(link.fromId); // The task is the source of the link
    }

    if (linkedTaskIds.isEmpty) {
      return [];
    }

    // Step 4: Fetch all potential tasks in one batch
    final linkedEntities = await journalDb.getJournalEntitiesForIdsUnordered(
      linkedTaskIds,
    );

    // Filter to only include actual tasks
    final actualTasks = linkedEntities.whereType<Task>().toList()
      ..sort((a, b) {
        final byDate = b.meta.dateFrom.compareTo(a.meta.dateFrom);
        return byDate != 0 ? byDate : a.meta.id.compareTo(b.meta.id);
      });

    final results = <TaskSummaryResult>[];

    // Get task IDs for bulk linked entity fetching
    final tasksToProcess = actualTasks.take(clampedLimit).toList();

    // Early return if no tasks to process
    if (tasksToProcess.isEmpty) {
      return <TaskSummaryResult>[];
    }

    final taskIds = tasksToProcess.map((t) => t.meta.id).toSet();

    // Bulk fetch legacy linked entities and agent reports for all tasks to
    // avoid per-task summary resolution queries.
    final bulkLinkedEntities = await journalDb.getBulkLinkedEntities(taskIds);
    final summariesByTaskId = await taskSummaryResolver.resolveMany(
      taskIds,
      linkedEntitiesByTaskId: bulkLinkedEntities,
    );

    // Process each task: resolve summary via agent report → legacy fallback
    for (final task in tasksToProcess) {
      final statusName = task.data.status.toDbString;
      final summary = summariesByTaskId[task.meta.id];

      results.add(
        TaskSummaryResult(
          taskId: task.meta.id,
          taskTitle: task.data.title,
          summary: summary ?? 'No AI summary available for this task.',
          taskDate: task.meta.dateFrom,
          status: statusName,
        ),
      );
    }

    return results;
  }
}
