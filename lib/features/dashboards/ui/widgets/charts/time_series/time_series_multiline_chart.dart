import 'dart:core';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/charts/utils.dart';

class TimeSeriesMultiLineChart extends StatelessWidget {
  const TimeSeriesMultiLineChart({
    required this.lineBarsData,
    required this.rangeStart,
    required this.rangeEnd,
    required this.minVal,
    required this.maxVal,
    this.unit = '',
    super.key,
  });

  final List<LineChartBarData> lineBarsData;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final num minVal;
  final num maxVal;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final axis = niceAxis(minVal, maxVal);

    return Padding(
      padding: EdgeInsets.only(
        top: tokens.spacing.step5,
        right: tokens.spacing.step2,
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: axis.interval,
            getDrawingHorizontalLine: (value) => chartGridLine(context),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipMargin: isMobile ? 24 : 16,
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              getTooltipColor: (_) => tokens.colors.background.level03,
              tooltipBorderRadius: BorderRadius.circular(8),
              getTooltipItems: (List<LineBarSpot> spots) {
                return spots.map((spot) {
                  return LineTooltipItem(
                    '',
                    TextStyle(
                      fontSize: fontSizeSmall,
                      fontWeight: FontWeight.w300,
                      color: tokens.colors.text.highEmphasis,
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
            bottomTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: axis.interval,
                getTitlesWidget: leftTitleWidgets,
                reservedSize: kChartLeftAxisWidth,
                minIncluded: false,
                maxIncluded: false,
              ),
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: tokens.colors.decorative.level01),
          ),
          minX: rangeStart.millisecondsSinceEpoch.toDouble(),
          maxX: rangeEnd.millisecondsSinceEpoch.toDouble(),
          minY: axis.min,
          maxY: axis.max,
          lineBarsData: lineBarsData,
        ),
        duration: Duration.zero,
      ),
    );
  }
}
