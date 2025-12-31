import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/labels/ui/widgets/label_chip.dart';
import 'package:lotti/features/tasks/ui/compact_task_progress.dart';
import 'package:lotti/features/tasks/ui/cover_art_thumbnail.dart';
import 'package:lotti/features/tasks/ui/due_date_text.dart';
import 'package:lotti/features/tasks/ui/time_recording_icon.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/index.dart';

/// A modern task card with gradient styling matching the settings page design.
///
/// When [showCoverArt] is true and the task has a cover art image set,
/// displays an 80x80 thumbnail on the left side of the card.
class ModernTaskCard extends StatelessWidget {
  const ModernTaskCard({
    required this.task,
    this.showCreationDate = false,
    this.showDueDate = true,
    this.showCoverArt = true,
    super.key,
  });

  final Task task;
  final bool showCreationDate;
  final bool showDueDate;

  /// Whether to show the cover art thumbnail when available.
  final bool showCoverArt;

  static const double _thumbnailSize = 120;

  @override
  Widget build(BuildContext context) {
    void onTap() => beamToNamed('/tasks/${task.meta.id}');

    final coverArtId = task.data.coverArtId;
    final hasCoverArt = showCoverArt && coverArtId != null;

    return ModernBaseCard(
      onTap: onTap,
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: AppTheme.cardSpacing / 2,
      ),
      padding: hasCoverArt
          ? EdgeInsets.zero
          : const EdgeInsets.only(
              left: AppTheme.cardPadding,
              top: AppTheme.cardPadding,
              right: AppTheme.cardPadding,
              bottom: 10,
            ),
      child: hasCoverArt
          ? _buildWithCoverArt(context, coverArtId)
          : _buildStandardContent(context),
    );
  }

  Widget _buildWithCoverArt(BuildContext context, String coverArtId) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cover art thumbnail with rounded left corners
        Padding(
          padding: const EdgeInsets.only(top: AppTheme.cardPadding * 1.25),
          child: ClipRRect(
            borderRadius: const BorderRadius.all(
                Radius.circular(AppTheme.cardBorderRadius / 2)),
            child: CoverArtThumbnail(
              imageId: coverArtId,
              size: _thumbnailSize,
              cropX: task.data.coverArtCropX,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Standard content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(
              top: AppTheme.cardPadding,
              right: AppTheme.cardPadding,
              bottom: 10,
            ),
            child: _buildStandardContent(context),
          ),
        ),
      ],
    );
  }

  Widget _buildStandardContent(BuildContext context) {
    return Column(
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
    );
  }

  Widget _buildDateRow(BuildContext context) {
    final hasCreationDate = showCreationDate;
    final hasDueDate = showDueDate && task.data.due != null;

    if (!hasCreationDate && !hasDueDate) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // LEFT: Creation date with icon for alignment
          if (hasCreationDate)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: AppTheme.statusIndicatorFontSize,
                  color: context.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.7),
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat.yMMMd().format(task.meta.dateFrom),
                  style: context.textTheme.bodySmall?.copyWith(
                    fontSize: AppTheme.statusIndicatorFontSize,
                    color: context.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.7),
                  ),
                ),
              ],
            )
          else
            const SizedBox.shrink(),
          // RIGHT: Due date with color logic
          if (hasDueDate)
            DueDateText(
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
