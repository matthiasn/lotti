import 'dart:core';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/state/workout_chart_controller.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_bar_chart.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/charts/utils.dart';

class WorkoutChartInfoWidget extends StatelessWidget {
  const WorkoutChartInfoWidget(
    this.chartConfig, {
    super.key,
  });

  final DashboardWorkoutItem chartConfig;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 20,
      child: SizedBox(
        width: max(MediaQuery.of(context).size.width, 350) - 20,
        child: IgnorePointer(
          child: Row(
            children: [
              Text(
                chartConfig.displayName,
                style: chartTitleStyle,
              ),
            ],
          ),
        ),
      ),
    );
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
    final observations = ref
            .watch(
              workoutObservationsControllerProvider(
                chartConfig: chartConfig,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
              ),
            )
            .value ??
        [];

    return DashboardChart(
      chart: TimeSeriesBarChart(
        data: observations,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        unit: chartConfig.displayName,
        transformationController: transformationController,
        colorByValue: (Observation observation) => colorFromCssHex('#82E6CE'),
      ),
      chartHeader: WorkoutChartInfoWidget(chartConfig),
      height: 120,
    );
  }
}
