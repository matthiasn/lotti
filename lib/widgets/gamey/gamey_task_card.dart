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
import 'package:lotti/themes/gamey/gamey_theme.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/gamey/gamey_card.dart';
import 'package:lotti/widgets/gamey/gamey_icon_badge.dart';

/// A gamified task card with unified bubbly styling.
///
/// Features:
/// - Unified gamey accent color for consistent look
/// - Playful tap animations
/// - Gradient icon badges for status
/// - Enhanced visual feedback
class GameyTaskCard extends StatelessWidget {
  const GameyTaskCard({
    required this.task,
    this.showCreationDate = false,
    this.showDueDate = true,
    this.showCoverArt = true,
    super.key,
  });

  final Task task;
  final bool showCreationDate;
  final bool showDueDate;
  final bool showCoverArt;

  static const double _thumbnailSize = 120;

  /// Unified gamey gradient for all cards
  static const Gradient _gameyGradient = LinearGradient(
    colors: [GameyColors.gameyAccent, GameyColors.gameyAccentLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    void onTap() => beamToNamed('/tasks/${task.meta.id}');

    final coverArtId = task.data.coverArtId;
    final hasCoverArt = showCoverArt && coverArtId != null;

    return GameySubtleCard(
      accentColor: GameyColors.gameyAccent,
      onTap: onTap,
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingLarge,
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
        Padding(
          padding: const EdgeInsets.only(top: AppTheme.cardPadding * 1.25),
          child: ClipRRect(
            borderRadius: const BorderRadius.all(
              Radius.circular(AppTheme.cardBorderRadius / 2),
            ),
            child: CoverArtThumbnail(
              imageId: coverArtId,
              size: _thumbnailSize,
              cropX: task.data.coverArtCropX,
            ),
          ),
        ),
        const SizedBox(width: 12),
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
        _buildHeader(context),
        _buildSubtitleWidget(context),
        _buildDateRow(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status icon with unified gamey gradient
        GameyIconBadge(
          icon: _getStatusIcon(task.data.status),
          gradient: _gameyGradient,
          size: 40,
          iconSize: 20,
        ),
        const SizedBox(width: 12),
        // Title and time recording
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.data.title,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: AppTheme.letterSpacingTitle,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TimeRecordingIcon(taskId: task.meta.id),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubtitleWidget(BuildContext context) {

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status row with unified gamey chips
          Row(
            children: [
              _GameyStatusChip(
                label: task.data.priority.short,
                color: GameyColors.gameyAccent,
              ),
              const SizedBox(width: 6),
              _GameyStatusChip(
                label: _getStatusLabel(context, task.data.status),
                color: GameyColors.gameyAccent,
                icon: _getStatusIcon(task.data.status),
              ),
              const SizedBox(width: 6),
              CategoryIconCompact(task.meta.categoryId),
              const Spacer(),
              CompactTaskProgress(taskId: task.id),
            ],
          ),
          // Labels
          _buildLabelsWrap(context),
        ],
      ),
    );
  }

  Widget _buildLabelsWrap(BuildContext context) {
    final labelIds = task.meta.labelIds;
    if (labelIds == null || labelIds.isEmpty) {
      return const SizedBox.shrink();
    }

    final cache = getIt<EntitiesCacheService>();
    final showPrivate = cache.showPrivateEntries;
    final labels = labelIds
        .map(cache.getLabelById)
        .whereType<LabelDefinition>()
        .where((label) => showPrivate || !(label.private ?? false))
        .toList();

    if (labels.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: labels.map((label) => LabelChip(label: label)).toList(),
      ),
    );
  }

  Widget _buildDateRow(BuildContext context) {
    final hasCreationDate = showCreationDate;
    final isCompleted =
        task.data.status is TaskDone || task.data.status is TaskRejected;
    final hasDueDate = showDueDate && task.data.due != null && !isCompleted;

    if (!hasCreationDate && !hasDueDate) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
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
          if (hasDueDate) DueDateText(dueDate: task.data.due!),
        ],
      ),
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

/// A gamey-styled status chip with gradient background and glow
class _GameyStatusChip extends StatelessWidget {
  const _GameyStatusChip({
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  /// Get contrasting text color based on background luminance
  Color _getTextColor() {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final textColor = _getTextColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
