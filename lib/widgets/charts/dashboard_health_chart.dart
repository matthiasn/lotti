import 'dart:core';
import 'dart:math';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:lotti/blocs/charts/health_chart_info_cubit.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/wait.dart';
import 'package:lotti/widgets/charts/dashboard_chart.dart';
import 'package:lotti/widgets/charts/dashboard_health_bmi_chart.dart';
import 'package:lotti/widgets/charts/dashboard_health_bp_chart.dart';
import 'package:lotti/widgets/charts/dashboard_health_config.dart';
import 'package:lotti/widgets/charts/dashboard_health_data.dart';
import 'package:lotti/widgets/charts/time_series/time_series_line_chart.dart';
import 'package:lotti/widgets/charts/utils.dart';

class DashboardHealthChart extends StatefulWidget {
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
  State<DashboardHealthChart> createState() => _DashboardHealthChartState();
}

class _DashboardHealthChartState extends State<DashboardHealthChart> {
  final JournalDb _db = getIt<JournalDb>();
  final HealthImport _healthImport = getIt<HealthImport>();
  final _chartState = charts.UserManagedState<DateTime>();

  @override
  void initState() {
    super.initState();
    runSoon(
      minWait: 1000,
      maxWait: 3000,
      callback: () {
        _healthImport.fetchHealthDataDelta(widget.chartConfig.healthType);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dataType = widget.chartConfig.healthType;

    if (dataType == 'BLOOD_PRESSURE') {
      return DashboardHealthBpChart(
        chartConfig: widget.chartConfig,
        rangeStart: widget.rangeStart,
        rangeEnd: widget.rangeEnd,
      );
    }

    if (dataType == 'BODY_MASS_INDEX') {
      return DashboardHealthBmiChart(
        chartConfig: widget.chartConfig,
        rangeStart: widget.rangeStart,
        rangeEnd: widget.rangeEnd,
      );
    }

    final healthType = healthTypes[dataType];
    final isBarChart = healthType?.chartType == HealthChartType.barChart;

    return BlocProvider<HealthChartInfoCubit>(
      create: (BuildContext context) => HealthChartInfoCubit(),
      child: StreamBuilder<List<JournalEntity>>(
        stream: _db.watchQuantitativeByType(
          type: widget.chartConfig.healthType,
          rangeStart: widget.rangeStart,
          rangeEnd: widget.rangeEnd,
        ),
        builder: (
          BuildContext context,
          AsyncSnapshot<List<JournalEntity>> snapshot,
        ) {
          final items = snapshot.data ?? [];
          final data = aggregateByType(items, dataType);

          void infoSelectionModelUpdated(
            charts.SelectionModel<DateTime> model,
          ) {
            if (model.hasDatumSelection) {
              final newSelection =
                  model.selectedDatum.first.datum as Observation;
              context.read<HealthChartInfoCubit>().setSelected(newSelection);

              _chartState.selectionModels[charts.SelectionModelType.info] =
                  charts.UserManagedSelectionModel(model: model);
            } else {
              context.read<HealthChartInfoCubit>().clearSelected();
              _chartState.selectionModels[charts.SelectionModelType.info] =
                  charts.UserManagedSelectionModel();
            }
          }

          final seriesList = <charts.Series<Observation, DateTime>>[
            charts.Series<Observation, DateTime>(
              id: dataType,
              colorFn: (Observation val, _) {
                return colorByValue(val, healthType);
              },
              domainFn: (Observation val, _) => val.dateTime,
              measureFn: (Observation val, _) => val.value,
              data: data,
            )
          ];

          return DashboardChart(
            chart: isBarChart
                ? charts.TimeSeriesChart(
                    seriesList,
                    animate: false,
                    behaviors: [
                      chartRangeAnnotation(
                        widget.rangeStart,
                        widget.rangeEnd,
                      ),
                    ],
                    domainAxis: timeSeriesAxis,
                    defaultRenderer:
                        isBarChart ? defaultBarRenderer : defaultLineRenderer,
                    selectionModels: [
                      charts.SelectionModelConfig(
                        updatedListener: infoSelectionModelUpdated,
                      ),
                    ],
                    primaryMeasureAxis: charts.NumericAxisSpec(
                      tickProviderSpec: charts.BasicNumericTickProviderSpec(
                        zeroBound: isBarChart,
                        desiredTickCount: 5,
                        dataIsInWholeNumbers: false,
                      ),
                      renderSpec: numericRenderSpec,
                      tickFormatterSpec:
                          healthType != null && healthType.hoursMinutes
                              ? const charts.BasicNumericTickFormatterSpec(
                                  hoursToHhMm,
                                )
                              : null,
                    ),
                  )
                : TimeSeriesLineChart(
                    data: data,
                    rangeStart: widget.rangeStart,
                    rangeEnd: widget.rangeEnd,
                    unit: healthType?.unit ?? '',
                  ),
            chartHeader: HealthChartInfoWidget(widget.chartConfig),
            height: isBarChart ? 120 : 150,
          );
        },
      ),
    );
  }
}

class HealthChartInfoWidget extends StatelessWidget {
  const HealthChartInfoWidget(
    this.chartConfig, {
    super.key,
  });

  final DashboardHealthItem chartConfig;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HealthChartInfoCubit, HealthChartInfoState>(
      builder: (BuildContext context, HealthChartInfoState state) {
        final selected = state.selected;
        final healthType = healthTypes[chartConfig.healthType];

        final valueLabel = healthType?.hoursMinutes ?? false
            ? hoursToHhMm(selected?.value ?? 0)
            : ' ${NumberFormat('#,###.##').format(selected?.value ?? 0)}';

        return Positioned(
          top: 0,
          left: 10,
          child: SizedBox(
            width: max(MediaQuery.of(context).size.width, 300) - 20,
            child: IgnorePointer(
              child: Row(
                children: [
                  Text(
                    healthType?.displayName ?? chartConfig.healthType,
                    style: chartTitleStyle().copyWith(),
                  ),
                  if (selected != null) ...[
                    const Spacer(),
                    Padding(
                      padding: AppTheme.chartDateHorizontalPadding,
                      child: Text(
                        ' ${ymd(selected.dateTime)}',
                        style: chartTitleStyle(),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      ' $valueLabel',
                      style: chartTitleStyle().copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
