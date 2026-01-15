import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/day_plan_controller.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/index.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// Summary section at the bottom of the Daily OS view.
class DaySummary extends ConsumerWidget {
  const DaySummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(dailyOsSelectedDateProvider);
    final dayPlanAsync =
        ref.watch(dayPlanControllerProvider(date: selectedDate));
    final budgetStatsAsync =
        ref.watch(dayBudgetStatsProvider(date: selectedDate));

    return dayPlanAsync.when(
      data: (dayPlan) {
        return budgetStatsAsync.when(
          data: (stats) {
            final isComplete =
                dayPlan is DayPlanEntry && dayPlan.data.isComplete;

            return ModernBaseCard(
              margin: const EdgeInsets.all(AppTheme.spacingLarge),
              padding: const EdgeInsets.all(AppTheme.spacingLarge),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(
                        isComplete ? MdiIcons.checkCircle : MdiIcons.sunCompass,
                        size: 24,
                        color: isComplete
                            ? Colors.green
                            : context.colorScheme.primary,
                      ),
                      const SizedBox(width: AppTheme.spacingMedium),
                      Text(
                        isComplete ? 'Day Complete' : 'Day Summary',
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppTheme.spacingLarge),

                  // Stats row
                  Row(
                    children: [
                      Expanded(
                        child: _StatItem(
                          label: 'Planned',
                          value: _formatDuration(stats.totalPlanned),
                          icon: MdiIcons.targetAccount,
                        ),
                      ),
                      Expanded(
                        child: _StatItem(
                          label: 'Recorded',
                          value: _formatDuration(stats.totalRecorded),
                          icon: MdiIcons.clockCheck,
                        ),
                      ),
                      Expanded(
                        child: _StatItem(
                          label: stats.isOverBudget ? 'Over' : 'Remaining',
                          value: _formatDuration(stats.totalRemaining.abs()),
                          icon: stats.isOverBudget
                              ? MdiIcons.alertCircle
                              : MdiIcons.clockOutline,
                          valueColor: stats.isOverBudget
                              ? context.colorScheme.error
                              : null,
                        ),
                      ),
                    ],
                  ),

                  // Progress indicator
                  if (stats.budgetCount > 0) ...[
                    const SizedBox(height: AppTheme.spacingLarge),
                    _OverallProgressBar(stats: stats),
                  ],

                  // Action buttons
                  if (!isComplete) ...[
                    const SizedBox(height: AppTheme.spacingLarge),
                    const Divider(),
                    const SizedBox(height: AppTheme.spacingMedium),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ActionButton(
                          icon: MdiIcons.checkAll,
                          label: 'Done for today',
                          onPressed: () {
                            ref
                                .read(
                                  dayPlanControllerProvider(date: selectedDate)
                                      .notifier,
                                )
                                .markComplete();
                          },
                        ),
                        _ActionButton(
                          icon: MdiIcons.contentCopy,
                          label: 'Copy to tomorrow',
                          onPressed: () {
                            // TODO: Implement copy budgets to next day
                          },
                        ),
                      ],
                    ),
                  ],

                  // Completion message
                  if (isComplete) ...[
                    const SizedBox(height: AppTheme.spacingMedium),
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingMedium),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            MdiIcons.partyPopper,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: AppTheme.spacingSmall),
                          Expanded(
                            child: Text(
                              'Great job! You completed your day.',
                              style: context.textTheme.bodyMedium?.copyWith(
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
          loading: () => const _LoadingState(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
      loading: () => const _LoadingState(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final mins = duration.inMinutes % 60;

    if (hours > 0) {
      if (mins == 0) return '${hours}h';
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }
}

/// Single stat item display.
class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
        Text(
          label,
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Overall progress bar for the day.
class _OverallProgressBar extends StatelessWidget {
  const _OverallProgressBar({required this.stats});

  final DayBudgetStats stats;

  @override
  Widget build(BuildContext context) {
    final fraction = stats.progressFraction.clamp(0.0, 1.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Overall Progress',
              style: context.textTheme.labelMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '${(fraction * 100).toInt()}%',
              style: context.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: _getProgressColor(context, fraction),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 8,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final fillWidth =
                  (fraction.clamp(0.0, 1.0) * maxWidth).clamp(0.0, maxWidth);

              return Stack(
                children: [
                  // Background
                  Container(
                    decoration: BoxDecoration(
                      color: context.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  // Fill
                  Container(
                    width: fillWidth,
                    decoration: BoxDecoration(
                      color: _getProgressColor(context, fraction),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Color _getProgressColor(BuildContext context, double fraction) {
    if (fraction >= 1.0) return Colors.green;
    if (fraction >= 0.8) return Colors.green.shade400;
    if (fraction >= 0.5) return context.colorScheme.primary;
    return context.colorScheme.primary.withValues(alpha: 0.7);
  }
}

/// Action button for summary actions.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: context.colorScheme.primary,
      ),
    );
  }
}

/// Loading state.
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppTheme.spacingLarge),
      padding: const EdgeInsets.all(24),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
