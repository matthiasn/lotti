import 'package:flutter/material.dart';
import 'package:graphic/graphic.dart';
import 'package:lotti/features/daily_os/state/time_history_header_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/color.dart';

/// Data item for the stream chart, representing one category's time for one day.
class StreamChartItem {
  StreamChartItem({
    required this.x,
    required this.categoryId,
    required this.minutes,
  });

  /// X-position in days, where each whole number is a midnight divider.
  /// Noon for a day should be at index + 0.5.
  final double x;
  final String categoryId;
  final int minutes;
}

/// Stream chart widget using the graphic library.
///
/// Displays a symmetric (mirrored) stacked area chart showing time by category
/// for a range of days. Updates when the visible date range changes.
class TimeHistoryStreamChart extends StatelessWidget {
  const TimeHistoryStreamChart({
    required this.days,
    this.height = 60,
    this.width,
    this.verticalScale = 1.0,
    super.key,
  });

  /// Set to true in tests to skip rendering the Chart widget
  /// (which has internal timers that cause test failures).
  static bool testMode = false;

  /// All available day summaries (may be more than visible range).
  final List<DayTimeSummary> days;

  /// Chart height in pixels.
  final double height;

  /// Chart width in pixels. If null, uses available width.
  final double? width;

  /// Vertical scale factor for visual emphasis (layout height is unchanged).
  final double verticalScale;

  @override
  Widget build(BuildContext context) {
    // In test mode, skip rendering the Chart widget to avoid timer issues
    if (testMode) {
      return SizedBox(height: height, width: width);
    }

    // Guard against empty or invalid data
    if (days.length < 2 || width == null || width! <= 0) {
      return SizedBox(height: height, width: width);
    }

    // Transform days data into chart items and validate
    final chartData = _buildChartData();
    if (chartData.isEmpty) {
      return SizedBox(height: height, width: width);
    }

    return SizedBox(
      height: height,
      width: width,
      child: ClipRect(
        child: Transform.scale(
          scaleY: verticalScale,
          child: Chart(
            data: chartData,
            variables: {
              'x': Variable(
                accessor: (StreamChartItem item) => item.x,
                scale: LinearScale(
                  min: 0,
                  max: days.length.toDouble(),
                ),
              ),
              'value': Variable(
                accessor: (StreamChartItem item) => item.minutes,
                scale: LinearScale(
                  // Fixed +/- 24 hours to keep visual scale comparable over time.
                  min: -1440,
                  max: 1440,
                ),
              ),
              'categoryId': Variable(
                accessor: (StreamChartItem item) => item.categoryId,
              ),
            },
            marks: [
              AreaMark(
                position: Varset('x') * Varset('value') / Varset('categoryId'),
                shape: ShapeEncode(
                  value: BasicAreaShape(smooth: true),
                ),
                color: ColorEncode(
                  encoder: (data) {
                    final categoryId = data['categoryId'] as String;
                    final categoryDefinition = getIt<EntitiesCacheService>()
                        .getCategoryById(categoryId);
                    return colorFromCssHex(
                      categoryDefinition?.color,
                      substitute: Colors.grey,
                    );
                  },
                ),
                modifiers: [
                  StackModifier(),
                  SymmetricModifier(),
                ],
              ),
            ],
            axes: const [],
            padding: (_) => EdgeInsets.zero,
          ),
        ),
      ),
    );
  }

  /// Build chart data from day summaries.
  ///
  /// Creates a consistent data structure where every day has the same
  /// categories in the same order. This is required for SymmetricModifier
  /// to work correctly.
  List<StreamChartItem> _buildChartData() {
    final items = <StreamChartItem>[];
    final cache = getIt<EntitiesCacheService>();
    final categoryOrder = cache.sortedCategories.map((c) => c.id).toList();

    // Check if any day has uncategorized time - if so, include it for all days
    final hasUncategorized = days.any(
      (day) =>
          (day.durationByCategoryId[null] ?? Duration.zero) > Duration.zero,
    );

    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      // Map newest->oldest list to oldest->newest x axis.
      final dayIndex = (days.length - 1 - i).toDouble();
      final x = dayIndex + 0.5; // Noon between dividers.

      // Add an item for each category (even if 0 minutes, for continuity)
      for (final categoryId in categoryOrder) {
        final duration = day.durationByCategoryId[categoryId] ?? Duration.zero;
        items.add(
          StreamChartItem(
            x: x,
            categoryId: categoryId,
            minutes: duration.inMinutes,
          ),
        );
      }

      // Include uncategorized for ALL days if ANY day has it (consistency)
      if (hasUncategorized) {
        final uncategorizedDuration =
            day.durationByCategoryId[null] ?? Duration.zero;
        items.add(
          StreamChartItem(
            x: x,
            categoryId: '__uncategorized__',
            minutes: uncategorizedDuration.inMinutes,
          ),
        );
      }
    }

    return items;
  }
}
