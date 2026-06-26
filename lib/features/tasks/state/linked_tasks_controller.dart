import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';

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
  LinkedTasksController([this.taskId = '']);

  final String taskId;

  @override
  LinkedTasksState build() {
    return const LinkedTasksState();
  }

  /// Toggle manage mode (shows/hides unlink buttons).
  void toggleManageMode() {
    state = state.copyWith(manageMode: !state.manageMode);
  }
}

/// Provider that resolves outgoing entry links to Task entities.
///
/// This is used by LinkedTasksWidget to get resolved Task objects
/// instead of EntryLinks, avoiding the need to watch individual
/// entryControllerProviders in the widget tree.
///
/// Returns `List<JournalEntity>` (all Tasks) - caller should cast with `whereType<Task>()`.
final ProviderFamily<List<JournalEntity>, String> outgoingLinkedTasksProvider =
    Provider.autoDispose.family<List<JournalEntity>, String>(
      outgoingLinkedTasks,
      name: 'outgoingLinkedTasksProvider',
    );
List<JournalEntity> outgoingLinkedTasks(
  Ref ref,
  String taskId,
) {
  final entities = ref.watch(resolvedOutgoingLinkedEntriesProvider(taskId));
  return entities.whereType<Task>().toList();
}
