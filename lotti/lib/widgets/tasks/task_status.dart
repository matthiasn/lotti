import 'package:flutter/cupertino.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/utils/task_utils.dart';

class TaskStatusWidget extends StatelessWidget {
  const TaskStatusWidget(
    this.task, {
    Key? key,
  }) : super(key: key);

  final Task task;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 2,
          horizontal: 8,
        ),
        color: taskColor(task.data.status),
        child: Text(
          task.data.status.map(
            open: (_) => 'OPEN',
            started: (_) => 'STARTED',
            inProgress: (_) => 'IN PROGRESS',
            blocked: (_) => 'BLOCKED',
            onHold: (_) => 'ON HOLD',
            done: (_) => 'DONE',
            rejected: (_) => 'REJECTED',
          ),
          style: TextStyle(
            fontFamily: 'Oswald',
            color: AppColors.bodyBgColor,
            fontSize: 12.0,
          ),
        ),
      ),
    );
  }
}
