import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/state/time_history_header_controller.dart';
import 'package:lotti/features/daily_os/state/unified_daily_os_data_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// Header widget for the Daily OS view with horizontal day navigation.
///
/// Shows a horizontally scrollable list of days with time history data,
/// optional day label, and status indicator. Supports swipe gestures
/// for day navigation and infinite scroll for loading more history.
class TimeHistoryHeader extends ConsumerStatefulWidget {
  const TimeHistoryHeader({super.key});

  static const double headerHeight = 120;
  static const double chartAreaHeight = 76;
  // 44 - 1 to account for 1px bottom border
  static const double dateLabelRowHeight = 43;
  static const double daySegmentWidth = 56;

  @override
  ConsumerState<TimeHistoryHeader> createState() => _TimeHistoryHeaderState();
}

class _TimeHistoryHeaderState extends ConsumerState<TimeHistoryHeader> {
  late ScrollController _scrollController;

  // Track visible month(s) for the sticky header
  String _visibleMonthLabel = '';

  // Track the current prefetch window to avoid redundant work
  int _lastPrefetchStart = -1;
  int _lastPrefetchEnd = -1;

  // Track visible indices for throttling month label updates
  int _lastVisibleStart = -1;
  int _lastVisibleEnd = -1;

  // Number of days to prefetch in each direction beyond visible
  static const int _prefetchBuffer = 5;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update month label when scroll position changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateVisibleMonth();
    });
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // Trigger load-more at 80% scroll threshold
    if (position.pixels > position.maxScrollExtent * 0.8) {
      ref.read(timeHistoryHeaderControllerProvider.notifier).loadMoreDays();
    }
    // Update visible month label and prefetch window
    _updateVisibleMonth();
    _updatePrefetchWindow();
  }

  /// Calculate visible day indices from scroll position.
  (int startIdx, int endIdx) _getVisibleIndices(TimeHistoryData data) {
    if (!_scrollController.hasClients || data.days.isEmpty) {
      return (0, 0);
    }

    final scrollOffset = _scrollController.offset;
    final viewportWidth = _scrollController.position.viewportDimension;

    // Calculate which day indices are visible
    // Since reverse: true, index 0 is at the right edge
    // scrollOffset increases as we scroll left (toward older days)
    final firstVisibleIndex =
        (scrollOffset / TimeHistoryHeader.daySegmentWidth).floor();
    final lastVisibleIndex =
        ((scrollOffset + viewportWidth) / TimeHistoryHeader.daySegmentWidth)
            .ceil();

    // Clamp to valid range
    final startIdx = firstVisibleIndex.clamp(0, data.days.length - 1);
    final endIdx = (lastVisibleIndex - 1).clamp(0, data.days.length - 1);

    return (startIdx, endIdx);
  }

  /// Update the visible month label based on scroll position.
  ///
  /// Throttled to only recompute when visible indices change.
  void _updateVisibleMonth() {
    final historyData = ref.read(timeHistoryHeaderControllerProvider).value;
    if (historyData == null || historyData.days.isEmpty) return;
    if (!_scrollController.hasClients) return;

    final (startIdx, endIdx) = _getVisibleIndices(historyData);

    // Throttle: skip if visible indices haven't changed
    if (startIdx == _lastVisibleStart && endIdx == _lastVisibleEnd) {
      return;
    }
    _lastVisibleStart = startIdx;
    _lastVisibleEnd = endIdx;

    // Collect unique month/year combinations in visible range
    // Using a map to preserve order and track year
    final visibleMonthYears = <String, DateTime>{};
    for (var i = startIdx; i <= endIdx; i++) {
      final day = historyData.days[i].day;
      final key = '${day.year}-${day.month}';
      visibleMonthYears.putIfAbsent(key, () => day);
    }

    // Sort by date (oldest first) and format
    final sortedDates = visibleMonthYears.values.toList()
      ..sort((a, b) => a.compareTo(b));

    // Use locale from context for proper localization
    final locale = Localizations.localeOf(context).toString();

    // Format the label
    String newLabel;
    if (sortedDates.length == 1) {
      // Single month: "Jan 2026"
      newLabel = DateFormat('MMM yyyy', locale).format(sortedDates.first);
    } else {
      // Multiple months: "Dec 2025 | Jan 2026" or "Dec | Jan 2026" if same year
      final first = sortedDates.first;
      final last = sortedDates.last;
      if (first.year == last.year) {
        // Same year: "Dec | Jan 2026"
        newLabel =
            '${DateFormat.MMM(locale).format(first)} | ${DateFormat('MMM yyyy', locale).format(last)}';
      } else {
        // Different years: "Dec 2025 | Jan 2026"
        newLabel =
            '${DateFormat('MMM yyyy', locale).format(first)} | ${DateFormat('MMM yyyy', locale).format(last)}';
      }
    }

    if (_visibleMonthLabel != newLabel) {
      setState(() {
        _visibleMonthLabel = newLabel;
      });
    }
  }

  /// Update the prefetch window based on visible indices.
  ///
  /// Only prefetches visible days + buffer in each direction.
  /// Invalidates providers that have scrolled far out of view to free memory.
  void _updatePrefetchWindow() {
    final historyData = ref.read(timeHistoryHeaderControllerProvider).value;
    if (historyData == null || historyData.days.isEmpty) return;

    final (visibleStart, visibleEnd) = _getVisibleIndices(historyData);

    // Calculate prefetch window: visible + buffer in each direction
    final prefetchStart =
        (visibleStart - _prefetchBuffer).clamp(0, historyData.days.length - 1);
    final prefetchEnd =
        (visibleEnd + _prefetchBuffer).clamp(0, historyData.days.length - 1);

    // Skip if window hasn't changed significantly
    if (prefetchStart == _lastPrefetchStart &&
        prefetchEnd == _lastPrefetchEnd) {
      return;
    }

    // Invalidate providers that are now outside the extended window
    // Use a larger margin (2x buffer) before invalidating to avoid thrashing
    const invalidateMargin = _prefetchBuffer * 2;
    if (_lastPrefetchStart >= 0 && _lastPrefetchEnd >= 0) {
      for (var i = _lastPrefetchStart; i <= _lastPrefetchEnd; i++) {
        // Skip if still within extended window
        if (i >= prefetchStart - invalidateMargin &&
            i <= prefetchEnd + invalidateMargin) {
          continue;
        }
        // Invalidate this provider to free memory
        final day = historyData.days[i].day.dayAtMidnight;
        ref
          ..invalidate(unifiedDailyOsDataControllerProvider(date: day))
          ..invalidate(dayBudgetStatsProvider(date: day));
      }
    }

    // Prefetch new days in the window (fire-and-forget)
    for (var i = prefetchStart; i <= prefetchEnd; i++) {
      // Skip if was in previous window
      if (i >= _lastPrefetchStart && i <= _lastPrefetchEnd) {
        continue;
      }
      final day = historyData.days[i].day.dayAtMidnight;
      // Fire-and-forget: just trigger the provider, don't await
      ref.read(unifiedDailyOsDataControllerProvider(date: day));
    }

    _lastPrefetchStart = prefetchStart;
    _lastPrefetchEnd = prefetchEnd;
  }

  /// Select a date immediately (no waiting for prefetch).
  ///
  /// The provider will show loading state if data isn't cached yet,
  /// but this avoids race conditions and failures blocking selection.
  void _selectDate(DateTime date) {
    ref.read(dailyOsSelectedDateProvider.notifier).selectDate(date);
  }

  /// Navigate back to today with scroll animation.
  void _onTodayPressed() {
    final today = clock.now().dayAtMidnight;

    // Navigate to today immediately
    ref.read(dailyOsSelectedDateProvider.notifier).goToToday();

    // Animate scroll to today's position (offset 0, since reverse: true)
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    // Check if today is in the data window, if not reset
    final data = ref.read(timeHistoryHeaderControllerProvider).value;
    if (data != null) {
      final todayInWindow =
          data.days.any((day) => day.day.dayAtMidnight == today);
      if (!todayInWindow) {
        ref.read(timeHistoryHeaderControllerProvider.notifier).resetToToday();
      }
    }

    // Prefetch today's data in background (fire-and-forget)
    ref.read(unifiedDailyOsDataControllerProvider(date: today));
  }

  @override
  Widget build(BuildContext context) {
    final historyDataAsync = ref.watch(timeHistoryHeaderControllerProvider);
    final selectedDate = ref.watch(dailyOsSelectedDateProvider);

    // Update prefetch window and month label after data loads
    historyDataAsync.whenData((data) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updatePrefetchWindow();
          _updateVisibleMonth();
        }
      });
    });

    return Container(
      height: TimeHistoryHeader.headerHeight,
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        children: [
          // Chart area with day segments
          SizedBox(
            height: TimeHistoryHeader.chartAreaHeight,
            child: historyDataAsync.when(
              data: (data) => _buildDayList(data, selectedDate),
              loading: _buildLoadingSkeleton,
              error: (_, __) => _buildLoadingSkeleton(),
            ),
          ),

          // Date label row
          SizedBox(
            height: TimeHistoryHeader.dateLabelRowHeight,
            child: _DateLabelRow(
              selectedDate: selectedDate,
              onTodayPressed: _onTodayPressed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayList(TimeHistoryData data, DateTime selectedDate) {
    final itemCount = data.days.length + (data.isLoadingMore ? 1 : 0);

    return Stack(
      children: [
        // Placeholder for CustomPaint (Phase 3)
        // Future: Time history chart will be drawn here

        // Day segments list with month labels
        Column(
          children: [
            // Sticky month label row
            SizedBox(
              height: 16,
              child: Center(
                child: Text(
                  _visibleMonthLabel,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            // Day segments
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                reverse: true, // Today at right edge
                itemCount: itemCount,
                itemExtent: TimeHistoryHeader.daySegmentWidth, // Fixed width
                itemBuilder: (context, index) {
                  if (data.isLoadingMore && index == data.days.length) {
                    return _buildLoadingIndicator();
                  }

                  final daySummary = data.days[index];
                  final isSelected = daySummary.day.dayAtMidnight ==
                      selectedDate.dayAtMidnight;

                  return _DaySegment(
                    daySummary: daySummary,
                    isSelected: isSelected,
                    onTap: () => _selectDate(daySummary.day),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingSkeleton() {
    return Column(
      children: [
        // Placeholder for month label
        const SizedBox(height: 16),
        // Skeleton day segments
        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            reverse: true,
            itemCount: 7,
            itemExtent: TimeHistoryHeader.daySegmentWidth,
            itemBuilder: (context, index) {
              return Container(
                width: TimeHistoryHeader.daySegmentWidth,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: context.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return SizedBox(
      width: TimeHistoryHeader.daySegmentWidth,
      child: Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: context.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// Individual day segment in the horizontal list.
class _DaySegment extends StatelessWidget {
  const _DaySegment({
    required this.daySummary,
    required this.isSelected,
    required this.onTap,
  });

  final DayTimeSummary daySummary;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final day = daySummary.day;

    return GestureDetector(
      onTap: onTap,
      child: Semantics(
        label: DateFormat.yMMMMd().format(day),
        button: true,
        selected: isSelected,
        child: Container(
          width: TimeHistoryHeader.daySegmentWidth,
          decoration: BoxDecoration(
            // Left border as day separator (midnight divider)
            border: Border(
              left: BorderSide(
                color:
                    context.colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            decoration: BoxDecoration(
              border: isSelected
                  ? Border.all(
                      color: context.colorScheme.primary,
                      width: 2,
                    )
                  : null,
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Day number
                Text(
                  day.day.toString(),
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: isSelected
                        ? context.colorScheme.primary
                        : context.colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Date label row at the bottom of the header.
class _DateLabelRow extends ConsumerWidget {
  const _DateLabelRow({
    required this.selectedDate,
    required this.onTodayPressed,
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
                child: _DayLabelChip(label: label),
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
                child: _StatusIndicator(stats: stats),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // Today button (if not viewing today)
          if (!_isToday(selectedDate))
            Padding(
              padding: const EdgeInsets.only(left: AppTheme.spacingSmall),
              child: _TodayButton(onPressed: onTodayPressed),
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
        syncPendingAccentColor,
        context.messages.dailyOsNearLimit,
      );
    }

    if (stats.progressFraction >= 0.8) {
      return (
        MdiIcons.checkCircle,
        successColor,
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

/// Button to navigate back to today.
class _TodayButton extends StatelessWidget {
  const _TodayButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
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
    );
  }
}
