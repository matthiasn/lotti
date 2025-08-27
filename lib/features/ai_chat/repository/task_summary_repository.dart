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
    // Get all tasks in the category
    // Task statuses: OPEN, IN PROGRESS, GROOMED, BLOCKED, ON HOLD, DONE, REJECTED
    final taskStatuses = [
      'OPEN',
      'IN PROGRESS',
      'GROOMED',
      'BLOCKED',
      'ON HOLD',
      'DONE',
      'REJECTED',
    ];

    final tasks = await journalDb.getTasks(
      starredStatuses: [true, false], // Include both starred and unstarred
      taskStatuses: taskStatuses,
      categoryIds: [categoryId],
      limit: 1000, // Get a large number, we'll filter by date
    );

    // Filter tasks by date range
    final filteredTasks = tasks.where((task) {
      final taskDate = task.meta.dateFrom;
      return taskDate
              .isAfter(request.startDate.subtract(const Duration(days: 1))) &&
          taskDate.isBefore(request.endDate.add(const Duration(days: 1)));
    }).toList();

    final results = <TaskSummaryResult>[];

    // For each task, find its latest AI summary
    for (final task in filteredTasks.take(request.limit)) {
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
          var statusName = 'Unknown';
          if (task is Task) {
            final status = task.data.status;
            statusName = status.map(
              open: (_) => 'OPEN',
              inProgress: (_) => 'IN PROGRESS',
              groomed: (_) => 'GROOMED',
              blocked: (_) => 'BLOCKED',
              onHold: (_) => 'ON HOLD',
              done: (_) => 'DONE',
              rejected: (_) => 'REJECTED',
            );
          }

          results.add(TaskSummaryResult(
            taskId: task.meta.id,
            taskTitle: task is Task ? task.data.title : 'Task',
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
        var statusName = 'Unknown';
        if (task is Task) {
          final status = task.data.status;
          statusName = status.map(
            open: (_) => 'OPEN',
            inProgress: (_) => 'IN PROGRESS',
            groomed: (_) => 'GROOMED',
            blocked: (_) => 'BLOCKED',
            onHold: (_) => 'ON HOLD',
            done: (_) => 'DONE',
            rejected: (_) => 'REJECTED',
          );
        }

        results.add(TaskSummaryResult(
          taskId: task.meta.id,
          taskTitle: task is Task ? task.data.title : 'Task',
          summary: 'No AI summary available for this task.',
          taskDate: task.meta.dateFrom,
          status: statusName,
        ));
      }
    }

    return results;
  }
}
