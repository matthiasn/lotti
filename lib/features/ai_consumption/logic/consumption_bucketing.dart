import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart'
    show dayStart, epochDay;

/// Pure bucketing for the AI-consumption dashboard: folds slim consumption rows
/// into per-day, per-category cells by additive sum.
///
/// Deterministic and free of Flutter/database imports so it can be
/// property-tested. Reuses the Insights day-key machinery ([epochDay],
/// [dayStart]) — day keys are "epoch days" for the local calendar date,
/// computed through a UTC anchor so they are DST-immune. Unlike the Insights
/// time buckets, consumption is a point-in-time scalar: each row drops into
/// exactly one `(epochDay(createdAt), categoryId)` cell with a plain sum — no
/// midnight-splitting, no interval union.
ConsumptionDayBuckets bucketize(
  List<ConsumptionMetricRow> rows, {
  required int windowStartDay,
}) {
  final windowStart = dayStart(windowStartDay);
  final days = <int, Map<String?, ConsumptionMetrics>>{};
  final modelDays = <int, Map<String?, ConsumptionMetrics>>{};
  final locationDays =
      <int, Map<ConsumptionLocationKey, ConsumptionLocationMetrics>>{};

  for (final row in rows) {
    // Defensive clip: the range query already filters to the window, but this
    // keeps the fold total for callers that pass edge rows.
    if (row.createdAt.isBefore(windowStart)) continue;

    final rowDay = epochDay(row.createdAt);
    final cell = days.putIfAbsent(
      rowDay,
      () => <String?, ConsumptionMetrics>{},
    );
    cell[row.categoryId] =
        (cell[row.categoryId] ?? ConsumptionMetrics.zero) + row.metrics;

    final modelKey = _modelKeyFor(row);
    final modelCell = modelDays.putIfAbsent(
      rowDay,
      () => <String?, ConsumptionMetrics>{},
    );
    modelCell[modelKey] =
        (modelCell[modelKey] ?? ConsumptionMetrics.zero) + row.metrics;

    final dataCenter = row.dataCenter?.trim();
    if (dataCenter == null || dataCenter.isEmpty) continue;

    final locationKey = ConsumptionLocationKey.fromDataCenter(dataCenter);
    final locationCell = locationDays.putIfAbsent(
      rowDay,
      () => <ConsumptionLocationKey, ConsumptionLocationMetrics>{},
    );
    locationCell[locationKey] =
        (locationCell[locationKey] ?? ConsumptionLocationMetrics.zero) +
        _locationMetricsFor(row);
  }

  return ConsumptionDayBuckets(
    windowStartDay: windowStartDay,
    days: days,
    modelDays: modelDays,
    locationDays: locationDays,
  );
}

String? _modelKeyFor(ConsumptionMetricRow row) {
  final providerModelId = row.providerModelId?.trim();
  if (providerModelId != null && providerModelId.isNotEmpty) {
    return providerModelId;
  }

  final modelId = row.modelId?.trim();
  if (modelId != null && modelId.isNotEmpty) {
    return modelId;
  }

  return null;
}

ConsumptionLocationMetrics _locationMetricsFor(ConsumptionMetricRow row) {
  final renewablePercent = row.renewablePercent;
  final renewableEnergyKwh =
      renewablePercent != null && row.metrics.energyKwh > 0
      ? row.metrics.energyKwh
      : 0.0;

  return ConsumptionLocationMetrics(
    metrics: row.metrics,
    renewablePercentSum: renewablePercent ?? 0,
    renewableSampleCount: renewablePercent == null ? 0 : 1,
    renewableEnergyKwh: renewableEnergyKwh,
    renewableWeightedPercentKwh: renewableEnergyKwh * (renewablePercent ?? 0),
  );
}
