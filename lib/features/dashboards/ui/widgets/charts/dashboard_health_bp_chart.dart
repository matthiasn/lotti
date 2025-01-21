import 'dart:core';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/state/health_chart_controller.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:tinycolor2/tinycolor2.dart';

class DashboardHealthBpChart extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final systolicData = ref
            .watch(
              healthObservationsControllerProvider(
                healthDataType: 'HealthDataType.BLOOD_PRESSURE_SYSTOLIC',
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
              ),
            )
            .valueOrNull ??
        [];

    final diastolicData = ref
            .watch(
              healthObservationsControllerProvider(
                healthDataType: 'HealthDataType.BLOOD_PRESSURE_DIASTOLIC',
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
              ),
            )
            .valueOrNull ??
        [];

    final rangeInDays = rangeEnd.difference(rangeStart).inDays;

    Widget bottomTitleWidgets(double value, TitleMeta meta) {
      final ymd = DateTime.fromMillisecondsSinceEpoch(value.toInt());
      if (ymd.day == 1 ||
          (rangeInDays < 90 && ymd.day == 15) ||
          (rangeInDays < 30 && ymd.day == 8) ||
          (rangeInDays < 30 && ymd.day == 22)) {
        return SideTitleWidget(
          meta: meta,
          child: ChartLabel(chartDateFormatterMmDd(value)),
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
              horizontalInterval: 10,
              verticalInterval: double.maxFinite,
              getDrawingHorizontalLine: (value) {
                if (value == 80.0) {
                  return gridLineEmphasized.copyWith(
                    color: Colors.blue.withAlpha(102),
                  );
                }
                if (value == 120.0) {
                  return gridLineEmphasized.copyWith(
                    color: Colors.red.withAlpha(102),
                  );
                }

                return gridLine;
              },
              getDrawingVerticalLine: (value) => gridLine,
            ),
            clipData: const FlClipData.horizontal(),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                tooltipMargin: isMobile ? 24 : 16,
                tooltipPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                getTooltipColor: (_) =>
                    Theme.of(context).primaryColor.desaturate(),
                tooltipRoundedRadius: 8,
                getTooltipItems: (List<LineBarSpot> spots) {
                  return spots.map((spot) {
                    return LineTooltipItem(
                      '',
                      const TextStyle(
                        fontSize: fontSizeSmall,
                        fontWeight: FontWeight.w300,
                      ),
                      children: [
                        TextSpan(
                          text: '${spot.y.toInt()} mmHg\n',
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
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: Duration.millisecondsPerDay.toDouble(),
                  getTitlesWidget: bottomTitleWidgets,
                ),
              ),
              leftTitles: const AxisTitles(
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
                  color: Colors.red.withAlpha(26),
                ),
                curveSmoothness: 0.1,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
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
                  color: Colors.blue.withAlpha(51),
                ),
                isStrokeCapRound: true,
                dotData: const FlDotData(
                  show: false,
                ),
              ),
            ],
          ),
          duration: Duration.zero,
        ),
      ),
      chartHeader: const BpChartInfoWidget(),
      height: 220,
    );
  }
}

class BpChartInfoWidget extends StatelessWidget {
  const BpChartInfoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Positioned(
      top: 0,
      left: 20,
      child: Text('Blood Pressure', style: chartTitleStyle),
    );
  }
}

Widget leftTitleWidgets(double value, TitleMeta meta) {
  return ChartLabel(value.toInt().toString());
}
