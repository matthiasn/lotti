import 'package:lotti/features/ai_chat/domain/models/task_query.dart';
import 'package:lotti/features/ai_chat/domain/models/task_summary.dart';

abstract class TaskQueryRepository {
  Future<TaskSummaryResult> queryTasks(TaskQuery query);

  Future<TaskSummary?> getTaskSummary(String taskId);

  Future<List<TaskSummary>> getTasksWithTimeLogged({
    required DateTime startDate,
    required DateTime endDate,
    List<String>? categoryIds,
  });

  Future<List<TaskSummary>> getTasksWithAiSummary({
    required DateTime startDate,
    required DateTime endDate,
    List<String>? categoryIds,
  });

  Future<Map<String, int>> getTaskCountsByCategory({
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<Duration> getTotalTimeLogged({
    required DateTime startDate,
    required DateTime endDate,
    List<String>? categoryIds,
  });

  Future<List<String>> getAvailableCategories();

  Future<List<String>> getAvailableTags({
    List<String>? categoryIds,
  });
}
