import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_icon.dart';
import 'package:lotti/features/tasks/ui/compact_task_progress.dart';
import 'package:lotti/features/tasks/ui/time_recording_icon.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';

/// A modern task card with gradient styling matching the settings page design
class ModernTaskCard extends StatelessWidget {
  const ModernTaskCard({
    required this.task,
    this.isCompact = false,
    super.key,
  });

  final Task task;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    void onTap() => beamToNamed('/tasks/${task.meta.id}');

    return AnimatedContainer(
      duration: const Duration(milliseconds: AppTheme.animationDuration),
      curve: AppTheme.animationCurve,
      margin: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: AppTheme.cardSpacing / 2,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? context.colorScheme.surface
            : null,
        gradient: Theme.of(context).brightness == Brightness.dark
            ? GradientThemes.cardGradient(context)
            : null,
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.light
              ? context.colorScheme.outline
                  .withValues(alpha: AppTheme.alphaOutline)
              : context.colorScheme.primaryContainer
                  .withValues(alpha: AppTheme.alphaPrimaryContainer),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.light
                ? context.colorScheme.shadow
                    .withValues(alpha: AppTheme.alphaShadowLight)
                : context.colorScheme.shadow
                    .withValues(alpha: AppTheme.alphaShadowDark),
            blurRadius: Theme.of(context).brightness == Brightness.light
                ? AppTheme.cardElevationLight
                : AppTheme.cardElevationDark,
            offset: AppTheme.shadowOffset,
          ),
        ],
      ),
      child: Material(
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
          splashColor: context.colorScheme.primary
              .withValues(alpha: AppTheme.alphaPrimary),
          highlightColor: context.colorScheme.primary
              .withValues(alpha: AppTheme.alphaPrimaryHighlight),
          child: Container(
            padding: EdgeInsets.all(
              isCompact ? AppTheme.cardPaddingCompact : AppTheme.cardPadding,
            ),
            child: Row(
              children: [
                // Category icon with gradient container
                _buildCategoryIcon(context),
                SizedBox(
                  width: isCompact
                      ? AppTheme.spacingMedium
                      : AppTheme.spacingLarge,
                ),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title row
                      Text(
                        task.data.title,
                        style: context.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: AppTheme.letterSpacingTitle,
                          fontSize: isCompact
                              ? AppTheme.titleFontSizeCompact
                              : AppTheme.titleFontSize,
                          color: context.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Status and metadata row
                      if (!isCompact) ...[
                        const SizedBox(
                          height: AppTheme.spacingBetweenTitleAndSubtitle,
                        ),
                        Row(
                          children: [
                            _buildStatusIndicator(context),
                            if (task.data.due != null) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.event_rounded,
                                size: AppTheme.subtitleFontSize,
                                color: context.colorScheme.onSurfaceVariant
                                    .withValues(
                                  alpha: AppTheme.alphaSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat.MMMd().format(task.data.due!),
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: context.colorScheme.onSurfaceVariant
                                      .withValues(
                                    alpha: AppTheme.alphaSurfaceVariant,
                                  ),
                                  fontSize: AppTheme.subtitleFontSize,
                                ),
                              ),
                            ],
                            const Spacer(),
                            CompactTaskProgress(taskId: task.meta.id),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Right side actions and info
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TimeRecordingIcon(
                      taskId: task.meta.id,
                      padding: const EdgeInsets.only(left: 8),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryIcon(BuildContext context) {
    return Container(
      width: isCompact
          ? AppTheme.iconContainerSizeCompact
          : AppTheme.iconContainerSize,
      height: isCompact
          ? AppTheme.iconContainerSizeCompact
          : AppTheme.iconContainerSize,
      decoration: BoxDecoration(
        gradient: GradientThemes.iconContainerGradient(context),
        borderRadius: BorderRadius.circular(
          AppTheme.iconContainerBorderRadius,
        ),
        border: Border.all(
          color: context.colorScheme.primaryContainer
              .withValues(alpha: AppTheme.alphaPrimaryBorder),
        ),
      ),
      child: Center(
        child: SizedBox(
          width: isCompact ? AppTheme.iconSizeCompact : AppTheme.iconSize,
          height: isCompact ? AppTheme.iconSizeCompact : AppTheme.iconSize,
          child: CategoryColorIcon(task.meta.categoryId),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(BuildContext context) {
    final status = task.data.status;
    final statusColor = _getStatusColor(status);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = _getStatusLabel(context, status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact
            ? AppTheme.statusIndicatorPaddingHorizontalCompact
            : AppTheme.statusIndicatorPaddingHorizontal,
        vertical: AppTheme.statusIndicatorPaddingVertical,
      ),
      decoration: BoxDecoration(
        color: statusColor.withValues(
          alpha: isDark
              ? AppTheme.alphaPrimaryContainerDark
              : AppTheme.alphaPrimaryContainerLight,
        ),
        borderRadius: BorderRadius.circular(
          isCompact
              ? AppTheme.statusIndicatorBorderRadiusSmall
              : AppTheme.statusIndicatorBorderRadius,
        ),
        border: Border.all(
          color: statusColor.withValues(
            alpha: AppTheme.alphaStatusIndicatorBorder,
          ),
          width: AppTheme.statusIndicatorBorderWidth,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(task.data.status),
            size: isCompact
                ? AppTheme.statusIndicatorIconSizeCompact
                : AppTheme.statusIndicatorIconSize,
            color: statusColor.withValues(
              alpha: AppTheme.alphaPrimaryIcon,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: isCompact
                  ? AppTheme.statusIndicatorFontSizeCompact
                  : AppTheme.statusIndicatorFontSize,
              fontWeight: FontWeight.w600,
              color: statusColor.withValues(
                alpha: isDark ? 0.9 : 0.8,
              ),
            ),
          ),
        ],
      ),
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
