import 'package:flutter/material.dart';
import 'package:lotti/features/tasks/ui/header/task_info_row.dart';
import 'package:lotti/features/tasks/ui/header/task_title_header.dart';

class TaskHeaderSection extends StatelessWidget {
  const TaskHeaderSection({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Material(
        elevation: 5,
        child: Container(
          color: Theme.of(context).appBarTheme.backgroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TaskTitleHeader(taskId: taskId),
              const SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TaskInfoRow(taskId: taskId),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
