import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/day_plan_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/daily_timeline.dart';
import 'package:lotti/features/daily_os/ui/widgets/day_header.dart';
import 'package:lotti/features/daily_os/ui/widgets/day_summary.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_budget_list.dart';
import 'package:lotti/themes/theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// Main page for the Daily Operating System view.
///
/// Displays a vertical scrollable column with:
/// - Day Header (sticky)
/// - Timeline (plan vs actual)
/// - Time Budgets
/// - Day Summary
class DailyOsPage extends ConsumerWidget {
  const DailyOsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(dailyOsSelectedDateProvider);
    final dayPlanAsync =
        ref.watch(dayPlanControllerProvider(date: selectedDate));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Sticky header
            const DayHeader(),

            // Scrollable content
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(dayPlanControllerProvider(date: selectedDate));
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Agreement status banner
                      dayPlanAsync.when(
                        data: (dayPlan) {
                          if (dayPlan is! DayPlanEntry) {
                            return const SizedBox.shrink();
                          }
                          final data = dayPlan.data;
                          if (data.isDraft) {
                            return _AgreementBanner(
                              message: 'Plan is in draft. Agree to lock it in.',
                              actionLabel: 'Agree to Plan',
                              onAction: () {
                                ref
                                    .read(
                                      dayPlanControllerProvider(
                                        date: selectedDate,
                                      ).notifier,
                                    )
                                    .agreeToPlan();
                              },
                            );
                          }
                          if (data.needsReview) {
                            return _AgreementBanner(
                              message: 'Changes detected. Review your plan.',
                              actionLabel: 'Re-agree',
                              onAction: () {
                                ref
                                    .read(
                                      dayPlanControllerProvider(
                                        date: selectedDate,
                                      ).notifier,
                                    )
                                    .agreeToPlan();
                              },
                              isWarning: true,
                            );
                          }
                          return const SizedBox.shrink();
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),

                      // Timeline section
                      const DailyTimeline(),

                      const SizedBox(height: AppTheme.spacingMedium),

                      // Budget section
                      const TimeBudgetList(),

                      const SizedBox(height: AppTheme.spacingMedium),

                      // Summary section
                      const DaySummary(),

                      // Bottom padding
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddBudgetSheet(context, ref, selectedDate);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddBudgetSheet(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddBudgetSheet(date: date),
    );
  }
}

/// Banner for agreement status.
class _AgreementBanner extends StatelessWidget {
  const _AgreementBanner({
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.isWarning = false,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isWarning
        ? Colors.orange.withValues(alpha: 0.15)
        : context.colorScheme.primaryContainer.withValues(alpha: 0.5);

    final iconColor = isWarning ? Colors.orange : context.colorScheme.primary;

    return Container(
      margin: const EdgeInsets.all(AppTheme.spacingLarge),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMedium,
        vertical: AppTheme.spacingSmall,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isWarning ? MdiIcons.alertCircle : MdiIcons.clipboardCheck,
            color: iconColor,
            size: 20,
          ),
          const SizedBox(width: AppTheme.spacingSmall),
          Expanded(
            child: Text(
              message,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurface,
              ),
            ),
          ),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: iconColor,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet for adding a new budget.
class _AddBudgetSheet extends ConsumerStatefulWidget {
  const _AddBudgetSheet({required this.date});

  final DateTime date;

  @override
  ConsumerState<_AddBudgetSheet> createState() => _AddBudgetSheetState();
}

class _AddBudgetSheetState extends ConsumerState<_AddBudgetSheet> {
  String? _selectedCategoryId;
  int _plannedMinutes = 60;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingLarge),

            // Title
            Text(
              'Add Time Budget',
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppTheme.spacingLarge),

            // Category selector placeholder
            Text(
              'Select Category',
              style: context.textTheme.labelLarge,
            ),
            const SizedBox(height: AppTheme.spacingSmall),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMedium),
              decoration: BoxDecoration(
                border: Border.all(
                  color: context.colorScheme.outline.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    MdiIcons.folderOutline,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppTheme.spacingSmall),
                  Text(
                    'Choose a category...',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spacingLarge),

            // Duration selector
            Text(
              'Planned Duration',
              style: context.textTheme.labelLarge,
            ),
            const SizedBox(height: AppTheme.spacingSmall),
            Row(
              children: [
                _DurationChip(
                  label: '30m',
                  isSelected: _plannedMinutes == 30,
                  onTap: () => setState(() => _plannedMinutes = 30),
                ),
                const SizedBox(width: 8),
                _DurationChip(
                  label: '1h',
                  isSelected: _plannedMinutes == 60,
                  onTap: () => setState(() => _plannedMinutes = 60),
                ),
                const SizedBox(width: 8),
                _DurationChip(
                  label: '2h',
                  isSelected: _plannedMinutes == 120,
                  onTap: () => setState(() => _plannedMinutes = 120),
                ),
                const SizedBox(width: 8),
                _DurationChip(
                  label: '3h',
                  isSelected: _plannedMinutes == 180,
                  onTap: () => setState(() => _plannedMinutes = 180),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingMedium),
                Expanded(
                  child: FilledButton(
                    onPressed: _selectedCategoryId != null
                        ? () {
                            // TODO: Add budget
                            Navigator.pop(context);
                          }
                        : null,
                    child: const Text('Add Budget'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacingMedium),
          ],
        ),
      ),
    );
  }
}

/// Duration selection chip.
class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? context.colorScheme.primaryContainer
              : context.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? context.colorScheme.primary
                : context.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: context.textTheme.labelLarge?.copyWith(
            color: isSelected
                ? context.colorScheme.onPrimaryContainer
                : context.colorScheme.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
