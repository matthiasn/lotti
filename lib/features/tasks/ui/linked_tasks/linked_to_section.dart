import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_task_card.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Section displaying tasks that the current task links TO (outgoing links).
///
/// Minimal design: just a small label and a list of text links.
class LinkedToSection extends ConsumerWidget {
  const LinkedToSection({
    required this.taskId,
    required this.outgoingTasks,
    required this.manageMode,
    super.key,
  });

  final String taskId;
  final List<Task> outgoingTasks;
  final bool manageMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (outgoingTasks.isEmpty) {
      return const SizedBox.shrink();
    }

    final color = context.colorScheme.outline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // Simple directional label
        Row(
          children: [
            Text(
              '↗ ',
              style: context.textTheme.labelSmall?.copyWith(
                color: color,
                fontSize: 10,
              ),
            ),
            Text(
              context.messages.linkedToLabel,
              style: context.textTheme.labelSmall?.copyWith(
                color: color,
                letterSpacing: 0.5,
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // List of linked task text links
        ...outgoingTasks.map(
          (task) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: LinkedTaskCard(
              task: task,
              showUnlinkButton: manageMode,
              onUnlink:
                  manageMode ? () => _unlinkTask(context, ref, task.id) : null,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _unlinkTask(
    BuildContext context,
    WidgetRef ref,
    String linkedTaskId,
  ) async {
    final confirmed = await _showUnlinkConfirmation(context);
    if (confirmed && context.mounted) {
      await ref
          .read(linkedEntriesControllerProvider(id: taskId).notifier)
          .removeLink(toId: linkedTaskId);
    }
  }

  Future<bool> _showUnlinkConfirmation(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.messages.unlinkTaskTitle),
        content: Text(context.messages.unlinkTaskConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.messages.cancelButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.messages.unlinkButton),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
