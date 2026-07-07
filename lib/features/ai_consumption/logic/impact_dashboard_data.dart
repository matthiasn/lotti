import 'dart:math' as math;

import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/model/impact_dashboard_models.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart'
    show dayStart, granularityFor, maxChartSeriesFor, weekStartDay;
import 'package:lotti/features/insights/model/insights_models.dart'
    show InsightsGranularity, InsightsRange, kInsightsOtherCategoryKey;

/// Pure derivations for the AI Impact dashboard.
///
/// Structural siblings of the Insights `time_bucketing.dart` builders, over
/// [ConsumptionDayBuckets] instead of merged time intervals: consumption is
/// a point-in-time scalar per (day, category) cell, so everything here is a
/// plain fold — no interval union, no midnight splitting, and therefore no
/// hourly view (see [buildImpactChartData]). Deterministic and free of
/// Flutter/database imports so it can be exhaustively property-tested.

/// The selected metric's value per category for every day of [range],
/// zero-filled for days without data. Index `i` of the result is day
/// `range.startDay + i`. Categories whose value for [metric] is zero are
/// dropped (e.g. a provider that reports tokens but no energy), so
/// downstream ranking and stacking never carry dead series.
List<Map<String?, double>> dailyMetricTotals(
  ConsumptionDayBuckets buckets,
  InsightsRange range,
  ConsumptionMetric metric,
) {
  return _dailyMetricTotalsFrom(buckets.days, range, metric);
}

/// The selected metric's value per model for every day of [range], using
/// `providerModelId` first, then `modelId`, then null = unknown model.
List<Map<String?, double>> dailyModelMetricTotals(
  ConsumptionDayBuckets buckets,
  InsightsRange range,
  ConsumptionMetric metric,
) {
  return _dailyMetricTotalsFrom(buckets.modelDays, range, metric);
}

List<Map<String?, double>> _dailyMetricTotalsFrom(
  Map<int, Map<String?, ConsumptionMetrics>> days,
  InsightsRange range,
  ConsumptionMetric metric,
) {
  return List.generate(range.dayCount, (i) {
    final cells = days[range.startDay + i];
    if (cells == null) return const <String?, double>{};
    final totals = <String?, double>{};
    cells.forEach((key, metrics) {
      final value = metric.valueOf(metrics);
      if (value > 0) totals[key] = value;
    });
    return totals;
  });
}

/// Total metric value per category across all buckets, descending; zero and
/// negative totals are dropped.
List<MapEntry<String?, double>> rankedImpactCategoryTotals(
  List<Map<String?, double>> totalsPerBucket,
) {
  final totals = <String?, double>{};
  for (final bucket in totalsPerBucket) {
    bucket.forEach((categoryId, value) {
      totals[categoryId] = (totals[categoryId] ?? 0) + value;
    });
  }
  final entries = totals.entries.where((e) => e.value > 0).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries;
}

/// Field-wise sum of every (day, category) cell inside [range] — the KPI
/// row's headline totals across all four metrics in one pass.
ConsumptionMetrics impactTotalsInRange(
  ConsumptionDayBuckets buckets,
  InsightsRange range,
) {
  var total = ConsumptionMetrics.zero;
  for (var day = range.startDay; day < range.endDayExclusive; day++) {
    final cells = buckets.days[day];
    if (cells == null) continue;
    for (final metrics in cells.values) {
      total = total + metrics;
    }
  }
  return total;
}

/// Total environmental impact by serving location across [range], descending
/// by energy and then carbon. Only rows whose provider reported a data centre
/// are present in [ConsumptionDayBuckets.locationDays], so token-only/local
/// calls never create a misleading unknown-location bucket.
List<MapEntry<ConsumptionLocationKey, ConsumptionLocationMetrics>>
rankedImpactLocationTotals(
  ConsumptionDayBuckets buckets,
  InsightsRange range,
) {
  final totals = <ConsumptionLocationKey, ConsumptionLocationMetrics>{};
  for (var day = range.startDay; day < range.endDayExclusive; day++) {
    final cells = buckets.locationDays[day];
    if (cells == null) continue;
    cells.forEach((location, metrics) {
      totals[location] =
          (totals[location] ?? ConsumptionLocationMetrics.zero) + metrics;
    });
  }

  final entries =
      totals.entries
          .where(
            (e) =>
                e.value.metrics.energyKwh > 0 || e.value.metrics.carbonGCo2 > 0,
          )
          .toList()
        ..sort((a, b) {
          final energy = b.value.metrics.energyKwh.compareTo(
            a.value.metrics.energyKwh,
          );
          if (energy != 0) return energy;
          final carbon = b.value.metrics.carbonGCo2.compareTo(
            a.value.metrics.carbonGCo2,
          );
          if (carbon != 0) return carbon;
          final country = (a.key.countryCode ?? '').compareTo(
            b.key.countryCode ?? '',
          );
          if (country != 0) return country;
          return a.key.dataCenter.compareTo(b.key.dataCenter);
        });
  return entries;
}

