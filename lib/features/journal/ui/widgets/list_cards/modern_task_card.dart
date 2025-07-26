import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_icon.dart';
import 'package:lotti/features/tasks/ui/compact_task_progress.dart';
import 'package:lotti/features/tasks/ui/time_recording_icon.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/index.dart';

/// A modern task card with gradient styling matching the settings page design
class ModernTaskCard extends StatelessWidget {
  const ModernTaskCard({
    required this.task,
    super.key,
  });

  final Task task;

  @override
  Widget build(BuildContext context) {
    void onTap() => beamToNamed('/tasks/${task.meta.id}');

    return ModernBaseCard(
      onTap: onTap,
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: AppTheme.cardSpacing / 2,
      ),
      child: ModernCardContent(
        title: task.data.title,
        maxTitleLines: 3,
        leading: ModernIconContainer(
          child: CategoryColorIcon(task.meta.categoryId),
        ),
        subtitleWidget: _buildSubtitleRow(context),
        trailing: TimeRecordingIcon(
          taskId: task.meta.id,
          padding: const EdgeInsets.only(left: 8),
        ),
      ),
    );
  }

  Widget _buildSubtitleRow(BuildContext context) {
    return Row(
      children: [
        ModernStatusChip(
          label: _getStatusLabel(context, task.data.status),
          color: _getStatusColor(task.data.status),
          icon: _getStatusIcon(task.data.status),
        ),
        if (task.data.due != null) ...[
          const SizedBox(width: 8),
          Icon(
            Icons.event_rounded,
            size: AppTheme.subtitleFontSize,
            color: context.colorScheme.onSurfaceVariant
                .withValues(alpha: AppTheme.alphaSurfaceVariant),
          ),
          const SizedBox(width: 4),
          Text(
            DateFormat.MMMd().format(task.data.due!),
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant
                  .withValues(alpha: AppTheme.alphaSurfaceVariant),
              fontSize: AppTheme.subtitleFontSize,
            ),
          ),
        ],
        const Spacer(),
        CompactTaskProgress(taskId: task.id),
      ],
    );
  }

  Color _getStatusColor(TaskStatus status) {
    return status.map(
      open: (_) => Colors.orange,
      groomed: (_) => Colors.lightGreenAccent,
      inProgress: (_) => Colors.blue,
      blocked: (_) => Colors.red,
      onHold: (_) => Colors.red,
      done: (_) => Colors.green,
      rejected: (_) => Colors.red,
    );
  }

  String _getStatusLabel(BuildContext context, TaskStatus status) {
    return status.map(
      open: (_) => 'Open',
      groomed: (_) => 'Groomed',
      inProgress: (_) => 'In Progress',
      blocked: (_) => 'Blocked',
      onHold: (_) => 'On Hold',
      done: (_) => 'Done',
      rejected: (_) => 'Rejected',
    );
  }

  IconData _getStatusIcon(TaskStatus status) {
    return status.map(
      open: (_) => Icons.radio_button_unchecked,
      groomed: (_) => Icons.done_outline_rounded,
      inProgress: (_) => Icons.play_circle_outline_rounded,
      blocked: (_) => Icons.block_rounded,
      onHold: (_) => Icons.pause_circle_outline_rounded,
      done: (_) => Icons.check_circle_rounded,
      rejected: (_) => Icons.cancel_rounded,
    );
  }
}
