import 'dart:core';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/state/workout_data.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_bar_chart.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/charts/utils.dart';

class DashboardWorkoutChart extends StatefulWidget {
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
  State<DashboardWorkoutChart> createState() => _DashboardWorkoutChartState();
}

class _DashboardWorkoutChartState extends State<DashboardWorkoutChart> {
  final JournalDb _db = getIt<JournalDb>();
  final HealthImport _healthImport = getIt<HealthImport>();

  @override
  void initState() {
    super.initState();
    _healthImport.getWorkoutsHealthDataDelta();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<JournalEntity>>(
      stream: _db.watchWorkouts(
        rangeStart: widget.rangeStart,
        rangeEnd: widget.rangeEnd,
      ),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<JournalEntity>> snapshot,
      ) {
        final items = snapshot.data ?? [];

        return DashboardChart(
          chart: TimeSeriesBarChart(
            data: aggregateWorkoutDailySum(
              items,
              chartConfig: widget.chartConfig,
              rangeStart: widget.rangeStart,
              rangeEnd: widget.rangeEnd,
            ),
            rangeStart: widget.rangeStart,
            rangeEnd: widget.rangeEnd,
            unit: widget.chartConfig.displayName,
            colorByValue: (Observation observation) =>
                colorFromCssHex('#82E6CE'),
          ),
          chartHeader: WorkoutChartInfoWidget(widget.chartConfig),
          height: 120,
        );
      },
    );
  }
}

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
