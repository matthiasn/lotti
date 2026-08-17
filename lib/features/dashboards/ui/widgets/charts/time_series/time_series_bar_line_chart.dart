import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/charts/utils.dart';

/// Daily observations as bars with a line series overlaid on the same axes.
///
/// Every calendar day in the range owns one equal-width slot. Missing actual
/// observations keep an empty slot rather than becoming zero, while [lineData]
/// can begin later (for example once a rolling window is available). The
/// invisible actual-point series in the line layer keeps both actual and
/// overlay values available to one shared tooltip without drawing a second
/// actual-data line over the bars.
class TimeSeriesBarLineChart extends StatelessWidget {
  const TimeSeriesBarLineChart({
    required this.barData,
    required this.lineData,
    required this.rangeStart,
    required this.rangeEnd,
    required this.maxVal,
    required this.barColor,
    required this.lineColor,
    required this.barLabel,
    required this.lineLabel,
    this.unit = '',
    this.dateOnly = false,
    this.horizontalLines = const [],
    super.key,
  });

  final List<Observation> barData;
  final List<Observation> lineData;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final num maxVal;
  final Color barColor;
  final Color lineColor;
  final String barLabel;
  final String lineLabel;
  final String unit;
  final bool dateOnly;
  final List<HorizontalLine> horizontalLines;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final axis = niceAxis(0, maxVal, zeroBased: true);
    final start = _utcDay(rangeStart);
    final end = _utcDay(rangeEnd);
    final dayCount = math.max(end.difference(start).inDays + 1, 1);
    final barsByDay = {
      for (final observation in barData)
        _utcDay(observation.dateTime): observation,
    };
    final barSpots = _indexedSpots(barData, start);
    final lineSpots = _indexedSpots(lineData, start);
    final lineStyle = chartEmphasisLine(lineColor);
    final barRadius = Radius.circular(tokens.radii.xs);

    return Padding(
      padding: EdgeInsets.only(
        top: tokens.spacing.step5,
        right: tokens.spacing.step2,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final plotWidth = math.max(
            constraints.maxWidth - kChartLeftAxisWidth,
            0,
          );
          final barWidth = math.min(
            tokens.spacing.step3,
            plotWidth / dayCount,
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  minY: axis.min,
                  maxY: axis.max,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: axis.interval,
                    getDrawingHorizontalLine: (value) => chartGridLine(context),
                  ),
                  barTouchData: const BarTouchData(enabled: false),
                  titlesData: _axisTitles(axis, showLabels: true),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(
                      color: tokens.colors.decorative.level01,
                    ),
                  ),
                  barGroups: [
                    for (var index = 0; index < dayCount; index++)
                      BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            fromY: axis.min,
                            toY:
                                barsByDay[start.add(Duration(days: index))]
                                    ?.value
                                    .toDouble() ??
                                axis.min,
                            width: barWidth,
                            color:
                                barsByDay.containsKey(
                                  start.add(Duration(days: index)),
                                )
                                ? barColor
                                : barColor.withValues(alpha: 0),
                            borderRadius: BorderRadius.only(
                              topLeft: barRadius,
                              topRight: barRadius,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                duration: Duration.zero,
              ),
              LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  clipData: const FlClipData.horizontal(),
                  lineTouchData: LineTouchData(
                    touchTooltipData: chartTouchTooltipData(
                      context,
                      getTooltipItems: (spots) =>
                          _tooltipItems(context, spots, start: start),
                    ),
                  ),
                  titlesData: _axisTitles(axis, showLabels: false),
                  borderData: FlBorderData(show: false),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: horizontalLines,
                  ),
                  minX: -0.5,
                  maxX: dayCount - 0.5,
                  minY: axis.min,
                  maxY: axis.max,
                  lineBarsData: [
                    LineChartBarData(
                      spots: barSpots,
                      color: barColor.withValues(alpha: 0),
                      barWidth: BorderWidths.hairline,
                      dotData: const FlDotData(show: false),
                    ),
                    LineChartBarData(
                      spots: lineSpots,
                      color: lineStyle.color,
                      barWidth: lineStyle.strokeWidth,
                      dashArray: lineStyle.dashArray,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
                duration: Duration.zero,
              ),
            ],
          );
        },
      ),
    );
  }

  FlTitlesData _axisTitles(NiceAxis axis, {required bool showLabels}) {
    return FlTitlesData(
      rightTitles: const AxisTitles(),
      topTitles: const AxisTitles(),
      bottomTitles: const AxisTitles(),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: axis.interval,
          getTitlesWidget: showLabels
              ? leftTitleWidgets
              : (_, _) => const SizedBox.shrink(),
          reservedSize: kChartLeftAxisWidth,
          minIncluded: false,
        ),
      ),
    );
  }

  /// One tooltip for the touched day: its date once as a header, then the bar
  /// value and — where the rolling line has a point that day — the overlay's,
  /// each under its own quiet label.
  List<LineTooltipItem> _tooltipItems(
    BuildContext context,
    List<LineBarSpot> spots, {
    required DateTime start,
  }) {
    if (spots.isEmpty) return const [];
    final locale = Localizations.localeOf(context).toLanguageTag();
    final number = NumberFormat('#,###.##', locale);
    final unitSuffix = unit.isEmpty ? '' : ' $unit';
    final date = start.add(Duration(days: spots.first.x.round()));
    final timestamp = date.millisecondsSinceEpoch.toDouble();
    return chartTooltipItems(
      context,
      date: dateOnly
          ? chartDateFormatterDateOnlyUtc(context, timestamp)
          : chartDateFormatterFull(context, timestamp),
      entries: [
        for (final spot in spots)
          (
            label: spot.barIndex == 0 ? barLabel : lineLabel,
            value: '${number.format(spot.y)}$unitSuffix',
          ),
      ],
    );
  }
}

List<FlSpot> _indexedSpots(
  Iterable<Observation> observations,
  DateTime start,
) => [
  for (final observation in observations)
    FlSpot(
      _utcDay(observation.dateTime).difference(start).inDays.toDouble(),
      observation.value.toDouble(),
    ),
];

DateTime _utcDay(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);
