import 'dart:core';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:tinycolor2/tinycolor2.dart';

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
        style: chartTitleStyleSmall(),
        textAlign: TextAlign.center,
      ),
    );
  }
}

List<Color> gradientColors = [
  styleConfig().primaryColorLight,
  styleConfig().primaryColor,
];

Widget leftTitleWidgets(double value, TitleMeta meta) {
  return ChartLabel(value.toInt().toString());
}

final gridLine = FlLine(
  color: styleConfig().chartTextColor.withOpacity(gridOpacity),
  strokeWidth: 1,
);

class TimeSeriesLineChart extends StatelessWidget {
  const TimeSeriesLineChart({
    required this.data,
    required this.rangeStart,
    required this.rangeEnd,
    this.unit = '',
    super.key,
  });

  final List<Observation> data;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final String unit;

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

    final spots = data
        .map(
          (item) => FlSpot(
            item.dateTime.millisecondsSinceEpoch.toDouble(),
            item.value.toDouble(),
          ),
        )
        .toList();

    Widget bottomTitleWidgets(double value, TitleMeta meta) {
      final ymd = DateTime.fromMillisecondsSinceEpoch(value.toInt());
      if (ymd.day == 1 ||
          (rangeInDays < 90 && ymd.day == 15) ||
          (rangeInDays < 30 && ymd.day == 8) ||
          (rangeInDays < 30 && ymd.day == 22)) {
        return SideTitleWidget(
          axisSide: meta.axisSide,
          child: ChartLabel(chartDateFormatter2(value)),
        );
      }
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(
        top: 20,
        right: 20,
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: false,
            drawVerticalLine: true,
            horizontalInterval: double.maxFinite,
            verticalInterval:
                Duration.millisecondsPerDay.toDouble() * gridInterval,
            getDrawingHorizontalLine: (value) => gridLine,
            getDrawingVerticalLine: (value) => gridLine,
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipMargin: isMobile ? 24 : 16,
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              tooltipBgColor: styleConfig().primaryColor.desaturate(),
              tooltipRoundedRadius: 8,
              getTooltipItems: (List<LineBarSpot> spots) {
                return spots.map((spot) {
                  return LineTooltipItem(
                    '',
                    const TextStyle(
                      fontSize: fontSizeSmall,
                      fontWeight: FontWeight.w300,
                    ),
                    children: [
                      TextSpan(
                        text: '${spot.y.toInt()} $unit\n',
                        style: chartTooltipStyleBold(),
                      ),
                      TextSpan(
                        text: chartDateFormatterFull(spot.x),
                        style: chartTooltipStyle(),
                      ),
                    ],
                  );
                }).toList();
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: false,
              ),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: Duration.millisecondsPerDay.toDouble(),
                getTitlesWidget: bottomTitleWidgets,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: double.maxFinite,
                getTitlesWidget: leftTitleWidgets,
                reservedSize: 30,
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: const Color(0xff37434d)),
          ),
          minX: rangeStart.millisecondsSinceEpoch.toDouble(),
          maxX: rangeEnd.millisecondsSinceEpoch.toDouble(),
          minY: max(minVal - valRange * 0.2, 0),
          maxY: maxVal + valRange * 0.2,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.1,
              gradient: LinearGradient(
                colors: gradientColors,
              ),
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: false,
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: gradientColors
                      .map((color) => color.withOpacity(0.3))
                      .toList(),
                ),
              ),
            ),
          ],
        ),
        swapAnimationDuration: Duration.zero,
      ),
    );
  }
}
