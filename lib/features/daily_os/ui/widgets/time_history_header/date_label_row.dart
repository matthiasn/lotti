import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/state/unified_daily_os_data_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_history_header/day_label_chip.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_history_header/status_indicator.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_history_header/today_button.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/date_utils_extension.dart';

/// Date label row at the bottom of the header.
class DateLabelRow extends ConsumerWidget {
  const DateLabelRow({
    required this.selectedDate,
    required this.onTodayPressed,
    super.key,
  });

  final DateTime selectedDate;
  final VoidCallback onTodayPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unifiedDataAsync =
        ref.watch(unifiedDailyOsDataControllerProvider(date: selectedDate));
    final budgetStatsAsync =
        ref.watch(dayBudgetStatsProvider(date: selectedDate));

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingSmall,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Tappable date text (flexible to prevent overflow)
          Flexible(
            child: GestureDetector(
              onTap: () => _showDatePicker(context, ref, selectedDate),
              child: Text(
                _formatDate(context, selectedDate),
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // Day label chip
          unifiedDataAsync.when(
            data: (unifiedData) {
              final dayPlan = unifiedData.dayPlan;
              final label = dayPlan.data.dayLabel;
              if (label == null || label.isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(left: AppTheme.spacingSmall),
                child: DayLabelChip(label: label),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Status indicator
          budgetStatsAsync.when(
            data: (stats) {
              if (stats.budgetCount == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(left: AppTheme.spacingSmall),
                child: StatusIndicator(stats: stats),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Today button (if not viewing today)
          if (!_isToday(selectedDate))
            Padding(
              padding: const EdgeInsets.only(left: AppTheme.spacingSmall),
              child: TodayButton(onPressed: onTodayPressed),
            ),
        ],
      ),
    );
  }

  String _formatDate(BuildContext context, DateTime date) {
    final locale = Localizations.localeOf(context).toString();
    final dayName = DateFormat('EEEE', locale).format(date);
    final formattedDate = DateFormat.yMMMd(locale).format(date);
    return '$dayName, $formattedDate';
  }

  bool _isToday(DateTime date) {
    return date.dayAtMidnight == clock.now().dayAtMidnight;
  }

  Future<void> _showDatePicker(
    BuildContext context,
    WidgetRef ref,
    DateTime currentDate,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      ref.read(dailyOsSelectedDateProvider.notifier).selectDate(picked);
    }
  }
}
