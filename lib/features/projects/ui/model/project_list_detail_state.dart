import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';

/// UI state for the project list/detail layout.
///
/// Holds the backing data, the current search query, and the selected project
/// ID. Computed getters derive the visible projects and groups from these
/// values.
class ProjectListDetailState {
  const ProjectListDetailState({
    required this.data,
    required this.searchQuery,
    required this.selectedProjectId,
  });

  final ProjectListData data;
  final String searchQuery;
  final String selectedProjectId;

  ProjectRecord? get selectedProject {
    final visible = visibleProjects;

    for (final record in visible) {
      if (record.project.meta.id == selectedProjectId) {
        return record;
      }
    }

    return visible.isNotEmpty ? visible.first : null;
  }

  List<ProjectRecord> get visibleProjects {
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
    final visibleIds = visibleProjects
        .map((project) => project.project.meta.id)
        .toSet();
    final groups = <ProjectGroup>[];

    for (final category in data.categories) {
      final projects = data.projects.where((record) {
        return record.category.id == category.id &&
            visibleIds.contains(record.project.meta.id);
      }).toList();

      if (projects.isEmpty) {
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
