import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/latest_ai_response_summary.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/checklists_widget.dart';

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // EditorWidget(entryId: taskId),
        const SizedBox(height: 10),
        LatestAiResponseSummary(
          id: taskId,
          aiResponseType: taskSummary,
        ),
        const SizedBox(height: 20),
        ChecklistsWidget(entryId: taskId, task: task),
        const SizedBox(height: 10),
      ],
    );
  }
}
