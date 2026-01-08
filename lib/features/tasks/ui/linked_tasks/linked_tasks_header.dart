import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/state/linked_from_entries_controller.dart';
import 'package:lotti/features/tasks/state/linked_tasks_controller.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/link_task_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/create_entry.dart';
import 'package:lotti/themes/theme.dart';

/// Section header for the Linked Tasks section with title and menu.
class LinkedTasksHeader extends ConsumerWidget {
  const LinkedTasksHeader({
    required this.taskId,
    required this.hasLinkedTasks,
    super.key,
  });

  final String taskId;
  final bool hasLinkedTasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = context.colorScheme.outline;
    final uiState = ref.watch(linkedTasksControllerProvider(taskId: taskId));
    final notifier =
        ref.read(linkedTasksControllerProvider(taskId: taskId).notifier);

    return Row(
      children: [
        Text(
          context.messages.linkedTasksTitle,
          style: context.textTheme.titleSmall?.copyWith(color: color),
        ),
        const Spacer(),
        // Menu button
        Theme(
          data: Theme.of(context).copyWith(
            popupMenuTheme: PopupMenuThemeData(
              color: context.colorScheme.surfaceContainerHighest,
              elevation: 8,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color:
                      context.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  width: 0.8,
                ),
              ),
            ),
          ),
          child: PopupMenuButton<String>(
            tooltip: context.messages.linkedTasksMenuTooltip,
            icon: Icon(Icons.more_vert, color: color, size: 20),
            position: PopupMenuPosition.under,
            onSelected: (value) async {
              switch (value) {
                case 'link_existing':
                  await _showLinkTaskModal(context, ref);
                case 'create_new':
                  await _createNewLinkedTask(context, ref);
                case 'manage':
                  notifier.toggleManageMode();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'link_existing',
                child: Row(
                  children: [
                    const Icon(Icons.link, size: 18),
                    const SizedBox(width: 8),
                    Flexible(child: Text(context.messages.linkExistingTask)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'create_new',
                child: Row(
                  children: [
                    const Icon(Icons.add, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(context.messages.createNewLinkedTask),
                    ),
                  ],
                ),
              ),
              if (hasLinkedTasks)
                PopupMenuItem(
                  value: 'manage',
                  child: Row(
                    children: [
                      Icon(
                        uiState.manageMode
                            ? Icons.check_rounded
                            : Icons.edit_rounded,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          uiState.manageMode
                              ? context.messages.doneButton
                              : context.messages.manageLinks,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showLinkTaskModal(BuildContext context, WidgetRef ref) async {
    // Collect existing linked task IDs to exclude from search results
    final outgoingLinks =
        ref.read(linkedEntriesControllerProvider(id: taskId)).value ?? [];
    final incomingEntities =
        ref.read(linkedFromEntriesControllerProvider(id: taskId)).value ?? [];

    // Get IDs from outgoing links (toId) and incoming tasks (meta.id)
    final existingLinkedIds = <String>{
      ...outgoingLinks.map((link) => link.toId),
      ...incomingEntities.whereType<Task>().map((task) => task.meta.id),
    };

    // Show the modal and let user select a task to link
    await LinkTaskModal.show(
      context: context,
      currentTaskId: taskId,
      existingLinkedIds: existingLinkedIds,
    );
  }

  Future<void> _createNewLinkedTask(BuildContext context, WidgetRef ref) async {
    // Get the current task's category to inherit
    final entryState = ref.read(entryControllerProvider(id: taskId)).value;
    final categoryId = entryState?.entry?.meta.categoryId;

    // Create new task linked to the current task
    final newTask = await createTask(
      linkedId: taskId,
      categoryId: categoryId,
    );

    if (newTask != null && context.mounted) {
      // Navigate to the new task
      tasksBeamerDelegate.beamToNamed('/tasks/${newTask.meta.id}');
    }
  }
}
