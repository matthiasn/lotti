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

/// The user's choice of grouping, ordering, whether done tasks stay in
/// their groups or fold into one trailing "Done" group, and which groups are
/// folded shut. Remembered per project; the defaults are what a project
/// shows the first time.
@immutable
class ProjectTaskListOptions {
  const ProjectTaskListOptions({
    this.groupBy = ProjectTaskGroupBy.creationMonth,
    this.sortBy = ProjectTaskSortBy.actionability,
    this.keepDoneInGroups = false,
    this.collapsedGroups = defaultCollapsedGroups,
  });

  /// Tolerant of unknown or missing values: a preference written by a newer
  /// build, or by hand, falls back field by field instead of failing.
  factory ProjectTaskListOptions.fromJson(Map<String, dynamic> json) {
    T pick<T extends Enum>(List<T> values, Object? raw, T fallback) =>
        values.firstWhere((v) => v.name == raw, orElse: () => fallback);
    final collapsed = json['collapsedGroups'];
    return ProjectTaskListOptions(
      groupBy: pick(
        ProjectTaskGroupBy.values,
        json['groupBy'],
        defaults.groupBy,
      ),
      sortBy: pick(ProjectTaskSortBy.values, json['sortBy'], defaults.sortBy),
      keepDoneInGroups: json['keepDoneInGroups'] == true,
      collapsedGroups: collapsed is List
          ? collapsed.whereType<String>().toSet()
          : defaultCollapsedGroups,
    );
  }

  static const defaults = ProjectTaskListOptions();

  /// The trailing "Done" group starts folded so a long project leads with
  /// open work.
  static const Set<String> defaultCollapsedGroups = {'done'};

  final ProjectTaskGroupBy groupBy;
  final ProjectTaskSortBy sortBy;

  /// `true` keeps finished tasks (done or rejected) inside their groups;
  /// `false` folds them into one collapsed trailing group so open work leads.
  final bool keepDoneInGroups;

  /// The ids of the groups folded shut. Group ids are unique across every
  /// grouping, so one set serves all of them.
  final Set<String> collapsedGroups;

  /// Whether the group with [groupId] is folded shut.
  bool isCollapsed(String groupId) => collapsedGroups.contains(groupId);

  /// These options with the group [groupId] folded the other way.
  ProjectTaskListOptions toggleCollapsed(String groupId) => copyWith(
    collapsedGroups: isCollapsed(groupId)
        ? (collapsedGroups.toSet()..remove(groupId))
        : {...collapsedGroups, groupId},
  );

  ProjectTaskListOptions copyWith({
    ProjectTaskGroupBy? groupBy,
    ProjectTaskSortBy? sortBy,
    bool? keepDoneInGroups,
    Set<String>? collapsedGroups,
  }) => ProjectTaskListOptions(
    groupBy: groupBy ?? this.groupBy,
    sortBy: sortBy ?? this.sortBy,
    keepDoneInGroups: keepDoneInGroups ?? this.keepDoneInGroups,
    collapsedGroups: collapsedGroups ?? this.collapsedGroups,
  );

  Map<String, dynamic> toJson() => {
    'groupBy': groupBy.name,
    'sortBy': sortBy.name,
    'keepDoneInGroups': keepDoneInGroups,
    'collapsedGroups': collapsedGroups.toList()..sort(),
  };

  @override
  bool operator ==(Object other) =>
      other is ProjectTaskListOptions &&
      other.groupBy == groupBy &&
      other.sortBy == sortBy &&
      other.keepDoneInGroups == keepDoneInGroups &&
      setEquals(other.collapsedGroups, collapsedGroups);

  @override
  int get hashCode => Object.hash(
    groupBy,
    sortBy,
    keepDoneInGroups,
    Object.hashAllUnordered(collapsedGroups),
  );

  @override
  String toString() =>
      'ProjectTaskListOptions(${groupBy.name}, ${sortBy.name}, '
      'keepDoneInGroups: $keepDoneInGroups, '
      'collapsed: ${collapsedGroups.toList()..sort()})';
}
