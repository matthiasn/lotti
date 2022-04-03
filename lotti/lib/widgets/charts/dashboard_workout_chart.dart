import 'dart:core';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lotti/blocs/charts/workout_chart_info_cubit.dart';
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
  final _chartState = charts.UserManagedState<DateTime>();

  @override
  void initState() {
    super.initState();
    _healthImport.getWorkoutsHealthDataDelta();
  }

  @override
  Widget build(BuildContext context) {
    charts.SeriesRendererConfig<DateTime>? defaultRenderer =
        charts.BarRendererConfig<DateTime>();

    return BlocProvider<WorkoutChartInfoCubit>(
      create: (BuildContext context) => WorkoutChartInfoCubit(),
      child: StreamBuilder<List<JournalEntity?>>(
        stream: _db.watchWorkouts(
          rangeStart: widget.rangeStart,
          rangeEnd: widget.rangeEnd,
        ),
        builder: (
          BuildContext context,
          AsyncSnapshot<List<JournalEntity?>> snapshot,
        ) {
          List<JournalEntity?>? items = snapshot.data ?? [];

          void _infoSelectionModelUpdated(
              charts.SelectionModel<DateTime> model) {
            if (model.hasDatumSelection) {
              Observation newSelection =
                  model.selectedDatum.first.datum as Observation;
              context.read<WorkoutChartInfoCubit>().setSelected(newSelection);

              _chartState.selectionModels[charts.SelectionModelType.info] =
                  charts.UserManagedSelectionModel(model: model);
            } else {
              context.read<WorkoutChartInfoCubit>().clearSelected();
              _chartState.selectionModels[charts.SelectionModelType.info] =
                  charts.UserManagedSelectionModel();
            }
          }

          List<charts.Series<Observation, DateTime>> seriesList = [
            charts.Series<Observation, DateTime>(
              id: widget.chartConfig.workoutType,
              domainFn: (Observation val, _) => val.dateTime,
              measureFn: (Observation val, _) => val.value,
              data: aggregateWorkoutDailySum(
                items,
                chartConfig: widget.chartConfig,
                rangeStart: widget.rangeStart,
                rangeEnd: widget.rangeEnd,
              ),
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
                      animate: false,
                      behaviors: [
                        chartRangeAnnotation(
                            widget.rangeStart, widget.rangeEnd),
                      ],
                      domainAxis: timeSeriesAxis,
                      defaultRenderer: defaultRenderer,
                      selectionModels: [
                        charts.SelectionModelConfig(
                          type: charts.SelectionModelType.info,
                          updatedListener: _infoSelectionModelUpdated,
                        ),
                      ],
                      primaryMeasureAxis: const charts.NumericAxisSpec(
                        tickProviderSpec: charts.BasicNumericTickProviderSpec(
                          zeroBound: false,
                          desiredTickCount: 5,
                          dataIsInWholeNumbers: true,
                        ),
                      ),
                    ),
                    WorkoutChartInfoWidget(widget.chartConfig),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class WorkoutChartInfoWidget extends StatelessWidget {
  const WorkoutChartInfoWidget(
    this.chartConfig, {
    Key? key,
  }) : super(key: key);

  final DashboardWorkoutItem chartConfig;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkoutChartInfoCubit, WorkoutChartInfoState>(
        builder: (BuildContext context, WorkoutChartInfoState state) {
      final Observation? selected = state.selected;

      return Positioned(
        top: -1,
        left: MediaQuery.of(context).size.width / 4,
        child: SizedBox(
          width: MediaQuery.of(context).size.width / 2,
          child: IgnorePointer(
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(),
                Text(
                  chartConfig.displayName,
                  style: chartTitleStyle,
                ),
                if (selected != null) ...[
                  const Spacer(),
                  Padding(
                    padding: AppTheme.chartDateHorizontalPadding,
                    child: Text(
                      ' ${ymd(selected.dateTime)}',
                      style: chartTitleStyle,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    ' ${NumberFormat('#,###.##').format(selected.value)}',
                    style: chartTitleStyle.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                const Spacer(),
              ],
            ),
          ),
        ),
      );
    });
  }
}
