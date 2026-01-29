import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_icon.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/task_view_preference_controller.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/tasks/ui/cover_art_thumbnail.dart';
import 'package:lotti/features/tasks/util/due_date_utils.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/cards/index.dart';

/// Formats a duration as "Xh Ym" or "Xm".
String _formatCompactDuration(Duration duration) {
  if (duration.inHours > 0) {
    final hours = duration.inHours;
    final mins = duration.inMinutes % 60;
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }
  return '${duration.inMinutes}m';
}

/// Returns the appropriate color for a task status.
Color _getTaskStatusColor(BuildContext context, TaskStatus status) {
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

              // Warning banner for categories with due tasks but no budget
              if (progress.hasNoBudgetWarning) ...[
                const SizedBox(height: AppTheme.spacingSmall),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border:
                        Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.messages.dailyOsNoBudgetWarning,
                        style: context.textTheme.labelSmall
                            ?.copyWith(color: Colors.orange),
                      ),
                    ],
                  ),
                ),
              ],

              // Task progress section
              if (progress.taskProgressItems.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacingMedium),
                const Divider(height: 1),
                _ExpandableTaskSection(
                  tasks: progress.taskProgressItems,
                  categoryId: progress.categoryId,
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

/// Expandable section showing tasks with their progress.
class _ExpandableTaskSection extends ConsumerStatefulWidget {
  const _ExpandableTaskSection({
    required this.tasks,
    required this.categoryId,
  });

  final List<TaskDayProgress> tasks;
  final String categoryId;

  @override
  ConsumerState<_ExpandableTaskSection> createState() =>
      _ExpandableTaskSectionState();
}

class _ExpandableTaskSectionState
    extends ConsumerState<_ExpandableTaskSection> {
  bool _isExpanded = true;

  Duration get _totalTime => widget.tasks.fold(
        Duration.zero,
        (total, item) => total + item.timeSpentOnDay,
      );

  @override
  Widget build(BuildContext context) {
    final viewModeAsync = ref.watch(
      taskViewPreferenceProvider(categoryId: widget.categoryId),
    );
    final viewMode = viewModeAsync.value ?? TaskViewMode.list;

    return Column(
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingSmall),
          child: Row(
            children: [
              // Tappable expand/collapse area
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Text(
                        '${context.messages.dailyOsTasks} (${widget.tasks.length})',
                        style: context.textTheme.labelMedium?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '• ${_formatCompactDuration(_totalTime)}',
                        style: context.textTheme.labelMedium?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // View mode toggle - larger tap target for mobile
              if (_isExpanded) ...[
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => ref
                      .read(
                        taskViewPreferenceProvider(
                                categoryId: widget.categoryId)
                            .notifier,
                      )
                      .toggle(),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      viewMode == TaskViewMode.list
                          ? Icons.grid_view_rounded
                          : Icons.view_list_rounded,
                      size: 20,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
              // Expand/collapse icon - larger tap target for mobile
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    size: 20,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Animated task list/grid
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child:
              _isExpanded ? _buildContent(viewMode) : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildContent(TaskViewMode viewMode) {
    if (viewMode == TaskViewMode.list) {
      return Column(
        children:
            widget.tasks.map((item) => _TaskProgressRow(item: item)).toList(),
      );
    }
    return _buildGrid();
  }

  Widget _buildGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 3 columns on mobile (<400), adaptive on larger screens
        // Aim for ~100-120px tiles
        final width = constraints.maxWidth;
        final crossAxisCount =
            width < 400 ? 3 : (width / 110).floor().clamp(3, 6);
        const spacing = 8.0;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: widget.tasks.length,
          itemBuilder: (context, index) =>
              _TaskGridTile(item: widget.tasks[index]),
        );
      },
    );
  }
}

/// A row displaying a task with thumbnail, time, and completion indicator.
class _TaskProgressRow extends StatelessWidget {
  const _TaskProgressRow({required this.item});

  final TaskDayProgress item;

  @override
  Widget build(BuildContext context) {
    final task = item.task;
    final isCompleted = item.wasCompletedOnDay;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final statusColor = _getTaskStatusColor(context, task.data.status);
    final checkColor = isLight ? taskStatusDarkGreen : taskStatusGreen;

    // Text color - slightly muted for completed tasks
    final textColor = isCompleted
        ? context.colorScheme.onSurface.withValues(alpha: 0.5)
        : context.colorScheme.onSurface.withValues(alpha: 0.85);

    return GestureDetector(
      onTap: () => beamToNamed('/tasks/${task.meta.id}'),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            // Status indicator
            if (isCompleted)
              Icon(Icons.check_circle, size: 18, color: checkColor)
            else
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: statusColor, width: 1.5),
                ),
              ),
            // Priority badge (show only for non-default priorities)
            if (task.data.priority != TaskPriority.p2Medium) ...[
              const SizedBox(width: 4),
              _PriorityBadge(priority: task.data.priority),
            ],
            // Due badge
            if (item.isDueOrOverdue) ...[
              const SizedBox(width: 4),
              _DueBadge(dueDateStatus: item.dueDateStatus),
            ],
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
            // Time spent
            Text(
              _formatCompactDuration(item.timeSpentOnDay),
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge showing due date status (Due Today or Overdue).
class _DueBadge extends StatelessWidget {
  const _DueBadge({required this.dueDateStatus});

  final DueDateStatus dueDateStatus;

  @override
  Widget build(BuildContext context) {
    final color = dueDateStatus.urgentColor ?? Colors.orange;
    final label = _getDueLabel(dueDateStatus, context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _getDueLabel(DueDateStatus status, BuildContext context) {
    return switch (status.urgency) {
      DueDateUrgency.overdue => context.messages.dailyOsOverdue,
      DueDateUrgency.dueToday => context.messages.dailyOsDueToday,
      DueDateUrgency.normal => '',
    };
  }
}

/// Compact priority badge styled like Linear.
class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority});

  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    final color = priority.colorForBrightness(Theme.of(context).brightness);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        priority.short,
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Compact priority badge for grid view.
class _PriorityGridBadge extends StatelessWidget {
  const _PriorityGridBadge({required this.priority});

  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    final color = priority.colorForBrightness(Theme.of(context).brightness);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        priority.short,
        style: context.textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// A grid tile displaying a task with thumbnail and overlay info.
class _TaskGridTile extends StatelessWidget {
  const _TaskGridTile({required this.item});

  final TaskDayProgress item;

  @override
  Widget build(BuildContext context) {
    final task = item.task;
    final isCompleted = item.wasCompletedOnDay;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final coverArtId = task.data.coverArtId;
    final statusColor = _getTaskStatusColor(context, task.data.status);

    return GestureDetector(
      onTap: () => beamToNamed('/tasks/${task.meta.id}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background - thumbnail or placeholder
            if (coverArtId != null)
              CoverArtThumbnail(
                imageId: coverArtId,
                size: 200, // Large enough for quality
                cropX: task.data.coverArtCropX,
              )
            else
              ColoredBox(
                color: context.colorScheme.surfaceContainerHighest,
                child: Center(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: statusColor, width: 2),
                    ),
                  ),
                ),
              ),

            // Gradient overlay for text readability
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
            ),

            // Time badge (top right)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _formatCompactDuration(item.timeSpentOnDay),
                  style: context.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            // Completion checkmark (top left)
            if (isCompleted)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isLight ? taskStatusDarkGreen : taskStatusGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),

            // Due badge (top left, below checkmark if completed)
            if (item.isDueOrOverdue)
              Positioned(
                top: isCompleted ? 28 : 4,
                left: 4,
                child: _DueGridBadge(dueDateStatus: item.dueDateStatus),
              ),

            // Priority badge (top left, below due badge if present)
            if (task.data.priority != TaskPriority.p2Medium)
              Positioned(
                top: _calculatePriorityBadgeTop(
                    isCompleted, item.isDueOrOverdue),
                left: 4,
                child: _PriorityGridBadge(priority: task.data.priority),
              ),

            // Title (bottom)
            Positioned(
              left: 6,
              right: 6,
              bottom: 6,
              child: Text(
                task.data.title,
                style: context.textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Calculate the top position for the priority badge based on other badges.
  double _calculatePriorityBadgeTop(bool isCompleted, bool isDueOrOverdue) {
    // Start from top
    var top = 4.0;
    // If completed, checkmark takes 24px (4 + 20 padding/size)
    if (isCompleted) top += 24;
    // If due badge is present, it takes 20px (4 + 16 padding/size)
    if (isDueOrOverdue) top += 20;
    return top;
  }
}

/// Compact badge for grid view showing due date status.
class _DueGridBadge extends StatelessWidget {
  const _DueGridBadge({required this.dueDateStatus});

  final DueDateStatus dueDateStatus;

  @override
  Widget build(BuildContext context) {
    final color = dueDateStatus.urgentColor ?? Colors.orange;
    final label = _getDueBadgeText(dueDateStatus, context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Short labels for compact grid
  String _getDueBadgeText(DueDateStatus status, BuildContext context) {
    return switch (status.urgency) {
      DueDateUrgency.overdue => context.messages.dailyOsOverdueShort,
      DueDateUrgency.dueToday => context.messages.dailyOsDueTodayShort,
      DueDateUrgency.normal => '',
    };
  }
}
