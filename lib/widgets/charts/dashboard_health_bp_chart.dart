import 'dart:core';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/charts/dashboard_chart.dart';
import 'package:lotti/widgets/charts/dashboard_health_data.dart';
import 'package:lotti/widgets/charts/habits/habit_completion_rate_chart.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:tinycolor2/tinycolor2.dart';

class DashboardHealthBpChart extends StatelessWidget {
  const DashboardHealthBpChart({
    required this.chartConfig,
    required this.rangeStart,
    required this.rangeEnd,
    super.key,
  });

  final DashboardHealthItem chartConfig;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  @override
  Widget build(BuildContext context) {
    const systolicType = 'HealthDataType.BLOOD_PRESSURE_SYSTOLIC';
    const diastolicType = 'HealthDataType.BLOOD_PRESSURE_DIASTOLIC';
    final dataTypes = <String>[systolicType, diastolicType];

    return StreamBuilder<List<JournalEntity>>(
      stream: getIt<JournalDb>().watchQuantitativeByTypes(
        types: dataTypes,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      ),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<JournalEntity>> snapshot,
      ) {
        final rangeInDays = rangeEnd.difference(rangeStart).inDays;

        final items = snapshot.data ?? [];

        final systolicData = aggregateNoneFilteredBy(items, systolicType);
        final diastolicData = aggregateNoneFilteredBy(items, diastolicType);

        Widget bottomTitleWidgets(double value, TitleMeta meta) {
          final ymd = DateTime.fromMillisecondsSinceEpoch(value.toInt());
          if (ymd.day == 1 ||
              (rangeInDays < 90 && ymd.day == 15) ||
              (rangeInDays < 30 && ymd.day == 8) ||
              (rangeInDays < 30 && ymd.day == 22)) {
            return SideTitleWidget(
              axisSide: meta.axisSide,
              child: ChartLabel(chartDateFormatter2(value)),
            );
          }
          return const SizedBox.shrink();
        }

        return DashboardChart(
          chart: Padding(
            padding: const EdgeInsets.only(top: 20, right: 20),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 10,
                  verticalInterval: double.maxFinite,
                  getDrawingHorizontalLine: (value) {
                    if (value == 80.0) {
                      return gridLineEmphasized.copyWith(
                        color: Colors.blue.withOpacity(0.4),
                      );
                    }
                    if (value == 120.0) {
                      return gridLineEmphasized.copyWith(
                        color: Colors.red.withOpacity(0.4),
                      );
                    }

                    return gridLine;
                  },
                  getDrawingVerticalLine: (value) => gridLine,
                ),
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
                              text: '${spot.y.toInt()} mmHg\n',
                              style: chartTooltipStyleBold(),
                            ),
                            TextSpan(
                              text: chartDateFormatterFull(spot.x),
                              style: chartTooltipStyle(),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false,
                    ),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: Duration.millisecondsPerDay.toDouble(),
                      getTitlesWidget: bottomTitleWidgets,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 10,
                      getTitlesWidget: leftTitleWidgets,
                      reservedSize: 30,
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: const Color(0xff37434d)),
                ),
                minX: rangeStart.millisecondsSinceEpoch.toDouble(),
                maxX: rangeEnd.millisecondsSinceEpoch.toDouble(),
                minY: 60,
                maxY: 160,
                lineBarsData: [
                  LineChartBarData(
                    spots: systolicData
                        .map(
                          (item) => FlSpot(
                            item.dateTime.millisecondsSinceEpoch.toDouble(),
                            item.value.toDouble(),
                          ),
                        )
                        .toList(),
                    isCurved: true,
                    color: Colors.red,
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.red.withOpacity(0.1),
                    ),
                    curveSmoothness: 0.1,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: false,
                    ),
                  ),
                  LineChartBarData(
                    spots: diastolicData
                        .map(
                          (item) => FlSpot(
                            item.dateTime.millisecondsSinceEpoch.toDouble(),
                            item.value.toDouble(),
                          ),
                        )
                        .toList(),
                    isCurved: true,
                    curveSmoothness: 0.1,
                    color: Colors.blue,
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withOpacity(0.2),
                    ),
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: false,
                    ),
                  ),
                ],
              ),
              swapAnimationDuration: const Duration(milliseconds: 250),
            ),
          ),
          chartHeader: const BpChartInfoWidget(),
          height: 220,
        );
      },
    );
  }
}

class BpChartInfoWidget extends StatelessWidget {
  const BpChartInfoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 10,
      child: Text(
        'Blood Pressure',
        style: chartTitleStyle(),
      ),
    );
  }
}

Widget leftTitleWidgets(double value, TitleMeta meta) {
  return ChartLabel(value.toInt().toString());
}
