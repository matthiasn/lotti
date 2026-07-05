import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai_consumption/logic/consumption_bucketing.dart';
import 'package:lotti/features/ai_consumption/logic/impact_dashboard_data.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/model/impact_dashboard_models.dart';
import 'package:lotti/features/insights/logic/time_bucketing.dart'
    show
        dayStart,
        epochDay,
        kInsightsMaxChartSeries,
        kInsightsMaxChartSeriesDense,
        weekStartDay;
import 'package:lotti/features/insights/model/insights_models.dart'
    show InsightsGranularity, InsightsRange, kInsightsOtherCategoryKey;

/// Monday, 2024-03-04 — the anchor day for all fixtures.
final int day0 = epochDay(DateTime(2024, 3, 4));

ConsumptionMetrics m({
  double credits = 0,
  double energyKwh = 0,
  double carbonGCo2 = 0,
  int totalTokens = 0,
  int callCount = 1,
}) => ConsumptionMetrics(
  callCount: callCount,
  totalTokens: totalTokens,
  credits: credits,
  energyKwh: energyKwh,
  carbonGCo2: carbonGCo2,
);

void main() {
  final buckets = ConsumptionDayBuckets(
    windowStartDay: day0,
    days: {
      day0: {
        'cat-a': m(
          credits: 2,
          energyKwh: 0.2,
          carbonGCo2: 20,
          totalTokens: 200,
        ),
        null: m(credits: 1, energyKwh: 0.1, carbonGCo2: 10, totalTokens: 100),
      },
      day0 + 2: {
        // Tokens-only cell: a provider that reports no impact data.
        'cat-b': m(totalTokens: 500),
      },
      // Outside every 3-day test range — must never leak in.
      day0 + 10: {
        'cat-a': m(credits: 99, energyKwh: 9, carbonGCo2: 900, totalTokens: 9),
      },
    },
  );
  final range3 = InsightsRange(startDay: day0, endDayExclusive: day0 + 3);

  group('dailyMetricTotals', () {
    test('zero-fills missing days and projects the selected metric', () {
      final daily = dailyMetricTotals(buckets, range3, ConsumptionMetric.cost);
      expect(daily, hasLength(3));
      expect(daily[0], {'cat-a': 2.0, null: 1.0});
      expect(daily[1], isEmpty);
      // cat-b has tokens but no credits — dropped under the cost metric.
      expect(daily[2], isEmpty);
    });

    test('the tokens metric surfaces cells other metrics drop', () {
      final daily = dailyMetricTotals(
        buckets,
        range3,
        ConsumptionMetric.tokens,
      );
      expect(daily[0], {'cat-a': 200.0, null: 100.0});
      expect(daily[2], {'cat-b': 500.0});
    });
  });

  group('rankedImpactCategoryTotals', () {
    test('sums across buckets, sorts descending, drops zeros', () {
      final ranked = rankedImpactCategoryTotals([
        {'cat-a': 1.0, 'cat-b': 5.0},
        {'cat-a': 3.0, null: 2.0, 'cat-c': 0.0},
      ]);
      expect(
        [for (final e in ranked) (e.key, e.value)],
        [('cat-b', 5.0), ('cat-a', 4.0), (null, 2.0)],
      );
    });
  });

  group('impactTotalsInRange', () {
    test('folds every cell inside the range and nothing outside it', () {
      final totals = impactTotalsInRange(buckets, range3);
      expect(totals.credits, 3.0);
      expect(totals.energyKwh, closeTo(0.3, 1e-12));
      expect(totals.carbonGCo2, 30.0);
      expect(totals.totalTokens, 800);
      expect(totals.callCount, 3);
    });

    test('is zero for a range with no data', () {
      final totals = impactTotalsInRange(
        buckets,
        InsightsRange(startDay: day0 + 3, endDayExclusive: day0 + 5),
      );
      expect(totals, ConsumptionMetrics.zero);
    });
  });

  group('buildImpactChartData', () {
    test('a single-day range collapses hour granularity to one day bucket', () {
      final data = buildImpactChartData(
        buckets,
        InsightsRange(startDay: day0, endDayExclusive: day0 + 1),
        ConsumptionMetric.cost,
      );
      expect(data.granularity, InsightsGranularity.day);
      expect(data.bucketStarts, [dayStart(day0)]);
      expect(data.seriesKeys, ['cat-a', null]);
      expect(data.values, [
        [2.0],
        [1.0],
      ]);
    });

    test('daily view: largest series first, values per day', () {
      final data = buildImpactChartData(
        buckets,
        range3,
        ConsumptionMetric.tokens,
      );
      expect(data.granularity, InsightsGranularity.day);
      expect(data.bucketStarts, [
        dayStart(day0),
        dayStart(day0 + 1),
        dayStart(day0 + 2),
      ]);
      // cat-b (500) > cat-a (200) > uncategorized (100).
      expect(data.seriesKeys, ['cat-b', 'cat-a', null]);
      expect(data.values, [
        [0.0, 0.0, 500.0],
        [200.0, 0.0, 0.0],
        [100.0, 0.0, 0.0],
      ]);
      expect(data.rolledUpCount, 0);
      expect(data.partialFirstBucket, isFalse);
      expect(data.partialLastBucket, isFalse);
    });

    test('rolls categories beyond the day-view cap into Other', () {
      final crowded = ConsumptionDayBuckets(
        windowStartDay: day0,
        days: {
          day0: {
            for (var c = 1; c <= 8; c++) 'cat-$c': m(credits: c.toDouble()),
          },
        },
      );
      final data = buildImpactChartData(
        crowded,
        InsightsRange(startDay: day0, endDayExclusive: day0 + 7),
        ConsumptionMetric.cost,
      );
      expect(data.seriesKeys, hasLength(kInsightsMaxChartSeries + 1));
      expect(data.seriesKeys.last, kInsightsOtherCategoryKey);
      // cat-8 … cat-3 visible; cat-2 + cat-1 rolled up.
      expect(data.seriesKeys.first, 'cat-8');
      expect(data.rolledUpCount, 2);
      expect(data.values.last[0], 3.0);
    });

    test('long ranges aggregate to calendar weeks with partial-edge flags', () {
      // Starts on a Thursday, 140 days → weekly granularity, first week
      // truncated.
      final start = day0 + 3;
      final range = InsightsRange(
        startDay: start,
        endDayExclusive: start + 140,
      );
      final weekly = ConsumptionDayBuckets(
        windowStartDay: day0,
        days: {
          start: {'cat-a': m(credits: 1)},
          start + 1: {'cat-a': m(credits: 2)},
          // Second calendar week (the Monday after the truncated first week).
          start + 4: {'cat-a': m(credits: 4)},
        },
      );
      final data = buildImpactChartData(weekly, range, ConsumptionMetric.cost);
      expect(data.granularity, InsightsGranularity.week);
      expect(data.partialFirstBucket, isTrue);
      expect(data.partialLastBucket, isTrue);
      // First bucket label clamps to the range start, not the prior Monday.
      expect(data.bucketStarts.first, dayStart(start));
      expect(weekStartDay(start), isNot(start));
      expect(data.seriesKeys, ['cat-a']);
      expect(data.values.single[0], 3.0);
      expect(data.values.single[1], 4.0);
      // Dense weekly view keeps the tighter series cap available.
      expect(
        kInsightsMaxChartSeriesDense,
        lessThan(kInsightsMaxChartSeries),
      );
    });
  });

  group('impactBucketTotal', () {
    test('sums every series in a bucket', () {
      final data = buildImpactChartData(
        buckets,
        range3,
        ConsumptionMetric.cost,
      );
      expect(impactBucketTotal(data, 0), 3.0);
      expect(impactBucketTotal(data, 1), 0.0);
    });
  });

  group('impactNiceCeiling', () {
    test('snaps to the 1/2/5 decade ladder', () {
      expect(impactNiceCeiling(0), 1.0);
      expect(impactNiceCeiling(-5), 1.0);
      expect(impactNiceCeiling(0.007), 0.01);
      expect(impactNiceCeiling(0.42), 0.5);
      expect(impactNiceCeiling(3.2), 5.0);
      expect(impactNiceCeiling(12), 20.0);
      expect(impactNiceCeiling(47), 50.0);
      expect(impactNiceCeiling(470), 500.0);
      expect(impactNiceCeiling(720), 1000.0);
    });

    test('absorbs floating-point accumulation noise at ladder thresholds', () {
      // Sums like 0.1+0.2 land epsilon above a rung; the ceiling must snap
      // to the rung, not jump a whole step.
      expect(impactNiceCeiling(1.0000000000000002), 1.0);
      expect(impactNiceCeiling(2.0000000000000004), 2.0);
      expect(impactNiceCeiling(5.000000000000001), 5.0);
      expect(impactNiceCeiling(0.30000000000000004), 0.5);
    });
  });

  // ---------------------------------------------------------------------
  // Property-based tests (Glados)
  // ---------------------------------------------------------------------

  ConsumptionDayBuckets bucketsOf(List<CallSpec> specs) => bucketize(
    [for (final spec in specs) spec.row],
    windowStartDay: day0,
  );
  final propertyRange = InsightsRange(
    startDay: day0,
    endDayExclusive: day0 + 41,
  );

  glados.Glados<List<CallSpec>>(glados.any.callSpecs).test(
    'chart values sum to the range totals for every metric '
    '(rollup loses nothing)',
    (specs) {
      final built = bucketsOf(specs);
      final totals = impactTotalsInRange(built, propertyRange);
      for (final metric in ConsumptionMetric.values) {
        final data = buildImpactChartData(built, propertyRange, metric);
        var chartSum = 0.0;
        for (final row in data.values) {
          expect(row, hasLength(data.bucketStarts.length));
          for (final value in row) {
            chartSum += value;
          }
        }
        // Integer-valued metrics → fp-exact sums in any order.
        expect(chartSum, metric.valueOf(totals));
      }
    },
    tags: 'glados',
  );

  glados.Glados<List<CallSpec>>(glados.any.callSpecs).test(
    'ranking is monotone descending and strictly positive',
    (specs) {
      final built = bucketsOf(specs);
      for (final metric in ConsumptionMetric.values) {
        final ranked = rankedImpactCategoryTotals(
          dailyMetricTotals(built, propertyRange, metric),
        );
        for (var i = 0; i < ranked.length; i++) {
          expect(ranked[i].value, greaterThan(0));
          if (i > 0) {
            expect(ranked[i].value, lessThanOrEqualTo(ranked[i - 1].value));
          }
        }
      }
    },
    tags: 'glados',
  );

  glados.Glados<int>(glados.any.intInRange(1, 400)).test(
    'granularity is never hour, for any range length',
    (dayCount) {
      final data = buildImpactChartData(
        ConsumptionDayBuckets(windowStartDay: day0, days: const {}),
        InsightsRange(startDay: day0, endDayExclusive: day0 + dayCount),
        ConsumptionMetric.cost,
      );
      expect(data.granularity, isNot(InsightsGranularity.hour));
      expect(
        data.granularity,
        dayCount > 120 ? InsightsGranularity.week : InsightsGranularity.day,
      );
    },
    tags: 'glados',
  );

  glados.Glados<int>(glados.any.intInRange(1, 10000000)).test(
    'nice ceiling bounds its input within one decade',
    (raw) {
      // Spread across magnitudes: raw/100 covers 0.01 … 100k.
      final value = raw / 100;
      final ceiling = impactNiceCeiling(value);
      // The fp-noise epsilon means the ceiling may sit a hair below the
      // input when the input itself carries accumulation error.
      expect(ceiling * (1 + 1e-9), greaterThanOrEqualTo(value));
      expect(ceiling, lessThanOrEqualTo(10 * value));
    },
    tags: 'glados',
  );
}

