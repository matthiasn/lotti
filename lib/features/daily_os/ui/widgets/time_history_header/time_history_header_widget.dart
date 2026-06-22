import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/time_history_header_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_history_header/date_label_row.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_history_header/day_segment.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_history_header/time_history_stream_chart.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/date_utils_extension.dart';

part 'time_history_header_skeleton.dart';

/// Header widget for the Daily OS view with horizontal day navigation.
///
/// Premium layout structure (top to bottom):
/// 1. Month label row (16px) - sticky month indicator
/// 2. Day selector row (56px) - weekday abbreviation + day number
/// 3. Stream chart row (40px) - time distribution visualization
/// 4. Date label row (44px) - full date, status, actions
class TimeHistoryHeader extends ConsumerStatefulWidget {
  const TimeHistoryHeader({super.key});

  /// Height of the sticky month-label row at the top.
  static const double monthLabelHeight = 16;

  /// Height of the combined day-selector strip plus the stream chart stacked
  /// behind it.
  static const double daySelectorWithChartHeight = 90;

  /// Height of the bottom row holding the full date, day label, and actions.
  static const double dateLabelRowHeight = 26;

  /// Total fixed header height; the parent reserves exactly this much space.
  static const double headerHeight =
      monthLabelHeight + daySelectorWithChartHeight + dateLabelRowHeight;

  /// Chart height within the combined day selector area.
  static const double chartHeight = 70;

  /// Offset from top where chart starts (below day labels).
  static const double chartTopOffset = 32;

  /// Chart opacity to reduce visual dominance behind day selectors.
  static const double chartOpacity = 0.9;

  /// Dark mode header background color.
  static const Color darkHeaderBackground = Color(0xFF1A1A1A);

  @override
  ConsumerState<TimeHistoryHeader> createState() => _TimeHistoryHeaderState();
}

class _TimeHistoryHeaderState extends ConsumerState<TimeHistoryHeader> {
  late ScrollController _scrollController;

  // Track visible month(s) for the sticky header
  String _visibleMonthLabel = '';

  // Track visible indices for throttling month label updates
  int _lastVisibleStart = -1;
  int _lastVisibleEnd = -1;

  // Whether we've set the initial scroll position to center on today
  bool _hasSetInitialScroll = false;

  // Number of days to render beyond visible range for smoother transitions
  static const int _chartBuffer = 2;

  // Memoization for the scroll-driven chart layer: the heavy stream chart is
  // rebuilt only when the rendered day window (chartStart..chartEnd) or the
  // underlying data changes — not on every scroll frame. See [_buildChartLayer].
  Widget? _cachedChart;
  int? _cachedChartStart;
  int? _cachedChartEnd;
  TimeHistoryData? _cachedChartData;
  double _cachedChartWidth = 0;

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

    // Trigger load-more-past at 80% scroll threshold (scrolling left/older)
    if (position.pixels > position.maxScrollExtent * 0.8) {
      ref.read(timeHistoryHeaderControllerProvider.notifier).loadMoreDays();
    }

