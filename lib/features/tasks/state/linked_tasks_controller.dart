import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'linked_tasks_controller.freezed.dart';

/// UI state for the LinkedTasks section in task detail view.
@freezed
abstract class LinkedTasksState with _$LinkedTasksState {
  const factory LinkedTasksState({
    /// Whether manage mode is active (shows unlink X buttons).
    @Default(false) bool manageMode,
  }) = _LinkedTasksState;
}

/// Controller for managing the LinkedTasks section UI state.
final NotifierProviderFamily<LinkedTasksController, LinkedTasksState, String>
linkedTasksControllerProvider = NotifierProvider.autoDispose
    .family<LinkedTasksController, LinkedTasksState, String>(
      LinkedTasksController.new,
      name: 'linkedTasksControllerProvider',
    );

class LinkedTasksController extends Notifier<LinkedTasksState> {
  LinkedTasksController([String _ = '']);

  @override
  LinkedTasksState build() {
    return const LinkedTasksState();
  }

  /// Toggle manage mode (shows/hides unlink buttons).
  void toggleManageMode() {
    state = state.copyWith(manageMode: !state.manageMode);
  }
}
