import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai_chat/domain/models/task_query.dart';
import 'package:lotti/features/ai_chat/domain/models/task_summary.dart'
    as domain;
import 'package:lotti/features/ai_chat/domain/repositories/task_query_repository.dart';
import 'package:lotti/features/ai_chat/models/task_summary_tool.dart' as tool;
import 'package:lotti/features/ai_chat/repository/task_summary_repository.dart';
import 'package:lotti/get_it.dart';

final Provider<TaskQueryRepository> taskQueryRepositoryProvider =
    Provider((ref) {
  return TaskQueryRepositoryImpl(
    taskSummaryRepository: ref.read(taskSummaryRepositoryProvider),
    journalDb: getIt<JournalDb>(),
  );
});

class TaskQueryRepositoryImpl implements TaskQueryRepository {
  TaskQueryRepositoryImpl({
    required this.taskSummaryRepository,
    required this.journalDb,
  });

  final TaskSummaryRepository taskSummaryRepository;
  final JournalDb journalDb;

  @override
  Future<domain.TaskSummaryResult> queryTasks(TaskQuery query) async {
    // For now, we'll use the default category approach
    // In a full implementation, this would handle multiple categories
    final categoryId = query.categoryIds?.first;
    if (categoryId == null) {
      return domain.TaskSummaryResult.empty(query.startDate, query.endDate);
    }

    final request = tool.TaskSummaryRequest(
      startDate: query.startDate,
      endDate: query.endDate,
      limit: query.limit ?? 100,
    );

    final summaryResults = await taskSummaryRepository.getTaskSummaries(
      categoryId: categoryId,
      request: request,
    );

    final tasks = summaryResults.map(_convertToTaskSummary).toList();

    return domain.TaskSummaryResult(
      tasks: tasks,
      queryStartDate: query.startDate,
      queryEndDate: query.endDate,
      totalCount: tasks.length,
      limitApplied: query.limit,
      categoriesQueried: query.categoryIds,
      tagsQueried: query.tagIds,
    );
  }

  @override
  Future<domain.TaskSummary?> getTaskSummary(String taskId) async {
    try {
      final entities = await journalDb.getJournalEntitiesForIds({taskId});
      final entity = entities.isEmpty ? null : entities.first;
      if (entity == null || entity is! Task) {
        return null;
      }

      return _convertTaskToSummary(entity);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<domain.TaskSummary>> getTasksWithTimeLogged({
    required DateTime startDate,
    required DateTime endDate,
    List<String>? categoryIds,
  }) async {
    final results = <domain.TaskSummary>[];

    if (categoryIds == null || categoryIds.isEmpty) {
      return results;
    }

    for (final categoryId in categoryIds) {
      final query = TaskQuery(
        startDate: startDate,
        endDate: endDate,
        categoryIds: [categoryId],
        queryType: TaskQueryType.withTimeLogged,
      );

      final queryResult = await queryTasks(query);
      results.addAll(queryResult.tasksWithTimeLogged);
    }

    return results;
  }

  @override
  Future<List<domain.TaskSummary>> getTasksWithAiSummary({
    required DateTime startDate,
    required DateTime endDate,
    List<String>? categoryIds,
  }) async {
    final results = <domain.TaskSummary>[];

    if (categoryIds == null || categoryIds.isEmpty) {
      return results;
    }

    for (final categoryId in categoryIds) {
      final query = TaskQuery(
        startDate: startDate,
        endDate: endDate,
        categoryIds: [categoryId],
        queryType: TaskQueryType.withAiSummary,
      );

      final queryResult = await queryTasks(query);
      results.addAll(queryResult.tasks.where((task) => task.hasAiSummary));
    }

    return results;
  }

  @override
  Future<Map<String, int>> getTaskCountsByCategory({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final categories = await getAvailableCategories();
    final counts = <String, int>{};

    for (final categoryId in categories) {
      final query = TaskQuery(
        startDate: startDate,
        endDate: endDate,
        categoryIds: [categoryId],
      );

      final result = await queryTasks(query);
      if (result.hasResults) {
        // Get category name from the tasks or use categoryId
        final categoryName = result.tasks.first.categoryName ?? categoryId;
        counts[categoryName] = result.totalCount;
      }
    }

    return counts;
  }

  @override
  Future<Duration> getTotalTimeLogged({
    required DateTime startDate,
    required DateTime endDate,
    List<String>? categoryIds,
  }) async {
    if (categoryIds == null || categoryIds.isEmpty) {
      final categories = await getAvailableCategories();
      categoryIds = categories;
    }

    var totalTime = Duration.zero;

    for (final categoryId in categoryIds) {
      final query = TaskQuery(
        startDate: startDate,
        endDate: endDate,
        categoryIds: [categoryId],
      );

      final result = await queryTasks(query);
      totalTime += result.totalTimeLogged;
    }

    return totalTime;
  }

  @override
  Future<List<String>> getAvailableCategories() async {
    try {
      final categories = await journalDb.allCategoryDefinitions().get();
      return categories.map((c) => c.id).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<String>> getAvailableTags({
    List<String>? categoryIds,
  }) async {
    try {
      final tags = await journalDb.allTagEntities().get();
      return tags.map((t) => t.tag).toList();
    } catch (e) {
      return [];
    }
  }

  domain.TaskSummary _convertToTaskSummary(tool.TaskSummaryResult result) {
    return domain.TaskSummary(
      taskId: result.taskId,
      taskName: result.taskTitle,
      createdAt: result.taskDate,
      completedAt: result.status == 'DONE' ? result.taskDate : null,
      aiSummary: result.summary,
      status: _mapStatus(result.status),
      metadata: result.metadata,
    );
  }

  domain.TaskSummary _convertTaskToSummary(Task task) {
    final status = _mapTaskStatus(task.data.status);

    return domain.TaskSummary(
      taskId: task.meta.id,
      taskName: task.data.title,
      createdAt: task.meta.dateFrom,
      completedAt:
          status == domain.TaskStatus.completed ? task.meta.dateTo : null,
      status: status,
      metadata: {
        'originalStatus': task.data.status.toString(),
      },
    );
  }

  domain.TaskStatus _mapStatus(String status) {
    switch (status.toLowerCase()) {
      case 'done':
        return domain.TaskStatus.completed;
      case 'in progress':
        return domain.TaskStatus.inProgress;
      case 'open':
      case 'groomed':
        return domain.TaskStatus.planned;
      case 'rejected':
        return domain.TaskStatus.cancelled;
      default:
        return domain.TaskStatus.planned;
    }
  }

  domain.TaskStatus _mapTaskStatus(TaskStatus status) {
    return status.map(
      open: (_) => domain.TaskStatus.planned,
      inProgress: (_) => domain.TaskStatus.inProgress,
      groomed: (_) => domain.TaskStatus.planned,
      blocked: (_) => domain.TaskStatus.inProgress,
      onHold: (_) => domain.TaskStatus.planned,
      done: (_) => domain.TaskStatus.completed,
      rejected: (_) => domain.TaskStatus.cancelled,
    );
  }
}
