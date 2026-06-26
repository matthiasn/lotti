import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/config/dashboard_health_config.dart';
import 'package:lotti/features/dashboards/state/health_chart_controller.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_health_bmi_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_health_bp_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/stale_async_value.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_bar_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/time_series_line_chart.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/time_series/utils.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/charts/utils.dart';

/// Header for a generic health chart card: the configured health type's display
/// name as title and its unit as subtitle (falling back to the raw health-type
/// key when unconfigured).
class HealthChartInfoWidget extends StatelessWidget {
  const HealthChartInfoWidget(
    this.chartConfig, {
    this.embedded = false,
    super.key,
  });

  final DashboardHealthItem chartConfig;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    // Embedded in an entry card, the host's value line already names the metric
    // (e.g. "Steps: 8,000"), so the chart's own title would just duplicate it —
    // drop the header entirely and let the trend stand on its own.
    if (embedded) return const SizedBox.shrink();

    final healthType = healthTypes[chartConfig.healthType];
    final unit = healthType?.unit ?? '';

    return DashboardChartHeader(
      title: healthType?.displayName ?? chartConfig.healthType,
      subtitle: unit.isEmpty ? null : unit,
    );
  }
}

/// Dispatcher for a health item, choosing the right renderer for its type:
/// blood pressure → [DashboardHealthBpChart], weight-vs-BMI →
/// [DashboardHealthBmiChart], and everything else → a generic line or bar
/// [DashboardChart] (bar when the type's config says so, e.g. steps/sleep).
///
/// For the generic path it watches [HealthObservationsController] for the
/// already-aggregated points, wraps them in a stale-aware [DashboardChart], and
/// colours bars by value threshold via [_healthBarColor]. Despite the
/// `Chart` suffix this widget mostly routes rather than draws.
class DashboardHealthChart extends ConsumerWidget {
  const DashboardHealthChart({
    required this.chartConfig,
    required this.rangeStart,
    required this.rangeEnd,
    this.embedded = false,
    super.key,
  });

  final DashboardHealthItem chartConfig;
  final bool embedded;
  final DateTime rangeStart;
  final DateTime rangeEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final healthType = healthTypes[chartConfig.healthType];
    final isBarChart = healthType?.chartType == HealthChartType.barChart;
    final dataType = chartConfig.healthType;

    if (dataType == 'BLOOD_PRESSURE') {
      return DashboardHealthBpChart(
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        embedded: embedded,
      );
    }

    if (dataType == 'BODY_MASS_INDEX') {
      return DashboardHealthBmiChart(
        chartConfig: chartConfig,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        embedded: embedded,
      );
    }

    final tokens = context.designTokens;

    return StaleAsyncValue<List<Observation>>(
      async: ref.watch(
        healthObservationsControllerProvider((
          healthDataType: chartConfig.healthType,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
        )),
      ),
      builder: (context, value, isInitialLoading) {
        final data = value ?? const <Observation>[];
        return DashboardChart(
          chart: isBarChart
              ? TimeSeriesBarChart(
                  data: data,
                  rangeStart: rangeStart,
                  rangeEnd: rangeEnd,
                  unit: healthType?.unit ?? '',
                  valueInHours: healthType?.unit == 'h',
                  colorByValue: (observation) =>
                      _healthBarColor(observation, healthType, tokens),
                )
              : TimeSeriesLineChart(
                  data: data,
                  rangeStart: rangeStart,
                  rangeEnd: rangeEnd,
                  unit: healthType?.unit ?? '',
                ),
          dateAxis: DashboardChartDateAxis(
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
          ),
          chartHeader: HealthChartInfoWidget(chartConfig, embedded: embedded),
          isLoading: isInitialLoading,
          isEmpty: data.isEmpty,
          emptyMessage: context.messages.dashboardChartNoData,
          embedded: embedded,
          height: embedded
              ? (isBarChart ? 132 : 116)
              : (isBarChart ? 180 : 150),
        );
      },
    );
  }
}

/// Colours a health bar by the health type's value thresholds (`colorByValue`),
/// mapped onto the design-system alert palette: the top tier reads as
/// [DsColorsAlert.success], the bottom as [DsColorsAlert.error], and any tier
/// in between as [DsColorsAlert.warning]. Health types without thresholds
/// (everything except Steps today) fall back to the single series colour.
///
/// Example — Steps (`{0, 6000, 10000}`): at-or-above-goal is green, the
/// approaching tier is amber, and below is red.
Color _healthBarColor(
  Observation observation,
  HealthTypeConfig? healthType,
  DsTokens tokens,
) {
  final thresholds = healthType?.colorByValue?.keys.toList();
  if (thresholds == null || thresholds.isEmpty) {
    return tokens.colors.interactive.enabled;
  }
  thresholds.sort();

  // The highest threshold the value reaches determines its tier.
  final reached = thresholds.lastWhere(
    (threshold) => observation.value >= threshold,
    orElse: () => thresholds.first,
  );
  final tier = thresholds.indexOf(reached);

  if (tier >= thresholds.length - 1) {
    return tokens.colors.alert.success.defaultColor;
  }
  if (tier <= 0) {
    return tokens.colors.alert.error.defaultColor;
  }
  return tokens.colors.alert.warning.defaultColor;
}
