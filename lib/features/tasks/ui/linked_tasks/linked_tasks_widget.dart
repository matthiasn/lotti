import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/linked_from_entries_controller.dart';
import 'package:lotti/features/tasks/state/linked_tasks_controller.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_from_section.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_tasks_header.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_to_section.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';

/// Widget displaying linked tasks in the task detail view.
///
/// Shows tasks that link TO this task (incoming, "Linked From") and
/// tasks that this task links TO (outgoing, "Linked To").
///
/// Features:
/// - Directional indicators (↳ LINKED FROM, ↗ LINKED TO)
/// - Dropdown menu for link management
/// - Manage mode with unlink buttons
class LinkedTasksWidget extends ConsumerWidget {
  const LinkedTasksWidget({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch UI state
    final uiState = ref.watch(linkedTasksControllerProvider(taskId: taskId));

    // Watch outgoing linked tasks (already resolved and filtered to Tasks)
    final outgoingTasks = ref
        .watch(outgoingLinkedTasksProvider(taskId))
        .whereType<Task>()
        .toList();

    // Watch incoming links (other entries -> this task)
    final incomingEntitiesAsync =
        ref.watch(linkedFromEntriesControllerProvider(id: taskId));

    // Handle loading/error states
    final incomingEntities = incomingEntitiesAsync.value ?? [];

    // Filter incoming to tasks only
    final incomingTasks = incomingEntities.whereType<Task>().toList();

    // Check if there are any linked tasks to show
    final hasIncoming = incomingTasks.isNotEmpty;
    final hasOutgoing = outgoingTasks.isNotEmpty;

    // Hide the section entirely if no linked tasks
    if (!hasIncoming && !hasOutgoing) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        LinkedTasksHeader(
          taskId: taskId,
          hasLinkedTasks: hasIncoming || hasOutgoing,
        ),
        ModernBaseCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasIncoming)
                LinkedFromSection(
                  taskId: taskId,
                  incomingTasks: incomingTasks,
                  manageMode: uiState.manageMode,
                ),
              if (hasIncoming && hasOutgoing) const SizedBox(height: 8),
              if (hasOutgoing)
                LinkedToSection(
                  taskId: taskId,
                  outgoingTasks: outgoingTasks,
                  manageMode: uiState.manageMode,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
