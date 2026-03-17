import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/tasks/ui/header/task_project_widget.dart';

class TaskProjectWrapper extends ConsumerWidget {
  const TaskProjectWrapper({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryState = ref.watch(entryControllerProvider(id: taskId)).value;
    final task = entryState?.entry;
    if (task is! Task) return const SizedBox.shrink();

    final categoryId = task.meta.categoryId;
    final projectAsync = ref.watch(projectForTaskProvider(taskId));

    return projectAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (ProjectEntry? project) => TaskProjectWidget(
        project: project,
        categoryId: categoryId,
        onSave: (projectId) async {
          final repository = ref.read(projectRepositoryProvider);
          if (projectId != null) {
            return repository.linkTaskToProject(
              projectId: projectId,
              taskId: taskId,
            );
          } else {
            return repository.unlinkTaskFromProject(taskId);
          }
        },
      ),
    );
  }
}
