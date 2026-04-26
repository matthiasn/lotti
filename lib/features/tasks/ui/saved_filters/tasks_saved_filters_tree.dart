import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_activator.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:lotti/features/tasks/ui/saved_filters/saved_task_filter_toast.dart';
import 'package:lotti/features/tasks/ui/saved_filters/saved_task_filters_section.dart';

/// Sidebar subtree under the Tasks destination.
///
/// Wires:
/// - [savedTaskFiltersControllerProvider] for the persisted list,
/// - [currentSavedTaskFilterIdProvider] to highlight the active row,
/// - [SavedTaskFilterActivator] to apply a saved filter to the live page.
///
/// New filters are saved through the Save button in the Tasks Filter modal,
/// not from the sidebar — so the section deliberately has no `+` affordance.
class TasksSavedFiltersTree extends ConsumerWidget {
  const TasksSavedFiltersTree({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeId = ref.watch(currentSavedTaskFilterIdProvider);

    return SavedTaskFiltersSection(
      activeId: activeId,
      onActivate: (SavedTaskFilter saved) async {
        final controller = ref.read(
          journalPageControllerProvider(true).notifier,
        );
        await SavedTaskFilterActivator(controller).activate(saved);
      },
      // onDeleted fires after an awaited controller mutation, so guard against
      // a defunct context (the user could have navigated away mid-flight).
      onDeleted: () {
        if (!context.mounted) return;
        showSavedTaskFilterDeletedToast(context);
      },
    );
  }
}
