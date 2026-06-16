import 'dart:core';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/charts/utils.dart';

/// Daily bar chart over a date range. Buckets [data] by day and fills every
/// missing day in `[rangeStart, rangeEnd]` with a zero bar so the time axis is
/// continuous, derives a "nice" zero-based value axis, and sizes the bars to the
/// chart's actual (not screen) width via [LayoutBuilder] so the row fits the
/// card exactly — important in the narrow desktop detail pane, where fl_chart
/// bars don't clip. Bar colour comes from [colorByValue]; tooltips show the
/// value (formatted as h:mm when [valueInHours]) plus the date.
class TimeSeriesBarChart extends StatelessWidget {
  const TimeSeriesBarChart({
    required this.data,
    required this.rangeStart,
    required this.rangeEnd,
    required this.colorByValue,
    this.unit = '',
    this.valueInHours = false,
    super.key,
  });

  final List<Observation> data;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final String unit;
  final bool valueInHours;

  final ColorByValue colorByValue;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final inRange = daysInRange(rangeStart: rangeStart, rangeEnd: rangeEnd);

    final byDay = <String, Observation>{};
    for (final observation in data) {
      final day = observation.dateTime.ymd;
      byDay[day] = observation;
    }

    final dataWithEmptyDays = inRange.map((day) {
      final observation = byDay[day] ?? Observation(DateTime.parse(day), 0);
      return observation;
    });

    final maxVal = dataWithEmptyDays.fold<double>(
      0,
      (m, o) => max(m, o.value.toDouble()),
    );
    final axis = niceAxis(0, maxVal, zeroBased: true);
    final barRadius = Radius.circular(tokens.radii.xs);
    final observations = dataWithEmptyDays
        .sortedBy((observation) => observation.dateTime)
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        top: tokens.spacing.step5,
        right: tokens.spacing.step2,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Size the bars (and the gaps) from the chart's *actual* width — not
          // the full screen width — so the group row fits the plot exactly and
          // never spills past the card. In the desktop detail pane the chart is
          // far narrower than the window, and fl_chart bar charts don't clip,
          // so the fit has to be exact. The gap collapses to zero once the bars
          // get dense (e.g. a year of daily bars).
          final count = observations.length;
          final plotWidth = constraints.maxWidth - kChartLeftAxisWidth;
          final groupsSpace = count > 1 && plotWidth / count > 4 ? 1 : 0;
          final rawWidth = count == 0
              ? plotWidth
              : (plotWidth - groupsSpace * (count + 1)) / count;
          // Never hand fl_chart a negative width: a tiny or transient
          // constraint can make plotWidth smaller than the reserved axis,
          // which would assert.
          final barsWidth = max<double>(rawWidth, 0);

          final barGroups = observations.map((observation) {
            return BarChartGroupData(
              x: observation.dateTime.millisecondsSinceEpoch,
              barRods: [
                BarChartRodData(
                  toY: observation.value.toDouble(),
                  borderRadius: BorderRadius.only(
                    topLeft: barRadius,
                    topRight: barRadius,
                  ),
                  color: colorByValue(observation),
                  width: barsWidth,
                ),
              ],
            );
          }).toList();

          return BarChart(
            BarChartData(
              groupsSpace: groupsSpace.toDouble(),
              alignment: BarChartAlignment.center,
              minY: 0,
              maxY: axis.max,
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: axis.interval,
                getDrawingHorizontalLine: (value) => chartGridLine(context),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  tooltipMargin: isMobile ? 24 : 16,
                  tooltipPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  getTooltipColor: (_) => tokens.colors.background.level03,
                  tooltipBorderRadius: BorderRadius.circular(8),
                  getTooltipItem: (groupData, timestamp, rodData, foo) {
                    final formatted = valueInHours
                        ? hoursToHhMm(rodData.toY)
                        : NumberFormat('#,###.##').format(rodData.toY);
                    return BarTooltipItem(
                      '$formatted $unit\n'
                      '${chartDateFormatterYMD(groupData.x)}',
                      chartTooltipStyleBold.copyWith(
                        color: tokens.colors.text.highEmphasis,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                bottomTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: leftTitleWidgets,
                    reservedSize: kChartLeftAxisWidth,
                    interval: axis.interval,
                    // Suppress the bottom tick (it overlaps the date axis) but
                    // keep the top tick so the value scale's ceiling shows.
                    minIncluded: false,
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: tokens.colors.decorative.level01),
              ),
              barGroups: barGroups,
            ),
          );
        },
      ),
    );
  }
}
