import 'dart:core';

import 'package:beamer/beamer.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
import 'package:lotti/blocs/charts/measurables_chart_info_cubit.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/charts/dashboard_chart.dart';
import 'package:lotti/widgets/charts/dashboard_measurables_line_chart.dart';
import 'package:lotti/widgets/charts/utils.dart';

class DashboardMeasurablesChart extends StatefulWidget {
  const DashboardMeasurablesChart({
    required this.measurableDataTypeId,
    required this.dashboardId,
    required this.rangeStart,
    required this.rangeEnd,
    this.aggregationType,
    this.enableCreate = false,
    super.key,
  });

  final String measurableDataTypeId;
  final String? dashboardId;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final bool enableCreate;
  final AggregationType? aggregationType;

  @override
  State<DashboardMeasurablesChart> createState() =>
      _DashboardMeasurablesChartState();
}

class _DashboardMeasurablesChartState extends State<DashboardMeasurablesChart> {
  final _chartState = charts.UserManagedState<DateTime>();
  final JournalDb _db = getIt<JournalDb>();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MeasurableDataType?>(
      stream: _db.watchMeasurableDataTypeById(widget.measurableDataTypeId),
      builder: (
        BuildContext context,
        AsyncSnapshot<MeasurableDataType?> typeSnapshot,
      ) {
        final measurableDataType = typeSnapshot.data;

        if (measurableDataType == null) {
          return const SizedBox.shrink();
        }

        final aggregationType = widget.aggregationType ??
            measurableDataType.aggregationType ??
            AggregationType.none;

        final aggregationNone = aggregationType == AggregationType.none;

        if (aggregationNone) {
          return DashboardMeasurablesLineChart(
            measurableDataTypeId: widget.measurableDataTypeId,
            dashboardId: widget.dashboardId,
            rangeStart: widget.rangeStart,
            rangeEnd: widget.rangeEnd,
            enableCreate: true,
          );
        }

        return BlocProvider<MeasurablesChartInfoCubit>(
          create: (BuildContext context) => MeasurablesChartInfoCubit(),
          child: StreamBuilder<List<JournalEntity>>(
            stream: _db.watchMeasurementsByType(
              type: measurableDataType.id,
              rangeStart: widget.rangeStart.subtract(const Duration(hours: 12)),
              rangeEnd: widget.rangeEnd,
            ),
            builder: (
              BuildContext context,
              AsyncSnapshot<List<JournalEntity>> measurementsSnapshot,
            ) {
              final measurements = measurementsSnapshot.data ?? [];

              charts.SeriesRendererConfig<DateTime>? defaultRenderer;

              if (aggregationNone) {
                defaultRenderer = charts.LineRendererConfig<DateTime>();
              } else {
                defaultRenderer = defaultBarRenderer;
              }

              List<Observation> data;
              if (aggregationType == AggregationType.none) {
                data = aggregateMeasurementNone(measurements);
              } else if (aggregationType == AggregationType.dailyMax) {
                data = aggregateMaxByDay(
                  measurements,
                  rangeStart: widget.rangeStart,
                  rangeEnd: widget.rangeEnd,
                );
              } else if (aggregationType == AggregationType.hourlySum) {
                data = aggregateSumByHour(
                  measurements,
                  rangeStart: widget.rangeStart,
                  rangeEnd: widget.rangeEnd,
                );
              } else {
                data = aggregateSumByDay(
                  measurements,
                  rangeStart: widget.rangeStart,
                  rangeEnd: widget.rangeEnd,
                );
              }

              void infoSelectionModelUpdated(
                charts.SelectionModel<DateTime> model,
              ) {
                if (model.hasDatumSelection) {
                  final newSelection =
                      model.selectedDatum.first.datum as Observation;
                  context
                      .read<MeasurablesChartInfoCubit>()
                      .setSelected(newSelection);

                  _chartState.selectionModels[charts.SelectionModelType.info] =
                      charts.UserManagedSelectionModel(model: model);
                } else {
                  context.read<MeasurablesChartInfoCubit>().clearSelected();
                  _chartState.selectionModels[charts.SelectionModelType.info] =
                      charts.UserManagedSelectionModel();
                }
              }

              final seriesList = [
                charts.Series<Observation, DateTime>(
                  id: measurableDataType.displayName,
                  colorFn: (Observation val, _) {
                    return charts.Color.fromHex(code: '#82E6CE');
                  },
                  domainFn: (Observation val, _) => val.dateTime,
                  measureFn: (Observation val, _) => val.value,
                  data: data,
                )
              ];
              return DashboardChart(
                topMargin: 10,
                chart: charts.TimeSeriesChart(
                  seriesList,
                  animate: false,
                  defaultRenderer: defaultRenderer,
                  selectionModels: [
                    charts.SelectionModelConfig(
                      updatedListener: infoSelectionModelUpdated,
                    )
                  ],
                  behaviors: [
                    chartRangeAnnotation(
                      aggregationType == AggregationType.none
                          ? widget.rangeStart
                              .subtract(const Duration(hours: 36))
                          : aggregationType == AggregationType.hourlySum
                              ? widget.rangeStart
                                  .subtract(const Duration(days: 1))
                              : widget.rangeStart,
                      widget.rangeEnd,
                    )
                  ],
                  domainAxis: timeSeriesAxis,
                  primaryMeasureAxis: charts.NumericAxisSpec(
                    tickProviderSpec: charts.BasicNumericTickProviderSpec(
                      zeroBound: !aggregationNone,
                      dataIsInWholeNumbers: false,
                      desiredMinTickCount: 4,
                      desiredMaxTickCount: 5,
                    ),
                    renderSpec: numericRenderSpec,
                  ),
                ),
                chartHeader: MeasurablesChartInfoWidget(
                  measurableDataType,
                  dashboardId: widget.dashboardId,
                  enableCreate: widget.enableCreate,
                  aggregationType: aggregationType,
                ),
                height: aggregationNone ? 272 : 136,
              );
            },
          ),
        );
      },
    );
  }
}

