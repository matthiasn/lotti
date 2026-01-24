import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_icon.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/cards/index.dart';

/// Card displaying a single time budget with progress.
class TimeBudgetCard extends ConsumerWidget {
  const TimeBudgetCard({
    required this.progress,
    this.onTap,
    this.onLongPress,
    this.isExpanded = false,
    super.key,
  });

  final TimeBudgetProgress progress;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isExpanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = progress.category;
    final categoryId = category?.id;
    final categoryColor = category != null
        ? colorFromCssHex(category.color)
        : context.colorScheme.primary;

    final highlightedId = ref.watch(highlightedCategoryIdProvider);
    final isHighlighted = categoryId != null && highlightedId == categoryId;

    return GestureDetector(
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingLarge,
          vertical: AppTheme.spacingSmall / 2,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
          border:
              isHighlighted ? Border.all(color: categoryColor, width: 2) : null,
          boxShadow: isHighlighted
              ? [
                  BoxShadow(
                    color: categoryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: ModernBaseCard(
          onTap: () {
            // Highlight this category
            if (categoryId != null) {
              ref
                  .read(dailyOsControllerProvider.notifier)
                  .highlightCategory(categoryId);
            }
            // Also call the original onTap if provided
            onTap?.call();
          },
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(AppTheme.cardPaddingCompact),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Category icon
                  if (category != null) ...[
                    ColorIcon(categoryColor, size: 24),
                    const SizedBox(width: AppTheme.spacingMedium),
                  ],

                  // Category name and planned duration
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category?.name ??
                              context.messages.dailyOsUncategorized,
                          style: context.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _formatPlannedDuration(
                            progress.plannedDuration,
                            context.messages,
                          ),
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Status text
                  _StatusText(progress: progress),
                ],
              ),

              const SizedBox(height: AppTheme.spacingMedium),

              // Progress bar
              _BudgetProgressBar(
                progress: progress,
                categoryColor: categoryColor,
              ),

              // Pinned tasks section (tasks planned to work on)
              if (progress.pinnedTasks.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacingMedium),
                const Divider(height: 1),
                const SizedBox(height: AppTheme.spacingSmall),
                ...progress.pinnedTasks.map(
                  (task) => _PinnedTaskRow(task: task),
                ),
              ],

              // Contributing tasks section (tasks tracked under this budget)
              if (progress.contributingTasks.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacingMedium),
                const Divider(height: 1),
                const SizedBox(height: AppTheme.spacingSmall),
                ...progress.contributingTasks.map(
                  (task) => _PinnedTaskRow(task: task),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatPlannedDuration(Duration duration, AppLocalizations messages) {
    if (duration.inHours > 0) {
      final hours = duration.inHours;
      final mins = duration.inMinutes % 60;
      if (mins == 0) return messages.dailyOsHoursPlanned(hours);
      return messages.dailyOsHoursMinutesPlanned(hours, mins);
    }
    return messages.dailyOsMinutesPlanned(duration.inMinutes);
  }
}

/// Status text showing remaining or over time.
class _StatusText extends StatelessWidget {
  const _StatusText({required this.progress});

  final TimeBudgetProgress progress;

  @override
  Widget build(BuildContext context) {
    final (text, color) = _getStatusTextAndColor(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: context.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  (String, Color) _getStatusTextAndColor(BuildContext context) {
    final messages = context.messages;
    switch (progress.status) {
      case BudgetProgressStatus.overBudget:
        final over = progress.recordedDuration - progress.plannedDuration;
        return (
          messages.dailyOsTimeOver(_formatDuration(over)),
          context.colorScheme.error,
        );

      case BudgetProgressStatus.exhausted:
        return (messages.dailyOsTimesUp, Colors.orange);

      case BudgetProgressStatus.nearLimit:
        return (
          messages.dailyOsTimeLeft(_formatDuration(progress.remainingDuration)),
          Colors.orange,
        );

      case BudgetProgressStatus.underBudget:
        return (
          messages.dailyOsTimeLeft(_formatDuration(progress.remainingDuration)),
          context.colorScheme.onSurfaceVariant,
        );
    }
  }

  String _formatDuration(Duration duration) {
    final isNegative = duration.isNegative;
    final absDuration = duration.abs();

    if (absDuration.inHours > 0) {
      final hours = absDuration.inHours;
      final mins = absDuration.inMinutes % 60;
      if (mins == 0) return '${isNegative ? '-' : ''}${hours}h';
      return '${isNegative ? '-' : ''}${hours}h ${mins}m';
    }
    return '${isNegative ? '-' : ''}${absDuration.inMinutes}m';
  }
}

/// Progress bar showing budget consumption.
class _BudgetProgressBar extends StatelessWidget {
  const _BudgetProgressBar({
    required this.progress,
    required this.categoryColor,
  });

  final TimeBudgetProgress progress;
  final Color categoryColor;

  @override
  Widget build(BuildContext context) {
    final fraction = progress.progressFraction.clamp(0.0, 1.5);
    final isOver = progress.isOverBudget;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final fillWidth =
            (fraction.clamp(0.0, 1.0) * maxWidth).clamp(0.0, maxWidth);
        final overWidth = isOver
            ? ((fraction - 1.0).clamp(0.0, 0.5) * maxWidth)
                .clamp(0.0, maxWidth * 0.5)
            : 0.0;

        return SizedBox(
          height: 8,
          child: Stack(
            children: [
              // Background track
              Container(
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),

              // Progress fill
              Container(
                width: fillWidth,
                decoration: BoxDecoration(
                  color: _getProgressColor(context),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),

              // Over-budget indicator
              if (isOver && overWidth > 0)
                Positioned(
                  left: fillWidth,
                  child: Container(
                    width: overWidth,
                    height: 8,
                    decoration: BoxDecoration(
                      color: context.colorScheme.error.withValues(alpha: 0.7),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(4),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                  ),
                ),

              // 100% marker
              Positioned(
                left: maxWidth - 2,
                child: Container(
                  width: 2,
                  height: 8,
                  color: context.colorScheme.outline.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getProgressColor(BuildContext context) {
    switch (progress.status) {
      case BudgetProgressStatus.overBudget:
        return categoryColor;
      case BudgetProgressStatus.exhausted:
        return Colors.orange;
      case BudgetProgressStatus.nearLimit:
        return categoryColor.withValues(alpha: 0.9);
      case BudgetProgressStatus.underBudget:
        return categoryColor.withValues(alpha: 0.8);
    }
  }
}

/// A compact row displaying a pinned task within a budget card.
class _PinnedTaskRow extends StatelessWidget {
  const _PinnedTaskRow({required this.task});

  final Task task;

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
      onTap: () => beamToNamed('/tasks/${task.meta.id}'),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
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
            // Task title
            Expanded(
              child: Text(
                task.data.title,
                style: context.textTheme.bodySmall?.copyWith(
                  color: textColor,
                  fontStyle: isCompleted ? FontStyle.italic : FontStyle.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // Navigation chevron
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
