import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/ui/header/task_due_date_widget.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';

class TaskDueDateWrapper extends ConsumerWidget {
  const TaskDueDateWrapper({
    required this.taskId,
    super.key,
  });

  final String taskId;

  Color _getDueDateColor(BuildContext context, DateTime? dueDate) {
    if (dueDate == null) return context.colorScheme.outline;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDateDay = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (dueDateDay.isBefore(today)) {
      return taskStatusRed; // Overdue
    } else if (dueDateDay == today) {
      return taskStatusOrange; // Due today
    }
    return context.colorScheme.outline;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: taskId);
    final notifier = ref.read(provider.notifier);
    final entryState = ref.watch(provider).valueOrNull;
    final task = entryState?.entry;

    if (task is! Task) return const SizedBox.shrink();

    final dueDate = task.data.due;
    final color = _getDueDateColor(context, dueDate);

    return InkWell(
      onTap: () async {
        await showDueDatePicker(
          context: context,
          initialDate: dueDate,
          onDueDateChanged: (newDate) async {
            if (newDate == null) {
              await notifier.save(clearDueDate: true);
            } else {
              await notifier.save(dueDate: newDate);
            }
          },
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_rounded,
            size: AppTheme.statusIndicatorIconSizeCompact,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            dueDate != null
                ? DateFormat.yMMMd().format(dueDate)
                : context.messages.taskNoDueDateLabel,
            style: context.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
