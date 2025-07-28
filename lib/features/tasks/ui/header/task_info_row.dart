import 'package:flutter/material.dart';
import 'package:lotti/features/tasks/ui/header/estimated_time_wrapper.dart';
import 'package:lotti/features/tasks/ui/header/task_category_wrapper.dart';
import 'package:lotti/features/tasks/ui/header/task_language_wrapper.dart';
import 'package:lotti/features/tasks/ui/header/task_status_wrapper.dart';

class TaskInfoRow extends StatelessWidget {
  const TaskInfoRow({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  Widget build(BuildContext context) {
    const spacerWidth = 5.0;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            EstimatedTimeWrapper(taskId: taskId),
            const SizedBox(width: spacerWidth),
            TaskCategoryWrapper(taskId: taskId),
            const SizedBox(width: spacerWidth),
            TaskLanguageWrapper(taskId: taskId),
            const SizedBox(width: spacerWidth),
            Padding(
              padding: const EdgeInsets.only(right: spacerWidth),
              child: TaskStatusWrapper(taskId: taskId),
            ),
          ],
        ),
      ],
    );
  }
}
