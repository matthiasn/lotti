import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/state/time_history_header_controller.dart';
import 'package:lotti/features/daily_os/state/unified_daily_os_data_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_history_header/date_label_row.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_history_header/day_segment.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/date_utils_extension.dart';

/// Header widget for the Daily OS view with horizontal day navigation.
///
/// Displays a horizontally scrollable list of day segments with:
/// - Tap-to-select navigation between days
/// - Sticky month label showing the currently visible month(s)
/// - Selected day highlighting with primary color border
/// - Infinite scroll to load more history (older days)
/// - Today button for quick navigation back to current day
/// - Day label chip and budget status indicator for the selected day
class TimeHistoryHeader extends ConsumerStatefulWidget {
  const TimeHistoryHeader({super.key});

  static const double headerHeight = 120;
  static const double chartAreaHeight = 76;
  // 44 - 1 to account for 1px bottom border
  static const double dateLabelRowHeight = 43;

  @override
  ConsumerState<TimeHistoryHeader> createState() => _TimeHistoryHeaderState();
}

class _TimeHistoryHeaderState extends ConsumerState<TimeHistoryHeader> {
  late ScrollController _scrollController;

  // Track visible month(s) for the sticky header
  String _visibleMonthLabel = '';

  // Track prefetched dates (date-based instead of index-based to handle list changes)
  final Set<DateTime> _prefetchedDates = {};

  // Track visible indices for throttling month label updates
  int _lastVisibleStart = -1;
  int _lastVisibleEnd = -1;

  // Number of days to prefetch in each direction beyond visible
  static const int _prefetchBuffer = 5;

  // Margin for invalidation (2x buffer to avoid thrashing)
  static const int _invalidateMargin = _prefetchBuffer * 2;

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
    final firstVisibleIndex = (scrollOffset / daySegmentWidth).floor();
    final lastVisibleIndex =
        ((scrollOffset + viewportWidth) / daySegmentWidth).ceil();

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
  /// Uses date-based tracking instead of index-based to handle list changes safely.
  void _updatePrefetchWindow() {
    final historyData = ref.read(timeHistoryHeaderControllerProvider).value;
    if (historyData == null || historyData.days.isEmpty) return;

    final (visibleStart, visibleEnd) = _getVisibleIndices(historyData);

    // Calculate prefetch window: visible + buffer in each direction
    final prefetchStart =
        (visibleStart - _prefetchBuffer).clamp(0, historyData.days.length - 1);
    final prefetchEnd =
        (visibleEnd + _prefetchBuffer).clamp(0, historyData.days.length - 1);

    // Collect dates in the current prefetch window
    final currentWindowDates = <DateTime>{};
    for (var i = prefetchStart; i <= prefetchEnd; i++) {
      currentWindowDates.add(historyData.days[i].day.dayAtMidnight);
    }

    // Collect dates in the extended window (for invalidation check)
    final extendedStart = (visibleStart - _invalidateMargin)
        .clamp(0, historyData.days.length - 1);
    final extendedEnd =
        (visibleEnd + _invalidateMargin).clamp(0, historyData.days.length - 1);
    final extendedWindowDates = <DateTime>{};
    for (var i = extendedStart; i <= extendedEnd; i++) {
      extendedWindowDates.add(historyData.days[i].day.dayAtMidnight);
    }

    // Invalidate providers for dates that are no longer in the extended window
    final datesToInvalidate =
        _prefetchedDates.difference(extendedWindowDates).toList();
    for (final date in datesToInvalidate) {
      ref
        ..invalidate(unifiedDailyOsDataControllerProvider(date: date))
        ..invalidate(dayBudgetStatsProvider(date: date));
      _prefetchedDates.remove(date);
    }

    // Prefetch new days in the window that haven't been prefetched yet
    for (final date in currentWindowDates) {
      if (!_prefetchedDates.contains(date)) {
        _prefetchedDates.add(date);
        // Fire-and-forget: just trigger the provider, don't await
        ref.read(unifiedDailyOsDataControllerProvider(date: date));
      }
    }
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
            child: DateLabelRow(
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
                itemExtent: daySegmentWidth, // Fixed width
                itemBuilder: (context, index) {
                  if (data.isLoadingMore && index == data.days.length) {
                    return _buildLoadingIndicator();
                  }

                  final daySummary = data.days[index];
                  final isSelected = daySummary.day.dayAtMidnight ==
                      selectedDate.dayAtMidnight;

                  return DaySegment(
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
            itemExtent: daySegmentWidth,
            itemBuilder: (context, index) {
              return Container(
                width: daySegmentWidth,
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
      width: daySegmentWidth,
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
