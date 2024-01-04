import 'dart:core';

import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/charts/dashboard_chart.dart';
import 'package:lotti/widgets/charts/dashboard_measurables_chart_info.dart';
import 'package:lotti/widgets/charts/dashboard_measurables_line_chart.dart';
import 'package:lotti/widgets/charts/time_series/time_series_bar_chart.dart';
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

        return StreamBuilder<List<JournalEntity>>(
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

            return DashboardChart(
              topMargin: 10,
              chart: TimeSeriesBarChart(
                data: data,
                rangeStart: widget.rangeStart,
                rangeEnd: widget.rangeEnd,
                unit: measurableDataType.unitName,
                colorByValue: (Observation observation) =>
                    colorFromCssHex('#82E6CE'),
              ),
              chartHeader: MeasurablesChartInfoWidget(
                measurableDataType,
                dashboardId: widget.dashboardId,
                enableCreate: widget.enableCreate,
                aggregationType: aggregationType,
              ),
              height: 180,
            );
          },
        );
      },
    );
  }
}
