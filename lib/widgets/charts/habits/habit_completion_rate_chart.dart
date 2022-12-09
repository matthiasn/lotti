import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/habits/habits_cubit.dart';
import 'package:lotti/blocs/habits/habits_state.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:tinycolor2/tinycolor2.dart';

List<Color> gradientColors = [
  styleConfig().primaryColorLight,
  styleConfig().primaryColor,
];

final gridLine = FlLine(
  color: styleConfig().chartTextColor.withOpacity(gridOpacity),
  strokeWidth: 1,
);

const gridOpacity = 0.3;
const labelOpacity = 0.5;

class HabitCompletionRateChart extends StatelessWidget {
  const HabitCompletionRateChart({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HabitsCubit, HabitsState>(
      builder: (context, HabitsState state) {
        final habitCount = state.habitDefinitions.length;
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

        return SizedBox(
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
                            fontFamily: mainFont,
                            fontWeight: FontWeight.w300,
                          ),
                          children: [
                            TextSpan(
                              text: '${spot.y.toInt()} %\n',
                              style: chartTooltipStyleBold(),
                            ),
                            TextSpan(
                              text: chartDateFormatter(days[spot.x.toInt()]),
                              style: chartTooltipStyle(),
                            ),
                          ],
                        );
                      }).toList();
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
                    color:
                        styleConfig().chartTextColor.withOpacity(labelOpacity),
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
                    habitCount: habitCount,
                  ),
                ],
              ),
              swapAnimationCurve: Curves.bounceInOut,
            ),
          ),
        );
      },
    );
  }
}

LineChartBarData barData({
  required List<String> days,
  required int habitCount,
  required Map<String, Set<String>> successfulByDay,
}) {
  final spots = days.mapIndexed((idx, day) {
    final value = successfulByDay[day]?.length ?? 0;
    return FlSpot(
      idx.toDouble(),
      habitCount > 0 ? value * 100 / habitCount : 0,
    );
  }).toList();

  return LineChartBarData(
    spots: spots,
    isCurved: true,
    gradient: LinearGradient(colors: gradientColors),
    barWidth: 2,
    isStrokeCapRound: true,
    dotData: FlDotData(show: false),
    belowBarData: BarAreaData(
      show: true,
      gradient: LinearGradient(
        colors: gradientColors.map((color) => color.withOpacity(0.3)).toList(),
      ),
    ),
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
