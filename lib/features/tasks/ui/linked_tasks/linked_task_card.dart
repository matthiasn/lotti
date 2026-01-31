import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';

/// A minimal, text-based link for displaying a linked task.
///
/// Renders as a tappable row with status circle, title, and navigation chevron.
/// The chevron provides clear tap affordance without dated underline styling.
class LinkedTaskCard extends StatelessWidget {
  const LinkedTaskCard({
    required this.task,
    this.showUnlinkButton = false,
    this.onUnlink,
    super.key,
  });

  final Task task;
  final bool showUnlinkButton;
  final VoidCallback? onUnlink;

  @override
  Widget build(BuildContext context) {
    final isCompleted =
        task.data.status is TaskDone || task.data.status is TaskRejected;

    // Text color - slightly muted for completed tasks
    final textColor = isCompleted
        ? context.colorScheme.onSurface.withValues(alpha: 0.5)
        : context.colorScheme.onSurface.withValues(alpha: 0.85);

    // Status color for circle and chevron
    final statusColor = _getStatusColor(context, task.data.status);

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => TaskDetailsPage(taskId: task.id),
        ),
      ),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
        child: Row(
          children: [
            // Status circle reflecting task state
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: statusColor,
                  width: 1.5,
                ),
                color: isCompleted ? statusColor.withValues(alpha: 0.3) : null,
              ),
              child: isCompleted
                  ? Icon(
                      Icons.check,
                      size: 10,
                      color: statusColor,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            // Task title - no underline, cleaner look
            Expanded(
              child: Text(
                task.data.title,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: textColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // Show unlink button in manage mode, chevron otherwise
            if (showUnlinkButton)
              GestureDetector(
                onTap: onUnlink,
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: context.colorScheme.outline,
                ),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: statusColor,
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(BuildContext context, TaskStatus status) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return switch (status) {
      TaskOpen() => context.colorScheme.outline,
      TaskInProgress() => context.colorScheme.primary,
      TaskGroomed() => context.colorScheme.tertiary,
      TaskOnHold() => context.colorScheme.secondary,
      TaskBlocked() => context.colorScheme.error,
      TaskDone() => isLight ? taskStatusDarkGreen : taskStatusGreen,
      TaskRejected() => context.colorScheme.outline,
    };
  }
}
