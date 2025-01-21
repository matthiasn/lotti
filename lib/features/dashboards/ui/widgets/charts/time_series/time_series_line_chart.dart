import 'dart:core';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:tinycolor2/tinycolor2.dart';

class TimeSeriesLineChart extends StatelessWidget {
  const TimeSeriesLineChart({
    required this.data,
    required this.rangeStart,
    required this.rangeEnd,
    this.unit = '',
    this.transformationController,
    super.key,
  });

  final List<Observation> data;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final String unit;
  final TransformationController? transformationController;

  @override
  Widget build(BuildContext context) {
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
          meta: meta,
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
      child: LineChart(
        transformationConfig: FlTransformationConfig(
          scaleAxis: FlScaleAxis.horizontal,
          transformationController: transformationController,
          maxScale: 20,
        ),
        LineChartData(
          gridData: FlGridData(
            show: false,
            horizontalInterval: double.maxFinite,
            verticalInterval:
                Duration.millisecondsPerDay.toDouble() * gridInterval,
            getDrawingHorizontalLine: (value) => gridLine,
            getDrawingVerticalLine: (value) => gridLine,
          ),
          clipData: const FlClipData.horizontal(),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipMargin: isMobile ? 24 : 16,
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              getTooltipColor: (_) =>
                  Theme.of(context).primaryColor.desaturate(),
              tooltipRoundedRadius: 8,
              getTooltipItems: (List<LineBarSpot> spots) {
                return spots.map((spot) {
                  return LineTooltipItem(
                    '',
                    TextStyle(
                      fontSize: fontSizeSmall,
                      fontWeight: FontWeight.w300,
                      color: context.colorScheme.onPrimary,
                    ),
                    children: [
                      TextSpan(
                        text: '${spot.y.toInt()} $unit\n',
                        style: chartTooltipStyleBold,
                      ),
                      TextSpan(
                        text: chartDateFormatterFull(spot.x),
                        style: chartTooltipStyle,
                      ),
                    ],
                  );
                }).toList();
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
          minX: rangeStart.millisecondsSinceEpoch.toDouble(),
          maxX: rangeEnd.millisecondsSinceEpoch.toDouble(),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              gradient: LinearGradient(
                colors: gradientColors,
              ),
              dotData: const FlDotData(
                show: false,
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: gradientColors
                      .map((color) => color.withAlpha(77))
                      .toList(),
                ),
              ),
            ),
          ],
        ),
        duration: Duration.zero,
      ),
    );
  }
}