    // Update visible month label
    _updateVisibleMonth();
  }

  /// Calculate visible day indices from scroll metrics.
  (int startIdx, int endIdx) _getVisibleIndicesForMetrics(
    TimeHistoryData data,
    double scrollOffset,
    double viewportWidth,
  ) {
    if (data.days.isEmpty) {
      return (0, 0);
    }

    // Calculate which day indices are visible
    // Since reverse: true, index 0 is at the right edge
    // scrollOffset increases as we scroll left (toward older days)
    final firstVisibleIndex = (scrollOffset / daySegmentWidth).floor();
    final lastVisibleIndex = ((scrollOffset + viewportWidth) / daySegmentWidth)
        .ceil();

    // Clamp to valid range
    final startIdx = firstVisibleIndex.clamp(0, data.days.length - 1);
    final endIdx = (lastVisibleIndex - 1).clamp(0, data.days.length - 1);

    return (startIdx, endIdx);
  }

  /// Calculate visible day indices from scroll position.
  (int startIdx, int endIdx) _getVisibleIndices(TimeHistoryData data) {
    if (!_scrollController.hasClients || data.days.isEmpty) {
      return (0, 0);
    }

    final scrollOffset = _scrollController.offset;
    final viewportWidth = _scrollController.position.viewportDimension;

    return _getVisibleIndicesForMetrics(data, scrollOffset, viewportWidth);
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

  /// Select a date immediately (no waiting for prefetch).
  void _selectDate(DateTime date) {
    ref.read(dailyOsSelectedDateProvider.notifier).selectDate(date);
  }

  /// Navigate back to today with scroll animation.
  void _onTodayPressed() {
    final today = clock.now().dayAtMidnight;

    // Navigate to today immediately
    ref.read(dailyOsSelectedDateProvider.notifier).goToToday();

    // Check if today is in the data window, if not reset
    final data = ref.read(timeHistoryHeaderControllerProvider).value;
    if (data != null) {
      final todayInWindow = data.days.any(
        (day) => day.day.dayAtMidnight == today,
      );
      if (!todayInWindow) {
        ref.read(timeHistoryHeaderControllerProvider.notifier).resetToToday();
      } else if (_scrollController.hasClients) {
        // Animate scroll to center today in the viewport
        final todayNoon = clock.now().dayAtNoon;
        final todayIndex = data.days.indexWhere((d) => d.day == todayNoon);
        if (todayIndex >= 0) {
          final viewportWidth = _scrollController.position.viewportDimension;
          final viewportDays = viewportWidth / daySegmentWidth;
          final targetOffset =
              (todayIndex - viewportDays / 2 + 0.5) * daySegmentWidth;
          _scrollController.animateTo(
            targetOffset.clamp(0, double.infinity),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    }
  }

  /// Center the scroll view on today when data first loads.
  void _centerOnTodayIfNeeded(TimeHistoryData data) {
    if (_hasSetInitialScroll) return;
    if (!_scrollController.hasClients) return;

    // Find today's index in the days list (newest-to-oldest order)
    final todayNoon = clock.now().dayAtNoon;
    final todayIndex = data.days.indexWhere((d) => d.day == todayNoon);
    if (todayIndex < 0) return;

    // Calculate scroll offset to center today in the viewport
    final viewportWidth = _scrollController.position.viewportDimension;
    final viewportDays = viewportWidth / daySegmentWidth;
    final targetOffset =
        (todayIndex - viewportDays / 2 + 0.5) * daySegmentWidth;

    // Jump immediately (no animation for initial positioning)
    _scrollController.jumpTo(targetOffset.clamp(0, double.infinity));

    // Only mark as done after successful centering
    _hasSetInitialScroll = true;
  }

  @override
  Widget build(BuildContext context) {
    final historyDataAsync = ref.watch(timeHistoryHeaderControllerProvider);
    final selectedDate = ref.watch(dailyOsSelectedDateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Center on today and update the month label after data loads
    historyDataAsync.whenData((data) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _centerOnTodayIfNeeded(data);
          _updateVisibleMonth();
        }
      });
    });

    final headerBackground = isDark
        ? TimeHistoryHeader.darkHeaderBackground
        : context.colorScheme.surfaceContainerHighest;

    return Container(
      height: TimeHistoryHeader.headerHeight,
      decoration: BoxDecoration(
        color: headerBackground,
      ),
      child: Column(
        children: [
          // Month label row
          _buildMonthLabelRow(context),

          // Day selector + chart (stacked, chart behind)
          SizedBox(
            height: TimeHistoryHeader.daySelectorWithChartHeight,
            child: historyDataAsync.when(
              data: (data) => _buildDaySelectorWithChart(data, selectedDate),
              loading: _buildDaySelectorSkeleton,
              error: (_, _) => _buildDaySelectorSkeleton(),
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

  Widget _buildMonthLabelRow(BuildContext context) {
    return SizedBox(
      height: TimeHistoryHeader.monthLabelHeight,
      child: Center(
        child: Text(
          _visibleMonthLabel,
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildDaySelectorWithChart(
    TimeHistoryData data,
    DateTime selectedDate,
  ) {
    final itemCount = data.days.length + (data.isLoadingMore ? 1 : 0);

    return Stack(
      children: [
        // Chart layer (behind day selector, positioned lower)
        if (data.days.length >= 2)
          Positioned(
            left: 0,
            right: 0,
            top: TimeHistoryHeader.chartTopOffset,
            height: TimeHistoryHeader.chartHeight,
            child: _buildChartLayer(data, TimeHistoryHeader.chartHeight),
          ),

        // Day selector layer (on top)
        Positioned.fill(
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            reverse: true,
            itemCount: itemCount,
            itemExtent: daySegmentWidth,
            itemBuilder: (context, index) {
              if (data.isLoadingMore && index == data.days.length) {
                return _buildLoadingIndicator();
              }

              final daySummary = data.days[index];
              final isSelected =
                  daySummary.day.dayAtMidnight == selectedDate.dayAtMidnight;

              return DaySegment(
                daySummary: daySummary,
                isSelected: isSelected,
                onTap: () => _selectDate(daySummary.day),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChartLayer(TimeHistoryData data, double chartHeight) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: _scrollController,
          builder: (context, _) {
            final scrollOffset = _scrollController.hasClients
                ? _scrollController.offset
                : 0.0;
            final hasViewport =
                _scrollController.hasClients &&
                _scrollController.position.hasViewportDimension;
            final viewportWidth = hasViewport
                ? _scrollController.position.viewportDimension
                : constraints.maxWidth;

            final (visibleStart, visibleEnd) = _getVisibleIndicesForMetrics(
              data,
              scrollOffset,
              viewportWidth,
            );

            final chartStart = (visibleStart - _chartBuffer).clamp(
              0,
              data.days.length - 1,
            );
            final chartEnd = (visibleEnd + _chartBuffer).clamp(
              0,
              data.days.length - 1,
            );

            if (chartEnd < chartStart) {
              return const SizedBox.shrink();
            }

            // Rebuild the heavy stream chart ONLY when the rendered day window
            // changes (a coarse step as you scroll past a day boundary) or the
            // data changes; a smooth scroll *within* a window reuses the cached
            // chart and only re-applies the Transform.translate below. Without
            // this the chart (an O(days × categories) graphic rebuild) was
            // reconstructed on every scroll frame. The RepaintBoundary isolates
            // its painting from the rest of the header.
            if (_cachedChart == null ||
                chartStart != _cachedChartStart ||
                chartEnd != _cachedChartEnd ||
                !identical(data, _cachedChartData)) {
              final chartDays = data.days.sublist(chartStart, chartEnd + 1);
              if (chartDays.length < 2) {
                _cachedChart = null;
                return const SizedBox.shrink();
              }
              final width = chartDays.length * daySegmentWidth;
              if (width <= 0) {
                _cachedChart = null;
                return const SizedBox.shrink();
              }
              _cachedChartStart = chartStart;
              _cachedChartEnd = chartEnd;
              _cachedChartData = data;
              _cachedChartWidth = width;
              _cachedChart = RepaintBoundary(
                child: Opacity(
                  opacity: TimeHistoryHeader.chartOpacity,
                  child: TimeHistoryStreamChart(
                    days: chartDays,
                    height: chartHeight,
                    maxDailyTotal: data.maxDailyTotal,
                    width: width,
                  ),
                ),
              );
            }

            final chartWidth = _cachedChartWidth;

            final chartRightEdge =
                constraints.maxWidth +
                scrollOffset -
                (chartStart * daySegmentWidth);

            // Calculate clip boundary at tomorrow noon (horizontal only)
            final tomorrow = clock.now().dayAtNoon.add(
              const Duration(days: 1),
            );
            final tomorrowIndex = data.days.indexWhere(
              (d) => d.day == tomorrow,
            );
            final clipRightX = tomorrowIndex >= 0
                ? constraints.maxWidth +
                      scrollOffset -
                      (tomorrowIndex * daySegmentWidth) -
                      (daySegmentWidth / 2)
                : double.infinity;

            final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
            final alignedRight =
                (chartRightEdge * devicePixelRatio).roundToDouble() /
                devicePixelRatio;
            final alignedLeft = alignedRight - chartWidth;

            return ClipRect(
              clipper: _HorizontalClipper(clipRightX: clipRightX),
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                maxWidth: chartWidth,
                minWidth: chartWidth,
                child: Transform.translate(
                  offset: Offset(alignedLeft, 0),
                  child: _cachedChart,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
