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

/// Single-series line chart over a date range, plotting [data] as a filled-area
/// line in epoch-millis x against a "nice" value axis derived from the data's
/// min/max. The x range is fixed to `[rangeStart, rangeEnd]` so adjacent cards
/// align; tooltips show the formatted value, [unit], and date. Unlike the bar
/// chart it does not backfill missing days; observations on either side remain
/// connected. A singleton renders its point because no line segment exists yet.
class TimeSeriesLineChart extends StatelessWidget {
  const TimeSeriesLineChart({
    required this.data,
    required this.rangeStart,
    required this.rangeEnd,
    this.unit = '',
    this.dateOnly = false,
    this.horizontalLines = const [],
    super.key,
  });

  final List<Observation> data;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final String unit;
  final bool dateOnly;
  final List<HorizontalLine> horizontalLines;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    final series = timeSeriesAreaLine(
      data: data,
      color: tokens.colors.interactive.enabled,
    );
    final spots = series.spots;

    final axisValues = [
      ...spots.map((spot) => spot.y),
      ...horizontalLines.map((line) => line.y),
    ];
    final minY = axisValues.isNotEmpty ? axisValues.reduce(min).floor() : 0;
    final maxY = axisValues.isNotEmpty ? axisValues.reduce(max).ceil() : 1;
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
                        text: dateOnly
                            ? chartDateFormatterDateOnlyUtc(context, spot.x)
                            : chartDateFormatterFull(context, spot.x),
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
          extraLinesData: ExtraLinesData(horizontalLines: horizontalLines),
          minX: rangeStart.millisecondsSinceEpoch.toDouble(),
          maxX: rangeEnd.millisecondsSinceEpoch.toDouble(),
          minY: axis.min,
          maxY: axis.max,
          lineBarsData: [series],
        ),
        duration: Duration.zero,
      ),
    );
  }
}

/// Shared actual-value treatment for continuous time-series measurements.
/// Keeps the line and its subtle same-hue area fill identical wherever an
/// additional overlay (such as a rolling average) is added by the caller.
LineChartBarData timeSeriesAreaLine({
  required List<Observation> data,
  required Color color,
}) => LineChartBarData(
  spots: [
    for (final item in data)
      FlSpot(
        item.dateTime.millisecondsSinceEpoch.toDouble(),
        item.value.toDouble(),
      ),
  ],
  color: color,
  isStrokeCapRound: true,
  dotData: FlDotData(show: data.length == 1),
  belowBarData: BarAreaData(
    show: true,
    color: color.withValues(alpha: 0.12),
  ),
);
