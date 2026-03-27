import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';

enum ProjectsSearchMode {
  disabled,
  localText,
  vector,
}

abstract final class ProjectStatusFilterIds {
  static const open = 'open';
  static const active = 'active';
  static const onHold = 'on-hold';
  static const completed = 'completed';
  static const archived = 'archived';
}

@immutable
class ProjectsQuery {
  const ProjectsQuery({
    this.categoryIds = const <String>{},
  });

  final Set<String> categoryIds;

  bool matchesCategory(String? categoryId) {
    if (categoryIds.isEmpty) {
      return true;
    }
    return categoryId != null && categoryIds.contains(categoryId);
  }

  ProjectsQuery copyWith({
    Set<String>? categoryIds,
  }) {
    return ProjectsQuery(
      categoryIds: categoryIds ?? this.categoryIds,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ProjectsQuery &&
            const SetEquality<String>().equals(
              other.categoryIds,
              categoryIds,
            );
  }

  @override
  int get hashCode => const SetEquality<String>().hash(categoryIds);
}

@immutable
class ProjectsFilter {
  const ProjectsFilter({
    this.selectedStatusIds = const <String>{},
    this.selectedCategoryIds = const <String>{},
    this.textQuery = '',
    this.searchMode = ProjectsSearchMode.disabled,
  });

  final Set<String> selectedStatusIds;
  final Set<String> selectedCategoryIds;
  final String textQuery;
  final ProjectsSearchMode searchMode;

  ProjectsFilter copyWith({
    Set<String>? selectedStatusIds,
    Set<String>? selectedCategoryIds,
    String? textQuery,
    ProjectsSearchMode? searchMode,
  }) {
    return ProjectsFilter(
      selectedStatusIds: selectedStatusIds ?? this.selectedStatusIds,
      selectedCategoryIds: selectedCategoryIds ?? this.selectedCategoryIds,
      textQuery: textQuery ?? this.textQuery,
      searchMode: searchMode ?? this.searchMode,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ProjectsFilter &&
            const SetEquality<String>().equals(
              other.selectedStatusIds,
              selectedStatusIds,
            ) &&
            const SetEquality<String>().equals(
              other.selectedCategoryIds,
              selectedCategoryIds,
            ) &&
            other.textQuery == textQuery &&
            other.searchMode == searchMode;
  }

  @override
  int get hashCode => Object.hash(
    const SetEquality<String>().hash(selectedStatusIds),
    const SetEquality<String>().hash(selectedCategoryIds),
    textQuery,
    searchMode,
  );
}

String projectStatusFilterId(ProjectStatus status) {
  return switch (status) {
    ProjectOpen() => ProjectStatusFilterIds.open,
    ProjectActive() => ProjectStatusFilterIds.active,
    ProjectOnHold() => ProjectStatusFilterIds.onHold,
    ProjectCompleted() => ProjectStatusFilterIds.completed,
    ProjectArchived() => ProjectStatusFilterIds.archived,
  };
}

@immutable
class ProjectTaskRollupData {
  const ProjectTaskRollupData({
    this.totalTaskCount = 0,
    this.completedTaskCount = 0,
    this.blockedTaskCount = 0,
  });

  final int totalTaskCount;
  final int completedTaskCount;
  final int blockedTaskCount;

  double get completionRatio {
    if (totalTaskCount == 0) {
      return 0;
    }
    return completedTaskCount / totalTaskCount;
  }

  int get completionPercent => (completionRatio * 100).round();
}

@immutable
class ProjectListItemData {
  const ProjectListItemData({
    required this.project,
    required this.category,
    required this.taskRollup,
  });

  final ProjectEntry project;
  final CategoryDefinition? category;
  final ProjectTaskRollupData taskRollup;

  String? get categoryId => project.meta.categoryId;

  String get categoryName => category?.name ?? '';

  ProjectStatus get status => project.data.status;

  DateTime? get targetDate => project.data.targetDate;

  String get searchableText => [
    project.data.title,
    project.entryText?.plainText ?? '',
    categoryName,
  ].where((segment) => segment.trim().isNotEmpty).join(' ');
}

@immutable
class ProjectCategoryGroup {
  const ProjectCategoryGroup({
    required this.categoryId,
    required this.category,
    required this.projects,
  });

  final String? categoryId;
  final CategoryDefinition? category;
  final List<ProjectListItemData> projects;

  int get projectCount => projects.length;

  ProjectCategoryGroup copyWith({
    List<ProjectListItemData>? projects,
  }) {
    return ProjectCategoryGroup(
      categoryId: categoryId,
      category: category,
      projects: projects ?? this.projects,
    );
  }
}

@immutable
class ProjectsOverviewSnapshot {
  const ProjectsOverviewSnapshot({
    required this.groups,
  });

  final List<ProjectCategoryGroup> groups;

  int get totalProjectCount => groups.fold<int>(
    0,
    (sum, group) => sum + group.projectCount,
  );

  bool get isEmpty => totalProjectCount == 0;
}

List<ProjectCategoryGroup> applyProjectsFilter(
  ProjectsOverviewSnapshot overview,
  ProjectsFilter filter,
) {
  final selectedStatusIds = filter.selectedStatusIds;
  final selectedCategoryIds = filter.selectedCategoryIds;
  final normalizedQuery = filter.textQuery.trim().toLowerCase();
  final shouldApplyTextQuery =
      normalizedQuery.isNotEmpty &&
      filter.searchMode == ProjectsSearchMode.localText;

  return overview.groups
      .where(
        (group) =>
            selectedCategoryIds.isEmpty ||
            (group.categoryId != null &&
                selectedCategoryIds.contains(group.categoryId)),
      )
      .map((group) {
        final filteredProjects = group.projects
            .where((project) {
              final matchesStatus =
                  selectedStatusIds.isEmpty ||
                  selectedStatusIds.contains(
                    projectStatusFilterId(project.status),
                  );
              final matchesQuery =
                  !shouldApplyTextQuery ||
                  project.searchableText.toLowerCase().contains(
                    normalizedQuery,
                  );
              return matchesStatus && matchesQuery;
            })
            .toList(growable: false);
        return group.copyWith(projects: filteredProjects);
      })
      .where((group) => group.projects.isNotEmpty)
      .toList(growable: false);
}
