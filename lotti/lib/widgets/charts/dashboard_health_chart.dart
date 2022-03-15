import 'dart:core';

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
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/charts/dashboard_health_bmi_chart.dart';
import 'package:lotti/widgets/charts/dashboard_health_config.dart';
import 'package:lotti/widgets/charts/dashboard_health_data.dart';
import 'package:lotti/widgets/charts/utils.dart';

import 'dashboard_health_bp_chart.dart';

class DashboardHealthChart extends StatefulWidget {
  final DashboardHealthItem chartConfig;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  const DashboardHealthChart({
    Key? key,
    required this.chartConfig,
    required this.rangeStart,
    required this.rangeEnd,
  }) : super(key: key);

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
    _healthImport.fetchHealthDataDelta(widget.chartConfig.healthType);
  }

  @override
  Widget build(BuildContext context) {
    String dataType = widget.chartConfig.healthType;

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

    HealthTypeConfig? healthType = healthTypes[dataType];
    charts.SeriesRendererConfig<DateTime>? defaultRenderer;

    if (healthType?.chartType == HealthChartType.barChart) {
      defaultRenderer = charts.BarRendererConfig<DateTime>();
    } else {
      defaultRenderer = charts.LineRendererConfig<DateTime>(
        includePoints: false,
        strokeWidthPx: 2,
      );
    }

    return BlocProvider<HealthChartInfoCubit>(
      create: (BuildContext context) => HealthChartInfoCubit(),
      child: StreamBuilder<List<JournalEntity?>>(
        stream: _db.watchQuantitativeByType(
          type: widget.chartConfig.healthType,
          rangeStart: widget.rangeStart,
          rangeEnd: widget.rangeEnd,
        ),
        builder: (
          BuildContext context,
          AsyncSnapshot<List<JournalEntity?>> snapshot,
        ) {
          void _infoSelectionModelUpdated(
              charts.SelectionModel<DateTime> model) {
            if (model.hasDatumSelection) {
              Observation newSelection =
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

          List<JournalEntity?>? items = snapshot.data ?? [];

          List<charts.Series<Observation, DateTime>> seriesList = [
            charts.Series<Observation, DateTime>(
              id: dataType,
              colorFn: (Observation val, _) {
                return colorByValue(val, healthType);
              },
              domainFn: (Observation val, _) => val.dateTime,
              measureFn: (Observation val, _) => val.value,
              data: aggregateByType(items, dataType),
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
                      primaryMeasureAxis: charts.NumericAxisSpec(
                        tickProviderSpec:
                            const charts.BasicNumericTickProviderSpec(
                          zeroBound: false,
                          desiredTickCount: 5,
                          dataIsInWholeNumbers: true,
                        ),
                        tickFormatterSpec:
                            healthType != null && healthType.hoursMinutes
                                ? const charts.BasicNumericTickFormatterSpec(
                                    hoursToHhMm)
                                : null,
                      ),
                    ),
                    HealthChartInfoWidget(widget.chartConfig),
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

class HealthChartInfoWidget extends StatelessWidget {
  const HealthChartInfoWidget(
    this.chartConfig, {
    Key? key,
  }) : super(key: key);

  final DashboardHealthItem chartConfig;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HealthChartInfoCubit, HealthChartInfoState>(
        builder: (BuildContext context, HealthChartInfoState state) {
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
                  healthTypes[chartConfig.healthType]?.displayName ??
                      chartConfig.healthType,
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
