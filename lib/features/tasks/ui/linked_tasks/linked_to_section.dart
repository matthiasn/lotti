import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
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
    required this.outgoingLinks,
    required this.manageMode,
    super.key,
  });

  final String taskId;
  final List<EntryLink> outgoingLinks;
  final bool manageMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (outgoingLinks.isEmpty) {
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
        ...outgoingLinks.map(
          (link) => _LinkedTaskCardFromLink(
            taskId: taskId,
            link: link,
            manageMode: manageMode,
          ),
        ),
      ],
    );
  }
}

/// Widget that resolves an EntryLink to a Task and renders a LinkedTaskCard.
class _LinkedTaskCardFromLink extends ConsumerWidget {
  const _LinkedTaskCardFromLink({
    required this.taskId,
    required this.link,
    required this.manageMode,
  });

  final String taskId;
  final EntryLink link;
  final bool manageMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fetch the linked entry
    final entryAsync = ref.watch(entryControllerProvider(id: link.toId));
    final entry = entryAsync.value?.entry;

    // Only show if it's a Task
    if (entry is! Task) {
      return const SizedBox.shrink();
    }

    return LinkedTaskCard(
      task: entry,
      showUnlinkButton: manageMode,
      onUnlink: manageMode ? () => _unlinkTask(context, ref) : null,
    );
  }

  Future<void> _unlinkTask(BuildContext context, WidgetRef ref) async {
    final confirmed = await _showUnlinkConfirmation(context);
    if (confirmed && context.mounted) {
      await ref
          .read(linkedEntriesControllerProvider(id: taskId).notifier)
          .removeLink(toId: link.toId);
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
