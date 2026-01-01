import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/ui/header/task_due_date_widget.dart';
import 'package:lotti/features/tasks/util/due_date_utils.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/cards/subtle_action_chip.dart';

class TaskDueDateWrapper extends ConsumerWidget {
  const TaskDueDateWrapper({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: taskId);
    final notifier = ref.read(provider.notifier);
    final entryState = ref.watch(provider).value;
    final task = entryState?.entry;

    if (task is! Task) return const SizedBox.shrink();

    final dueDate = task.data.due;
    final status = getDueDateStatus(
      dueDate: dueDate,
      referenceDate: clock.now(),
    );

    // Don't show urgency for completed/rejected tasks - they're done
    final isCompleted =
        task.data.status is TaskDone || task.data.status is TaskRejected;

    final label = dueDate != null
        ? context.messages
            .taskDueDateWithDate(DateFormat.yMMMd().format(dueDate))
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
        // When task is completed/rejected, show grayed-out styling instead of urgent
        isUrgent: !isCompleted && status.isUrgent,
        urgentColor: isCompleted ? null : status.urgentColor,
      ),
    );
  }
}
