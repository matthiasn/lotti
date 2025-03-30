import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class TaskStatusWidget extends StatelessWidget {
  const TaskStatusWidget({
    required this.task,
    super.key,
  });

  final Task task;

  @override
  Widget build(BuildContext context) {
    final statusLabel = task.data.status.localizedLabel(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.messages.taskStatusLabel,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 90),
          child: Text(
            statusLabel,
            style: context.textTheme.titleMedium?.copyWith(
              color: Colors.amber,
            ),
          ),
        ),
      ],
    );
  }
}
