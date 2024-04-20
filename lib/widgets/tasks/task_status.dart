import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/task_utils.dart';
import 'package:tinycolor2/tinycolor2.dart';

class TaskStatusWidget extends StatelessWidget {
  const TaskStatusWidget(
    this.task, {
    super.key,
  });

  final Task task;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = taskColor(task.data.status) ?? Colors.grey;

    return Chip(
      label: Text(
        task.data.status.map(
          open: (_) => context.messages.taskStatusOpen,
          groomed: (_) => context.messages.taskStatusGroomed,
          // ignore: flutter_style_todos
          started: (_) => 'STARTED', // TODO: remove DEPRECATED status
          inProgress: (_) => context.messages.taskStatusInProgress,
          blocked: (_) => context.messages.taskStatusBlocked,
          onHold: (_) => context.messages.taskStatusOnHold,
          done: (_) => context.messages.taskStatusDone,
          rejected: (_) => context.messages.taskStatusRejected,
        ),
        style: TextStyle(
          fontSize: fontSizeSmall,
          color: backgroundColor.isLight ? Colors.black : Colors.white,
        ),
      ),
      backgroundColor: backgroundColor,
      visualDensity: VisualDensity.compact,
    );
  }
}
