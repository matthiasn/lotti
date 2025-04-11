import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_icon.dart';
import 'package:lotti/features/tasks/ui/task_status.dart';
import 'package:lotti/features/tasks/ui/time_recording_icon.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';

class TaskListCard extends StatelessWidget {
  const TaskListCard({
    required this.task,
    super.key,
  });

  final Task task;

  @override
  Widget build(BuildContext context) {
    void onTap() => beamToNamed('/tasks/${task.meta.id}');

    return Card(
      margin: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: CategoryColorIcon(task.meta.categoryId),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TimeRecordingIcon(
              taskId: task.meta.id,
              padding: const EdgeInsets.only(right: 10),
            ),
            TaskStatusWidget(task),
          ],
        ),
        title: Text(
          task.data.title,
          style: const TextStyle(
            fontSize: fontSizeMediumLarge,
          ),
        ),
      ),
    );
  }
}
