import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/latest_ai_response_summary.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_widget.dart';
import 'package:lotti/features/tasks/ui/checklists/checklists_widget.dart';
import 'package:lotti/features/tasks/ui/header/task_info_row.dart';
import 'package:lotti/features/tasks/ui/task_date_row.dart';
import 'package:lotti/themes/theme.dart';

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

    final dividerColor = context.colorScheme.outline.withAlpha(60);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaskDateRow(taskId: taskId),
        TaskInfoRow(taskId: taskId),
        EditorWidget(entryId: taskId, margin: EdgeInsets.zero),
        Divider(color: dividerColor),
        const SizedBox(height: 10),
        LatestAiResponseSummary(
          id: taskId,
          aiResponseType: taskSummary,
        ),
        ChecklistsWidget(entryId: taskId, task: task),
        const SizedBox(height: 10),
        Divider(color: dividerColor),
      ],
    );
  }
}
