import 'dart:core';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/dashboards/state/health_chart_controller.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/charts/utils.dart';

class DashboardHealthBpChart extends ConsumerWidget {
  const DashboardHealthBpChart({
    required this.rangeStart,
    required this.rangeEnd,
    this.transformationController,
    super.key,
  });

  final DateTime rangeStart;
  final DateTime rangeEnd;
  final TransformationController? transformationController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final systolicColor = tokens.colors.alert.error.defaultColor;
    final diastolicColor = tokens.colors.alert.info.defaultColor;

    final systolicAsync = ref.watch(
      healthObservationsControllerProvider(
        healthDataType: 'HealthDataType.BLOOD_PRESSURE_SYSTOLIC',
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      ),
    );
    final diastolicAsync = ref.watch(
      healthObservationsControllerProvider(
        healthDataType: 'HealthDataType.BLOOD_PRESSURE_DIASTOLIC',
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      ),
    );
    final systolicData = systolicAsync.value ?? const <Observation>[];
    final diastolicData = diastolicAsync.value ?? const <Observation>[];
    final isLoading =
        (systolicAsync.isLoading && !systolicAsync.hasValue) ||
        (diastolicAsync.isLoading && !diastolicAsync.hasValue);

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
          transformationConfig: FlTransformationConfig(
            scaleAxis: FlScaleAxis.horizontal,
            transformationController: transformationController,
            maxScale: maxScale,
          ),
          LineChartData(
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: 10,
              getDrawingHorizontalLine: (value) {
                if (value == 80.0) {
                  return chartEmphasisLine(
                    diastolicColor.withValues(alpha: 0.5),
                  );
                }
                if (value == 120.0) {
                  return chartEmphasisLine(
                    systolicColor.withValues(alpha: 0.5),
                  );
                }

                return chartGridLine(context);
              },
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
                    return LineTooltipItem(
                      '',
                      TextStyle(
                        fontSize: fontSizeSmall,
                        fontWeight: FontWeight.w300,
                        color: tokens.colors.text.highEmphasis,
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
                  reservedSize: 40,
                  minIncluded: false,
                  maxIncluded: false,
                ),
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: tokens.colors.decorative.level01),
            ),
            minX: rangeStart.millisecondsSinceEpoch.toDouble(),
            maxX: rangeEnd.millisecondsSinceEpoch.toDouble(),
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
                color: systolicColor,
                belowBarData: BarAreaData(
                  show: true,
                  color: systolicColor.withValues(alpha: 0.1),
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
                color: diastolicColor,
                belowBarData: BarAreaData(
                  show: true,
                  color: diastolicColor.withValues(alpha: 0.1),
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
      isLoading: isLoading,
      isEmpty: systolicData.isEmpty && diastolicData.isEmpty,
      emptyMessage: context.messages.dashboardChartNoData,
      footer: DashboardChartLegend(
        entries: [
          DashboardLegendEntry(
            color: systolicColor,
            label: context.messages.dashboardHealthSystolic,
          ),
          DashboardLegendEntry(
            color: diastolicColor,
            label: context.messages.dashboardHealthDiastolic,
          ),
        ],
      ),
      height: 220,
    );
  }
}

class BpChartInfoWidget extends StatelessWidget {
  const BpChartInfoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return DashboardChartHeader(
      title: context.messages.dashboardHealthBloodPressure,
    );
  }
}

Widget leftTitleWidgets(double value, TitleMeta meta) {
  return ChartLabel(value.toInt().toString());
}
