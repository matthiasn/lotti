import 'dart:core';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/charts/time_series/utils.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:tinycolor2/tinycolor2.dart';

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

    final gridInterval = rangeInDays > 182
        ? 30
        : rangeInDays > 92
            ? 14
            : rangeInDays > 30
                ? 7
                : 1;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final barsWidth =
        (screenWidth - 150 - rangeInDays - screenWidth * 0.1) / rangeInDays;

    final barGroups = dataWithEmptyDays
        .sortedBy((observation) => observation.dateTime)
        .map((observation) {
      return BarChartGroupData(
        x: observation.dateTime.millisecondsSinceEpoch,
        barRods: [
          BarChartRodData(
            toY: observation.value.toDouble(),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(1),
              topRight: Radius.circular(1),
            ),
            color: colorByValue(observation),
            width: max(barsWidth, 1),
          ),
        ],
      );
    }).toList();

    Widget bottomTitleWidgets(
      double value,
      TitleMeta meta,
    ) {
      final ymd = DateTime.fromMillisecondsSinceEpoch(value.toInt());
      if (ymd.day == 1 ||
          (rangeInDays < 92 && ymd.day == 15) ||
          (rangeInDays < 30 && ymd.day == 8) ||
          (rangeInDays < 30 && ymd.day == 22)) {
        return SideTitleWidget(
          axisSide: meta.axisSide,
          child: ChartLabel(chartDateFormatterMmDd(value)),
        );
      }
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(
        top: 20,
        right: 20,
      ),
      child: BarChart(
        BarChartData(
          groupsSpace: 5,
          gridData: FlGridData(
            show: false,
            horizontalInterval: double.maxFinite,
            verticalInterval:
                Duration.millisecondsPerDay.toDouble() * gridInterval,
            getDrawingHorizontalLine: (value) => gridLine,
            getDrawingVerticalLine: (value) => gridLine,
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              tooltipMargin: isMobile ? 24 : 16,
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              getTooltipColor: (_) =>
                  Theme.of(context).primaryColor.desaturate(),
              tooltipRoundedRadius: 8,
              getTooltipItem: (groupData, timestamp, rodData, foo) {
                final formatted = valueInHours
                    ? hoursToHhMm(rodData.toY)
                    : NumberFormat('#,###').format(rodData.toY);
                return BarTooltipItem(
                  '$formatted $unit\n'
                  '${chartDateFormatterYMD(groupData.x)}',
                  chartTooltipStyleBold.copyWith(
                    color: context.colorScheme.onPrimary,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: Duration.millisecondsPerDay.toDouble(),
                getTitlesWidget: bottomTitleWidgets,
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: leftTitleWidgets,
                reservedSize: 40,
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: const Color(0xff37434d)),
          ),
          barGroups: barGroups,
        ),
        //duration: Duration.zero,
      ),
    );
  }
}
