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
    // Step 1: Get text and audio entries with logged time within date range
    final journalTypes = ['JournalEntry', 'JournalAudio'];

    final entries = await journalDb.getJournalEntities(
      types: journalTypes,
      starredStatuses: [true, false],
      privateStatuses: [true, false],
      flaggedStatuses: [0, 1, 2, 3],
      ids: null,
      categoryIds: {categoryId},
      limit: 10000, // Large limit to get all entries
    );

    // Filter entries by date range and minimum duration
    final workEntries = <JournalEntity>[];

    for (final entry in entries) {
      // Check if entry falls within the date range (inclusive)
      final entryDate = entry.meta.dateFrom;
      if (!entryDate.isBefore(request.startDate) &&
          !entryDate.isAfter(request.endDate)) {
        // Check duration for text entries
        if (entry is JournalEntry) {
          final entryDuration =
              entry.meta.dateTo.difference(entry.meta.dateFrom);
          if (entryDuration.inSeconds >= 15) {
            workEntries.add(entry);
          }
        }
        // Include all audio entries (they typically represent work)
        else if (entry is JournalAudio) {
          workEntries.add(entry);
        }
      }
    }

    if (workEntries.isEmpty) {
      return [];
    }

    // Step 2: Collect all entry IDs
    final entryIds = workEntries.map((e) => e.meta.id).toSet();

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

    // For each task, find its latest AI summary
    for (final task in actualTasks.take(clampedLimit)) {
      // Get entities linked to this task (including AI responses)
      final linkedEntitiesForTask =
          await journalDb.getLinkedEntities(task.meta.id);

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
