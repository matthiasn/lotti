import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_activator.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:lotti/features/tasks/ui/filtering/task_filter_modal.dart';
import 'package:lotti/features/tasks/ui/saved_filters/saved_task_filter_toast.dart';
import 'package:lotti/features/tasks/ui/saved_filters/saved_task_filters_section.dart';

/// Sidebar subtree under the Tasks destination.
///
/// Wires:
/// - [savedTaskFiltersControllerProvider] for the persisted list,
/// - [currentSavedTaskFilterIdProvider] to highlight the active row,
/// - [tasksFilterHasUnsavedClausesProvider] to enable the `+` button,
/// - [SavedTaskFilterActivator] to apply a saved filter to the live page,
/// - [showTaskFilterModal] to open the modal when `+` is pressed (where
///   the user names and saves the current filter).
class TasksSavedFiltersTree extends ConsumerWidget {
  const TasksSavedFiltersTree({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeId = ref.watch(currentSavedTaskFilterIdProvider);
    final canAdd = ref.watch(tasksFilterHasUnsavedClausesProvider);

    return SavedTaskFiltersSection(
      activeId: activeId,
      canAdd: canAdd,
      onActivate: (SavedTaskFilter saved) async {
        final controller = ref.read(
          journalPageControllerProvider(true).notifier,
        );
        await SavedTaskFilterActivator(controller).activate(saved);
      },
      onAddPressed: () => showTaskFilterModal(context, showTasks: true),
      onDeleted: () => showSavedTaskFilterDeletedToast(context),
    );
  }
}
