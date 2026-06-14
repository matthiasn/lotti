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

    final rangeInDays = rangeEnd.difference(rangeStart).inDays;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final barsWidth =
        (screenWidth - 150 - rangeInDays - screenWidth * 0.1) / rangeInDays;

    final maxVal = dataWithEmptyDays.fold<double>(
      0,
      (m, o) => max(m, o.value.toDouble()),
    );
    final axis = niceAxis(0, maxVal, zeroBased: true);
    final barRadius = Radius.circular(tokens.radii.xs);

    final barGroups = dataWithEmptyDays
        .sortedBy((observation) => observation.dateTime)
        .map((observation) {
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
                width: max(barsWidth, 1),
              ),
            ],
          );
        })
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        top: tokens.spacing.step5,
        right: tokens.spacing.step2,
      ),
      child: BarChart(
        BarChartData(
          groupsSpace: 5,
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
                // Suppress the bottom tick (it overlaps the date axis) but keep
                // the default top tick so the value scale's ceiling is labelled.
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
        //duration: Duration.zero,
      ),
    );
  }
}
