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
    if (value == state.searchQuery) {
      return;
    }

    final candidate = state.copyWith(searchQuery: value);
    final visible = candidate.visibleProjects;

    final currentStillVisible = visible.any(
      (r) => r.project.meta.id == state.selectedProjectId,
    );

    final nextSelectedId = currentStillVisible
        ? state.selectedProjectId
        : (visible.isNotEmpty
              ? visible.first.project.meta.id
              : state.selectedProjectId);

    state = candidate.copyWith(selectedProjectId: nextSelectedId);
  }

  void selectProject(String projectId) {
    if (projectId == state.selectedProjectId) {
      return;
    }

    final projectExists = state.data.projects.any(
      (record) => record.project.meta.id == projectId,
    );
    if (!projectExists) {
      return;
    }

    state = state.copyWith(selectedProjectId: projectId);
  }
}
