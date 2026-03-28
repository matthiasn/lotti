// ignore_for_file: specify_nonobvious_property_types

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/services/db_notification.dart';

part 'project_detail_controller.freezed.dart';

/// Typed error keys for project detail operations.
///
/// Avoids stringly-typed error passing between controller and UI.
enum ProjectDetailError {
  loadFailed,
  updateFailed,
  titleRequired,
}

@freezed
abstract class ProjectDetailState with _$ProjectDetailState {
  const factory ProjectDetailState({
    required ProjectEntry? project,
    required List<Task> linkedTasks,
    required bool isLoading,
    required bool isSaving,
    required bool hasChanges,
    ProjectDetailError? error,
  }) = _ProjectDetailState;

  factory ProjectDetailState.initial() => const ProjectDetailState(
    project: null,
    linkedTasks: [],
    isLoading: true,
    isSaving: false,
    hasChanges: false,
  );
}

final projectDetailControllerProvider = NotifierProvider.autoDispose
    .family<ProjectDetailController, ProjectDetailState, String>(
      ProjectDetailController.new,
    );

class ProjectDetailController extends Notifier<ProjectDetailState> {
  ProjectDetailController(this._projectId);

  final String _projectId;
  late final ProjectRepository _repository;
  StreamSubscription<Set<String>>? _subscription;

  ProjectEntry? _originalProject;
  ProjectEntry? _pendingProject;

  @override
  ProjectDetailState build() {
    _repository = ref.watch(projectRepositoryProvider);
    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
    });
    _init();
    return ProjectDetailState.initial();
  }

  void _init() {
    _subscription = _repository.updateStream
        .where(
          (ids) =>
              ids.contains(_projectId) || ids.contains(projectNotification),
        )
        .listen((_) => _reload());
    _reload();
  }

  Future<void> _reload() async {
    try {
      final (project, tasks) = await (
        _repository.getProjectById(_projectId),
        _repository.getTasksForProject(_projectId),
      ).wait;

      if (project != null) {
        if (_originalProject == null || !_hasChanges()) {
          // First load or clean reload: update both baseline and pending
          _originalProject = project;
          _pendingProject = project;
        }
      }

      if (ref.mounted) {
        state = state.copyWith(
          project: _hasChanges() ? _pendingProject : project,
          linkedTasks: tasks,
          isLoading: false,
          hasChanges: _hasChanges(),
          error: null,
        );
      }
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(
          isLoading: false,
          error: ProjectDetailError.loadFailed,
        );
      }
    }
  }

  bool _hasChanges() {
    if (_pendingProject == null || _originalProject == null) return false;
    return _pendingProject!.data.title != _originalProject!.data.title ||
        _pendingProject!.meta.categoryId != _originalProject!.meta.categoryId ||
        _pendingProject!.data.targetDate != _originalProject!.data.targetDate ||
        _pendingProject!.data.status != _originalProject!.data.status;
  }

  /// Updates the pending project title.
  void updateTitle(String title) {
    if (_pendingProject == null) return;
    _pendingProject = _pendingProject!.copyWith(
      data: _pendingProject!.data.copyWith(title: title),
    );
    state = state.copyWith(
      project: _pendingProject,
      hasChanges: _hasChanges(),
      error: null,
    );
  }

  /// Updates the pending project target date.
  void updateTargetDate(DateTime? targetDate) {
    if (_pendingProject == null) return;
    _pendingProject = _pendingProject!.copyWith(
      data: _pendingProject!.data.copyWith(targetDate: targetDate),
    );
    state = state.copyWith(
      project: _pendingProject,
      hasChanges: _hasChanges(),
      error: null,
    );
  }

  /// Updates the pending project category.
  void updateCategoryId(String? categoryId) {
    if (_pendingProject == null) return;
    _pendingProject = _pendingProject!.copyWith(
      meta: _pendingProject!.meta.copyWith(categoryId: categoryId),
    );
    state = state.copyWith(
      project: _pendingProject,
      hasChanges: _hasChanges(),
      error: null,
    );
  }

  /// Updates the pending project status.
  ///
  /// Only updates the status field on the pending project; the status
  /// history is appended in [saveChanges] when the change is persisted.
  void updateStatus(ProjectStatus newStatus) {
    if (_pendingProject == null) return;
    _pendingProject = _pendingProject!.copyWith(
      data: _pendingProject!.data.copyWith(status: newStatus),
    );
    state = state.copyWith(
      project: _pendingProject,
      hasChanges: _hasChanges(),
      error: null,
    );
  }

  /// Persists pending changes.
  ///
  /// If the status was changed, the previous status is appended to the
  /// history at save time (not during each picker change) so that rapid
  /// toggling doesn't bloat the history.
  Future<void> saveChanges() async {
    if (_pendingProject == null || !state.hasChanges || state.isSaving) return;

    if (_pendingProject!.data.title.trim().isEmpty) {
      state = state.copyWith(
        error: ProjectDetailError.titleRequired,
        isSaving: false,
      );
      return;
    }

    state = state.copyWith(isSaving: true, error: null);

    try {
      // Append the original status to history when status has changed.
      var toSave = _pendingProject!;
      if (_originalProject != null &&
          _pendingProject!.data.status != _originalProject!.data.status) {
        toSave = toSave.copyWith(
          data: toSave.data.copyWith(
            statusHistory: [
              ...toSave.data.statusHistory,
              _originalProject!.data.status,
            ],
          ),
        );
      }

      final success = await _repository.updateProject(toSave);
      if (!ref.mounted) return;
      if (success) {
        _originalProject = toSave;
        _pendingProject = toSave;
        state = state.copyWith(
          project: toSave,
          isSaving: false,
          hasChanges: false,
        );
      } else {
        state = state.copyWith(
          isSaving: false,
          error: ProjectDetailError.updateFailed,
        );
      }
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isSaving: false,
        error: ProjectDetailError.updateFailed,
      );
    }
  }
}
