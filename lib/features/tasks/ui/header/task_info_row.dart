import 'package:flutter/material.dart';
import 'package:lotti/features/tasks/ui/header/estimated_time_wrapper.dart';
import 'package:lotti/features/tasks/ui/header/task_category_wrapper.dart';
import 'package:lotti/features/tasks/ui/header/task_status_wrapper.dart';

class TaskInfoRow extends StatelessWidget {
  const TaskInfoRow({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        EstimatedTimeWrapper(taskId: taskId),
        TaskStatusWrapper(taskId: taskId),
        TaskCategoryWrapper(taskId: taskId),
      ],
    );
  }
}
