import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/widgets/search/filter_choice_chip.dart';

/// A modal content widget for showing task status options.
///
/// The [labelResolver] function can be provided for testing purposes to avoid
/// depending on localization context.
class TaskStatusModalContent extends StatelessWidget {
  const TaskStatusModalContent({
    required this.task,
    this.labelResolver,
    super.key,
  });

  final Task task;

  /// Function to resolve the label for a status string.
  /// Defaults to taskLabelFromStatusString if not provided.
  final String Function(String status, BuildContext context)? labelResolver;

  @override
  Widget build(BuildContext context) {
    final taskStatus = task.data.status.toDbString;

    // Use the provided labelResolver or fall back to the default
    final resolveLabel = labelResolver ?? taskLabelFromStatusString;

    return Wrap(
      runSpacing: 8,
      spacing: 8,
      children: [
        ...allTaskStatuses.map(
          (status) {
            return FilterChoiceChip(
              label: resolveLabel(status, context),
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
