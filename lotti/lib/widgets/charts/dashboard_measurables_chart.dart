import 'dart:core';

import 'package:auto_route/auto_route.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lotti/blocs/charts/measurables_chart_info_cubit.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/charts/utils.dart';

class DashboardMeasurablesChart extends StatefulWidget {
  final String measurableDataTypeId;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final bool enableCreate;

  const DashboardMeasurablesChart({
    Key? key,
    required this.measurableDataTypeId,
    required this.rangeStart,
    required this.rangeEnd,
    this.enableCreate = false,
  }) : super(key: key);

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
        MeasurableDataType? measurableDataType = typeSnapshot.data;

        if (measurableDataType == null) {
          return const SizedBox.shrink();
        }

        return BlocProvider<MeasurablesChartInfoCubit>(
          create: (BuildContext context) => MeasurablesChartInfoCubit(),
          child: StreamBuilder<List<JournalEntity?>>(
            stream: _db.watchMeasurementsByType(
              type: measurableDataType.id,
              rangeStart: widget.rangeStart,
              rangeEnd: widget.rangeEnd,
            ),
            builder: (
              BuildContext context,
              AsyncSnapshot<List<JournalEntity?>> measurementsSnapshot,
            ) {
              List<JournalEntity?>? measurements =
                  measurementsSnapshot.data ?? [];

              charts.SeriesRendererConfig<DateTime>? defaultRenderer;

              final bool aggregationNone =
                  measurableDataType.aggregationType == AggregationType.none;

              if (aggregationNone) {
                defaultRenderer = charts.LineRendererConfig<DateTime>(
                  includePoints: false,
                  strokeWidthPx: 2,
                );
              } else {
                defaultRenderer = charts.BarRendererConfig<DateTime>();
              }

              void onDoubleTap() {
                if (widget.enableCreate) {
                  context.router.push(CreateMeasurementWithTypeRoute(
                      selectedId: measurableDataType.id));
                }
              }

              List<MeasuredObservation> data;
              if (measurableDataType.aggregationType == AggregationType.none) {
                data = aggregateMeasurementNone(measurements);
              } else {
                data = aggregateSumByDay(
                  measurements,
                  rangeStart: widget.rangeStart,
                  rangeEnd: widget.rangeEnd,
                );
              }

              void _infoSelectionModelUpdated(
                  charts.SelectionModel<DateTime> model) {
                if (model.hasDatumSelection) {
                  MeasuredObservation newSelection =
                      model.selectedDatum.first.datum as MeasuredObservation;
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

              List<charts.Series<MeasuredObservation, DateTime>> seriesList = [
                charts.Series<MeasuredObservation, DateTime>(
                  id: measurableDataType.displayName,
                  colorFn: (MeasuredObservation val, _) {
                    return charts.MaterialPalette.blue.shadeDefault;
                  },
                  domainFn: (MeasuredObservation val, _) => val.dateTime,
                  measureFn: (MeasuredObservation val, _) => val.value,
                  data: data,
                )
              ];
              return GestureDetector(
                onDoubleTap: onDoubleTap,
                onLongPress: onDoubleTap,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      key: Key(measurableDataType.description),
                      color: Colors.white,
                      height: 120,
                      padding: const EdgeInsets.all(8.0),
                      child: Stack(
                        children: [
                          charts.TimeSeriesChart(
                            seriesList,
                            animate: false,
                            defaultRenderer: defaultRenderer,
                            selectionModels: [
                              charts.SelectionModelConfig(
                                type: charts.SelectionModelType.info,
                                updatedListener: _infoSelectionModelUpdated,
                              )
                            ],
                            behaviors: [
                              chartRangeAnnotation(
                                  widget.rangeStart, widget.rangeEnd)
                            ],
                            domainAxis: timeSeriesAxis,
                            primaryMeasureAxis: charts.NumericAxisSpec(
                              tickProviderSpec:
                                  charts.BasicNumericTickProviderSpec(
                                zeroBound: !aggregationNone,
                                dataIsInWholeNumbers: true,
                                desiredTickCount: 4,
                              ),
                            ),
                          ),
                          MeasurablesChartInfoWidget(measurableDataType),
                        ],
                      ),
                    ),
                  ),
                ),
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
    Key? key,
  }) : super(key: key);

  final MeasurableDataType measurableDataType;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MeasurablesChartInfoCubit, MeasurablesChartInfoState>(
        builder: (BuildContext context, MeasurablesChartInfoState state) {
      final MeasuredObservation? selected = state.selected;

      return Positioned(
        top: -4,
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
                  measurableDataType.displayName,
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
                    ' ${selected.value.floor()} ${measurableDataType.unitName}',
                    style:
                        chartTitleStyle.copyWith(fontWeight: FontWeight.bold),
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
