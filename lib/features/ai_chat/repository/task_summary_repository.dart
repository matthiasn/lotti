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
    
    // Debug: Check first few entries to see their dates
    if (entries.isNotEmpty) {
      print('Sample entry dates and types:');
      for (var i = 0; i < 5 && i < entries.length; i++) {
        final entry = entries[i];
        final entryType = entry.runtimeType.toString();
        var duration = 'N/A';
        if (entry is JournalEntry) {
          final dur = entry.meta.dateTo.difference(entry.meta.dateFrom);
          duration = '${dur.inSeconds}s';
        }
        print('  Entry ${i+1}: ${entry.meta.dateFrom} - Type: $entryType, Duration: $duration');
      }
      print('Searching for range: ${request.startDate} to ${request.endDate}');
    }
    
    int matchingDateCount = 0;
    for (final entry in entries) {
      // Check if entry falls within the date range (inclusive)
      final entryDate = entry.meta.dateFrom;
      if (!entryDate.isBefore(request.startDate) &&
          !entryDate.isAfter(request.endDate)) {
        matchingDateCount++;
        // Check duration for text entries
        if (entry is JournalEntry) {
          final entryDuration =
              entry.meta.dateTo.difference(entry.meta.dateFrom);
          if (entryDuration.inSeconds >= 15) {
            workEntries.add(entry);
            print('Added JournalEntry with ${entryDuration.inSeconds}s duration');
          } else {
            print('Skipped JournalEntry with only ${entryDuration.inSeconds}s duration (< 15s)');
          }
        }
        // Include all audio entries (they typically represent work)
        else if (entry is JournalAudio) {
          workEntries.add(entry);
          print('Added JournalAudio entry');
        } else {
          print('Skipped entry of type: ${entry.runtimeType}');
        }
      }
    }
    print('Total entries matching date range: $matchingDateCount');

    if (workEntries.isEmpty) {
      print('No work entries found');
      return [];
    }
    print('Found ${workEntries.length} work entries');

    // Step 2: Collect all entry IDs
    final entryIds = workEntries.map((e) => e.meta.id).toSet();
    print('Collected ${entryIds.length} unique entry IDs');

    // Step 3: Get all links TO these entries (where work entries are the target)
    // We need to find tasks that link TO our work entries
    final allLinks = await journalDb.linksForEntryIds(entryIds);
    print('Found ${allLinks.length} links where work entries are the target');

    // Collect all unique task IDs (the from_id when work entry is to_id)
    final linkedTaskIds = <String>{};
    for (final link in allLinks) {
      linkedTaskIds.add(link.fromId);  // The task is the source of the link
      print('Link: ${link.fromId} (potential task) -> ${link.toId} (work entry)');
    }
    print('Found ${linkedTaskIds.length} unique source entity IDs (potential tasks)');

    if (linkedTaskIds.isEmpty) {
      print('No linked entities found from work entries');
      return [];
    }

    // Step 4: Fetch all potential tasks in one batch
    final linkedEntities =
        await journalDb.getJournalEntitiesForIds(linkedTaskIds);

    // Filter to only include actual tasks
    final actualTasks = linkedEntities.whereType<Task>().toList();

    final results = <TaskSummaryResult>[];

    // For each task, find its latest AI summary
    for (final task in actualTasks.take(request.limit)) {
      // Get entities linked to this task (including AI responses)
      final linkedEntities = await journalDb.getLinkedEntities(task.meta.id);

      // Filter for AI response entries that are task summaries
      final aiResponses = <JournalEntity>[];
      for (final entity in linkedEntities) {
        if (entity is AiResponseEntry) {
          final aiData = entity.data;
          if (aiData.type == AiResponseType.taskSummary) {
            aiResponses.add(entity);
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
