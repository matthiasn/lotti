import 'dart:core';

import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_measurables_chart_info.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/widgets/charts/dashboard_chart.dart';
import 'package:lotti/widgets/charts/time_series/time_series_line_chart.dart';
import 'package:lotti/widgets/charts/utils.dart';

class DashboardMeasurablesLineChart extends StatelessWidget {
  const DashboardMeasurablesLineChart({
    required this.measurableDataTypeId,
    required this.dashboardId,
    required this.rangeStart,
    required this.rangeEnd,
    this.enableCreate = false,
    super.key,
  });

  final String measurableDataTypeId;
  final String? dashboardId;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final bool enableCreate;

  @override
  Widget build(BuildContext context) {
    final db = getIt<JournalDb>();

    return StreamBuilder<MeasurableDataType?>(
      stream: db.watchMeasurableDataTypeById(measurableDataTypeId),
      builder: (
        BuildContext context,
        AsyncSnapshot<MeasurableDataType?> typeSnapshot,
      ) {
        final measurableDataType = typeSnapshot.data;

        if (measurableDataType == null) {
          return const SizedBox.shrink();
        }

        return StreamBuilder<List<JournalEntity>>(
          stream: db.watchMeasurementsByType(
            type: measurableDataType.id,
            rangeStart: rangeStart.subtract(const Duration(hours: 12)),
            rangeEnd: rangeEnd,
          ),
          builder: (
            BuildContext context,
            AsyncSnapshot<List<JournalEntity>> measurementsSnapshot,
          ) {
            final measurements = measurementsSnapshot.data ?? [];

            final aggregationType =
                measurableDataType.aggregationType ?? AggregationType.none;

            List<Observation> data;
            if (aggregationType == AggregationType.none) {
              data = aggregateMeasurementNone(measurements);
            } else if (aggregationType == AggregationType.dailyMax) {
              data = aggregateMaxByDay(
                measurements,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
              );
            } else if (aggregationType == AggregationType.hourlySum) {
              data = aggregateSumByHour(
                measurements,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
              );
            } else {
              data = aggregateSumByDay(
                measurements,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
              );
            }

            return DashboardChart(
              topMargin: 20,
              chartHeader: MeasurablesChartInfoWidget(
                measurableDataType,
                dashboardId: dashboardId,
                enableCreate: enableCreate,
                aggregationType: aggregationType,
              ),
              height: 180,
              chart: TimeSeriesLineChart(
                data: data,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
                unit: measurableDataType.unitName,
              ),
            );
          },
        );
      },
    );
  }
}
