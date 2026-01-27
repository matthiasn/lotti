import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/state/unified_daily_os_data_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// Header widget for the Daily OS view.
///
/// Shows the current date, optional day label, and status indicator.
/// Supports swipe gestures for day navigation.
class DayHeader extends ConsumerWidget {
  const DayHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(dailyOsSelectedDateProvider);
    final unifiedDataAsync =
        ref.watch(unifiedDailyOsDataControllerProvider(date: selectedDate));
    final budgetStatsAsync =
        ref.watch(dayBudgetStatsProvider(date: selectedDate));

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 0) {
          ref.read(dailyOsSelectedDateProvider.notifier).goToPreviousDay();
        } else if (velocity < 0) {
          ref.read(dailyOsSelectedDateProvider.notifier).goToNextDay();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingLarge,
          vertical: AppTheme.spacingMedium,
        ),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerHighest,
          border: Border(
            bottom: BorderSide(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Previous day button
                IconButton(
                  icon: Icon(
                    MdiIcons.chevronLeft,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    ref
                        .read(dailyOsSelectedDateProvider.notifier)
                        .goToPreviousDay();
                  },
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),

                // Date display
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showDatePicker(context, ref, selectedDate),
                    child: Column(
                      children: [
                        Text(
                          _formatDayName(context, selectedDate),
                          style: context.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(context, selectedDate),
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Next day button
                IconButton(
                  icon: Icon(
                    MdiIcons.chevronRight,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    ref
                        .read(dailyOsSelectedDateProvider.notifier)
                        .goToNextDay();
                  },
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),

            // Day label and status row
            const SizedBox(height: AppTheme.spacingSmall),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Day label chip
                unifiedDataAsync.when(
                  data: (unifiedData) {
                    final dayPlan = unifiedData.dayPlan;
                    final label = dayPlan.data.dayLabel;
                    if (label == null || label.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return _DayLabelChip(label: label);
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                // Status indicator
                budgetStatsAsync.when(
                  data: (stats) {
                    if (stats.budgetCount == 0) return const SizedBox.shrink();
                    return Padding(
                      padding:
                          const EdgeInsets.only(left: AppTheme.spacingSmall),
                      child: _StatusIndicator(stats: stats),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

                // Today button (if not on today)
                if (!_isToday(selectedDate))
                  Padding(
                    padding: const EdgeInsets.only(left: AppTheme.spacingSmall),
                    child: TextButton.icon(
                      onPressed: () {
                        ref
                            .read(dailyOsSelectedDateProvider.notifier)
                            .goToToday();
                      },
                      icon: Icon(
                        MdiIcons.calendarToday,
                        size: 16,
                        color: context.colorScheme.primary,
                      ),
                      label: Text(
                        context.messages.dailyOsTodayButton,
                        style: context.textTheme.labelMedium?.copyWith(
                          color: context.colorScheme.primary,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingSmall,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDayName(BuildContext context, DateTime date) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat('EEEE', locale).format(date);
  }

  String _formatDate(BuildContext context, DateTime date) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.yMMMMd(locale).format(date);
  }

  bool _isToday(DateTime date) {
    return date.dayAtMidnight == DateTime.now().dayAtMidnight;
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

/// Chip showing the day's label/intent.
class _DayLabelChip extends StatelessWidget {
  const _DayLabelChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMedium,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: context.colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: context.textTheme.labelMedium?.copyWith(
          color: context.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Status indicator showing budget health.
class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.stats});

  final DayBudgetStats stats;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = _getStatusDetails(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingMedium,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: context.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color, String) _getStatusDetails(BuildContext context) {
    if (stats.isOverBudget) {
      return (
        MdiIcons.alertCircle,
        context.colorScheme.error,
        context.messages.dailyOsOverBudget,
      );
    }

    final remaining = stats.totalRemaining;
    if (remaining.inMinutes <= 15 && remaining.inMinutes > 0) {
      return (
        MdiIcons.clockAlert,
        Colors.orange,
        context.messages.dailyOsNearLimit,
      );
    }

    if (stats.progressFraction >= 0.8) {
      return (
        MdiIcons.checkCircle,
        Colors.green,
        context.messages.dailyOsOnTrack,
      );
    }

    return (
      MdiIcons.clockOutline,
      context.colorScheme.onSurfaceVariant,
      context.messages
          .dailyOsTimeLeft(_formatDuration(context, stats.totalRemaining)),
    );
  }

  String _formatDuration(BuildContext context, Duration duration) {
    if (duration.inHours > 0) {
      final hours = duration.inHours;
      final mins = duration.inMinutes % 60;
      if (mins == 0) return context.messages.dailyOsDurationHours(hours);
      return context.messages.dailyOsDurationHoursMinutes(hours, mins);
    }
    return context.messages.dailyOsDurationMinutes(duration.inMinutes);
  }
}
