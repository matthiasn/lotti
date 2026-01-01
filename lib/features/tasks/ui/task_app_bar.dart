import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/journal_app_bar.dart';
import 'package:lotti/features/tasks/ui/task_compact_app_bar.dart';
import 'package:lotti/features/tasks/ui/task_expandable_app_bar.dart';

/// Orchestrator widget that selects the appropriate app bar for a task.
///
/// - If entry is null or not a Task: uses [JournalSliverAppBar]
/// - If task has no cover art: uses [TaskCompactAppBar]
/// - If task has cover art: uses [TaskExpandableAppBar]
class TaskSliverAppBar extends ConsumerWidget {
  const TaskSliverAppBar({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: taskId);
    final item = ref.watch(provider).value?.entry;

    if (item == null || item is! Task) {
      return JournalSliverAppBar(entryId: taskId);
    }

    final coverArtId = item.data.coverArtId;

    if (coverArtId == null) {
      return TaskCompactAppBar(task: item);
    }

    return TaskExpandableAppBar(task: item, coverArtId: coverArtId);
  }
}
