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
import 'package:lotti/services/entities_cache_service.dart';
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
        subtitleWidget: _buildSubtitleWidget(context),
        trailing: TimeRecordingIcon(
          taskId: task.meta.id,
        ),
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
            (label) => LabelChip(label: label, showDot: false),
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
