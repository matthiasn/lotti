import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';

/// UI state for the project list/detail layout.
///
/// Holds the backing data, the shared projects filter state, and the selected
/// project ID. Computed getters derive the visible projects and groups from
/// these values.
class ProjectListDetailState {
  ProjectListDetailState({
    required this.data,
    required this.filter,
    required this.selectedProjectId,
  });

  final ProjectListData data;
  final ProjectsFilter filter;
  final String selectedProjectId;

  String get searchQuery => filter.textQuery;

  late final ProjectsOverviewSnapshot overviewSnapshot = data.overviewSnapshot;

  /// Cached grouped project list. Computed lazily on first access.
  late final List<ProjectCategoryGroup> visibleGroups = applyProjectsFilter(
    overviewSnapshot,
    filter,
  );

  /// Cached filtered project list. Computed lazily on first access and reused
  /// by [selectedProject].
  late final List<ProjectRecord> visibleProjects = _computeVisibleProjects();

  ProjectRecord? get selectedProject {
    return visibleProjects
            .where((r) => r.project.meta.id == selectedProjectId)
            .firstOrNull ??
        visibleProjects.firstOrNull;
  }

  List<ProjectRecord> _computeVisibleProjects() {
    final visibleIds = visibleGroups
        .expand((group) => group.projects)
        .map((project) => project.project.meta.id)
        .toSet();

    return data.projects
        .where((record) => visibleIds.contains(record.project.meta.id))
        .toList(growable: false);
  }

  ProjectListDetailState copyWith({
    ProjectListData? data,
    ProjectsFilter? filter,
    String? selectedProjectId,
  }) {
    return ProjectListDetailState(
      data: data ?? this.data,
      filter: filter ?? this.filter,
      selectedProjectId: selectedProjectId ?? this.selectedProjectId,
    );
  }
}
