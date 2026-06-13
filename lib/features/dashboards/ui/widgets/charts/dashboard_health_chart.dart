import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/config/dashboard_health_config.dart';
import 'package:lotti/features/dashboards/state/health_chart_controller.dart';
import 'package:lotti/features/dashboards/state/health_data.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_health_bmi_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_health_bp_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_bar_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_line_chart.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
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
    final unit = healthType?.unit ?? '';

    return DashboardChartHeader(
      title: healthType?.displayName ?? chartConfig.healthType,
      subtitle: unit.isEmpty ? null : unit,
    );
  }
}

class DashboardHealthChart extends ConsumerWidget {
  const DashboardHealthChart({
    required this.chartConfig,
    required this.rangeStart,
    required this.rangeEnd,
    this.transformationController,
    super.key,
  });

  final DashboardHealthItem chartConfig;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final TransformationController? transformationController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthType = healthTypes[chartConfig.healthType];
    final isBarChart = healthType?.chartType == HealthChartType.barChart;
    final dataType = chartConfig.healthType;

    if (dataType == 'BLOOD_PRESSURE') {
      return DashboardHealthBpChart(
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        transformationController: transformationController,
      );
    }

    if (dataType == 'BODY_MASS_INDEX') {
      return DashboardHealthBmiChart(
        chartConfig: chartConfig,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        transformationController: transformationController,
      );
    }

    final dataAsync = ref.watch(
      healthObservationsControllerProvider(
        healthDataType: chartConfig.healthType,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      ),
    );
    final data = dataAsync.value ?? const <Observation>[];

    return DashboardChart(
      chart: isBarChart
          ? TimeSeriesBarChart(
              data: data,
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
              unit: healthType?.unit ?? '',
              valueInHours: healthType?.unit == 'h',
              transformationController: transformationController,
              colorByValue: (Observation observation) => colorByValueAndType(
                observation,
                healthType,
              ),
            )
          : TimeSeriesLineChart(
              data: data,
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
              transformationController: transformationController,
              unit: healthType?.unit ?? '',
            ),
      chartHeader: HealthChartInfoWidget(chartConfig),
      isLoading: dataAsync.isLoading && !dataAsync.hasValue,
      isEmpty: data.isEmpty,
      emptyMessage: context.messages.dashboardChartNoData,
      height: isBarChart ? 180 : 150,
    );
  }
}
