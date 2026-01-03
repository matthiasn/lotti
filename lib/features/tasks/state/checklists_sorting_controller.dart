// ignore_for_file: specify_nonobvious_property_types

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'checklists_sorting_controller.freezed.dart';

/// State for the global checklist sorting mode.
///
/// When sorting mode is active, all checklist cards collapse and
/// show large drag handles for reordering. The [preExpansionStates]
/// map stores which checklists were expanded before entering sorting mode,
/// so they can be restored when exiting.
@freezed
abstract class ChecklistsSortingState with _$ChecklistsSortingState {
  const factory ChecklistsSortingState({
    /// Whether sorting mode is currently active.
    @Default(false) bool isSorting,

    /// Map of checklist IDs to their expansion state before sorting began.
    /// Used to restore expansion states when exiting sorting mode.
    @Default(<String, bool>{}) Map<String, bool> preExpansionStates,
  }) = _ChecklistsSortingState;
}

/// Controller for managing the global checklist sorting mode within a task.
///
/// Usage:
/// ```dart
/// final sortingState = ref.watch(checklistsSortingControllerProvider(taskId));
/// final notifier = ref.read(checklistsSortingControllerProvider(taskId).notifier);
/// notifier.enterSortingMode({'checklist-1': true, 'checklist-2': false});
/// ```
class ChecklistsSortingController extends Notifier<ChecklistsSortingState> {
  ChecklistsSortingController(this.taskId);

  final String taskId;

  @override
  ChecklistsSortingState build() {
    return const ChecklistsSortingState();
  }

  /// Enters sorting mode, storing the current expansion states.
  ///
  /// [currentExpansionStates] is a map of checklist IDs to their current
  /// expanded/collapsed state. These will be restored when exitSortingMode
  /// is called.
  void enterSortingMode(Map<String, bool> currentExpansionStates) {
    state = state.copyWith(
      isSorting: true,
      preExpansionStates: Map<String, bool>.from(currentExpansionStates),
    );
  }

  /// Exits sorting mode.
  ///
  /// The `preExpansionStates` are retained so widgets can read them
  /// and restore their expansion state.
  void exitSortingMode() {
    state = state.copyWith(isSorting: false);
  }

  /// Clears the stored expansion states after they have been restored.
  ///
  /// Call this after all checklists have restored their expansion states.
  void clearPreExpansionStates() {
    state = state.copyWith(preExpansionStates: const <String, bool>{});
  }
}

/// Provider for the checklist sorting controller, scoped to a task.
///
/// The [String] parameter is the task ID.
final checklistsSortingControllerProvider = NotifierProvider.autoDispose
    .family<ChecklistsSortingController, ChecklistsSortingState, String>(
  ChecklistsSortingController.new,
);
