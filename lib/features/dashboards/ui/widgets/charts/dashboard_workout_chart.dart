import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/state/workout_chart_controller.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/stale_async_value.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_bar_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/charts/utils.dart';

/// Header for a workout chart card: the series display name as title and the
/// value type's unit symbol (`min`/`km`/`kcal`) as subtitle.
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
      subtitle: workoutUnitLabel(chartConfig.valueType),
    );
  }
}

/// The unit symbol for a workout value type, shared by the card subtitle and
/// the bar chart's value tooltip so they always agree (e.g. "12 km", not the
/// workout's display name).
String workoutUnitLabel(WorkoutValueType valueType) {
  switch (valueType) {
    case WorkoutValueType.duration:
      return 'min';
    case WorkoutValueType.distance:
      return 'km';
    case WorkoutValueType.energy:
      return 'kcal';
  }
}

/// Chart card for one workout series: a daily-sum bar chart of the configured
/// workout type's chosen dimension (duration / distance / energy).
///
/// Watches [WorkoutObservationsController] for the per-day totals and wraps them
/// in a stale-aware [DashboardChart] so a span change doesn't flash the card
/// empty.
class DashboardWorkoutChart extends ConsumerWidget {
  const DashboardWorkoutChart({
    required this.chartConfig,
    required this.rangeStart,
    required this.rangeEnd,
    super.key,
  });

  final DashboardWorkoutItem chartConfig;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;

    return StaleAsyncValue<List<Observation>>(
      async: ref.watch(
        workoutObservationsControllerProvider(
          chartConfig: chartConfig,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ),
      ),
      builder: (context, value, isInitialLoading) {
        final observations = value ?? const <Observation>[];
        return DashboardChart(
          chart: TimeSeriesBarChart(
            data: observations,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            unit: workoutUnitLabel(chartConfig.valueType),
            colorByValue: (Observation observation) =>
                tokens.colors.interactive.enabled,
          ),
          dateAxis: DashboardChartDateAxis(
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
          chartHeader: WorkoutChartInfoWidget(chartConfig),
          isLoading: isInitialLoading,
          isEmpty: observations.isEmpty,
          emptyMessage: context.messages.dashboardChartNoData,
          height: 120,
        );
      },
    );
  }
}
