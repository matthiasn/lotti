import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_icon.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/tasks/ui/cover_art_thumbnail.dart';
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

              // Task progress section
              if (progress.taskProgressItems.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacingMedium),
                const Divider(height: 1),
                _ExpandableTaskSection(tasks: progress.taskProgressItems),
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

/// View mode for task section.
enum _TaskViewMode { list, grid }

/// Expandable section showing tasks with their progress.
class _ExpandableTaskSection extends StatefulWidget {
  const _ExpandableTaskSection({required this.tasks});

  final List<TaskDayProgress> tasks;

  @override
  State<_ExpandableTaskSection> createState() => _ExpandableTaskSectionState();
}

class _ExpandableTaskSectionState extends State<_ExpandableTaskSection> {
  bool _isExpanded = true;
  _TaskViewMode _viewMode = _TaskViewMode.grid;

  Duration get _totalTime => widget.tasks.fold(
        Duration.zero,
        (total, item) => total + item.timeSpentOnDay,
      );

  @override
  Widget build(BuildContext context) {
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
                        '• ${_formatDuration(_totalTime)}',
                        style: context.textTheme.labelMedium?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // View mode toggle
              if (_isExpanded) ...[
                GestureDetector(
                  onTap: () => setState(() {
                    _viewMode = _viewMode == _TaskViewMode.list
                        ? _TaskViewMode.grid
                        : _TaskViewMode.list;
                  }),
                  child: Icon(
                    _viewMode == _TaskViewMode.list
                        ? Icons.grid_view_rounded
                        : Icons.view_list_rounded,
                    size: 20,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // Expand/collapse icon
              GestureDetector(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 20,
                  color: context.colorScheme.onSurfaceVariant,
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
          child: _isExpanded ? _buildContent() : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_viewMode == _TaskViewMode.list) {
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

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      final hours = duration.inHours;
      final mins = duration.inMinutes % 60;
      if (mins == 0) return '${hours}h';
      return '${hours}h ${mins}m';
    }
    return '${duration.inMinutes}m';
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
    final statusColor = _getStatusColor(context, task.data.status);
    final checkColor = isLight ? taskStatusDarkGreen : taskStatusGreen;

    // Text color - slightly muted for completed tasks
    final textColor = isCompleted
        ? context.colorScheme.onSurface.withValues(alpha: 0.5)
        : context.colorScheme.onSurface.withValues(alpha: 0.85);

    return GestureDetector(
      onTap: () => beamToNamed('/tasks/${task.meta.id}'),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
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
              _formatDuration(item.timeSpentOnDay),
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      final hours = duration.inHours;
      final mins = duration.inMinutes % 60;
      if (mins == 0) return '${hours}h';
      return '${hours}h ${mins}m';
    }
    return '${duration.inMinutes}m';
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
    final statusColor = _getStatusColor(context, task.data.status);

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
                  _formatDuration(item.timeSpentOnDay),
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

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      final hours = duration.inHours;
      final mins = duration.inMinutes % 60;
      if (mins == 0) return '${hours}h';
      return '${hours}h ${mins}m';
    }
    return '${duration.inMinutes}m';
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
