import 'dart:core';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/charts/dashboard_health_bmi_data.dart';
import 'package:lotti/widgets/charts/dashboard_health_config.dart';
import 'package:lotti/widgets/charts/dashboard_health_data.dart';
import 'package:lotti/widgets/charts/utils.dart';

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
            List<JournalEntity?>? items = snapshot.data ?? [];

            List<Observation> weightData = aggregateNone(items, weightType);

            List<charts.RangeAnnotationSegment<num>> rangeAnnotationSegments =
                makeRangeAnnotationSegments(weightData, height);

            int tickCount = rangeAnnotationSegments.length * 2;
            charts.Color blue = charts.MaterialPalette.blue.shadeDefault;

            List<charts.Series<Observation, DateTime>> seriesList = [
              charts.Series<Observation, DateTime>(
                id: weightType,
                colorFn: (Observation val, _) => blue,
                domainFn: (Observation val, _) => val.dateTime,
                measureFn: (Observation val, _) => val.value,
                data: weightData,
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
                          charts.RangeAnnotation([
                            charts.RangeAnnotationSegment(rangeStart, rangeEnd,
                                charts.RangeAnnotationAxisType.domain,
                                color: charts.Color.white),
                            ...rangeAnnotationSegments,
                          ]),
                        ],
                        domainAxis: timeSeriesAxis,
                        defaultRenderer: defaultRenderer,
                        primaryMeasureAxis: charts.NumericAxisSpec(
                          tickProviderSpec: charts.BasicNumericTickProviderSpec(
                            zeroBound: false,
                            dataIsInWholeNumbers: true,
                            desiredTickCount: tickCount,
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
                      const BmiRangeLegend(),
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

class BmiRangeLegend extends StatelessWidget {
  const BmiRangeLegend({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 40,
      left: 40,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3), //New
              blurRadius: 8.0,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            color: Colors.white.withOpacity(0.75),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...bmiRanges.reversed.map(
                    (range) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              width: 12,
                              height: 12,
                              color: HexColor(range.hexColor).withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(
                            width: 6,
                          ),
                          Text(
                            range.name,
                            style: chartTitleStyle.copyWith(
                              fontSize: 10,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
