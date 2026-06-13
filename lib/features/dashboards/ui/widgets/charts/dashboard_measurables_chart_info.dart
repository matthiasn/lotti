import 'dart:core';

import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/ui/widgets/charts/dashboard_chart.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/create/create_measurement_dialog.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

class MeasurablesChartInfoWidget extends StatelessWidget {
  const MeasurablesChartInfoWidget(
    this.measurableDataType, {
    required this.aggregationType,
    required this.enableCreate,
    super.key,
  });

  final MeasurableDataType measurableDataType;
  final AggregationType aggregationType;
  final bool enableCreate;

  Widget _buildModalTitle(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          measurableDataType.displayName,
          style: theme.textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        if (measurableDataType.description.isNotEmpty)
          Text(
            measurableDataType.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Future<void> captureData() async {
      await ModalUtils.showSinglePageModal<void>(
        context: context,
        titleWidget: _buildModalTitle(context),
        builder: (_) {
          return MeasurementDialog(
            measurableId: measurableDataType.id,
          );
        },
      );
    }

    // The aggregation is surfaced as a quiet caption (e.g. "Daily total")
    // rather than concatenating a developer enum like "[dailySum]" into the
    // title; the human-readable description follows it.
    final aggregation = aggregationDisplayLabel(context, aggregationType);
    final subtitle = [
      if (aggregation.isNotEmpty) aggregation,
      if (measurableDataType.description.isNotEmpty)
        measurableDataType.description,
    ].join(' · ');

    return DashboardChartHeader(
      title: measurableDataType.displayName,
      subtitle: subtitle,
      action: enableCreate
          ? DashboardChartAddButton(
              tooltip: context.messages.dashboardAddMeasurementTooltip,
              onPressed: captureData,
            )
          : null,
    );
  }
}

/// Localized, human-readable label for an [AggregationType] (empty for
/// [AggregationType.none]).
String aggregationDisplayLabel(BuildContext context, AggregationType type) {
  final messages = context.messages;
  switch (type) {
    case AggregationType.none:
      return '';
    case AggregationType.dailySum:
      return messages.dashboardAggregationDailyTotal;
    case AggregationType.dailyMax:
      return messages.dashboardAggregationDailyMax;
    case AggregationType.dailyAvg:
      return messages.dashboardAggregationDailyAverage;
    case AggregationType.hourlySum:
      return messages.dashboardAggregationHourlyTotal;
  }
}
