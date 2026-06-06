part of 'time_budget_card.dart';

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

/// Compact badge indicator for "No time budgeted" state.
///
/// Used inline to show that no budget is set, with bordered badge styling.
class _NoBudgetBadge extends StatelessWidget {
  const _NoBudgetBadge({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 14,
            color: Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            message,
            style: context.textTheme.labelMedium?.copyWith(
              color: Colors.orange,
              fontWeight: FontWeight.w600,
            ),
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
