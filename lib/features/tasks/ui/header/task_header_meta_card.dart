import 'package:flutter/material.dart';
import 'package:lotti/features/tasks/ui/header/task_category_wrapper.dart';
import 'package:lotti/features/tasks/ui/header/task_creation_date_widget.dart';
import 'package:lotti/features/tasks/ui/header/task_due_date_wrapper.dart';
import 'package:lotti/features/tasks/ui/header/task_language_wrapper.dart';
import 'package:lotti/features/tasks/ui/header/task_priority_wrapper.dart';
import 'package:lotti/features/tasks/ui/header/task_status_wrapper.dart';
import 'package:lotti/features/tasks/ui/remove_cover_art_chip.dart';
import 'package:lotti/themes/theme.dart';

class TaskHeaderMetaCard extends StatelessWidget {
  const TaskHeaderMetaCard({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: Primary Status (High Visibility Chips)
        _TaskMetadataRow(taskId: taskId),
        const SizedBox(height: 12),
        // Row 2: Dates (Subtle Action Chips)
        Row(
          spacing: 8,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TaskCreationDateWidget(taskId: taskId),
            TaskDueDateWrapper(taskId: taskId),
          ],
        ),
      ],
    );
  }
}

class _TaskMetadataRow extends StatelessWidget {
  const _TaskMetadataRow({
    required this.taskId,
  });

  final String taskId;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: AppTheme.cardSpacing,
            runSpacing: AppTheme.cardSpacing / 2,
            children: [
              TaskPriorityWrapper(
                taskId: taskId,
                showLabel: false,
              ),
              TaskStatusWrapper(
                taskId: taskId,
                showLabel: false,
              ),
              TaskCategoryWrapper(taskId: taskId),
              TaskLanguageWrapper(taskId: taskId),
              RemoveCoverArtChip(taskId: taskId),
            ],
          ),
        ),
      ],
    );
  }
}
