import 'dart:core';

import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/charts/utils.dart';

class DashboardBarChart extends StatelessWidget {
  final String measurableDataTypeId;

  DashboardBarChart({
    Key? key,
    required this.measurableDataTypeId,
    required this.durationDays,
  }) : super(key: key);

  final JournalDb _db = getIt<JournalDb>();
  final int durationDays;

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
            measurableDataType.name,
            DateTime.now().subtract(Duration(days: durationDays)),
          ),
          builder: (
            BuildContext context,
            AsyncSnapshot<List<JournalEntity?>> measurementsSnapshot,
          ) {
            List<JournalEntity?>? measurements = measurementsSnapshot.data;

            if (measurements == null || measurements.isEmpty) {
              return const SizedBox.shrink();
            }

            List<charts.Series<SumPerDay, DateTime>> seriesList = [
              charts.Series<SumPerDay, DateTime>(
                id: measurableDataType.id,
                colorFn: (SumPerDay val, _) {
                  return charts.MaterialPalette.blue.shadeDefault;
                },
                domainFn: (SumPerDay val, _) => val.day,
                measureFn: (SumPerDay val, _) => val.sum,
                data: aggregateByDay(measurements),
              )
            ];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  key: Key(measurableDataType.description),
                  color: Colors.white,
                  height: 160,
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Text(
                        measurableDataType.displayName,
                        style: chartTitleStyle,
                      ),
                      Expanded(
                        child: charts.TimeSeriesChart(
                          seriesList,
                          animate: true,
                          defaultRenderer: charts.BarRendererConfig<DateTime>(),
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
