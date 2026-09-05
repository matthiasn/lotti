import 'package:flutter/foundation.dart';

/// How the project detail groups its task list.
enum ProjectTaskGroupBy { creationMonth, status, priority, dueWindow, none }

/// How tasks are ordered inside each group.
enum ProjectTaskSortBy {
  actionability,
  created,
  dueDate,
  estimate,
  priority,
  recentlyUpdated,
  title,
}

/// The user's choice of grouping, ordering and whether done tasks stay in
/// their groups or fold into one trailing "Done" group. Remembered per
/// project; the defaults are what a project shows the first time.
@immutable
class ProjectTaskListOptions {
  const ProjectTaskListOptions({
    this.groupBy = ProjectTaskGroupBy.creationMonth,
    this.sortBy = ProjectTaskSortBy.actionability,
    this.showDone = false,
  });

  /// Tolerant of unknown or missing values: a preference written by a newer
  /// build, or by hand, falls back field by field instead of failing.
  factory ProjectTaskListOptions.fromJson(Map<String, dynamic> json) {
    T pick<T extends Enum>(List<T> values, Object? raw, T fallback) =>
        values.firstWhere((v) => v.name == raw, orElse: () => fallback);
    return ProjectTaskListOptions(
      groupBy: pick(
        ProjectTaskGroupBy.values,
        json['groupBy'],
        defaults.groupBy,
      ),
      sortBy: pick(ProjectTaskSortBy.values, json['sortBy'], defaults.sortBy),
      showDone: json['showDone'] == true,
    );
  }

  static const defaults = ProjectTaskListOptions();

  final ProjectTaskGroupBy groupBy;
  final ProjectTaskSortBy sortBy;

  /// `true` keeps done tasks inside their groups; `false` folds them into
  /// one trailing group.
  final bool showDone;

  ProjectTaskListOptions copyWith({
    ProjectTaskGroupBy? groupBy,
    ProjectTaskSortBy? sortBy,
    bool? showDone,
  }) => ProjectTaskListOptions(
    groupBy: groupBy ?? this.groupBy,
    sortBy: sortBy ?? this.sortBy,
    showDone: showDone ?? this.showDone,
  );

  Map<String, dynamic> toJson() => {
    'groupBy': groupBy.name,
    'sortBy': sortBy.name,
    'showDone': showDone,
  };

  @override
  bool operator ==(Object other) =>
      other is ProjectTaskListOptions &&
      other.groupBy == groupBy &&
      other.sortBy == sortBy &&
      other.showDone == showDone;

  @override
  int get hashCode => Object.hash(groupBy, sortBy, showDone);

  @override
  String toString() =>
      'ProjectTaskListOptions(${groupBy.name}, ${sortBy.name}, '
      'showDone: $showDone)';
}
