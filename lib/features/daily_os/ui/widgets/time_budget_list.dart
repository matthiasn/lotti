import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/day_plan_controller.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/add_budget_sheet.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_budget_card.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_budget_edit_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// List of time budgets for the day.
class TimeBudgetList extends ConsumerWidget {
  const TimeBudgetList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(dailyOsSelectedDateProvider);
    final budgetProgressAsync = ref.watch(
      timeBudgetProgressControllerProvider(date: selectedDate),
    );

    return budgetProgressAsync.when(
      data: (budgets) {
        if (budgets.isEmpty) {
          return _EmptyBudgetsState(date: selectedDate);
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
                ],
              ),
            ),

            // Reorderable budget cards
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: budgets.length,
              onReorder: (oldIndex, newIndex) {
                // Adjust index for removal
                final adjustedNewIndex =
                    newIndex > oldIndex ? newIndex - 1 : newIndex;

                // Create new order of budget IDs
                final budgetIds = budgets.map((p) => p.budget.id).toList();
                final movedId = budgetIds.removeAt(oldIndex);
                budgetIds.insert(adjustedNewIndex, movedId);

                // Update the order in the controller
                ref
                    .read(
                        dayPlanControllerProvider(date: selectedDate).notifier)
                    .reorderBudgets(budgetIds);
              },
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    final animValue =
                        Curves.easeInOut.transform(animation.value);
                    final elevation = lerpDouble(0, 6, animValue);
                    return Material(
                      elevation: elevation ?? 0,
                      color: Colors.transparent,
                      shadowColor: context.colorScheme.shadow,
                      child: child,
                    );
                  },
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final progress = budgets[index];
                return ReorderableDragStartListener(
                  key: ValueKey(progress.budget.id),
                  index: index,
                  child: TimeBudgetCard(
                    progress: progress,
                    onTap: () {
                      // TODO: Expand or navigate to budget details
                    },
                    onLongPress: () {
                      TimeBudgetEditModal.show(
                        context,
                        progress.budget,
                        progress.category,
                        selectedDate,
                      );
                    },
                  ),
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

/// Empty state when no budgets are defined.
class _EmptyBudgetsState extends StatelessWidget {
  const _EmptyBudgetsState({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppTheme.spacingLarge),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            MdiIcons.chartDonutVariant,
            size: 48,
            color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppTheme.spacingMedium),
          Text(
            context.messages.dailyOsNoBudgets,
            style: context.textTheme.titleMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSmall),
          Text(
            context.messages.dailyOsNoBudgetsHint,
            style: context.textTheme.bodyMedium?.copyWith(
              color:
                  context.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingLarge),
          FilledButton.tonalIcon(
            onPressed: () {
              AddBudgetSheet.show(context, date);
            },
            icon: const Icon(Icons.add),
            label: Text(context.messages.dailyOsAddBudget),
          ),
        ],
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
