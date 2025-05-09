import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/ui/header/estimated_time_widget.dart';

class EstimatedTimeWrapper extends ConsumerWidget {
  const EstimatedTimeWrapper({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: taskId);
    final notifier = ref.read(provider.notifier);
    final entryState = ref.watch(provider).valueOrNull;

    final task = entryState?.entry;

    if (task is! Task) {
      return const SizedBox.shrink();
    }

    return EstimatedTimeWidget(
      task: task,
      save: notifier.save,
    );
  }
}
