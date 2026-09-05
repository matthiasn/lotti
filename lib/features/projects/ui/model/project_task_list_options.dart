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
    this.keepDoneInGroups = false,
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
      keepDoneInGroups: json['keepDoneInGroups'] == true,
    );
  }

  static const defaults = ProjectTaskListOptions();

  final ProjectTaskGroupBy groupBy;
  final ProjectTaskSortBy sortBy;

  /// `true` keeps finished tasks (done or rejected) inside their groups;
  /// `false` folds them into one collapsed trailing group so open work leads.
  final bool keepDoneInGroups;

  ProjectTaskListOptions copyWith({
    ProjectTaskGroupBy? groupBy,
    ProjectTaskSortBy? sortBy,
    bool? keepDoneInGroups,
  }) => ProjectTaskListOptions(
    groupBy: groupBy ?? this.groupBy,
    sortBy: sortBy ?? this.sortBy,
    keepDoneInGroups: keepDoneInGroups ?? this.keepDoneInGroups,
  );

  Map<String, dynamic> toJson() => {
    'groupBy': groupBy.name,
    'sortBy': sortBy.name,
    'keepDoneInGroups': keepDoneInGroups,
  };

  @override
  bool operator ==(Object other) =>
      other is ProjectTaskListOptions &&
      other.groupBy == groupBy &&
      other.sortBy == sortBy &&
      other.keepDoneInGroups == keepDoneInGroups;

  @override
  int get hashCode => Object.hash(groupBy, sortBy, keepDoneInGroups);

  @override
  String toString() =>
      'ProjectTaskListOptions(${groupBy.name}, ${sortBy.name}, '
      'keepDoneInGroups: $keepDoneInGroups)';
}
