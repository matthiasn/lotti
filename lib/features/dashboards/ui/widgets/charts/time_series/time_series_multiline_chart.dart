import 'dart:core';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
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
    final locale = Localizations.localeOf(context).toLanguageTag();

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
            touchTooltipData: chartTouchTooltipData(
              context,
              getTooltipItems: (List<LineBarSpot> spots) {
                if (spots.isEmpty) return const [];
                final unitSuffix = unit.isEmpty ? '' : ' $unit';
                final number = NumberFormat('#,###.##', locale);
                // Every touched spot on a line chart shares one x — so one
                // date names the whole tooltip, taken from the first spot.
                return chartTooltipItems(
                  context,
                  date: dateOnly
                      ? chartDateFormatterDateOnlyUtc(context, spots.first.x)
                      : chartDateFormatterFull(context, spots.first.x),
                  entries: [
                    for (final spot in spots)
                      (
                        label: spot.barIndex < seriesLabels.length
                            ? seriesLabels[spot.barIndex]
                            : null,
                        value: '${number.format(spot.y)}$unitSuffix',
                      ),
                  ],
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
