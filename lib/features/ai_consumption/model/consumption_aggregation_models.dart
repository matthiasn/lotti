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
    this.dataCenter,
    this.renewablePercent,
  });

  final DateTime createdAt;
  final String? categoryId;
  final ConsumptionMetrics metrics;

  /// Serving data-centre identifier as reported by Melious, when available.
  /// Current responses use ISO-3166 country codes (`FI`, `SE`) and may grow
  /// more specific suffixes later.
  final String? dataCenter;

  /// Percentage of the serving data centre's energy from renewables (0–100).
  final double? renewablePercent;
}

/// Normalized serving-location key for AI impact rows.
///
/// [countryCode] is inferred only from data-centre ids that begin with a
/// two-letter ISO-3166-like region (`FI`, `FI-HEL1`, `SE/stockholm`). Unknown
/// formats still keep the raw [dataCenter] so the UI can show what the provider
/// reported without pretending to know the country.
@immutable
class ConsumptionLocationKey {
  const ConsumptionLocationKey({
    required this.countryCode,
    required this.dataCenter,
  });

  factory ConsumptionLocationKey.fromDataCenter(String dataCenter) {
    final normalized = dataCenter.trim().toUpperCase();
    return ConsumptionLocationKey(
      countryCode: _countryCodeFromDataCenter(normalized),
      dataCenter: normalized,
    );
  }

  final String? countryCode;
  final String dataCenter;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConsumptionLocationKey &&
          other.countryCode == countryCode &&
          other.dataCenter == dataCenter;

  @override
  int get hashCode => Object.hash(countryCode, dataCenter);
}

String? _countryCodeFromDataCenter(String dataCenter) {
  final match = RegExp(
    r'^([A-Z]{2})(?:$|[-_:/.\s])',
  ).firstMatch(dataCenter);
  return match?.group(1);
}

/// Additive environmental summary for one serving location.
///
/// [renewablePercent] is energy-weighted when any row has positive energy:
/// a 90% renewable 10 Wh call should dominate a 10% renewable 1 Wh call. If
/// the provider reports renewable percentages without energy, it falls back to
/// the arithmetic mean across reported samples so the percentage is still
/// visible instead of silently dropped.
@immutable
class ConsumptionLocationMetrics {
  const ConsumptionLocationMetrics({
    required this.metrics,
    this.renewablePercentSum = 0,
    this.renewableSampleCount = 0,
    this.renewableEnergyKwh = 0,
    this.renewableWeightedPercentKwh = 0,
  });

  static const zero = ConsumptionLocationMetrics(
    metrics: ConsumptionMetrics.zero,
  );

  final ConsumptionMetrics metrics;
  final double renewablePercentSum;
  final int renewableSampleCount;
  final double renewableEnergyKwh;
  final double renewableWeightedPercentKwh;

  double? get renewablePercent {
    if (renewableEnergyKwh > 0) {
      return renewableWeightedPercentKwh / renewableEnergyKwh;
    }
    if (renewableSampleCount > 0) {
      return renewablePercentSum / renewableSampleCount;
    }
    return null;
  }

  ConsumptionLocationMetrics operator +(
    ConsumptionLocationMetrics other,
  ) => ConsumptionLocationMetrics(
    metrics: metrics + other.metrics,
    renewablePercentSum: renewablePercentSum + other.renewablePercentSum,
    renewableSampleCount: renewableSampleCount + other.renewableSampleCount,
    renewableEnergyKwh: renewableEnergyKwh + other.renewableEnergyKwh,
    renewableWeightedPercentKwh:
        renewableWeightedPercentKwh + other.renewableWeightedPercentKwh,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConsumptionLocationMetrics &&
          other.metrics == metrics &&
          other.renewablePercentSum == renewablePercentSum &&
          other.renewableSampleCount == renewableSampleCount &&
          other.renewableEnergyKwh == renewableEnergyKwh &&
          other.renewableWeightedPercentKwh == renewableWeightedPercentKwh;

  @override
  int get hashCode => Object.hash(
    metrics,
    renewablePercentSum,
    renewableSampleCount,
    renewableEnergyKwh,
    renewableWeightedPercentKwh,
  );
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
    this.locationDays = const {},
  });

  final int windowStartDay;
  final Map<int, Map<String?, ConsumptionMetrics>> days;

  /// `locationDays[epochDay][location]` is the field-wise sum of every call
  /// whose provider reported a serving data centre.
  final Map<int, Map<ConsumptionLocationKey, ConsumptionLocationMetrics>>
  locationDays;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConsumptionDayBuckets &&
          other.windowStartDay == windowStartDay &&
          const DeepCollectionEquality().equals(days, other.days) &&
          const DeepCollectionEquality().equals(
            locationDays,
            other.locationDays,
          );

  @override
  int get hashCode => Object.hash(
    windowStartDay,
    const DeepCollectionEquality().hash(days),
    const DeepCollectionEquality().hash(locationDays),
  );
}
