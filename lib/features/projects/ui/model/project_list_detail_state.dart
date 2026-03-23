import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';

/// UI state for the project list/detail layout.
///
/// Holds the backing data, the current search query, and the selected project
/// ID. Computed getters derive the visible projects and groups from these
/// values.
class ProjectListDetailState {
  ProjectListDetailState({
    required this.data,
    required this.searchQuery,
    required this.selectedProjectId,
  });

  final ProjectListData data;
  final String searchQuery;
  final String selectedProjectId;

  /// Cached filtered project list. Computed lazily on first access and reused
  /// by [selectedProject] and [visibleGroups].
  late final List<ProjectRecord> visibleProjects = _computeVisibleProjects();

  ProjectRecord? get selectedProject {
    return visibleProjects
            .where((r) => r.project.meta.id == selectedProjectId)
            .firstOrNull ??
        visibleProjects.firstOrNull;
  }

  List<ProjectRecord> _computeVisibleProjects() {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return data.projects;
    }

    return data.projects.where((record) {
      final titleMatch = record.project.data.title.toLowerCase().contains(
        query,
      );
      final categoryMatch = record.category.name.toLowerCase().contains(query);
      return titleMatch || categoryMatch;
    }).toList();
  }

  List<ProjectGroup> get visibleGroups {
    final visible = visibleProjects;
    final byCategory = <String, List<ProjectRecord>>{};

    for (final record in visible) {
      (byCategory[record.category.id] ??= []).add(record);
    }

    final groups = <ProjectGroup>[];

    for (final category in data.categories) {
      final projects = byCategory[category.id];
      if (projects == null || projects.isEmpty) {
        continue;
      }

      groups.add(
        ProjectGroup(
          label: category.name,
          projects: projects,
        ),
      );
    }

    return groups;
  }

  ProjectListDetailState copyWith({
    ProjectListData? data,
    String? searchQuery,
    String? selectedProjectId,
  }) {
    return ProjectListDetailState(
      data: data ?? this.data,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedProjectId: selectedProjectId ?? this.selectedProjectId,
    );
  }
}
