import 'package:flutter/material.dart';
import 'package:graphic/graphic.dart';
import 'package:lotti/features/daily_os/state/time_history_header_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/color.dart';

/// Data item for the stream chart, representing one category's time for one day.
class StreamChartItem {
  StreamChartItem({
    required this.date,
    required this.categoryId,
    required this.minutes,
  });

  final DateTime date;
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
    required this.visibleStartDate,
    required this.visibleEndDate,
    this.height = 60,
    this.width,
    super.key,
  });

  /// Set to true in tests to skip rendering the Chart widget
  /// (which has internal timers that cause test failures).
  static bool testMode = false;

  /// All available day summaries (may be more than visible range).
  final List<DayTimeSummary> days;

  /// Start of the visible date range (oldest visible day).
  final DateTime visibleStartDate;

  /// End of the visible date range (newest visible day, usually today or selected).
  final DateTime visibleEndDate;

  /// Chart height in pixels.
  final double height;

  /// Chart width in pixels. If null, uses available width.
  final double? width;

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
      child: Chart(
        data: chartData,
        variables: {
          'date': Variable(
            accessor: (StreamChartItem item) => item.date,
            scale: TimeScale(
              tickCount: 0, // No axis labels
              // Normalize to midnight boundaries so noon sits between dividers.
              min: DateTime(
                visibleStartDate.year,
                visibleStartDate.month,
                visibleStartDate.day,
              ),
              max: DateTime(
                visibleEndDate.year,
                visibleEndDate.month,
                visibleEndDate.day,
              ).add(const Duration(days: 1)),
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
            position: Varset('date') * Varset('value') / Varset('categoryId'),
            shape: ShapeEncode(
              value: BasicAreaShape(smooth: true),
            ),
            color: ColorEncode(
              encoder: (data) {
                final categoryId = data['categoryId'] as String;
                final categoryDefinition =
                    getIt<EntitiesCacheService>().getCategoryById(categoryId);
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

    for (final day in days) {
      // Normalize date to noon to align with day segment centers.
      final normalizedDate =
          DateTime(day.day.year, day.day.month, day.day.day, 12);

      // Add an item for each category (even if 0 minutes, for continuity)
      for (final categoryId in categoryOrder) {
        final duration = day.durationByCategoryId[categoryId] ?? Duration.zero;
        items.add(
          StreamChartItem(
            date: normalizedDate,
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
            date: normalizedDate,
            categoryId: '__uncategorized__',
            minutes: uncategorizedDuration.inMinutes,
          ),
        );
      }
    }

    return items;
  }
}
