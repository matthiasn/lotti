import 'dart:core';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/charts/dashboard_health_config.dart';
import 'package:lotti/widgets/charts/dashboard_health_data.dart';
import 'package:lotti/widgets/charts/utils.dart';

num calculateBMI(num height, num weight) {
  num heightSquare = height * height;
  return weight / heightSquare;
}

charts.RangeAnnotationSegment<num> makeRange(
  Color color,
  double from,
  double to,
) {
  return charts.RangeAnnotationSegment(
    from,
    to,
    charts.RangeAnnotationAxisType.measure,
    color: charts.Color(
      r: color.red,
      g: color.green,
      b: color.blue,
      a: 100,
    ),
  );
}

class DashboardHealthBmiChart extends StatelessWidget {
  final DashboardHealthItem chartConfig;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  DashboardHealthBmiChart({
    Key? key,
    required this.chartConfig,
    required this.rangeStart,
    required this.rangeEnd,
  }) : super(key: key);

  final JournalDb _db = getIt<JournalDb>();

  @override
  Widget build(BuildContext context) {
    String weightType = 'HealthDataType.WEIGHT';

    charts.SeriesRendererConfig<DateTime>? defaultRenderer =
        charts.LineRendererConfig<DateTime>(
      includePoints: false,
      strokeWidthPx: 2,
    );

    return StreamBuilder<List<JournalEntity?>>(
      stream: _db.watchQuantitativeByType(
        type: 'HealthDataType.HEIGHT',
        rangeStart: DateTime(2010),
        rangeEnd: DateTime.now(),
      ),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<JournalEntity?>> snapshot,
      ) {
        QuantitativeEntry? weightEntry =
            snapshot.data?.first as QuantitativeEntry?;
        num height = weightEntry?.data.value ?? 0;

        return StreamBuilder<List<JournalEntity?>>(
          stream: _db.watchQuantitativeByType(
            type: weightType,
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

            List<Observation> weightData = aggregateNone(items);
            List<Observation> bmiData = weightData
                .map((Observation o) =>
                    Observation(o.dateTime, calculateBMI(height, o.value)))
                .toList();

            charts.Color blue = charts.MaterialPalette.blue.shadeDefault;

            List<charts.Series<Observation, DateTime>> seriesList = [
              charts.Series<Observation, DateTime>(
                id: weightType,
                colorFn: (Observation val, _) => blue,
                domainFn: (Observation val, _) => val.dateTime,
                measureFn: (Observation val, _) => val.value,
                data: bmiData,
              ),
            ];

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  key: Key('${chartConfig.hashCode}'),
                  color: Colors.white,
                  height: 320,
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Stack(
                    children: [
                      charts.TimeSeriesChart(
                        seriesList,
                        animate: true,
                        behaviors: [
                          charts.RangeAnnotation(
                            [
                              makeRange(Colors.green, 18.5, 24.99),
                              makeRange(Colors.yellow, 25, 29.99),
                              makeRange(Colors.orange, 30, 34.99),
                              makeRange(Colors.red, 35, 39.99),
                            ],
                          )
                        ],
                        domainAxis: timeSeriesAxis,
                        defaultRenderer: defaultRenderer,
                        primaryMeasureAxis: const charts.NumericAxisSpec(
                          tickProviderSpec: charts.BasicNumericTickProviderSpec(
                            zeroBound: false,
                            dataIsInWholeNumbers: true,
                            desiredMinTickCount: 6,
                            desiredMaxTickCount: 8,
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
                                healthTypes[chartConfig.healthType]
                                        ?.displayName ??
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
      },
    );
  }
}
