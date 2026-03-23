// ignore_for_file: specify_nonobvious_property_types

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_state.dart';
import 'package:lotti/features/projects/widgetbook/project_list_detail_mock_data.dart';

final projectListDetailShowcaseControllerProvider =
    NotifierProvider.autoDispose<
      ProjectListDetailShowcaseController,
      ProjectListDetailState
    >(ProjectListDetailShowcaseController.new);

class ProjectListDetailShowcaseController
    extends Notifier<ProjectListDetailState> {
  @override
  ProjectListDetailState build() {
    final data = buildProjectListDetailMockData();
    return ProjectListDetailState(
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
    final trimmed = query.trim().toLowerCase();
    final projects = trimmed.isEmpty
        ? state.data.projects
        : state.data.projects.where((record) {
            final titleMatch = record.project.data.title.toLowerCase().contains(
              trimmed,
            );
            final categoryMatch = record.category.name.toLowerCase().contains(
              trimmed,
            );
            return titleMatch || categoryMatch;
          });
    return projects.map((record) => record.project.meta.id).toList();
  }
}
