import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/tasks/ui/header/task_status_modal_content.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

class TaskStatusWidget extends StatelessWidget {
  const TaskStatusWidget({
    required this.task,
    required this.onStatusChanged,
    super.key,
  });

  final Task task;
  final StringCallback onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final statusLabel = task.data.status.localizedLabel(context);
    final brightness = Theme.of(context).brightness;
    final color = task.data.status.colorForBrightness(brightness);

    Future<void> onTap() async {
      final newStatus = await ModalUtils.showSinglePageModal<String>(
        context: context,
        title: context.messages.taskStatusLabel,
        builder: (BuildContext _) {
          return TaskStatusModalContent(task: task);
        },
      );
      onStatusChanged(newStatus);
    }

    return InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.messages.taskStatusLabel,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            statusLabel,
            softWrap: false,
            style: context.textTheme.titleMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
