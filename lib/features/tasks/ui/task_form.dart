import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/ui/ai_summary_card.dart';
import 'package:lotti/features/design_system/components/motion/staggered_entrance.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
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
    final provider = entryControllerProvider(taskId);
    final entryState = ref.watch(provider).value;
    final task = entryState?.entry;

    if (task == null || task is! Task) {
      return const SizedBox.shrink();
    }

    // only show editor for legacy entries where there is text already
    final plainText = entryState?.entry?.entryText?.plainText.trim() ?? '';
    final hasBody =
        entryState?.entry?.entryText != null && plainText.isNotEmpty;
    final tokens = context.designTokens;

    // Reading zones top-to-bottom: identity (header), the legacy body, the
    // user's WORK (checklists + linked tasks), then the AI assistant. The work
    // comes before the AI card so "what's left to do" is visible without
    // scrolling past the suggestions; a sectionGap sets the AI zone apart from
    // the work above it. Inter-section spacing is baked into each section's
    // leading padding so the staggered entrance cascades evenly.
    return StaggeredEntrance(
      children: [
        DesktopTaskHeaderConnector(taskId: taskId),
        if (hasBody)
          Padding(
            padding: EdgeInsets.only(top: tokens.spacing.sectionGap),
            // A faint top rule marks the body as its own band between the
            // identity header and the work below, so the sections read as
            // even, anchored regions rather than one floating bullet line.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Divider(
                  height: 1,
                  thickness: 1,
                  color: tokens.colors.decorative.level01,
                ),
                SizedBox(height: tokens.spacing.step4),
                EditorWidget(entryId: taskId, margin: EdgeInsets.zero),
              ],
            ),
          ),
        ChecklistsWidget(entryId: taskId, task: task),
        LinkedTasksWidget(taskId: taskId),
        Padding(
          // The AI zone sits a notch below the work above it, but only a
          // notch: LinkedTasks already adds its own step3 bottom padding, so a
          // full sectionGap on top stacked into an oversized gap. A step4 top
          // keeps the rhythm even with the other section gaps, and a sectionGap
          // BOTTOM gives the card real breathing room above the action bar
          // (the linked-entries sliver below contributes almost none).
          padding: EdgeInsets.only(
            top: tokens.spacing.step4,
            bottom: tokens.spacing.step5,
          ),
          child: AiSummaryCard(
            taskId: taskId,
            proposalsFocusKey: suggestionsFocusKey,
          ),
        ),
      ],
    );
  }
}
