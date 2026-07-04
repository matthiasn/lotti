import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// The lifetime (or windowed) sum of consumption metrics for a single owner —
/// e.g. everything one task has ever burned across all its calls.
///
/// Value type with structural equality so Riverpod providers can short-circuit
/// unchanged rebuilds. Token sums are `int`; cost/energy/carbon/water are
/// `double` in the units Melious delivers (credits ≈ EUR, kWh, gCO₂, litres).
///
/// [callCount] is the total number of calls attributed to the owner;
/// [impactCallCount] is how many of those actually reported environmental
/// impact (only Melious does), so a UI can honestly say "energy measured for N
/// of M calls".
@immutable
class ConsumptionTotals {
  const ConsumptionTotals({
    required this.callCount,
    required this.impactCallCount,
    required this.inputTokens,
    required this.outputTokens,
    required this.cachedInputTokens,
    required this.thoughtsTokens,
    required this.totalTokens,
    required this.credits,
    required this.energyKwh,
    required this.carbonGCo2,
    required this.waterLiters,
  });

  static const empty = ConsumptionTotals(
    callCount: 0,
    impactCallCount: 0,
    inputTokens: 0,
    outputTokens: 0,
    cachedInputTokens: 0,
    thoughtsTokens: 0,
    totalTokens: 0,
    credits: 0,
    energyKwh: 0,
    carbonGCo2: 0,
    waterLiters: 0,
  );

  final int callCount;
  final int impactCallCount;
  final int inputTokens;
  final int outputTokens;
  final int cachedInputTokens;
  final int thoughtsTokens;
  final int totalTokens;
  final double credits;
  final double energyKwh;
  final double carbonGCo2;
  final double waterLiters;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConsumptionTotals &&
          other.callCount == callCount &&
          other.impactCallCount == impactCallCount &&
          other.inputTokens == inputTokens &&
          other.outputTokens == outputTokens &&
          other.cachedInputTokens == cachedInputTokens &&
          other.thoughtsTokens == thoughtsTokens &&
          other.totalTokens == totalTokens &&
          other.credits == credits &&
          other.energyKwh == energyKwh &&
          other.carbonGCo2 == carbonGCo2 &&
          other.waterLiters == waterLiters;

  @override
  int get hashCode => Object.hash(
    callCount,
    impactCallCount,
    inputTokens,
    outputTokens,
    cachedInputTokens,
    thoughtsTokens,
    totalTokens,
    credits,
    energyKwh,
    carbonGCo2,
    waterLiters,
  );
}

/// The additive bucket value — a running field-wise sum of consumption metrics
/// for one (day, category) cell.
///
/// [callCount] counts the calls folded in. Consumption is a point-in-time
/// scalar, so accumulation is a plain sum (no interval union like the Insights
/// time buckets).
@immutable
class ConsumptionMetrics {
  const ConsumptionMetrics({
    this.callCount = 0,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cachedInputTokens = 0,
    this.thoughtsTokens = 0,
    this.totalTokens = 0,
    this.credits = 0,
    this.energyKwh = 0,
    this.carbonGCo2 = 0,
    this.waterLiters = 0,
  });

  static const zero = ConsumptionMetrics();

  final int callCount;
  final int inputTokens;
  final int outputTokens;
  final int cachedInputTokens;
  final int thoughtsTokens;
  final int totalTokens;
  final double credits;
  final double energyKwh;
  final double carbonGCo2;
  final double waterLiters;

  /// Field-wise sum — the fold used to accumulate rows into a cell.
  ConsumptionMetrics operator +(ConsumptionMetrics other) => ConsumptionMetrics(
    callCount: callCount + other.callCount,
    inputTokens: inputTokens + other.inputTokens,
    outputTokens: outputTokens + other.outputTokens,
    cachedInputTokens: cachedInputTokens + other.cachedInputTokens,
    thoughtsTokens: thoughtsTokens + other.thoughtsTokens,
    totalTokens: totalTokens + other.totalTokens,
    credits: credits + other.credits,
    energyKwh: energyKwh + other.energyKwh,
    carbonGCo2: carbonGCo2 + other.carbonGCo2,
    waterLiters: waterLiters + other.waterLiters,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConsumptionMetrics &&
          other.callCount == callCount &&
          other.inputTokens == inputTokens &&
          other.outputTokens == outputTokens &&
          other.cachedInputTokens == cachedInputTokens &&
          other.thoughtsTokens == thoughtsTokens &&
          other.totalTokens == totalTokens &&
          other.credits == credits &&
          other.energyKwh == energyKwh &&
          other.carbonGCo2 == carbonGCo2 &&
          other.waterLiters == waterLiters;

  @override
  int get hashCode => Object.hash(
    callCount,
    inputTokens,
    outputTokens,
    cachedInputTokens,
    thoughtsTokens,
    totalTokens,
    credits,
    energyKwh,
    carbonGCo2,
    waterLiters,
  );
}

/// One consumption event projected for time-bucketed aggregation: when it
/// happened, the category it belongs to (`null` = uncategorized), and its
/// metrics (with `callCount` 1).
@immutable
class ConsumptionMetricRow {
  const ConsumptionMetricRow({
    required this.createdAt,
    required this.categoryId,
    required this.metrics,
  });

  final DateTime createdAt;
  final String? categoryId;
  final ConsumptionMetrics metrics;
}

/// Per-day, per-category summed consumption over a window.
///
/// `days[epochDay][categoryId]` is the field-wise sum of every call in that
/// (day, category) cell. Mirrors the Insights `InsightsDayBuckets`; the cell
/// value is an additive scalar bundle rather than merged intervals. Deep
/// structural equality lets a provider short-circuit an unchanged refetch.
@immutable
class ConsumptionDayBuckets {
  const ConsumptionDayBuckets({
    required this.windowStartDay,
    required this.days,
  });

  final int windowStartDay;
  final Map<int, Map<String?, ConsumptionMetrics>> days;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConsumptionDayBuckets &&
          other.windowStartDay == windowStartDay &&
          const DeepCollectionEquality().equals(days, other.days);

  @override
  int get hashCode =>
      Object.hash(windowStartDay, const DeepCollectionEquality().hash(days));
}
