import 'dart:math';

import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/habits/habits_cubit.dart';
import 'package:lotti/blocs/habits/habits_state.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:tinycolor2/tinycolor2.dart';

final gridLine = FlLine(
  color: styleConfig().chartTextColor.withOpacity(gridOpacity),
  strokeWidth: 1,
);

const gridOpacity = 0.3;
const labelOpacity = 0.5;

class HabitCompletionRateChart extends StatelessWidget
    with PreferredSizeWidget {
  const HabitCompletionRateChart({
    this.showSuccessful = true,
    this.showSkipped = true,
    super.key,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  final bool showSuccessful;
  final bool showSkipped;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HabitsCubit, HabitsState>(
      builder: (context, HabitsState state) {
        final cubit = context.read<HabitsCubit>();
        final timeSpanDays = state.timeSpanDays;

        final days = daysInRange(
          rangeStart: DateTime.now().subtract(Duration(days: timeSpanDays)),
          rangeEnd: DateTime.now().add(const Duration(days: 1)),
        )..sort();

        Widget bottomTitleWidgets(double value, TitleMeta meta) {
          var ymd = '';

          if (value.toInt() == 1) {
            ymd = days[1];
          }

          if (value.toInt() == timeSpanDays - 1) {
            ymd = days[timeSpanDays - 1];
          }

          return SideTitleWidget(
            axisSide: meta.axisSide,
            child: ChartLabel(chartDateFormatter(ymd)),
          );
        }

        final skipColor = styleConfig()
            .primaryColorLight
            .mix(styleConfig().alarm.complement());

        String completionRate(
          Map<String, Set<String>> byDay,
          String label,
        ) {
          final n = byDay[state.selectedInfoYmd]?.length ?? 0;
          final total = state.habitCount;
          final percentage = (n / total) * 100;
          return '${percentage.floor()}% $label';
        }

        return Column(
          children: [
            SizedBox(
              height: 25,
              child: state.selectedInfoYmd.isNotEmpty
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InfoLabel('${state.selectedInfoYmd}:'),
                        InfoLabel(
                          completionRate(state.successfulByDay, 'successful'),
                        ),
                        InfoLabel(
                          completionRate(state.skippedByDay, 'skipped'),
                        ),
                        InfoLabel(
                          completionRate(state.failedByDay, 'recorded fails'),
                        ),
                      ],
                    )
                  : null,
            ),
            SizedBox(
              height: 110,
              width: MediaQuery.of(context).size.width,
              child: Padding(
                padding: const EdgeInsets.only(
                  right: 25,
                  left: 20,
                ),
                child: LineChart(
                  LineChartData(
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        tooltipMargin: -150,
                        tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        tooltipBgColor: styleConfig().primaryColor,
                        tooltipRoundedRadius: 8,
                        getTooltipItems: (List<LineBarSpot> spots) {
                          final ymd = days[spots.first.x.toInt()];
                          cubit.setInfoYmd(ymd);
                          return [];
                        },
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      horizontalInterval: 12.5,
                      verticalInterval: 1,
                      getDrawingHorizontalLine: (value) => gridLine,
                      getDrawingVerticalLine: (value) => gridLine,
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 1,
                          getTitlesWidget: bottomTitleWidgets,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 12.5,
                          getTitlesWidget: leftTitleWidgets,
                          reservedSize: 35,
                        ),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border.all(
                        color: styleConfig()
                            .chartTextColor
                            .withOpacity(labelOpacity),
                      ),
                    ),
                    minX: 0,
                    maxX: timeSpanDays.toDouble(),
                    minY: 0,
                    maxY: 100,
                    lineBarsData: [
                      barData(
                        days: days,
                        successfulByDay: state.successfulByDay,
                        skippedByDay: state.skippedByDay,
                        failedByDay: state.failedByDay,
                        showSkipped: true,
                        showSuccessful: true,
                        showFailed: true,
                        habitCount: state.habitCount,
                        color: styleConfig().alarm.lighten().desaturate(),
                        aboveColor: styleConfig().alarm.withOpacity(0.5),
                      ),
                      barData(
                        days: days,
                        successfulByDay: state.successfulByDay,
                        skippedByDay: state.skippedByDay,
                        failedByDay: state.failedByDay,
                        showSkipped: true,
                        showSuccessful: true,
                        showFailed: false,
                        habitCount: state.habitCount,
                        color: skipColor,
                      ),
                      barData(
                        days: days,
                        successfulByDay: state.successfulByDay,
                        skippedByDay: state.skippedByDay,
                        failedByDay: state.failedByDay,
                        showSkipped: false,
                        showSuccessful: true,
                        showFailed: false,
                        habitCount: state.habitCount,
                        color: styleConfig().primaryColor,
                      ),
                    ],
                  ),
                  swapAnimationCurve: Curves.bounceInOut,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

LineChartBarData barData({
  required List<String> days,
  required int habitCount,
  required Map<String, Set<String>> successfulByDay,
  required Map<String, Set<String>> skippedByDay,
  required Map<String, Set<String>> failedByDay,
  required bool showSuccessful,
  required bool showSkipped,
  required bool showFailed,
  required Color color,
  Color? aboveColor,
}) {
  final spots = days.mapIndexed((idx, day) {
    final successCount = successfulByDay[day]?.length ?? 0;
    final skippedCount = skippedByDay[day]?.length ?? 0;
    final failedCount = failedByDay[day]?.length ?? 0;

    var value = 0;

    if (showSuccessful) {
      value = value + successCount;
    }

    if (showSkipped) {
      value = value + skippedCount;
    }

    if (showFailed) {
      value = value + failedCount;
    }

    return FlSpot(
      idx.toDouble(),
      min(
        habitCount > 0 ? value * 100 / habitCount : 0,
        100,
      ),
    );
  }).toList();

  return LineChartBarData(
    spots: spots,
    isCurved: true,
    preventCurveOverShooting: true,
    preventCurveOvershootingThreshold: 0,
    color: color,
    barWidth: 1,
    isStrokeCapRound: true,
    dotData: FlDotData(show: false),
    belowBarData: BarAreaData(
      show: true,
      color: color.withOpacity(0.5),
    ),
    aboveBarData: aboveColor != null
        ? BarAreaData(
            show: true,
            color: aboveColor,
          )
        : null,
  );
}

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

Widget leftTitleWidgets(double value, TitleMeta meta) {
  String text;
  switch (value.toInt()) {
    case 25:
      text = '25%';
      break;
    case 50:
      text = '50%';
      break;
    case 75:
      text = '75%';
      break;
    case 100:
      text = '100%';
      break;
    default:
      return Container();
  }

  return ChartLabel(text);
}

class InfoLabel extends StatelessWidget {
  const InfoLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          text,
          style: chartTitleStyleSmall(),
        ),
      ),
    );
  }
}
