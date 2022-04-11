import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/tasks/task_status.dart';

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
    AppLocalizations localizations = AppLocalizations.of(context)!;

    if (task == null) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.start,
              children: [
                Text(
                  task!.data.title,
                  style: taskTitleStyle,
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  iconSize: 32,
                  color: AppColors.entryTextColor,
                  tooltip: localizations.taskEditHint,
                  onPressed: onPressed,
                ),
              ],
            ),
            TaskStatusWidget(
              task!,
              padding: const EdgeInsets.symmetric(
                vertical: 4,
                horizontal: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
