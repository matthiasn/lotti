import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/ui/header/task_category_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';

class TaskCategoryWrapper extends ConsumerWidget {
  const TaskCategoryWrapper({
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

    final categoryId = task.meta.categoryId;
    final category = getIt<EntitiesCacheService>().getCategoryById(categoryId);

    return TaskCategoryWidget(
      category: category,
      onSave: notifier.updateCategoryId,
      hideLabelWhenValueSet: true,
    );
  }
}
