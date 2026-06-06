import 'dart:async';

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
import 'package:lotti/logic/create/create_entry.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/cards/index.dart';

part 'budget_card_indicators.dart';
part 'budget_card_task_list.dart';

/// Formats a duration as "Xh Ym" or "Xm".
@visibleForTesting
String formatCompactDuration(Duration duration) {
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
    required this.selectedDate,
    this.onTap,
    this.onLongPress,
    this.isExpanded = false,
    this.isFocusActive,
    super.key,
  });

  final TimeBudgetProgress progress;

  /// The currently selected date, used for task creation due date.
  final DateTime selectedDate;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isExpanded;

  /// Whether this category is the currently active focus.
  /// - `true`: This is the active category, task section starts expanded
  /// - `false`: Another category is active, task section starts collapsed
  /// - `null`: No active focus (no block covering current time), collapsed
  final bool? isFocusActive;

  @override
  ConsumerState<TimeBudgetCard> createState() => _TimeBudgetCardState();
}

class _TimeBudgetCardState extends ConsumerState<TimeBudgetCard> {
  late bool _isExpanded;
  bool _userHasToggled = false;

  @override
  void initState() {
    super.initState();
    // Default to collapsed. Only expand if this is the active focus category.
    _isExpanded = widget.isFocusActive ?? false;
  }

  @override
  void didUpdateWidget(TimeBudgetCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only auto-update if user hasn't manually toggled
    if (widget.isFocusActive != oldWidget.isFocusActive && !_userHasToggled) {
      setState(() {
        // Default to collapsed. Only expand if this is the active focus category.
        _isExpanded = widget.isFocusActive ?? false;
      });
    }
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

    // Check if a timer is running for this category (for visual indicator)
    final runningTimerCategoryId = ref.watch(runningTimerCategoryIdProvider);
    final isTimerRunningForCategory =
        runningTimerCategoryId == progress.categoryId;

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
          border: isHighlighted
              ? Border.all(color: categoryColor, width: 2)
              : null,
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

                  // Quick create task button
                  Tooltip(
                    message: context.messages.dailyOsQuickCreateTask,
                    child: GestureDetector(
                      onTap: () => _quickCreateTask(context),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.add_circle_outline,
                          size: 20,
                          color: context.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),

                  // Task completion indicator (if has tasks)
                  if (hasTasks) ...[
                    const SizedBox(width: 8),
                    _TaskCompletionIndicator(
                      tasks: progress.taskProgressItems,
                    ),
                  ],

                  // Expand/collapse icon
                  if (hasTasks) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => setState(() {
                        _isExpanded = !_isExpanded;
                        _userHasToggled = true;
                      }),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          _isExpanded
                              ? Icons.keyboard_arrow_down
                              : Icons.chevron_right,
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
              // Scenario A: No budget AND no time recorded -> show inline "No time budgeted"
              // Scenario B: No budget BUT time recorded -> show "Xm / 0m" format
              // Normal: Show full time info with progress bar and status badge
              _buildTimeRow(
                context,
                progress: progress,
                isTimerRunningForCategory: isTimerRunningForCategory,
              ),

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

  Future<void> _quickCreateTask(BuildContext context) async {
    final categoryId = widget.progress.category?.id;

    // Create task with category and due date pre-assigned
    final task = await createTask(
      categoryId: categoryId,
      due: widget.selectedDate,
    );

    // Navigate to the newly created task
    if (task != null && context.mounted) {
      unawaited(autoAssignCategoryAgent(ref, task));
      beamToNamed('/tasks/${task.meta.id}');
    }
  }

  /// Builds the time row with conditional display based on budget state.
  ///
  /// - **Scenario A** (no budget, no time recorded): Shows "No time budgeted" badge only
  /// - **Scenario B** (no budget, time recorded): Shows "Xm / 0m" with "No time budgeted" badge
  /// - **Normal**: Shows full time info with progress bar and status badge
  Widget _buildTimeRow(
    BuildContext context, {
    required TimeBudgetProgress progress,
    required bool isTimerRunningForCategory,
  }) {
    final hasNoBudget = progress.plannedDuration == Duration.zero;
    final hasNoTimeRecorded = progress.recordedDuration == Duration.zero;

    // Scenario A: No budget AND no time recorded -> show only the badge (right-aligned)
    if (hasNoBudget && hasNoTimeRecorded && progress.hasNoBudgetWarning) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _NoBudgetBadge(
            message: context.messages.dailyOsNoBudgetWarning,
          ),
        ],
      );
    }

    // Scenario B: Show "No time budgeted" badge instead of status
    final showNoBudgetBadge =
        hasNoBudget && !hasNoTimeRecorded && progress.hasNoBudgetWarning;

    // Build the badge widget
    final badge = showNoBudgetBadge
        ? _NoBudgetBadge(message: context.messages.dailyOsNoBudgetWarning)
        : _StatusText(progress: progress);

    return Row(
      children: [
        // Timer indicator when running
        if (isTimerRunningForCategory) ...[
          Icon(
            Icons.timer,
            size: 14,
            color: context.colorScheme.error,
          ),
          const SizedBox(width: 4),
        ],
        // Time: recorded / planned
        Text(
          '${formatCompactDuration(progress.recordedDuration)} / ${formatCompactDuration(progress.plannedDuration)}',
          style: context.textTheme.bodySmall?.copyWith(
            color: isTimerRunningForCategory
                ? context.colorScheme.error
                : context.colorScheme.onSurfaceVariant,
            fontWeight: isTimerRunningForCategory ? FontWeight.w600 : null,
          ),
        ),

        const SizedBox(width: 8),

        // Progress bar (fixed width)
        _MiniProgressBar(progress: progress),

        // Flexible spacer to push badge to the right
        const Expanded(child: SizedBox.shrink()),

        // Status badge or "No time budgeted" badge (right-aligned)
        badge,
      ],
    );
  }
}
