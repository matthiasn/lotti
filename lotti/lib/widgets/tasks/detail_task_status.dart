import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/utils/task_utils.dart';

class DetailTaskStatusWidget extends StatelessWidget {
  const DetailTaskStatusWidget(
    this.task, {
    required this.onPressed,
    Key? key,
  }) : super(key: key);

  final Task? task;
  final void Function() onPressed;

  @override
  Widget build(BuildContext context) {
    if (task == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 24.0),
              child: Text(
                task!.data.title,
                style: taskTitleStyle,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 24.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 16,
                  ),
                  color: taskColor(task!.data.status),
                  child: Text(
                    task!.data.status.map(
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
                      fontSize: 16.0,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              iconSize: 32,
              color: AppColors.entryTextColor,
              tooltip: 'Edit Task',
              onPressed: onPressed,
            ),
          ],
        ),
      ),
    );
  }
}
