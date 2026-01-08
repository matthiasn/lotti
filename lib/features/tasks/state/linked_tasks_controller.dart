import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
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

/// Provider that resolves outgoing entry links to Task entities.
///
/// This is used by LinkedToSection to get resolved Task objects
/// instead of EntryLinks, avoiding the need to watch individual
/// entryControllerProviders in the widget tree.
///
/// Returns `List<JournalEntity>` (all Tasks) - caller should cast with `whereType<Task>()`.
@riverpod
List<JournalEntity> outgoingLinkedTasks(
  Ref ref,
  String taskId,
) {
  final entities = ref.watch(resolvedOutgoingLinkedEntriesProvider(taskId));
  return entities.whereType<Task>().toList();
}
