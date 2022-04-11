import 'package:flutter/cupertino.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/utils/task_utils.dart';

class TaskStatusWidget extends StatelessWidget {
  const TaskStatusWidget(
    this.task, {
    Key? key,
    this.padding = chipPadding,
  }) : super(key: key);

  final Task task;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(chipBorderRadius),
      child: Container(
        padding: padding,
        color: taskColor(task.data.status),
        child: Text(
          task.data.status.map(
            open: (_) => AppLocalizations.of(context)!.taskStatusOpen,
            started: (_) => 'STARTED', // TODO: remove DEPRECATED status
            inProgress: (_) =>
                AppLocalizations.of(context)!.taskStatusInProgress,
            blocked: (_) => AppLocalizations.of(context)!.taskStatusBlocked,
            onHold: (_) => AppLocalizations.of(context)!.taskStatusOnHold,
            done: (_) => AppLocalizations.of(context)!.taskStatusDone,
            rejected: (_) => AppLocalizations.of(context)!.taskStatusRejected,
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
