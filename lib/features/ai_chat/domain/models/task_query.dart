import 'package:freezed_annotation/freezed_annotation.dart';

part 'task_query.freezed.dart';
part 'task_query.g.dart';

@freezed
class TaskQuery with _$TaskQuery {
  const factory TaskQuery({
    required DateTime startDate,
    required DateTime endDate,
    List<String>? categoryIds,
    List<String>? tagIds,
    int? limit,
    TaskQueryType? queryType,
    Map<String, dynamic>? filters,
  }) = _TaskQuery;

  factory TaskQuery.fromJson(Map<String, dynamic> json) =>
      _$TaskQueryFromJson(json);

  factory TaskQuery.dateRange(DateTime startDate, DateTime endDate) =>
      TaskQuery(
        startDate: startDate,
        endDate: endDate,
      );

  factory TaskQuery.lastDays(int days) {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day - days);
    return TaskQuery(
      startDate: startDate,
      endDate: now,
    );
  }

  factory TaskQuery.thisWeek() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startDate =
        DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    return TaskQuery(
      startDate: startDate,
      endDate: now,
    );
  }

  factory TaskQuery.thisMonth() {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month);
    return TaskQuery(
      startDate: startDate,
      endDate: now,
    );
  }

  factory TaskQuery.lastMonth() {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1);
    final endOfLastMonth = DateTime(now.year, now.month, 0);
    return TaskQuery(
      startDate: lastMonth,
      endDate: endOfLastMonth,
    );
  }
}

extension TaskQueryX on TaskQuery {
  bool get hasDateRange => startDate.isBefore(endDate);

  bool get hasCategoryFilter => categoryIds != null && categoryIds!.isNotEmpty;

  bool get hasTagFilter => tagIds != null && tagIds!.isNotEmpty;

  Duration get dateSpan => endDate.difference(startDate);

  int get dayCount => dateSpan.inDays;

  TaskQuery withCategories(List<String> categories) => copyWith(
        categoryIds: categories,
      );

  TaskQuery withTags(List<String> tags) => copyWith(
        tagIds: tags,
      );

  TaskQuery withLimit(int maxResults) => copyWith(
        limit: maxResults,
      );
}

enum TaskQueryType {
  all,
  withTimeLogged,
  withAiSummary,
  completed,
  incomplete,
}
