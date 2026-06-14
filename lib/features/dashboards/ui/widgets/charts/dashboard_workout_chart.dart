import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/state/workout_chart_controller.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_bar_chart.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/charts/utils.dart';

class WorkoutChartInfoWidget extends StatelessWidget {
  const WorkoutChartInfoWidget(
    this.chartConfig, {
    super.key,
  });

  final DashboardWorkoutItem chartConfig;

  @override
  Widget build(BuildContext context) {
    return DashboardChartHeader(
      title: chartConfig.displayName,
      subtitle: _unitLabel(chartConfig.valueType),
    );
  }

  static String _unitLabel(WorkoutValueType valueType) {
    switch (valueType) {
      case WorkoutValueType.duration:
        return 'min';
      case WorkoutValueType.distance:
        return 'km';
      case WorkoutValueType.energy:
        return 'kcal';
    }
  }
}

class DashboardWorkoutChart extends ConsumerWidget {
  const DashboardWorkoutChart({
    required this.chartConfig,
    required this.rangeStart,
    required this.rangeEnd,
    this.transformationController,
    super.key,
  });

  final DashboardWorkoutItem chartConfig;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final TransformationController? transformationController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final observationsAsync = ref.watch(
      workoutObservationsControllerProvider(
        chartConfig: chartConfig,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      ),
    );
    final observations = observationsAsync.value ?? const <Observation>[];
    final tokens = context.designTokens;

    return DashboardChart(
      chart: TimeSeriesBarChart(
        data: observations,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        unit: chartConfig.displayName,
        transformationController: transformationController,
        colorByValue: (Observation observation) =>
            tokens.colors.interactive.enabled,
      ),
      chartHeader: WorkoutChartInfoWidget(chartConfig),
      isLoading: observationsAsync.isLoading && !observationsAsync.hasValue,
      isEmpty: observations.isEmpty,
      emptyMessage: context.messages.dashboardChartNoData,
      height: 120,
    );
  }
}
