import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';

/// A minimal, text-based link for displaying a linked task.
///
/// Renders as a simple underlined text link with a small status circle,
/// following the Linear-style compact list aesthetic.
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

    // Circle color based on status
    final circleColor = _getStatusColor(context, task.data.status);

    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Simple status circle - like checklist items
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: circleColor,
                  width: 1.5,
                ),
                color: isCompleted ? circleColor.withValues(alpha: 0.3) : null,
              ),
              child: isCompleted
                  ? Icon(
                      Icons.check,
                      size: 10,
                      color: circleColor,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          // Task title as underlined text link
          Expanded(
            child: GestureDetector(
              onTap: () => beamToNamed('/tasks/${task.id}'),
              child: Text(
                task.data.title,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  decoration: TextDecoration.underline,
                  decorationColor: textColor.withValues(alpha: 0.4),
                  decorationThickness: 1,
                  fontStyle: isCompleted ? FontStyle.italic : FontStyle.normal,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // Unlink button (shown in manage mode)
          if (showUnlinkButton) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onUnlink,
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: context.colorScheme.outline,
              ),
            ),
          ],
        ],
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
