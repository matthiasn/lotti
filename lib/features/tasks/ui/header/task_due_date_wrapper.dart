import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/ui/header/task_due_date_widget.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/widgets/cards/subtle_action_chip.dart';

class TaskDueDateWrapper extends ConsumerWidget {
  const TaskDueDateWrapper({
    required this.taskId,
    super.key,
  });

  final String taskId;

  /// Returns (isUrgent, urgentColor) based on due date status
  (bool, Color?) _getDueDateStatus(BuildContext context, DateTime? dueDate) {
    if (dueDate == null) return (false, null);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDateDay = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (dueDateDay.isBefore(today)) {
      return (true, taskStatusRed); // Overdue
    } else if (dueDateDay == today) {
      return (true, taskStatusOrange); // Due today
    }
    return (false, null);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: taskId);
    final notifier = ref.read(provider.notifier);
    final entryState = ref.watch(provider).valueOrNull;
    final task = entryState?.entry;

    if (task is! Task) return const SizedBox.shrink();

    final dueDate = task.data.due;
    final (isUrgent, urgentColor) = _getDueDateStatus(context, dueDate);

    final label = dueDate != null
        ? 'Due: ${DateFormat.yMMMd().format(dueDate)}'
        : context.messages.taskNoDueDateLabel;

    return GestureDetector(
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
      child: SubtleActionChip(
        label: label,
        icon: Icons.event_rounded,
        isUrgent: isUrgent,
        urgentColor: urgentColor,
      ),
    );
  }
}
