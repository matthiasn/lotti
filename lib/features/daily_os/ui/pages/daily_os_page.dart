import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/day_plan_controller.dart';
import 'package:lotti/features/daily_os/state/unified_daily_os_data_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/add_budget_sheet.dart'
    as add_block;
import 'package:lotti/features/daily_os/ui/widgets/daily_timeline.dart';
import 'package:lotti/features/daily_os/ui/widgets/day_header.dart';
import 'package:lotti/features/daily_os/ui/widgets/day_summary.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_budget_list.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
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
    final unifiedDataAsync =
        ref.watch(unifiedDailyOsDataControllerProvider(date: selectedDate));

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
                  // Invalidate the unified controller to trigger a full refresh
                  ref.invalidate(
                    unifiedDailyOsDataControllerProvider(date: selectedDate),
                  );
                  await ref.read(
                    unifiedDailyOsDataControllerProvider(date: selectedDate)
                        .future,
                  );
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Agreement status banner
                      unifiedDataAsync.when(
                        data: (unifiedData) {
                          final dayPlan = unifiedData.dayPlan;
                          final data = dayPlan.data;
                          if (data.isDraft) {
                            return _AgreementBanner(
                              message: context.messages.dailyOsDraftMessage,
                              actionLabel: context.messages.dailyOsAgreeToPlan,
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
                              message: context.messages.dailyOsReviewMessage,
                              actionLabel: context.messages.dailyOsReAgree,
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
          add_block.AddBlockSheet.show(context, selectedDate);
        },
        child: const Icon(Icons.add),
      ),
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
