part of 'time_budget_card.dart';

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
                '• ${formatCompactDuration(totalTime)}',
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              // View mode toggle
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => ref
                    .read(
                      taskViewPreferenceProvider(
                        categoryId: categoryId,
                      ).notifier,
                    )
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
            children: tasks
                .map((item) => _TaskProgressRow(item: item))
                .toList(),
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
        final crossAxisCount = (constraints.maxWidth / minTileWidth)
            .floor()
            .clamp(2, 4);

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

/// A row displaying a task with thumbnail, time, and completion indicator.
class _TaskProgressRow extends StatelessWidget {
  const _TaskProgressRow({required this.item});

  static const _fadedCheckmarkOpacity = 0.45;

  final TaskDayProgress item;

  @override
  Widget build(BuildContext context) {
    final task = item.task;
    final isCompletedOnDay = item.wasCompletedOnDay;
    final isTaskDoneOrRejected =
        task.data.status is TaskDone || task.data.status is TaskRejected;
    final isCompletedElsewhere = !isCompletedOnDay && isTaskDoneOrRejected;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final statusColor = _getTaskStatusColor(context, task.data.status);
    final checkColor = isLight ? taskStatusDarkGreen : taskStatusGreen;

    // Text color - slightly muted for completed tasks
    final textColor = (isCompletedOnDay || isCompletedElsewhere)
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
            if (isCompletedOnDay)
              Icon(Icons.check_circle, size: 18, color: checkColor)
            else if (isCompletedElsewhere)
              Icon(
                Icons.check_circle,
                size: 18,
                color: checkColor.withValues(alpha: _fadedCheckmarkOpacity),
              )
            else
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: statusColor, width: 1.5),
                ),
              ),
            // Priority badge
            const SizedBox(width: 4),
            _PriorityBadge(priority: task.data.priority),
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
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // Time spent
            Text(
              formatCompactDuration(item.timeSpentOnDay),
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
                  formatCompactDuration(item.timeSpentOnDay),
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
                  isCompleted,
                  item.isDueOrOverdue,
                ),
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
