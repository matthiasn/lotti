import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/state/unified_daily_os_data_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/add_budget_sheet.dart';
import 'package:lotti/features/daily_os/ui/widgets/daily_os_empty_states.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_budget_card.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// List of time budgets for the day.
///
/// Budgets are derived from the sum of planned blocks per category.
class TimeBudgetList extends ConsumerWidget {
  const TimeBudgetList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(dailyOsSelectedDateProvider);
    final unifiedDataAsync = ref.watch(
      unifiedDailyOsDataControllerProvider(date: selectedDate),
    );

    // Watch the active focus category for auto-expand/collapse behavior
    final activeFocusCategoryId =
        ref.watch(activeFocusCategoryIdProvider).value;

    return unifiedDataAsync.when(
      data: (unifiedData) {
        final budgets = unifiedData.budgetProgress;
        if (budgets.isEmpty) {
          return BudgetsEmptyState(date: selectedDate);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingLarge,
                vertical: AppTheme.spacingMedium,
              ),
              child: Row(
                children: [
                  Icon(
                    MdiIcons.chartDonut,
                    size: 20,
                    color: context.colorScheme.primary,
                  ),
                  const SizedBox(width: AppTheme.spacingSmall),
                  Text(
                    context.messages.dailyOsTimeBudgets,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  _BudgetsSummaryChip(budgets: budgets),
                  const SizedBox(width: AppTheme.spacingSmall),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => AddBlockSheet.show(context, selectedDate),
                    tooltip: context.messages.dailyOsAddBlock,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            // Budget cards (derived from planned blocks)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: budgets.length,
              itemBuilder: (context, index) {
                final progress = budgets[index];

                // Determine focus state for this category:
                // - null: No focus context (no active block) -> expanded by default
                // - true: This is the active category -> expanded
                // - false: Another category is active -> collapsed
                final isFocusActive = activeFocusCategoryId == null
                    ? null
                    : activeFocusCategoryId == progress.categoryId;

                return TimeBudgetCard(
                  key: ValueKey(progress.categoryId),
                  progress: progress,
                  selectedDate: selectedDate,
                  isFocusActive: isFocusActive,
                  onTap: () {
                    // Highlight this category in the timeline
                    ref
                        .read(dailyOsControllerProvider.notifier)
                        .highlightCategory(progress.categoryId);
                  },
                );
              },
            ),
          ],
        );
      },
      loading: () => const _LoadingState(),
      error: (error, stack) => _ErrorState(error: error),
    );
  }
}

/// Summary chip showing total budget stats.
class _BudgetsSummaryChip extends StatelessWidget {
  const _BudgetsSummaryChip({required this.budgets});

  final List<TimeBudgetProgress> budgets;

  @override
  Widget build(BuildContext context) {
    final totalRecorded = budgets.fold(
      Duration.zero,
      (total, b) => total + b.recordedDuration,
    );
    final totalPlanned = budgets.fold(
      Duration.zero,
      (total, b) => total + b.plannedDuration,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${_formatDuration(totalRecorded)} / ${_formatDuration(totalPlanned)}',
        style: context.textTheme.labelMedium?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
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
}

/// Loading state.
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// Error state.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppTheme.spacingLarge),
      padding: const EdgeInsets.all(AppTheme.spacingLarge),
      decoration: BoxDecoration(
        color: context.colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
      ),
      child: Row(
        children: [
          Icon(
            MdiIcons.alertCircle,
            color: context.colorScheme.error,
          ),
          const SizedBox(width: AppTheme.spacingMedium),
          Expanded(
            child: Text(
              context.messages.dailyOsFailedToLoadBudgets,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
