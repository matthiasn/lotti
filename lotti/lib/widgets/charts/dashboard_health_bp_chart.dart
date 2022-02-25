import 'dart:core';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/charts/dashboard_health_data.dart';
import 'package:lotti/widgets/charts/utils.dart';

class DashboardHealthBpChart extends StatelessWidget {
  final DashboardHealthItem chartConfig;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  DashboardHealthBpChart({
    Key? key,
    required this.chartConfig,
    required this.rangeStart,
    required this.rangeEnd,
  }) : super(key: key);

  final JournalDb _db = getIt<JournalDb>();

  @override
  Widget build(BuildContext context) {
    String systolicType = 'HealthDataType.BLOOD_PRESSURE_SYSTOLIC';
    String diastolicType = 'HealthDataType.BLOOD_PRESSURE_DIASTOLIC';
    List<String> dataTypes = [systolicType, diastolicType];

    charts.SeriesRendererConfig<DateTime>? defaultRenderer =
        charts.LineRendererConfig<DateTime>(
      includePoints: false,
      strokeWidthPx: 2,
    );

    return StreamBuilder<List<JournalEntity?>>(
      stream: _db.watchQuantitativeByTypes(
        types: dataTypes,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      ),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<JournalEntity?>> snapshot,
      ) {
        List<JournalEntity?>? items = snapshot.data;

        if (items == null || items.isEmpty) {
          return const SizedBox.shrink();
        }

        List<Observation> systolicData =
            aggregateNoneFilteredBy(items, systolicType);
        List<Observation> diastolicData =
            aggregateNoneFilteredBy(items, diastolicType);

        charts.Color blue = charts.MaterialPalette.blue.shadeDefault;
        charts.Color red = charts.MaterialPalette.red.shadeDefault;

        List<charts.Series<Observation, DateTime>> seriesList = [
          charts.Series<Observation, DateTime>(
            id: systolicType,
            colorFn: (Observation val, _) => red,
            domainFn: (Observation val, _) => val.dateTime,
            measureFn: (Observation val, _) => val.value,
            data: systolicData,
          ),
          charts.Series<Observation, DateTime>(
            id: diastolicType,
            colorFn: (Observation val, _) => blue,
            domainFn: (Observation val, _) => val.dateTime,
            measureFn: (Observation val, _) => val.value,
            data: diastolicData,
          ),
        ];

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              key: Key('${chartConfig.hashCode}'),
              color: Colors.white,
              height: 200,
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Stack(
                children: [
                  charts.TimeSeriesChart(
                    seriesList,
                    animate: true,
                    behaviors: [
                      charts.RangeAnnotation(
                        [
                          charts.RangeAnnotationSegment(
                            rangeStart,
                            rangeEnd,
                            charts.RangeAnnotationAxisType.domain,
                            color: charts.MaterialPalette.white,
                          ),
                          charts.RangeAnnotationSegment(
                            60,
                            80,
                            charts.RangeAnnotationAxisType.measure,
                            color: charts.Color(
                              r: blue.r,
                              g: blue.g,
                              b: blue.b,
                              a: 24,
                            ),
                          ),
                          charts.RangeAnnotationSegment(
                            90,
                            130,
                            charts.RangeAnnotationAxisType.measure,
                            color: charts.Color(
                              r: red.r,
                              g: red.g,
                              b: red.b,
                              a: 24,
                            ),
                          ),
                        ],
                      )
                    ],
                    domainAxis: timeSeriesAxis,
                    defaultRenderer: defaultRenderer,
                    primaryMeasureAxis: const charts.NumericAxisSpec(
                      tickProviderSpec: charts.BasicNumericTickProviderSpec(
                        zeroBound: false,
                        dataIsInWholeNumbers: true,
                        desiredMinTickCount: 11,
                        desiredMaxTickCount: 15,
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
                            healthTypes[chartConfig.healthType]?.displayName ??
                                chartConfig.healthType,
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
