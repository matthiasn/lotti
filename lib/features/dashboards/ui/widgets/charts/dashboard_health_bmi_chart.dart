import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/config/dashboard_health_config.dart';
import 'package:lotti/features/dashboards/state/health_bmi_data.dart';
import 'package:lotti/features/dashboards/state/health_chart_controller.dart';
import 'package:lotti/features/dashboards/state/health_data.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_line_chart.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/charts/utils.dart';

/// Legend for the BMI weight bands, rendered below the chart (in the card
/// footer) so it never occludes the weight series.
class BmiRangeLegend extends StatelessWidget {
  const BmiRangeLegend({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardChartLegend(
      entries: [
        for (final range in bmiRanges.reversed)
          DashboardLegendEntry(
            color: colorFromCssHex(range.hexColor),
            label: range.name,
          ),
      ],
    );
  }
}

class BmiChartInfoWidget extends ConsumerWidget {
  const BmiChartInfoWidget(
    this.chartConfig, {
    required this.minInRange,
    required this.maxInRange,
    super.key,
  });

  final DashboardHealthItem chartConfig;
  final num minInRange;
  final num maxInRange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final minWeight = '${NumberFormat('#,###.#').format(minInRange)} kg';
    final maxWeight = '${NumberFormat('#,###.#').format(maxInRange)} kg';

    return DashboardChartHeader(
      title:
          healthTypes[chartConfig.healthType]?.displayName ??
          chartConfig.healthType,
      trailing: Text(
        '$minWeight – $maxWeight',
        style: tokens.typography.styles.others.caption.copyWith(
          color: tokens.colors.text.mediumEmphasis,
          fontWeight: tokens.typography.weight.semiBold,
        ),
      ),
    );
  }
}

class DashboardHealthBmiChart extends ConsumerWidget {
  const DashboardHealthBmiChart({
    required this.chartConfig,
    required this.rangeStart,
    required this.rangeEnd,
    this.transformationController,
    super.key,
  });

  final DashboardHealthItem chartConfig;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final TransformationController? transformationController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weightAsync = ref.watch(
      healthObservationsControllerProvider(
        healthDataType: 'HealthDataType.WEIGHT',
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
      ),
    );
    final weightData = weightAsync.value ?? const <Observation>[];

    final minInRange = findMin(weightData);
    final maxInRange = findMax(weightData);
    return DashboardChart(
      chart: TimeSeriesLineChart(
        data: weightData,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        transformationController: transformationController,
      ),
      chartHeader: BmiChartInfoWidget(
        chartConfig,
        minInRange: minInRange,
        maxInRange: maxInRange,
      ),
      isLoading: weightAsync.isLoading && !weightAsync.hasValue,
      isEmpty: weightData.isEmpty,
      emptyMessage: context.messages.dashboardChartNoData,
      footer: const BmiRangeLegend(),
      height: 320,
    );
  }
}
