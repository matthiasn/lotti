import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/config/dashboard_health_config.dart';
import 'package:lotti/features/dashboards/state/health_chart_controller.dart';
import 'package:lotti/features/dashboards/state/health_data.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/stale_async_value.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_line_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/charts/utils.dart';

/// Header for the BMI/weight chart card. Titled "Weight" (the card actually
/// plots weight, despite the configured BMI type's misleading display name) and
/// shows the in-range min–max weight as a trailing readout.
class BmiChartInfoWidget extends ConsumerWidget {
  const BmiChartInfoWidget({
    required this.minInRange,
    required this.maxInRange,
    super.key,
  });

  final num minInRange;
  final num maxInRange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final minWeight = '${NumberFormat('#,###.#').format(minInRange)} kg';
    final maxWeight = '${NumberFormat('#,###.#').format(maxInRange)} kg';

    return DashboardChartHeader(
      // The chart plots WEIGHT (not a BMI comparison), so the card title is the
      // weight health type's display name rather than the configured BMI type's
      // misleading "Weight vs. Body Mass Index".
      title: healthTypes['HealthDataType.WEIGHT']?.displayName ?? 'Weight',
      subtitle: 'kg',
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

/// "Weight vs. Body Mass Index" chart card. Despite the name and the
/// `BODY_MASS_INDEX` config key, it plots the **weight** series (a tall line
/// chart), not BMI: it always watches `HealthDataType.WEIGHT` observations and
/// surfaces the in-range min/max weight in its header. `chartConfig` carries the
/// item identity but does not change which series is read.
class DashboardHealthBmiChart extends ConsumerWidget {
  const DashboardHealthBmiChart({
    required this.chartConfig,
    required this.rangeStart,
    required this.rangeEnd,
    super.key,
  });

  final DashboardHealthItem chartConfig;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StaleAsyncValue<List<Observation>>(
      async: ref.watch(
        healthObservationsControllerProvider(
          healthDataType: 'HealthDataType.WEIGHT',
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        ),
      ),
      builder: (context, value, isInitialLoading) {
        final weightData = value ?? const <Observation>[];
        final minInRange = findMin(weightData);
        final maxInRange = findMax(weightData);
        return DashboardChart(
          chart: TimeSeriesLineChart(
            data: weightData,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
          dateAxis: DashboardChartDateAxis(
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
          chartHeader: BmiChartInfoWidget(
            minInRange: minInRange,
            maxInRange: maxInRange,
          ),
          isLoading: isInitialLoading,
          isEmpty: weightData.isEmpty,
          emptyMessage: context.messages.dashboardChartNoData,
          height: 320,
        );
      },
    );
  }
}
