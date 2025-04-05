// ignore_for_file: avoid_dynamic_calls

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/latest_ai_response_summary.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_widget.dart';
import 'package:lotti/features/tasks/ui/checklists/checklists_widget.dart';

class TaskForm extends ConsumerWidget {
  const TaskForm(
    this.task, {
    super.key,
  });

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryId = task.meta.id;
    final provider = entryControllerProvider(id: entryId);
    final entryState = ref.watch(provider).value;

    if (entryState == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EditorWidget(entryId: entryId),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: LatestAiResponseSummary(
            id: entryId,
            aiResponseType: taskSummary,
          ),
        ),
        const SizedBox(height: 10),
        ChecklistsWidget(entryId: entryId, task: task),
        const SizedBox(height: 20),
      ],
    );
  }
}
