import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/dashboards/state/measurable_choice_series.dart';
import 'package:lotti/features/dashboards/state/measurables_controller.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_measurables_chart_info.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/measurable_choice_strip.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/stale_async_value.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_bar_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_line_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/charts/utils.dart';

/// Chart card for one measurable on a dashboard. The name is historical: this
/// renders a *bar* chart only when an aggregation is applied; with
/// `AggregationType.none` it renders a line chart of individual readings, and
/// a choice measurable gets a day strip — one cell per day coloured by the
/// day's latest choice, with a legend — since its numbers are occurrence
/// counts and no aggregation of those is a picture of the data.
///
/// Resolves the measurable definition and the effective aggregation (dashboard
/// override → type default → daily sum) via providers, then watches
/// [MeasurableObservationsController] and wraps the result in a stale-aware
/// [DashboardChart]. With `enableCreate` the header shows an add button that
/// opens the measurement capture dialog. Renders nothing until the measurable
/// definition has loaded.
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

    if (measurableDataType.isChoice) {
      return _ChoiceChart(
        dataType: measurableDataType,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        enableCreate: enableCreate,
      );
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

/// The choice measurable's card: the raw entries of the range reduced to one
/// choice per day, rendered as a strip under the shared date axis.
class _ChoiceChart extends ConsumerWidget {
  const _ChoiceChart({
    required this.dataType,
    required this.rangeStart,
    required this.rangeEnd,
    required this.enableCreate,
  });

  final MeasurableDataType dataType;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final bool enableCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    return StaleAsyncValue<List<JournalEntity>>(
      async: ref.watch(
        measurableChartDataControllerProvider((
          measurableDataTypeId: dataType.id,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        )),
      ),
      builder: (context, data, isInitialLoading) {
        final entries = data ?? const <JournalEntity>[];
        final days = choiceDaySeries(
          entries,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        );
        return DashboardChart(
          chart: MeasurableChoiceStrip(days: days, dataType: dataType),
          dateAxis: DashboardChartDateAxis(
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
          footer: MeasurableChoiceLegend(days: days, dataType: dataType),
          chartHeader: MeasurablesChartInfoWidget(
            dataType,
            enableCreate: enableCreate,
            aggregationType: AggregationType.none,
          ),
          isLoading: isInitialLoading,
          // Numeric entries from before the switch to choices are in range
          // but colour nothing; a strip of empty cells is not data.
          isEmpty: days.every((day) => day.choiceId == null),
          emptyMessage: context.messages.dashboardChartNoData,
          height: tokens.spacing.step10,
        );
      },
    );
  }
}