/// Builds chart-ready stacked series for [range] and [metric]: resolves
/// granularity, aggregates weekly when needed, ranks categories, and rolls
/// everything beyond the granularity's series cap into the Insights "Other"
/// sentinel ([kInsightsOtherCategoryKey]).
///
/// Granularity follows the Insights rules ([granularityFor]) with one
/// deliberate difference: `hour` collapses to `day`. Consumption buckets
/// are day-keyed (a call lands in exactly one calendar day), so a 1-day
/// range renders as a single day bucket rather than 24 empty-ish hour
/// slots.
///
/// Series are ordered largest-total-first so the biggest category sits on
/// the stack baseline where it stays comparable across buckets.
/// [precomputedDaily] lets the caller share one [dailyMetricTotals] pass
/// with the ranking/table derivations; it must equal
/// `dailyMetricTotals(buckets, range, metric)` when provided.
ImpactChartData buildImpactChartData(
  ConsumptionDayBuckets buckets,
  InsightsRange range,
  ConsumptionMetric metric, {
  List<Map<String?, double>>? precomputedDaily,
}) {
  final resolved = granularityFor(range);
  final granularity = resolved == InsightsGranularity.hour
      ? InsightsGranularity.day
      : resolved;

  final daily = precomputedDaily ?? dailyMetricTotals(buckets, range, metric);

  List<Map<String?, double>> perBucket;
  List<DateTime> bucketStarts;
  var partialFirstBucket = false;
  var partialLastBucket = false;

  if (granularity == InsightsGranularity.day) {
    perBucket = daily;
    bucketStarts = List.generate(
      range.dayCount,
      (i) => dayStart(range.startDay + i),
    );
  } else {
    final firstWeek = weekStartDay(range.startDay);
    final lastWeek = weekStartDay(range.endDayExclusive - 1);
    final weekCount = (lastWeek - firstWeek) ~/ 7 + 1;
    perBucket = List.generate(weekCount, (_) => <String?, double>{});
    for (var i = 0; i < daily.length; i++) {
      final week = (weekStartDay(range.startDay + i) - firstWeek) ~/ 7;
      daily[i].forEach((categoryId, value) {
        perBucket[week][categoryId] =
            (perBucket[week][categoryId] ?? 0) + value;
      });
    }
    // The first week may begin before the range (e.g. YTD starting on a
    // Thursday); clamp its label to the range start so the chart never
    // shows a date outside the selected period.
    bucketStarts = List.generate(weekCount, (w) {
      final weekStart = firstWeek + w * 7;
      return dayStart(weekStart < range.startDay ? range.startDay : weekStart);
    });
    // Truncated edge weeks read as artificial dips; flag them so the
    // tooltip can say "partial week".
    partialFirstBucket = range.startDay > firstWeek;
    partialLastBucket = range.endDayExclusive < lastWeek + 7;
  }

  final ranked = rankedImpactCategoryTotals(perBucket);
  final maxSeries = maxChartSeriesFor(granularity);
  final visible = ranked.take(maxSeries).map((e) => e.key);
  final rolledUp = ranked.skip(maxSeries).map((e) => e.key).toSet();

  final seriesKeys = <String?>[
    ...visible,
    if (rolledUp.isNotEmpty) kInsightsOtherCategoryKey,
  ];

  final values = [
    for (final key in seriesKeys)
      [
        for (final bucket in perBucket)
          key == kInsightsOtherCategoryKey
              ? rolledUp.fold<double>(0, (sum, id) => sum + (bucket[id] ?? 0))
              : bucket[key] ?? 0,
      ],
  ];

  return ImpactChartData(
    granularity: granularity,
    bucketStarts: bucketStarts,
    seriesKeys: seriesKeys,
    values: values,
    rolledUpCount: rolledUp.length,
    partialFirstBucket: partialFirstBucket,
    partialLastBucket: partialLastBucket,
  );
}

/// Total metric value in [data]'s bucket at [index] across every series.
double impactBucketTotal(ImpactChartData data, int index) {
  var total = 0.0;
  for (final row in data.values) {
    total += row[index];
  }
  return total;
}

/// Smallest "nice" chart ceiling at or above [maxValue]: 1, 2, or 5 times a
/// power of ten (…, 0.2, 0.5, 1, 2, 5, 10, 20, …). Returns 1 for
/// non-positive input so an all-zero chart still has a drawable axis.
///
/// Deliberately not the Insights hour-ladder ceiling — consumption metrics
/// span wildly different magnitudes (cents to euros, Wh to kWh), so the
/// axis snaps to decade-friendly steps instead of time-friendly ones.
double impactNiceCeiling(double maxValue) {
  if (maxValue <= 0) return 1;
  final exponent = (math.log(maxValue) / math.ln10).floor();
  final magnitude = math.pow(10.0, exponent).toDouble();
  final normalized = maxValue / magnitude;
  // Tolerance for floating-point accumulation noise: a summed maximum like
  // 2.0000000000000004 must snap to 2, not jump a whole ladder step to 5.
  const epsilon = 1e-9;
  if (normalized <= 1 + epsilon) return magnitude;
  if (normalized <= 2 + epsilon) return 2 * magnitude;
  if (normalized <= 5 + epsilon) return 5 * magnitude;
  return 10 * magnitude;
}
