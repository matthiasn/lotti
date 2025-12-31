import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/ui/header/task_status_widget.dart';

class TaskStatusWrapper extends ConsumerWidget {
  const TaskStatusWrapper({
    required this.taskId,
    this.showLabel = true,
    super.key,
  });

  final String taskId;
  final bool showLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: taskId);
    final notifier = ref.read(provider.notifier);
    final entryState = ref.watch(provider).value;
    final task = entryState?.entry;

    if (task is! Task) {
      return const SizedBox.shrink();
    }

    return TaskStatusWidget(
      task: task,
      onStatusChanged: notifier.updateTaskStatus,
      showLabel: showLabel,
    );
  }
}
