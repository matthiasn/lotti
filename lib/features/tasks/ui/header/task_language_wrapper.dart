import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/supported_language.dart';
import 'package:lotti/features/ai/state/direct_task_summary_refresh_controller.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/ui/header/task_language_widget.dart';

class TaskLanguageWrapper extends ConsumerWidget {
  const TaskLanguageWrapper({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: taskId);
    final entryState = ref.watch(provider).valueOrNull;

    final task = entryState?.entry;

    if (task is! Task) {
      return const SizedBox.shrink();
    }

    return TaskLanguageWidget(
      task: task,
      onLanguageChanged: (SupportedLanguage? language) async {
        final updatedTask = task.copyWith(
          data: task.data.copyWith(
            languageCode: language?.code,
          ),
        );
        await ref
            .read(journalRepositoryProvider)
            .updateJournalEntity(updatedTask);

        // Trigger task summary update
        await ref
            .read(directTaskSummaryRefreshControllerProvider.notifier)
            .requestTaskSummaryRefresh(taskId);
      },
    );
  }
}
