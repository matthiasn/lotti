import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';

/// How the Projects-tab text query is interpreted.
///
/// [disabled] short-circuits text matching (empty query); [localText] does an
/// in-memory substring match against each project's [ProjectListItemData.searchableText].
enum ProjectsSearchMode {
  disabled,
  localText,

  /// Reserved for vector-based search — not yet wired into the filter
  /// pipeline. Keep this slot so the persisted enum index stays stable
  /// when the embedding-backed path lands.
  vector,
}

/// Stable string identifiers for the six project statuses, used as filter
/// option IDs in the filter sheet and persisted in [ProjectsFilter].
///
/// These are decoupled from the `ProjectStatus` runtime types so a status
/// rename doesn't invalidate stored filter selections; map back via
/// `projectStatusKindFromFilterId`.
abstract final class ProjectStatusFilterIds {
  static const open = 'open';
  static const active = 'active';
  static const monitoring = 'monitoring';
  static const onHold = 'on-hold';
  static const completed = 'completed';
  static const archived = 'archived';
}

/// Repository-layer scope for the overview rollup: which categories to load.
///
/// Distinct from [ProjectsFilter] (the UI-layer filter applied to the loaded
/// snapshot). An empty [categoryIds] means "all categories". Value equality is
/// defined so the watch stream only re-fetches when the scope actually changes.
@immutable
class ProjectsQuery {
  const ProjectsQuery({
    this.categoryIds = const <String>{},
  });

  final Set<String> categoryIds;

  /// Returns `true` if [categoryId] is in scope. An empty query matches every
  /// category (including the `null`/unassigned group).
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

/// The user-facing filter state for the Projects tab: status + category
/// selections plus a text query and its [ProjectsSearchMode].
///
/// Held by `ProjectsFilterController` and applied to a loaded
/// [ProjectsOverviewSnapshot] via [applyProjectsFilter]. Value equality lets
/// Riverpod skip recomputes when the filter is unchanged.
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

/// Maps a concrete [ProjectStatus] to its stable [ProjectStatusFilterIds]
/// string, used to test a project against the selected status filter.
String projectStatusFilterId(ProjectStatus status) {
  return switch (status) {
    ProjectOpen() => ProjectStatusFilterIds.open,
    ProjectActive() => ProjectStatusFilterIds.active,
    ProjectMonitoring() => ProjectStatusFilterIds.monitoring,
    ProjectOnHold() => ProjectStatusFilterIds.onHold,
    ProjectCompleted() => ProjectStatusFilterIds.completed,
    ProjectArchived() => ProjectStatusFilterIds.archived,
  };
}

/// Aggregated task counts for a single project, computed by the DB rollup
/// query and shown as the progress ring / count in each list row.
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

/// One project as displayed in an overview list row: the project entity, its
/// resolved category, and aggregated task counts.
///
/// [searchableText] is the haystack used by the Projects-tab local text filter
/// (title + entry plain text + category name).
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

/// A category header plus the projects under it, the unit the overview list
/// renders as a section. A `null` [categoryId]/[category] is the
/// unassigned/uncategorised bucket.
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

/// The full set of category groups for the overview, as produced by the
/// repository rollup before any [ProjectsFilter] is applied.
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

/// Applies [filter] to a loaded [overview], returning only the matching groups.
///
/// Filtering is layered: groups are first kept by selected category (empty =
/// all), then each surviving group's projects are kept by selected status
/// (empty = all) and, when the search mode is `localText` with a non-empty
/// query, by a case-insensitive substring match against
/// [ProjectListItemData.searchableText]. Groups left with no projects are
/// dropped. This is the pure model behind `visibleProjectGroupsProvider`.
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
