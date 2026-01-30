import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_icon.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/task_view_preference_controller.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/tasks/ui/cover_art_thumbnail.dart';
import 'package:lotti/features/tasks/util/due_date_utils.dart';
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
///
/// Single slim header row with expand/collapse icon. Task list expands below.
class TimeBudgetCard extends ConsumerStatefulWidget {
  const TimeBudgetCard({
    required this.progress,
    this.onTap,
    this.onLongPress,
    this.isExpanded = false,
    this.isFocusActive,
    super.key,
  });

  final TimeBudgetProgress progress;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isExpanded;

  /// Whether this category is the currently active focus.
  /// - `true`: This is the active category, task section starts expanded
  /// - `false`: Another category is active, task section starts collapsed
  /// - `null`: No focus context, task section starts expanded (default behavior)
  final bool? isFocusActive;

  @override
  ConsumerState<TimeBudgetCard> createState() => _TimeBudgetCardState();
}

class _TimeBudgetCardState extends ConsumerState<TimeBudgetCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isFocusActive ?? true;
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress;
    final category = progress.category;
    final categoryId = category?.id;
    final categoryColor = category != null
        ? colorFromCssHex(category.color)
        : context.colorScheme.primary;

    final highlightedId = ref.watch(highlightedCategoryIdProvider);
    final isHighlighted = categoryId != null && highlightedId == categoryId;
    final hasTasks = progress.taskProgressItems.isNotEmpty;

    return GestureDetector(
      onLongPress: widget.onLongPress,
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
            if (categoryId != null) {
              ref
                  .read(dailyOsControllerProvider.notifier)
                  .highlightCategory(categoryId);
            }
            widget.onTap?.call();
          },
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingSmall + 2,
            vertical: AppTheme.spacingSmall,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Category name with task indicator and expand icon
              Row(
                children: [
                  // Category icon
                  if (category != null) ...[
                    ColorIcon(categoryColor, size: 16),
                    const SizedBox(width: 8),
                  ],

                  // Category name (flexible, can be long)
                  Expanded(
                    child: Text(
                      category?.name ?? context.messages.dailyOsUncategorized,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Task completion indicator (if has tasks)
                  if (hasTasks) ...[
                    const SizedBox(width: 12),
                    _TaskCompletionIndicator(
                      tasks: progress.taskProgressItems,
                    ),
                  ],

                  // Expand/collapse icon
                  if (hasTasks) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => setState(() => _isExpanded = !_isExpanded),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          _isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 20,
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 6),

              // Row 2: Time info, progress bar, status
              Row(
                children: [
                  // Time: recorded / planned (fixed width for alignment)
                  SizedBox(
                    width: 120,
                    child: Text(
                      '${_formatCompactDuration(progress.recordedDuration)} / ${_formatCompactDuration(progress.plannedDuration)}',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),

                  // Progress bar (fixed width)
                  _MiniProgressBar(progress: progress),

                  const Spacer(),

                  // Status badge
                  _StatusText(progress: progress),
                ],
              ),

              // Warning banner for categories with due tasks but no budget
              if (progress.hasNoBudgetWarning) ...[
                const SizedBox(height: AppTheme.spacingSmall),
                _WarningBanner(
                    message: context.messages.dailyOsNoBudgetWarning),
              ],

              // Expandable task list
              if (hasTasks)
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: _isExpanded
                      ? _TaskListContent(
                          tasks: progress.taskProgressItems,
                          categoryId: progress.categoryId,
                        )
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mini inline progress bar for the header row.
class _MiniProgressBar extends StatelessWidget {
  const _MiniProgressBar({required this.progress});

  final TimeBudgetProgress progress;

  @override
  Widget build(BuildContext context) {
    final fraction = progress.progressFraction.clamp(0.0, 1.0);
    final isOver = progress.isOverBudget;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final progressColor = isOver
        ? context.colorScheme.error
        : (isLight ? taskStatusDarkGreen : taskStatusGreen);

    return SizedBox(
      width: 64,
      height: 3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(1.5),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: fraction,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: progressColor,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular indicator showing task completion percentage.
class _TaskCompletionIndicator extends StatelessWidget {
  const _TaskCompletionIndicator({required this.tasks});

  final List<TaskDayProgress> tasks;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) return const SizedBox.shrink();

    final completed = tasks.where((t) => t.wasCompletedOnDay).length;
    final total = tasks.length;
    final fraction = total > 0 ? completed / total : 0.0;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final completedColor = isLight ? taskStatusDarkGreen : taskStatusGreen;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Task count text
        Text(
          '$completed/$total',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        // Progress ring
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            value: fraction,
            strokeWidth: 2,
            backgroundColor: context.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(completedColor),
          ),
        ),
      ],
    );
  }
}

/// Task list content (shown when expanded).
class _TaskListContent extends ConsumerWidget {
  const _TaskListContent({
    required this.tasks,
    required this.categoryId,
  });

  final List<TaskDayProgress> tasks;
  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModeAsync = ref.watch(
      taskViewPreferenceProvider(categoryId: categoryId),
    );
    final viewMode = viewModeAsync.value ?? TaskViewMode.list;

    final totalTime = tasks.fold(
      Duration.zero,
      (total, item) => total + item.timeSpentOnDay,
    );

    return Column(
      children: [
        const SizedBox(height: AppTheme.spacingSmall),
        const Divider(height: 1),
        // Task header row
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Text(
                '${context.messages.dailyOsTasks} (${tasks.length})',
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '• ${_formatCompactDuration(totalTime)}',
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              // View mode toggle
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => ref
                    .read(taskViewPreferenceProvider(categoryId: categoryId)
                        .notifier)
                    .toggle(),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    viewMode == TaskViewMode.list
                        ? Icons.grid_view_rounded
                        : Icons.view_list_rounded,
                    size: 16,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Task content
        if (viewMode == TaskViewMode.list)
          Column(
            children:
                tasks.map((item) => _TaskProgressRow(item: item)).toList(),
          )
        else
          _buildGrid(context),
      ],
    );
  }

  Widget _buildGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const minTileWidth = 100.0;
        final crossAxisCount =
            (constraints.maxWidth / minTileWidth).floor().clamp(2, 4);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: tasks.length,
          itemBuilder: (context, index) => _TaskGridTile(item: tasks[index]),
        );
      },
    );
  }
}

/// Warning banner widget.
class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
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
            message,
            style: context.textTheme.labelSmall?.copyWith(color: Colors.orange),
          ),
        ],
      ),
    );
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
    final textColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        priority.short,
        style: context.textTheme.labelSmall?.copyWith(
          color: textColor,
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

  // Badge layout constants
  static const _badgeInitialTop = 4.0;
  static const _completedBadgeHeight = 24.0; // 4px padding + 20px icon/badge
  static const _dueBadgeHeight = 20.0; // 4px padding + 16px badge

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
    var top = _badgeInitialTop;
    if (isCompleted) top += _completedBadgeHeight;
    if (isDueOrOverdue) top += _dueBadgeHeight;
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
