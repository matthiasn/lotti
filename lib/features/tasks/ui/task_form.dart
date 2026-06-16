import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/ui/ai_summary_card.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_widget.dart';
import 'package:lotti/features/tasks/ui/checklists/checklists_widget.dart';
import 'package:lotti/features/tasks/ui/header/desktop_task_header_connector.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_tasks_widget.dart';

/// Composes the task detail form for the task identified by [taskId].
///
/// Watches `entryControllerProvider` and, once the entry resolves to a
/// [Task], stacks (top to bottom): the [DesktopTaskHeaderConnector] header,
/// an [EditorWidget] for legacy entries that already contain rich text, the
/// [AiSummaryCard] (whose proposals can be scrolled into view via
/// [suggestionsFocusKey]), the [LinkedTasksWidget], and the
/// [ChecklistsWidget]. Renders nothing until the entry loads as a task.
class TaskForm extends ConsumerWidget {
  const TaskForm({
    required this.taskId,
    this.suggestionsFocusKey,
    super.key,
  });

  final String taskId;
  final GlobalKey? suggestionsFocusKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: taskId);
    final entryState = ref.watch(provider).value;
    final task = entryState?.entry;

    if (task == null || task is! Task) {
      return const SizedBox.shrink();
    }

    // only show editor for legacy entries where there is text already
    final plainText = entryState?.entry?.entryText?.plainText.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesktopTaskHeaderConnector(taskId: taskId),
        const SizedBox(height: 8),
        if (entryState?.entry?.entryText != null && plainText.isNotEmpty) ...[
          EditorWidget(entryId: taskId, margin: EdgeInsets.zero),
          const SizedBox(height: 10),
        ],
        AiSummaryCard(
          taskId: taskId,
          proposalsFocusKey: suggestionsFocusKey,
        ),
        LinkedTasksWidget(taskId: taskId),
        ChecklistsWidget(entryId: taskId, task: task),
      ],
    );
  }
}
