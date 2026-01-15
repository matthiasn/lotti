import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_icon.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/cards/index.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

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
                          category?.name ?? 'Uncategorized',
                          style: context.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _formatPlannedDuration(progress.plannedDuration),
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

              // Expanded content (task list preview)
              if (isExpanded && progress.contributingEntries.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacingMedium),
                const Divider(height: 1),
                const SizedBox(height: AppTheme.spacingSmall),
                ...progress.contributingEntries.take(3).map(
                      (entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(
                              MdiIcons.checkCircle,
                              size: 14,
                              color: categoryColor.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _getEntryTitle(entry),
                                style: context.textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                if (progress.contributingEntries.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+${progress.contributingEntries.length - 3} more',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatPlannedDuration(Duration duration) {
    if (duration.inHours > 0) {
      final hours = duration.inHours;
      final mins = duration.inMinutes % 60;
      if (mins == 0) return '$hours hour${hours == 1 ? '' : 's'} planned';
      return '${hours}h ${mins}m planned';
    }
    return '${duration.inMinutes} min planned';
  }

  String _getEntryTitle(JournalEntity entry) {
    return switch (entry) {
      Task(:final data) => data.title,
      _ => 'Entry',
    };
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
    switch (progress.status) {
      case BudgetProgressStatus.overBudget:
        final over = progress.recordedDuration - progress.plannedDuration;
        return ('+${_formatDuration(over)} over', context.colorScheme.error);

      case BudgetProgressStatus.exhausted:
        return ("Time's up", Colors.orange);

      case BudgetProgressStatus.nearLimit:
        return (
          '${_formatDuration(progress.remainingDuration)} left',
          Colors.orange
        );

      case BudgetProgressStatus.underBudget:
        return (
          '${_formatDuration(progress.remainingDuration)} left',
          context.colorScheme.onSurfaceVariant
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