/// Generated consumption call: a day offset into the property window, a
/// category seed (0 → uncategorized), and an integer unit driving all four
/// metrics so cross-metric sums stay fp-exact.
class CallSpec {
  const CallSpec({
    required this.dayOffset,
    required this.categorySeed,
    required this.unit,
  });

  final int dayOffset;
  final int categorySeed;
  final int unit;

  String? get categoryId => categorySeed == 0 ? null : 'cat-$categorySeed';

  ConsumptionMetricRow get row => ConsumptionMetricRow(
    createdAt: dayStart(day0 + dayOffset).add(const Duration(hours: 12)),
    categoryId: categoryId,
    metrics: ConsumptionMetrics(
      callCount: 1,
      totalTokens: unit,
      credits: unit.toDouble(),
      energyKwh: (unit * 2).toDouble(),
      carbonGCo2: (unit * 3).toDouble(),
    ),
  );

  @override
  String toString() => 'CallSpec(+${dayOffset}d, cat:$categorySeed, $unit)';
}

extension on glados.Any {
  glados.Generator<CallSpec> get callSpec => combine3(
    intInRange(0, 41),
    intInRange(0, 9),
    intInRange(0, 1000),
    (int day, int category, int unit) => CallSpec(
      dayOffset: day,
      categorySeed: category,
      unit: unit,
    ),
  );

  glados.Generator<List<CallSpec>> get callSpecs => list(callSpec);
}
