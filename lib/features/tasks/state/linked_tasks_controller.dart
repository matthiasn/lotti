import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'linked_tasks_controller.freezed.dart';
part 'linked_tasks_controller.g.dart';

/// UI state for the LinkedTasks section in task detail view.
@freezed
abstract class LinkedTasksState with _$LinkedTasksState {
  const factory LinkedTasksState({
    /// Whether manage mode is active (shows unlink X buttons).
    @Default(false) bool manageMode,
  }) = _LinkedTasksState;
}

/// Controller for managing the LinkedTasks section UI state.
@riverpod
class LinkedTasksController extends _$LinkedTasksController {
  @override
  LinkedTasksState build({required String taskId}) {
    return const LinkedTasksState();
  }

  /// Toggle manage mode (shows/hides unlink buttons).
  void toggleManageMode() {
    state = state.copyWith(manageMode: !state.manageMode);
  }

  /// Exit manage mode.
  void exitManageMode() {
    state = state.copyWith(manageMode: false);
  }
}
