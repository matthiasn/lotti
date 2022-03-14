import 'dart:core';

import 'package:auto_route/auto_route.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
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
  MeasuredObservation? selected;

  final JournalDb _db = getIt<JournalDb>();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MeasurableDataType?>>(
      stream: _db.watchMeasurableDataTypeById(widget.measurableDataTypeId),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<MeasurableDataType?>> typeSnapshot,
      ) {
        if (typeSnapshot.data == null || typeSnapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        MeasurableDataType? measurableDataType = typeSnapshot.data?.first;

        if (measurableDataType == null) {
          return const SizedBox.shrink();
        }

        return StreamBuilder<List<JournalEntity?>>(
          stream: _db.watchMeasurementsByType(
            type: measurableDataType.name,
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

            if (measurableDataType.aggregationType == AggregationType.none) {
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
                setState(() {
                  selected = selected?.dateTime == newSelection.dateTime
                      ? null
                      : newSelection;
                });
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
                        ),
                        Positioned(
                          top: -4,
                          left: MediaQuery.of(context).size.width / 4,
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width / 2,
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
                                  Text(
                                    ' ${ymd(selected!.dateTime)}',
                                    style: chartTitleStyle,
                                  ),
                                  const Spacer(),
                                  Text(
                                    ' ${selected?.value.floor()} ${measurableDataType.unitName}',
                                    style: chartTitleStyle.copyWith(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                                const Spacer(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
