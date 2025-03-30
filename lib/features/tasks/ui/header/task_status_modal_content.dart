import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/widgets/search/filter_choice_chip.dart';

class TaskStatusModalContent extends StatelessWidget {
  const TaskStatusModalContent({
    required this.task,
    super.key,
  });

  final Task task;

  @override
  Widget build(BuildContext context) {
    final taskStatus = task.data.status.toDbString;

    return Wrap(
      runSpacing: 8,
      spacing: 8,
      children: [
        ...allTaskStatuses.map(
          (status) {
            return FilterChoiceChip(
              label: taskLabelFromStatusString(status, context),
              isSelected: status == taskStatus,
              onTap: () => Navigator.pop(context, status),
              selectedColor: taskColorFromStatusString(status),
            );
          },
        ),
      ],
    );
  }
}
