import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/labels/ui/widgets/label_chip.dart';
import 'package:lotti/features/tasks/ui/compact_task_progress.dart';
import 'package:lotti/features/tasks/ui/time_recording_icon.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/index.dart';

/// A modern task card with gradient styling matching the settings page design
class ModernTaskCard extends StatelessWidget {
  const ModernTaskCard({
    required this.task,
    this.showCreationDate = false,
    this.showDueDate = true,
    super.key,
  });

  final Task task;
  final bool showCreationDate;
  final bool showDueDate;

  @override
  Widget build(BuildContext context) {
    void onTap() => beamToNamed('/tasks/${task.meta.id}');

    return ModernBaseCard(
      onTap: onTap,
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: AppTheme.cardSpacing / 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ModernCardContent(
            title: task.data.title,
            maxTitleLines: 3,
            subtitleWidget: _buildSubtitleWidget(context),
            trailing: TimeRecordingIcon(
              taskId: task.meta.id,
            ),
          ),
          _buildDateRow(context),
        ],
      ),
    );
  }

  Widget _buildDateRow(BuildContext context) {
    final hasCreationDate = showCreationDate;
    final hasDueDate = showDueDate && task.data.due != null;

    if (!hasCreationDate && !hasDueDate) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // LEFT: Creation date
          if (hasCreationDate)
            Text(
              DateFormat.yMMMd().format(task.meta.dateFrom),
              style: context.textTheme.bodySmall?.copyWith(
                fontSize: fontSizeSmall,
                color:
                    context.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            )
          else
            const SizedBox.shrink(),
          // RIGHT: Due date with color logic
          if (hasDueDate)
            _DueDateText(
              dueDate: task.data.due!,
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildSubtitleWidget(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final statusRow = Row(
      key: const Key('task_status_row'),
      children: [
        ModernStatusChip(
          label: task.data.priority.short,
          color: task.data.priority.colorForBrightness(brightness),
          borderWidth: AppTheme.statusIndicatorBorderWidth * 1.5,
        ),
        const SizedBox(width: 6),
        ModernStatusChip(
          label: _getStatusLabel(context, task.data.status),
          color: task.data.status.colorForBrightness(brightness),
          icon: _getStatusIcon(task.data.status),
        ),
        const SizedBox(width: 6),
        // Inline category icon after status chip for better chip alignment
        CategoryIconCompact(task.meta.categoryId),
        const Spacer(),
        CompactTaskProgress(taskId: task.id),
      ],
    );

    final labels = _buildLabelsWrap(context);

    if (labels == null) {
      return statusRow;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        statusRow,
        const SizedBox(height: 6),
        labels,
      ],
    );
  }

  Widget? _buildLabelsWrap(BuildContext context) {
    final labelIds = task.meta.labelIds;
    if (labelIds == null || labelIds.isEmpty) {
      return null;
    }

    final cache = getIt<EntitiesCacheService>();
    final showPrivate = cache.showPrivateEntries;
    final labels = labelIds
        .map(cache.getLabelById)
        .whereType<LabelDefinition>()
        .where((label) => showPrivate || !(label.private ?? false))
        .toList();

    if (labels.isEmpty) {
      return null;
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: labels
          .map(
            (label) => LabelChip(label: label),
          )
          .toList(),
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

/// Widget to display due date with color coding for overdue/today status
class _DueDateText extends StatelessWidget {
  const _DueDateText({required this.dueDate});

  final DateTime dueDate;

  Color _getColor(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDateDay = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (dueDateDay.isBefore(today)) {
      return taskStatusRed; // Overdue
    }
    if (dueDateDay == today) {
      return taskStatusOrange; // Due today
    }
    return context.colorScheme.onSurfaceVariant.withValues(alpha: 0.7);
  }

  String _getText(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDateDay = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (dueDateDay == today) {
      return context.messages.taskDueToday;
    }
    return DateFormat.MMMd().format(dueDate);
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.event_rounded,
          size: fontSizeSmall,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          _getText(context),
          style: context.textTheme.bodySmall?.copyWith(
            fontSize: fontSizeSmall,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
