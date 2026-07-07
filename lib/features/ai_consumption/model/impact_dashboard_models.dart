import 'package:collection/collection.dart';
import 'package:lotti/features/ai_consumption/logic/consumption_formatting.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/insights/model/insights_models.dart'
    show InsightsGranularity;
import 'package:meta/meta.dart';

const DeepCollectionEquality _deepEquality = DeepCollectionEquality();

/// The headline dimensions the impact dashboard can break AI consumption
/// down by: money, electricity, emissions, raw token volume, and call count.
/// The dashboard shows all of them in the KPI row and lets the user pick one
/// for the chart + ranked table.
///
/// [requests] (raw call count) is the only metric populated for *every*
/// provider — cost/energy/carbon are reported by cloud providers alone and
/// tokens require usage reporting — so it is the dependable lens for
/// "favorite models over time".
enum ConsumptionMetric { cost, energy, carbon, tokens, requests }

/// Projection + formatting lens for one [ConsumptionMetric], so chart/table
/// code can stay metric-agnostic: pick the value with [valueOf], render it
/// with [formatValue].
extension ConsumptionMetricLens on ConsumptionMetric {
  /// The metric's scalar out of a [ConsumptionMetrics] bundle — credits (≈
  /// EUR) for cost, kWh for energy, grams CO₂ for carbon, and the total
  /// token count (as a double, so all metrics share one aggregation path).
  double valueOf(ConsumptionMetrics metrics) => switch (this) {
    ConsumptionMetric.cost => metrics.credits,
    ConsumptionMetric.energy => metrics.energyKwh,
    ConsumptionMetric.carbon => metrics.carbonGCo2,
    ConsumptionMetric.tokens => metrics.totalTokens.toDouble(),
    ConsumptionMetric.requests => metrics.callCount.toDouble(),
  };

  /// Formats a [valueOf]-scaled value with its unit, via the shared
  /// adaptive-unit formatters (`consumption_formatting.dart`) so the
  /// dashboard can never mislabel a converted number.
  String formatValue(double value) => switch (this) {
    ConsumptionMetric.cost => formatCredits(value),
    ConsumptionMetric.energy => formatEnergyKwh(value),
    ConsumptionMetric.carbon => formatCarbonGrams(value),
    ConsumptionMetric.tokens => formatTokenCount(value.round()),
    ConsumptionMetric.requests => formatCallCount(value.round()),
  };

  /// Whether this metric is reported by every provider ([requests]) or only
  /// by cloud providers that return billing/impact data (cost/energy/carbon)
  /// or usage (tokens). Drives the "measured for cloud models only" coverage
  /// note.
  bool get isCloudOnly => switch (this) {
    ConsumptionMetric.requests => false,
    _ => true,
  };
}

/// Chart-ready stacked series for the impact dashboard — the shape of the
/// Insights `InsightsChartData`, with `double` metric values instead of
/// integer seconds.
///
/// [seriesKeys] are ordered bottom-to-top of the stack (largest total
/// first); they may include the Insights "Other" rollup sentinel
/// (`kInsightsOtherCategoryKey`) and `null` (uncategorized).
/// `values[seriesIndex][bucketIndex]` is the metric value in the metric's
/// own unit. [granularity] is never `hour`: consumption buckets are
/// day-keyed, so a single-day range renders as one day bucket.
@immutable
class ImpactChartData {
  const ImpactChartData({
    required this.granularity,
    required this.bucketStarts,
    required this.seriesKeys,
    required this.values,
    this.rolledUpCount = 0,
    this.partialFirstBucket = false,
    this.partialLastBucket = false,
  });

  /// X-axis granularity — `day` or `week`, never `hour`.
  final InsightsGranularity granularity;

  /// Local start time of each x bucket (day or week start).
  final List<DateTime> bucketStarts;

  /// Stacking order, bottom of stack first.
  final List<String?> seriesKeys;

  /// Metric value per series per bucket: `values[series][bucket]`.
  final List<List<double>> values;

  /// How many categories were rolled into the "Other" series — surfaced in
  /// the legend so the chart and the exhaustive table tell the same story.
  final int rolledUpCount;

  /// Whether the first/last weekly bucket is truncated by the range (e.g.
  /// a range starting mid-week) — flagged in tooltips so shorter edge bars
  /// aren't misread as low-usage weeks.
  final bool partialFirstBucket;
  final bool partialLastBucket;

  /// True when there is nothing to plot (no series, or every value zero).
  bool get isEmpty =>
      values.isEmpty || values.every((row) => row.every((v) => v <= 0));

  @override
  bool operator ==(Object other) =>
      other is ImpactChartData &&
      other.granularity == granularity &&
      other.rolledUpCount == rolledUpCount &&
      other.partialFirstBucket == partialFirstBucket &&
      other.partialLastBucket == partialLastBucket &&
      _deepEquality.equals(other.bucketStarts, bucketStarts) &&
      _deepEquality.equals(other.seriesKeys, seriesKeys) &&
      _deepEquality.equals(other.values, values);

  @override
  int get hashCode => Object.hash(
    granularity,
    rolledUpCount,
    partialFirstBucket,
    partialLastBucket,
    _deepEquality.hash(bucketStarts),
    _deepEquality.hash(seriesKeys),
    _deepEquality.hash(values),
  );
}