class MeasurablesChartInfoWidget extends StatelessWidget {
  const MeasurablesChartInfoWidget(
    this.measurableDataType, {
    required this.dashboardId,
    required this.aggregationType,
    required this.enableCreate,
    super.key,
  });

  final MeasurableDataType measurableDataType;
  final AggregationType aggregationType;
  final String? dashboardId;
  final bool enableCreate;

  void onTapAdd() {
    final beamState =
        dashboardsBeamerDelegate.currentBeamLocation.state as BeamState;

    final id =
        beamState.uri.path.contains('carousel') ? 'carousel' : dashboardId;

    beamToNamed(
      '/dashboards/$id/measure/${measurableDataType.id}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MeasurablesChartInfoCubit, MeasurablesChartInfoState>(
      builder: (BuildContext context, MeasurablesChartInfoState state) {
        final selected = state.selected;

        return Positioned(
          top: 0,
          left: 10,
          child: SizedBox(
            width: MediaQuery.of(context).size.width - 20,
            child: Row(
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width / 2,
                  ),
                  child: Text(
                    '${measurableDataType.displayName}'
                    '${aggregationType != AggregationType.none ? ' ' : ''}'
                    '${aggregationLabel(aggregationType)}',
                    style: chartTitleStyle(),
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
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
                    ' ${NumberFormat('#,###.##').format(selected.value)}'
                    ' ${measurableDataType.unitName}',
                    style:
                        chartTitleStyle().copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
                const Spacer(),
                if (enableCreate)
                  IconButton(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    onPressed: onTapAdd,
                    hoverColor: Colors.transparent,
                    icon: SvgPicture.asset(styleConfig().addIcon),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String aggregationLabel(AggregationType? aggregationType) {
  if (aggregationType == null) {
    return '';
  }
  return aggregationType != AggregationType.none
      ? '[${EnumToString.convertToString(aggregationType)}]'
      : '';
}
