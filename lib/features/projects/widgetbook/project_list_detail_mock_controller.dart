// ignore_for_file: specify_nonobvious_property_types

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/projects/widgetbook/project_list_detail_mock_data.dart';

class ProjectListDetailShowcaseGroup {
  const ProjectListDetailShowcaseGroup({
    required this.label,
    required this.projects,
  });

  final String label;
  final List<ProjectListDetailMockRecord> projects;
}

class ProjectListDetailShowcaseState {
  const ProjectListDetailShowcaseState({
    required this.data,
    required this.searchQuery,
    required this.selectedProjectId,
  });

  final ProjectListDetailMockData data;
  final String searchQuery;
  final String selectedProjectId;

  ProjectListDetailMockRecord? get selectedProject {
    return _recordForId(selectedProjectId) ??
        (visibleProjects.isNotEmpty ? visibleProjects.first : null) ??
        (data.projects.isNotEmpty ? data.projects.first : null);
  }

  List<ProjectListDetailMockRecord> get visibleProjects {
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

  List<ProjectListDetailShowcaseGroup> get visibleGroups {
    final visibleIds = visibleProjects
        .map((project) => project.project.meta.id)
        .toSet();
    final groups = <ProjectListDetailShowcaseGroup>[];

    for (final category in data.categories) {
      final projects = data.projects.where((record) {
        return record.category.id == category.id &&
            visibleIds.contains(record.project.meta.id);
      }).toList();

      if (projects.isEmpty) {
        continue;
      }

      groups.add(
        ProjectListDetailShowcaseGroup(
          label: category.name,
          projects: projects,
        ),
      );
    }

    return groups;
  }

  ProjectListDetailShowcaseState copyWith({
    ProjectListDetailMockData? data,
    String? searchQuery,
    String? selectedProjectId,
  }) {
    return ProjectListDetailShowcaseState(
      data: data ?? this.data,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedProjectId: selectedProjectId ?? this.selectedProjectId,
    );
  }

  ProjectListDetailMockRecord? _recordForId(String projectId) {
    for (final record in data.projects) {
      if (record.project.meta.id == projectId) {
        return record;
      }
    }
    return null;
  }
}

final projectListDetailShowcaseControllerProvider =
    NotifierProvider.autoDispose<
      ProjectListDetailShowcaseController,
      ProjectListDetailShowcaseState
    >(ProjectListDetailShowcaseController.new);

class ProjectListDetailShowcaseController
    extends Notifier<ProjectListDetailShowcaseState> {
  @override
  ProjectListDetailShowcaseState build() {
    final data = buildProjectListDetailMockData();
    return ProjectListDetailShowcaseState(
      data: data,
      searchQuery: '',
      selectedProjectId: data.projects.first.project.meta.id,
    );
  }

  void updateSearchQuery(String value) {
    final nextSelectedProjectId = _selectedProjectIdForQuery(
      query: value,
      fallbackSelectedProjectId: state.selectedProjectId,
    );

    state = state.copyWith(
      searchQuery: value,
      selectedProjectId: nextSelectedProjectId,
    );
  }

  void selectProject(String projectId) {
    final projectExists = state.data.projects.any(
      (record) => record.project.meta.id == projectId,
    );
    if (!projectExists) {
      return;
    }

    state = state.copyWith(selectedProjectId: projectId);
  }

  String _selectedProjectIdForQuery({
    required String query,
    required String fallbackSelectedProjectId,
  }) {
    final visibleProjectIds = _visibleProjectIdsForQuery(query);

    if (visibleProjectIds.contains(fallbackSelectedProjectId)) {
      return fallbackSelectedProjectId;
    }

    if (visibleProjectIds.isNotEmpty) {
      return visibleProjectIds.first;
    }

    return fallbackSelectedProjectId;
  }

  List<String> _visibleProjectIdsForQuery(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return state.data.projects
          .map((record) => record.project.meta.id)
          .toList();
    }

    return state.data.projects
        .where((record) {
          final titleMatch = record.project.data.title.toLowerCase().contains(
            normalizedQuery,
          );
          final categoryMatch = record.category.name.toLowerCase().contains(
            normalizedQuery,
          );
          return titleMatch || categoryMatch;
        })
        .map((record) => record.project.meta.id)
        .toList();
  }
}
