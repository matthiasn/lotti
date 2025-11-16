import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/latest_ai_response_summary.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_widget.dart';
import 'package:lotti/features/tasks/ui/checklists/checklists_widget.dart';
import 'package:lotti/features/tasks/ui/header/task_header_meta_card.dart';
import 'package:lotti/features/tasks/ui/labels/task_labels_wrapper.dart';

class TaskForm extends ConsumerWidget {
  const TaskForm({
    required this.taskId,
    super.key,
  });

  final String taskId;

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
        TaskHeaderMetaCard(taskId: taskId),
        const SizedBox(height: 10),
        TaskLabelsWrapper(taskId: taskId),
        const SizedBox(height: 10),
        if (entryState?.entry?.entryText != null && plainText.isNotEmpty) ...[
          EditorWidget(entryId: taskId, margin: EdgeInsets.zero),
          const SizedBox(height: 10),
        ],
        LatestAiResponseSummary(
          id: taskId,
          aiResponseType: AiResponseType.taskSummary,
        ),
        ChecklistsWidget(entryId: taskId, task: task),
      ],
    );
  }
}
