import 'package:freezed_annotation/freezed_annotation.dart';

part 'task_summary.freezed.dart';
part 'task_summary.g.dart';

@freezed
class TaskSummary with _$TaskSummary {
  const factory TaskSummary({
    required String taskId,
    required String taskName,
    required DateTime createdAt,
    DateTime? completedAt,
    String? categoryId,
    String? categoryName,
    List<String>? tags,
    String? aiSummary,
    Duration? timeLogged,
    TaskStatus? status,
    Map<String, dynamic>? metadata,
  }) = _TaskSummary;

  factory TaskSummary.fromJson(Map<String, dynamic> json) =>
      _$TaskSummaryFromJson(json);
}

extension TaskSummaryX on TaskSummary {
  bool get isCompleted => completedAt != null;

  bool get hasAiSummary => aiSummary != null && aiSummary!.isNotEmpty;

  bool get hasTimeLogged => timeLogged != null && timeLogged!.inSeconds > 0;

  bool get hasTags => tags != null && tags!.isNotEmpty;

  String get displayName => taskName.isEmpty ? 'Untitled Task' : taskName;

  String get statusText => switch (status) {
        TaskStatus.completed => 'Completed',
        TaskStatus.inProgress => 'In Progress',
        TaskStatus.planned => 'Planned',
        TaskStatus.cancelled => 'Cancelled',
        null => 'Unknown',
      };

  Duration get loggedTimeOrZero => timeLogged ?? Duration.zero;

  String get formattedTimeLogged {
    final time = loggedTimeOrZero;
    if (time.inHours > 0) {
      return '${time.inHours}h ${time.inMinutes.remainder(60)}m';
    } else if (time.inMinutes > 0) {
      return '${time.inMinutes}m';
    } else if (time.inSeconds > 0) {
      return '${time.inSeconds}s';
    }
    return '0s';
  }
}

@freezed
class TaskSummaryResult with _$TaskSummaryResult {
  const factory TaskSummaryResult({
    required List<TaskSummary> tasks,
    required DateTime queryStartDate,
    required DateTime queryEndDate,
    required int totalCount,
    int? limitApplied,
    List<String>? categoriesQueried,
    List<String>? tagsQueried,
  }) = _TaskSummaryResult;

  factory TaskSummaryResult.fromJson(Map<String, dynamic> json) =>
      _$TaskSummaryResultFromJson(json);

  factory TaskSummaryResult.empty(DateTime startDate, DateTime endDate) =>
      TaskSummaryResult(
        tasks: [],
        queryStartDate: startDate,
        queryEndDate: endDate,
        totalCount: 0,
      );
}

extension TaskSummaryResultX on TaskSummaryResult {
  bool get isEmpty => tasks.isEmpty;

  bool get hasResults => tasks.isNotEmpty;

  Duration get totalTimeLogged => tasks.fold(
        Duration.zero,
        (total, task) => total + task.loggedTimeOrZero,
      );

  int get completedTasksCount => tasks.where((task) => task.isCompleted).length;

  int get tasksWithAiSummaryCount =>
      tasks.where((task) => task.hasAiSummary).length;

  List<TaskSummary> get completedTasks =>
      tasks.where((task) => task.isCompleted).toList();

  List<TaskSummary> get incompleteTasks =>
      tasks.where((task) => !task.isCompleted).toList();

  List<TaskSummary> get tasksWithTimeLogged =>
      tasks.where((task) => task.hasTimeLogged).toList();

  Map<String, List<TaskSummary>> get tasksByCategory {
    final result = <String, List<TaskSummary>>{};
    for (final task in tasks) {
      final category = task.categoryName ?? 'Uncategorized';
      result.putIfAbsent(category, () => []).add(task);
    }
    return result;
  }

  String get formattedDateRange {
    final startFormatted =
        '${queryStartDate.day}/${queryStartDate.month}/${queryStartDate.year}';
    final endFormatted =
        '${queryEndDate.day}/${queryEndDate.month}/${queryEndDate.year}';
    return '$startFormatted - $endFormatted';
  }
}

enum TaskStatus {
  planned,
  inProgress,
  completed,
  cancelled,
}
