import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai_chat/models/task_summary_tool.dart';
import 'package:lotti/get_it.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'task_summary_repository.g.dart';

@riverpod
TaskSummaryRepository taskSummaryRepository(Ref ref) {
  return TaskSummaryRepository(
    journalDb: getIt<JournalDb>(),
  );
}

class TaskSummaryRepository {
  TaskSummaryRepository({
    required this.journalDb,
  });

  final JournalDb journalDb;

  Future<List<TaskSummaryResult>> getTaskSummaries({
    required String categoryId,
    required TaskSummaryRequest request,
  }) async {
    // Validate request parameters
    if (request.endDate.isBefore(request.startDate)) {
      // Swap dates if they're in wrong order
      final correctedRequest = TaskSummaryRequest(
        startDate: request.endDate,
        endDate: request.startDate,
        limit: request.limit,
      );
      return getTaskSummaries(
          categoryId: categoryId, request: correctedRequest);
    }

    // Clamp limit to reasonable bounds
    final clampedLimit = math.max(1, math.min(request.limit, 100));

    // Step 1: Get work entries using database-level filtering for performance
    final journalTypes = ['JournalEntry', 'JournalAudio'];
    final workEntries = await journalDb
        .workEntriesInDateRange(
          journalTypes,
          [categoryId],
          request.startDate,
          request.endDate,
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
    final linkedEntities =
        await journalDb.getJournalEntitiesForIds(linkedTaskIds);

    // Filter to only include actual tasks
    final actualTasks = linkedEntities.whereType<Task>().toList();

    final results = <TaskSummaryResult>[];

    // Get task IDs for bulk linked entity fetching
    final tasksToProcess = actualTasks.take(clampedLimit).toList();

    // Early return if no tasks to process
    if (tasksToProcess.isEmpty) {
      return <TaskSummaryResult>[];
    }

    final taskIds = tasksToProcess.map((t) => t.meta.id).toSet();

    // Bulk fetch linked entities for all tasks to avoid N+1 queries
    final bulkLinkedEntities = await journalDb.getBulkLinkedEntities(taskIds);

    // Process each task with its pre-fetched linked entities
    for (final task in tasksToProcess) {
      final linkedEntitiesForTask = bulkLinkedEntities[task.meta.id] ?? [];

      // Filter for AI response entries that are task summaries
      final aiResponses = <JournalEntity>[];
      for (final linkedEntity in linkedEntitiesForTask) {
        if (linkedEntity is AiResponseEntry) {
          final aiData = linkedEntity.data;
          if (aiData.type == AiResponseType.taskSummary) {
            aiResponses.add(linkedEntity);
          }
        }
      }

      if (aiResponses.isNotEmpty) {
        // Sort by date to get the most recent
        aiResponses.sort((a, b) => b.meta.dateFrom.compareTo(a.meta.dateFrom));

        final latestSummary = aiResponses.first;
        if (latestSummary is AiResponseEntry) {
          final aiData = latestSummary.data;

          // Get task status name
          final status = task.data.status;
          final statusName = status.map(
            open: (_) => 'OPEN',
            inProgress: (_) => 'IN PROGRESS',
            groomed: (_) => 'GROOMED',
            blocked: (_) => 'BLOCKED',
            onHold: (_) => 'ON HOLD',
            done: (_) => 'DONE',
            rejected: (_) => 'REJECTED',
          );

          results.add(TaskSummaryResult(
            taskId: task.meta.id,
            taskTitle: task.data.title,
            summary: aiData.response,
            taskDate: task.meta.dateFrom,
            status: statusName,
            metadata: {
              'model': aiData.model,
              'promptId': aiData.promptId ?? '',
              'generatedAt': latestSummary.meta.dateFrom.toIso8601String(),
            },
          ));
        }
      } else {
        // No AI summary available, create a basic summary
        final status = task.data.status;
        final statusName = status.map(
          open: (_) => 'OPEN',
          inProgress: (_) => 'IN PROGRESS',
          groomed: (_) => 'GROOMED',
          blocked: (_) => 'BLOCKED',
          onHold: (_) => 'ON HOLD',
          done: (_) => 'DONE',
          rejected: (_) => 'REJECTED',
        );

        results.add(TaskSummaryResult(
          taskId: task.meta.id,
          taskTitle: task.data.title,
          summary: 'No AI summary available for this task.',
          taskDate: task.meta.dateFrom,
          status: statusName,
        ));
      }
    }

    return results;
  }
}
