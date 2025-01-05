import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/state/measurables_controller.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_measurables_chart_info.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_bar_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_line_chart.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/charts/utils.dart';

class MeasurablesBarChart extends ConsumerWidget {
  const MeasurablesBarChart({
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
  Widget build(BuildContext context, WidgetRef ref) {
    final measurableDataType = ref
        .watch(measurableDataTypeControllerProvider(id: measurableDataTypeId))
        .valueOrNull;

    if (measurableDataType == null) {
      return const SizedBox.shrink();
    }

    final chartAggregationType = ref
            .watch(
              aggregationTypeControllerProvider(
                measurableDataTypeId: measurableDataTypeId,
                dashboardDefinedAggregationType: aggregationType,
              ),
            )
            .valueOrNull ??
        AggregationType.none;

    final data = ref
            .watch(
              measurableObservationsControllerProvider(
                measurableDataTypeId: measurableDataTypeId,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd,
                dashboardDefinedAggregationType: chartAggregationType,
              ),
            )
            .valueOrNull ??
        [];

    return DashboardChart(
      topMargin: 10,
      chart: chartAggregationType == AggregationType.none
          ? TimeSeriesLineChart(
              data: data,
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
              unit: measurableDataType.unitName,
            )
          : TimeSeriesBarChart(
              data: data,
              rangeStart: rangeStart,
              rangeEnd: rangeEnd,
              unit: measurableDataType.unitName,
              colorByValue: (Observation observation) =>
                  colorFromCssHex('#82E6CE'),
            ),
      chartHeader: MeasurablesChartInfoWidget(
        measurableDataType,
        dashboardId: dashboardId,
        enableCreate: enableCreate,
        aggregationType: chartAggregationType,
      ),
      height: 180,
    );
  }
}
