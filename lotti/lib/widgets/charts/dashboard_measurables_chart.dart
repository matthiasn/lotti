import 'dart:core';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/add/new_measurement_page.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/charts/utils.dart';

class DashboardMeasurablesChart extends StatelessWidget {
  final String measurableDataTypeId;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final bool enableCreate;

  DashboardMeasurablesChart({
    Key? key,
    required this.measurableDataTypeId,
    required this.rangeStart,
    required this.rangeEnd,
    this.enableCreate = false,
  }) : super(key: key);

  final JournalDb _db = getIt<JournalDb>();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MeasurableDataType?>>(
      stream: _db.watchMeasurableDataTypeById(measurableDataTypeId),
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
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
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
              if (enableCreate) {
                // String selectedId = measurableDataType.id;
                // context.router
                //     .pushNamed('journal/dashboard_add_measurement/$selectedId');

                // TODO: fix above & remove code below
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (BuildContext context) {
                      return NewMeasurementPage(
                        selected: measurableDataType,
                      );
                    },
                  ),
                );
              }
            }

            List<MeasureObservation> data;
            if (measurableDataType.aggregationType == AggregationType.none) {
              data = aggregateMeasurementNone(measurements);
            } else {
              data = aggregateSumByDay(
                measurements,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
              );
            }

            List<charts.Series<MeasureObservation, DateTime>> seriesList = [
              charts.Series<MeasureObservation, DateTime>(
                id: measurableDataType.id,
                colorFn: (MeasureObservation val, _) {
                  return charts.MaterialPalette.blue.shadeDefault;
                },
                domainFn: (MeasureObservation val, _) => val.dateTime,
                measureFn: (MeasureObservation val, _) => val.value,
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
                          animate: true,
                          defaultRenderer: defaultRenderer,
                          behaviors: [
                            chartRangeAnnotation(rangeStart, rangeEnd),
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
                                Text(
                                  measurableDataType.displayName,
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
              ),
            );
          },
        );
      },
    );
  }
}
