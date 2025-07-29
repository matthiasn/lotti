import 'package:flutter/material.dart';
import 'package:lotti/features/tasks/ui/header/estimated_time_wrapper.dart';
import 'package:lotti/features/tasks/ui/header/task_category_wrapper.dart';
import 'package:lotti/features/tasks/ui/header/task_language_wrapper.dart';
import 'package:lotti/features/tasks/ui/header/task_status_wrapper.dart';
import 'package:lotti/widgets/layouts/space_between_wrap.dart';

class TaskInfoRow extends StatelessWidget {
  const TaskInfoRow({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  Widget build(BuildContext context) {
    const spacing = 10.0;

    return SpaceBetweenWrap(
      spacing: spacing,
      runSpacing: spacing,
      children: [
        EstimatedTimeWrapper(taskId: taskId),
        TaskCategoryWrapper(taskId: taskId),
        TaskLanguageWrapper(taskId: taskId),
        TaskStatusWrapper(taskId: taskId),
      ],
    );
  }
}
