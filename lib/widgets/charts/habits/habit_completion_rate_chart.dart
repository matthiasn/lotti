import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/habits/habits_cubit.dart';
import 'package:lotti/blocs/habits/habits_state.dart';
import 'package:lotti/themes/theme.dart';

List<Color> gradientColors = [
  styleConfig().primaryColorLight,
  styleConfig().primaryColor,
];

const gridOpacity = 0.3;
const labelOpacity = 0.5;

class HabitCompletionRateChart extends StatelessWidget {
  const HabitCompletionRateChart({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HabitsCubit, HabitsState>(
        builder: (context, HabitsState state) {
      return SizedBox(
        height: 130,
        width: MediaQuery.of(context).size.width,
        child: Padding(
          padding: const EdgeInsets.only(
            right: 20,
            left: 10,
          ),
          child: LineChart(mainData()),
        ),
      );
    });
  }

  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    Widget text;
    switch (value.toInt()) {
      case 1:
        text = const ChartLabel('Nov 26');
        break;
      case 7:
        text = const ChartLabel('Dec 2');
        break;
      case 13:
        text = const ChartLabel('Dec 8');
        break;
      default:
        text = const ChartLabel('');
        break;
    }

    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: text,
    );
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

  LineChartData mainData() {
    final gridLine = FlLine(
      color: styleConfig().chartTextColor.withOpacity(gridOpacity),
      strokeWidth: 1,
    );

    return LineChartData(
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
            interval: 1,
            getTitlesWidget: leftTitleWidgets,
            reservedSize: 42,
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(
          color: styleConfig().chartTextColor.withOpacity(labelOpacity),
        ),
      ),
      minX: 0,
      maxX: 14,
      minY: 0,
      maxY: 100,
      lineBarsData: [
        LineChartBarData(
          spots: const [
            FlSpot(0, 95),
            FlSpot(1, 81),
            FlSpot(2, 57),
            FlSpot(3, 54),
            FlSpot(4, 82),
            FlSpot(5, 90),
            FlSpot(6, 88),
            FlSpot(7, 62),
            FlSpot(8, 24),
            FlSpot(9, 32),
            FlSpot(10, 26),
            FlSpot(11, 54),
            FlSpot(12, 79),
            FlSpot(13, 66),
            FlSpot(14, 82),
          ],
          isCurved: true,
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
    );
  }
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
