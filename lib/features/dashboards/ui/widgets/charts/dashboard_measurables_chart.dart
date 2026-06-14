import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/state/measurables_controller.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_measurables_chart_info.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/stale_async_value.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_bar_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_line_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/charts/utils.dart';

class MeasurablesBarChart extends ConsumerWidget {
  const MeasurablesBarChart({
    required this.measurableDataTypeId,
    required this.rangeStart,
    required this.rangeEnd,
    this.aggregationType,
    this.enableCreate = false,
    super.key,
  });

  final String measurableDataTypeId;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final bool enableCreate;
  final AggregationType? aggregationType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final measurableDataType = ref
        .watch(measurableDataTypeControllerProvider(measurableDataTypeId))
        .value;

    if (measurableDataType == null) {
      return const SizedBox.shrink();
    }

    final chartAggregationType =
        ref
            .watch(
              aggregationTypeControllerProvider((
                measurableDataTypeId: measurableDataTypeId,
                dashboardDefinedAggregationType: aggregationType,
              )),
            )
            .value ??
        AggregationType.none;

    final tokens = context.designTokens;

    return StaleAsyncValue<List<Observation>>(
      async: ref.watch(
        measurableObservationsControllerProvider((
          measurableDataTypeId: measurableDataTypeId,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          dashboardDefinedAggregationType: chartAggregationType,
        )),
      ),
      builder: (context, data, isInitialLoading) {
        final observations = data ?? const <Observation>[];
        return DashboardChart(
          chart: chartAggregationType == AggregationType.none
              ? TimeSeriesLineChart(
                  data: observations,
                  rangeStart: rangeStart,
                  rangeEnd: rangeEnd,
                  unit: measurableDataType.unitName,
                )
              : TimeSeriesBarChart(
                  data: observations,
                  rangeStart: rangeStart,
                  rangeEnd: rangeEnd,
                  unit: measurableDataType.unitName,
                  colorByValue: (Observation observation) =>
                      tokens.colors.interactive.enabled,
                ),
          dateAxis: DashboardChartDateAxis(
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
          chartHeader: MeasurablesChartInfoWidget(
            measurableDataType,
            enableCreate: enableCreate,
            aggregationType: chartAggregationType,
          ),
          isLoading: isInitialLoading,
          isEmpty: observations.isEmpty,
          emptyMessage: context.messages.dashboardChartNoData,
          height: 180,
        );
      },
    );
  }
}
