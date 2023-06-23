import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/journal_entities.dart';
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
    final localizations = AppLocalizations.of(context)!;
    final backgroundColor = taskColor(task.data.status) ?? Colors.grey;

    return Chip(
      label: Text(
        task.data.status.map(
          open: (_) => localizations.taskStatusOpen,
          groomed: (_) => localizations.taskStatusGroomed,
          // ignore: flutter_style_todos
          started: (_) => 'STARTED', // TODO: remove DEPRECATED status
          inProgress: (_) => localizations.taskStatusInProgress,
          blocked: (_) => localizations.taskStatusBlocked,
          onHold: (_) => localizations.taskStatusOnHold,
          done: (_) => localizations.taskStatusDone,
          rejected: (_) => localizations.taskStatusRejected,
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
