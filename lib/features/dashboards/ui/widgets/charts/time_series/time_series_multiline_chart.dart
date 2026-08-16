import 'dart:core';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/charts/utils.dart';

/// Multi-series line chart over a date range. Unlike the single-line chart this
/// takes already-built fl_chart [lineBarsData] (the caller styles each series —
/// e.g. `surveyLines`) plus an explicit `minVal`/`maxVal` spanning all series,
/// from which it derives one shared "nice" value axis so every line is on the
/// same scale. The x range is fixed to `[rangeStart, rangeEnd]`.
class TimeSeriesMultiLineChart extends StatelessWidget {
  const TimeSeriesMultiLineChart({
    required this.lineBarsData,
    required this.rangeStart,
    required this.rangeEnd,
    required this.minVal,
    required this.maxVal,
    this.unit = '',
    this.dateOnly = false,
    this.horizontalLines = const [],
    this.seriesLabels = const [],
    super.key,
  });

  final List<LineChartBarData> lineBarsData;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final num minVal;
  final num maxVal;
  final String unit;
  final bool dateOnly;
  final List<HorizontalLine> horizontalLines;

  /// Labels matched by index to [lineBarsData]. When supplied, tooltips name
  /// each value so overlapping series such as actual and rolling average stay
  /// distinguishable without relying on colour alone.
  final List<String> seriesLabels;

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
                  final seriesLabel = spot.barIndex < seriesLabels.length
                      ? seriesLabels[spot.barIndex]
                      : '';
                  final formattedValue = NumberFormat(
                    '#,###.##',
                  ).format(spot.y);
                  final unitSuffix = unit.isEmpty ? '' : ' $unit';
                  return LineTooltipItem(
                    '',
                    TextStyle(
                      fontSize: fontSizeSmall,
                      fontWeight: FontWeight.w300,
                      color: tokens.colors.text.highEmphasis,
                    ),
                    children: [
                      if (seriesLabel.isNotEmpty)
                        TextSpan(
                          text: '$seriesLabel\n',
                          style: chartTooltipStyleBold,
                        ),
                      TextSpan(
                        text: '$formattedValue$unitSuffix\n',
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
                interval: axis.interval,
                getTitlesWidget: leftTitleWidgets,
                reservedSize: kChartLeftAxisWidth,
                // Suppress the bottom tick (it overlaps the date axis) but keep
                // the top tick so the value scale's ceiling shows — matching
                // the bar and single-line variants' shared-axis behavior.
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
          lineBarsData: lineBarsData,
        ),
        duration: Duration.zero,
      ),
    );
  }
}
