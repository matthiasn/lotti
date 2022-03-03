import 'dart:core';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/charts/dashboard_health_data.dart';
import 'package:lotti/widgets/charts/dashboard_workout_data.dart';
import 'package:lotti/widgets/charts/utils.dart';

class DashboardWorkoutChart extends StatefulWidget {
  final DashboardWorkoutItem chartConfig;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  const DashboardWorkoutChart({
    Key? key,
    required this.chartConfig,
    required this.rangeStart,
    required this.rangeEnd,
  }) : super(key: key);

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
    charts.SeriesRendererConfig<DateTime>? defaultRenderer =
        charts.BarRendererConfig<DateTime>();

    return StreamBuilder<List<JournalEntity?>>(
      stream: _db.watchWorkouts(
        rangeStart: widget.rangeStart,
        rangeEnd: widget.rangeEnd,
      ),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<JournalEntity?>> snapshot,
      ) {
        List<JournalEntity?>? items = snapshot.data;

        if (items == null || items.isEmpty) {
          return const SizedBox.shrink();
        }

        List<charts.Series<Observation, DateTime>> seriesList = [
          charts.Series<Observation, DateTime>(
            id: widget.chartConfig.workoutType,
            domainFn: (Observation val, _) => val.dateTime,
            measureFn: (Observation val, _) => val.value,
            data: aggregateWorkoutDailySum(items, widget.chartConfig),
          )
        ];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              key: Key('${widget.chartConfig.hashCode}'),
              color: Colors.white,
              height: 120,
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Stack(
                children: [
                  charts.TimeSeriesChart(
                    seriesList,
                    animate: true,
                    behaviors: [
                      chartRangeAnnotation(widget.rangeStart, widget.rangeEnd),
                    ],
                    domainAxis: timeSeriesAxis,
                    defaultRenderer: defaultRenderer,
                    primaryMeasureAxis: const charts.NumericAxisSpec(
                      tickProviderSpec: charts.BasicNumericTickProviderSpec(
                        zeroBound: false,
                        desiredTickCount: 5,
                        dataIsInWholeNumbers: true,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: MediaQuery.of(context).size.width / 4,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width / 2,
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            widget.chartConfig.displayName,
                            style: chartTitleStyle,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
