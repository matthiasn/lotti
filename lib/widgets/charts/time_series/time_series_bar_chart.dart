import 'dart:core';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/charts/utils.dart';

typedef ColorByValue = Color Function(Observation);

const gridOpacity = 0.3;
const labelOpacity = 0.5;

class ChartLabel extends StatelessWidget {
  const ChartLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: labelOpacity,
      child: Text(
        text,
        style: chartTitleStyleSmall,
        textAlign: TextAlign.center,
      ),
    );
  }
}

List<Color> gradientColors = [
  oldPrimaryColorLight,
  oldPrimaryColor,
];

Widget leftTitleWidgets(double value, TitleMeta meta) {
  return ChartLabel(value.toInt().toString());
}

final gridLine = FlLine(
  color: chartTextColor.withOpacity(gridOpacity),
  strokeWidth: 1,
);

class TimeSeriesBarChart extends StatelessWidget {
  const TimeSeriesBarChart({
    required this.data,
    required this.rangeStart,
    required this.rangeEnd,
    required this.colorByValue,
    this.unit = '',
    super.key,
  });

  final List<Observation> data;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final String unit;
  final ColorByValue colorByValue;

  @override
  Widget build(BuildContext context) {
    final minVal = data.isEmpty ? 0 : data.map((e) => e.value).reduce(min);
    final maxVal = data.isEmpty ? 0 : data.map((e) => e.value).reduce(max);
    final valRange = maxVal - minVal;

    final rangeInDays = rangeEnd.difference(rangeStart).inDays;

    final gridInterval = rangeInDays > 182
        ? 30
        : rangeInDays > 92
            ? 14
            : rangeInDays > 30
                ? 7
                : 1;

    const barsWidth = 5.0;

    final barGroups =
        data.sortedBy((observation) => observation.dateTime).map((observation) {
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
            width: barsWidth,
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
              tooltipBgColor: Colors.grey[600],
              tooltipRoundedRadius: 8,
              getTooltipItem: (groupData, timestamp, rodData, foo) {
                return BarTooltipItem(
                  '${chartDateFormatterYMD(groupData.x)} \n'
                  '${rodData.toY.floor()} $unit',
                  TextStyle(
                    fontSize: fontSizeMedium,
                    color: rodData.color,
                    fontWeight: FontWeight.bold,
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
                interval: double.maxFinite,
                getTitlesWidget: leftTitleWidgets,
                reservedSize: 40,
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: const Color(0xff37434d)),
          ),
          minY: max(minVal - valRange * 0.2, 0),
          maxY: maxVal + valRange * 0.2,
          barGroups: barGroups,
        ),
        //duration: Duration.zero,
      ),
    );
  }
}
