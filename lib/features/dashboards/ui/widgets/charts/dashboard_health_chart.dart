import 'dart:core';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/state/health_chart_controller.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_health_bmi_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_health_bp_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_health_config.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_health_data.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/charts/time_series/time_series_bar_chart.dart';
import 'package:lotti/widgets/charts/time_series/time_series_line_chart.dart';
import 'package:lotti/widgets/charts/utils.dart';

class HealthChartInfoWidget extends StatelessWidget {
  const HealthChartInfoWidget(
    this.chartConfig, {
    super.key,
  });

  final DashboardHealthItem chartConfig;

  @override
  Widget build(BuildContext context) {
    final healthType = healthTypes[chartConfig.healthType];

    return Positioned(
      top: 0,
      left: 20,
      child: SizedBox(
        width: max(MediaQuery.of(context).size.width, 300) - 20,
        child: IgnorePointer(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                healthType?.displayName ?? chartConfig.healthType,
                style: chartTitleStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardHealthChart extends ConsumerWidget {
  const DashboardHealthChart({
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
    final healthType = healthTypes[chartConfig.healthType];
    final isBarChart = healthType?.chartType == HealthChartType.barChart;
    final dataType = chartConfig.healthType;

    if (dataType == 'BLOOD_PRESSURE') {
      return DashboardHealthBpChart(
        chartConfig: chartConfig,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );
    }

    if (dataType == 'BODY_MASS_INDEX') {
      return DashboardHealthBmiChart(
        chartConfig: chartConfig,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      );
    }

    final data = ref
            .watch(
              healthObservationsControllerProvider(
                healthDataType: chartConfig.healthType,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
              ),
            )
            .valueOrNull ??
        [];

    return DashboardChart(
      chart: isBarChart
          ? TimeSeriesBarChart(
              data: data,
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
              unit: healthType?.unit ?? '',
              valueInHours: healthType?.unit == 'h',
              colorByValue: (Observation observation) => colorByValueAndType(
                observation,
                healthType,
              ),
            )
          : TimeSeriesLineChart(
              data: data,
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
              unit: healthType?.unit ?? '',
            ),
      chartHeader: HealthChartInfoWidget(chartConfig),
      height: isBarChart ? 180 : 150,
    );
  }
}
