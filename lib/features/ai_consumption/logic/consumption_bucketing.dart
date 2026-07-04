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

  for (final row in rows) {
    // Defensive clip: the range query already filters to the window, but this
    // keeps the fold total for callers that pass edge rows.
    if (row.createdAt.isBefore(windowStart)) continue;

    final cell = days.putIfAbsent(
      epochDay(row.createdAt),
      () => <String?, ConsumptionMetrics>{},
    );
    cell[row.categoryId] =
        (cell[row.categoryId] ?? ConsumptionMetrics.zero) + row.metrics;
  }

  return ConsumptionDayBuckets(windowStartDay: windowStartDay, days: days);
}
