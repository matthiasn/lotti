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
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              flex: 2,
              child: EstimatedTimeWrapper(taskId: taskId),
            ),
            Flexible(
              flex: 3,
              child: TaskCategoryWrapper(taskId: taskId),
            ),
            TaskLanguageWrapper(taskId: taskId),
            Container(
              constraints: const BoxConstraints(minWidth: 90),
              child: TaskStatusWrapper(taskId: taskId),
            ),
          ],
        ),
      ],
    );
  }
}
