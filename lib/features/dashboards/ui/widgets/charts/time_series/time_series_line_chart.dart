import 'dart:core';
import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/charts/utils.dart';

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
    final tokens = context.designTokens;

    final spots = data
        .map(
          (item) => FlSpot(
            item.dateTime.millisecondsSinceEpoch.toDouble(),
            item.value.toDouble(),
          ),
        )
        .toList();

    final spotValues = spots.map((spot) => spot.y).toList();
    final minY = spotValues.isNotEmpty ? spotValues.reduce(min).floor() : 0;
    final maxY = spotValues.isNotEmpty ? spotValues.reduce(max).ceil() : 1;
    final axis = niceAxis(minY, maxY);

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
          clipData: const FlClipData.horizontal(),
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
                  final formattedValue = NumberFormat(
                    '#,###.##',
                  ).format(spot.y);

                  return LineTooltipItem(
                    '',
                    TextStyle(
                      fontSize: fontSizeSmall,
                      fontWeight: FontWeight.w300,
                      color: tokens.colors.text.highEmphasis,
                    ),
                    children: [
                      TextSpan(
                        text: '$formattedValue $unit\n',
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
                getTitlesWidget: leftTitleWidgets,
                reservedSize: kChartLeftAxisWidth,
                // Suppress the bottom tick (it overlaps the date axis) but keep
                // the default top tick so the value scale's ceiling is labelled.
                interval: axis.interval,
                minIncluded: false,
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
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: tokens.colors.interactive.enabled,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: tokens.colors.interactive.enabled.withValues(
                  alpha: 0.12,
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
