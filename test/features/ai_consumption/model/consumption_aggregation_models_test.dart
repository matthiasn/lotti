import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';

void main() {
  group('ConsumptionTotals', () {
    test('empty reports zero calls, tokens, cost, and impact', () {
      const e = ConsumptionTotals.empty;
      expect(e.callCount, 0);
      expect(e.impactCallCount, 0);
      expect(e.inputTokens, 0);
      expect(e.outputTokens, 0);
      expect(e.cachedInputTokens, 0);
      expect(e.thoughtsTokens, 0);
      expect(e.totalTokens, 0);
      expect(e.credits, 0);
      expect(e.energyKwh, 0);
      expect(e.carbonGCo2, 0);
      expect(e.waterLiters, 0);
    });

    test('equality and hashCode are structural, not identity-based', () {
      final a = _makeTotals();
      final b = _makeTotals();
      expect(identical(a, b), isFalse);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('instances differing in exactly one field are unequal', () {
      final base = _makeTotals();
      final variants = <String, ConsumptionTotals>{
        'callCount': _makeTotals(callCount: 8),
        'impactCallCount': _makeTotals(impactCallCount: 6),
        'inputTokens': _makeTotals(inputTokens: 1001),
        'outputTokens': _makeTotals(outputTokens: 501),
        'cachedInputTokens': _makeTotals(cachedInputTokens: 201),
        'thoughtsTokens': _makeTotals(thoughtsTokens: 51),
        'totalTokens': _makeTotals(totalTokens: 1751),
        'credits': _makeTotals(credits: 0.03),
        'energyKwh': _makeTotals(energyKwh: 0.004),
        'carbonGCo2': _makeTotals(carbonGCo2: 1.3),
        'waterLiters': _makeTotals(waterLiters: 0.5),
      };
      for (final MapEntry(key: field, value: variant) in variants.entries) {
        expect(
          variant,
          isNot(equals(base)),
          reason: '$field must participate in equality',
        );
      }
    });
  });

  group('ConsumptionMetrics', () {
    test('zero equals the default constructor and is all-zero', () {
      // The comparison against the freshly built default is the point here.
      // ignore: use_named_constants
      expect(ConsumptionMetrics.zero, equals(const ConsumptionMetrics()));
      const z = ConsumptionMetrics.zero;
      expect(z.callCount, 0);
      expect(z.inputTokens, 0);
      expect(z.outputTokens, 0);
      expect(z.cachedInputTokens, 0);
      expect(z.thoughtsTokens, 0);
      expect(z.totalTokens, 0);
      expect(z.credits, 0);
      expect(z.energyKwh, 0);
      expect(z.carbonGCo2, 0);
      expect(z.waterLiters, 0);
    });

    test('+ sums every field independently (no cross-wiring)', () {
      // Distinct per-field values so a field accidentally added into the
      // wrong slot produces a wrong (and unique) expected sum.
      const a = ConsumptionMetrics(
        callCount: 1,
        inputTokens: 10,
        outputTokens: 20,
        cachedInputTokens: 30,
        thoughtsTokens: 40,
        totalTokens: 100,
        credits: 0.5,
        energyKwh: 1.5,
        carbonGCo2: 2.5,
        waterLiters: 3.5,
      );
      const b = ConsumptionMetrics(
        callCount: 2,
        inputTokens: 100,
        outputTokens: 200,
        cachedInputTokens: 300,
        thoughtsTokens: 400,
        totalTokens: 1000,
        credits: 0.25,
        energyKwh: 0.75,
        carbonGCo2: 1.25,
        waterLiters: 1.75,
      );

      final sum = a + b;
      expect(sum.callCount, 3);
      expect(sum.inputTokens, 110);
      expect(sum.outputTokens, 220);
      expect(sum.cachedInputTokens, 330);
      expect(sum.thoughtsTokens, 440);
      expect(sum.totalTokens, 1100);
      expect(sum.credits, 0.75);
      expect(sum.energyKwh, 2.25);
      expect(sum.carbonGCo2, 3.75);
      expect(sum.waterLiters, 5.25);
    });

    test('equality and hashCode are structural, not identity-based', () {
      final a = _makeMetrics();
      final b = _makeMetrics();
      expect(identical(a, b), isFalse);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('instances differing in exactly one field are unequal', () {
      final base = _makeMetrics();
      final variants = <String, ConsumptionMetrics>{
        'callCount': _makeMetrics(callCount: 2),
        'inputTokens': _makeMetrics(inputTokens: 12),
        'outputTokens': _makeMetrics(outputTokens: 14),
        'cachedInputTokens': _makeMetrics(cachedInputTokens: 18),
        'thoughtsTokens': _makeMetrics(thoughtsTokens: 20),
        'totalTokens': _makeMetrics(totalTokens: 61),
        'credits': _makeMetrics(credits: 0.5),
        'energyKwh': _makeMetrics(energyKwh: 0.75),
        'carbonGCo2': _makeMetrics(carbonGCo2: 1),
        'waterLiters': _makeMetrics(waterLiters: 1.5),
      };
      for (final MapEntry(key: field, value: variant) in variants.entries) {
        expect(
          variant,
          isNot(equals(base)),
          reason: '$field must participate in equality',
        );
      }
    });
  });

  group('ConsumptionMetricRow', () {
    test(
      'rows fold into per-category sums via +, keyed by nullable category',
      () {
        final rows = [
          ConsumptionMetricRow(
            createdAt: DateTime(2026, 3, 15, 9),
            categoryId: 'work',
            metrics: const ConsumptionMetrics(
              callCount: 1,
              inputTokens: 100,
              totalTokens: 100,
              credits: 0.25,
            ),
          ),
          ConsumptionMetricRow(
            createdAt: DateTime(2026, 3, 15, 10),
            categoryId: null,
            metrics: const ConsumptionMetrics(
              callCount: 1,
              inputTokens: 40,
              totalTokens: 40,
              credits: 0.5,
            ),
          ),
          ConsumptionMetricRow(
            createdAt: DateTime(2026, 3, 15, 11),
            categoryId: 'work',
            metrics: const ConsumptionMetrics(
              callCount: 1,
              inputTokens: 60,
              totalTokens: 60,
              credits: 0.75,
            ),
          ),
        ];

        final byCategory = <String?, ConsumptionMetrics>{};
        for (final row in rows) {
          byCategory[row.categoryId] =
              (byCategory[row.categoryId] ?? ConsumptionMetrics.zero) +
              row.metrics;
        }

        expect(byCategory, hasLength(2));
        expect(
          byCategory['work'],
          const ConsumptionMetrics(
            callCount: 2,
            inputTokens: 160,
            totalTokens: 160,
            credits: 1,
          ),
        );
        expect(
          byCategory[null],
          const ConsumptionMetrics(
            callCount: 1,
            inputTokens: 40,
            totalTokens: 40,
            credits: 0.5,
          ),
        );
      },
    );
  });

  group('ConsumptionLocationKey', () {
    test('normalizes data center ids and infers country prefixes', () {
      final key = ConsumptionLocationKey.fromDataCenter(' fi-hel1 ');

      expect(key.countryCode, 'FI');
      expect(key.dataCenter, 'FI-HEL1');
      expect(key, ConsumptionLocationKey.fromDataCenter('FI-HEL1'));
      expect(
        key.hashCode,
        ConsumptionLocationKey.fromDataCenter('FI-HEL1').hashCode,
      );
    });

    test('keeps unknown data-center formats without inventing a country', () {
      final key = ConsumptionLocationKey.fromDataCenter('stockholm');

      expect(key.countryCode, isNull);
      expect(key.dataCenter, 'STOCKHOLM');
    });

    test('equality rejects different country, data center, and types', () {
      final key = ConsumptionLocationKey.fromDataCenter('FI-HEL1');

      expect(key, isNot(ConsumptionLocationKey.fromDataCenter('SE')));
      expect(key, isNot(ConsumptionLocationKey.fromDataCenter('FI-TMP1')));
      expect(key, isNot(equals('FI-HEL1')));
    });
  });

  group('ConsumptionLocationMetrics', () {
    test('energy-weights renewable percentage when energy is available', () {
      const a = ConsumptionLocationMetrics(
        metrics: ConsumptionMetrics(energyKwh: 0.01, carbonGCo2: 1),
        renewablePercentSum: 80,
        renewableSampleCount: 1,
        renewableEnergyKwh: 0.01,
        renewableWeightedPercentKwh: 0.8,
      );
      const b = ConsumptionLocationMetrics(
        metrics: ConsumptionMetrics(energyKwh: 0.03, carbonGCo2: 3),
        renewablePercentSum: 100,
        renewableSampleCount: 1,
        renewableEnergyKwh: 0.03,
        renewableWeightedPercentKwh: 3,
      );

      final sum = a + b;
      expect(sum.metrics.energyKwh, closeTo(0.04, 1e-12));
      expect(sum.metrics.carbonGCo2, 4);
      expect(sum.renewableSampleCount, 2);
      expect(sum.renewablePercent, closeTo(95, 1e-12));
    });

    test('falls back to sample average when energy was not reported', () {
      const metrics = ConsumptionLocationMetrics(
        metrics: ConsumptionMetrics.zero,
        renewablePercentSum: 120,
        renewableSampleCount: 2,
      );

      expect(metrics.renewablePercent, 60);
    });

    test('returns null when no renewable sample was reported', () {
      expect(ConsumptionLocationMetrics.zero.renewablePercent, isNull);
    });

    test('equality and hashCode include every aggregate field', () {
      const base = ConsumptionLocationMetrics(
        metrics: ConsumptionMetrics(energyKwh: 0.01, carbonGCo2: 2),
        renewablePercentSum: 80,
        renewableSampleCount: 1,
        renewableEnergyKwh: 0.01,
        renewableWeightedPercentKwh: 0.8,
      );
      final copy = ConsumptionLocationMetrics(
        metrics: base.metrics,
        renewablePercentSum: 80,
        renewableSampleCount: 1,
        renewableEnergyKwh: 0.01,
        renewableWeightedPercentKwh: 0.8,
      );

      expect(identical(base, copy), isFalse);
      expect(base, copy);
      expect(base.hashCode, copy.hashCode);

      final variants = <String, ConsumptionLocationMetrics>{
        'metrics': const ConsumptionLocationMetrics(
          metrics: ConsumptionMetrics(energyKwh: 0.02, carbonGCo2: 2),
          renewablePercentSum: 80,
          renewableSampleCount: 1,
          renewableEnergyKwh: 0.01,
          renewableWeightedPercentKwh: 0.8,
        ),
        'renewablePercentSum': const ConsumptionLocationMetrics(
          metrics: ConsumptionMetrics(energyKwh: 0.01, carbonGCo2: 2),
          renewablePercentSum: 90,
          renewableSampleCount: 1,
          renewableEnergyKwh: 0.01,
          renewableWeightedPercentKwh: 0.8,
        ),
        'renewableSampleCount': const ConsumptionLocationMetrics(
          metrics: ConsumptionMetrics(energyKwh: 0.01, carbonGCo2: 2),
          renewablePercentSum: 80,
          renewableSampleCount: 2,
          renewableEnergyKwh: 0.01,
          renewableWeightedPercentKwh: 0.8,
        ),
        'renewableEnergyKwh': const ConsumptionLocationMetrics(
          metrics: ConsumptionMetrics(energyKwh: 0.01, carbonGCo2: 2),
          renewablePercentSum: 80,
          renewableSampleCount: 1,
          renewableEnergyKwh: 0.02,
          renewableWeightedPercentKwh: 0.8,
        ),
        'renewableWeightedPercentKwh': const ConsumptionLocationMetrics(
          metrics: ConsumptionMetrics(energyKwh: 0.01, carbonGCo2: 2),
          renewablePercentSum: 80,
          renewableSampleCount: 1,
          renewableEnergyKwh: 0.01,
          renewableWeightedPercentKwh: 0.9,
        ),
      };

      for (final MapEntry(key: field, value: variant) in variants.entries) {
        expect(
          variant,
          isNot(equals(base)),
          reason: '$field must participate in equality',
        );
      }
      expect(base, isNot(equals(Object())));
    });
  });

  group('ConsumptionDayBuckets', () {
    test('deep structural equality across independently built nested maps', () {
      final a = _makeBuckets();
      final b = _makeBuckets();
      expect(identical(a, b), isFalse);
      expect(identical(a.days, b.days), isFalse);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test(
      'unequal when the window, a day, a category key, or a cell differs',
      () {
        final base = _makeBuckets();
        final variants = <String, ConsumptionDayBuckets>{
          'windowStartDay': _makeBuckets(windowStartDay: 20501),
          'cell value': _makeBuckets(
            days: {
              20500: {
                'work': _makeMetrics(callCount: 99),
                null: _makeMetrics(callCount: 2),
              },
              20501: {'play': _makeMetrics(inputTokens: 99)},
            },
          ),
          'category key': _makeBuckets(
            days: {
              20500: {
                'work': _makeMetrics(),
                'other': _makeMetrics(callCount: 2),
              },
              20501: {'play': _makeMetrics(inputTokens: 99)},
            },
          ),
          'missing day': _makeBuckets(
            days: {
              20500: {
                'work': _makeMetrics(),
                null: _makeMetrics(callCount: 2),
              },
            },
          ),
          'model day': _makeBuckets(
            modelDays: {
              20500: {
                'glm-5.2': _makeMetrics(callCount: 3),
                null: _makeMetrics(totalTokens: 7),
              },
            },
          ),
          'location day': _makeBuckets(
            locationDays: {
              20500: {
                ConsumptionLocationKey.fromDataCenter(
                  'FI',
                ): const ConsumptionLocationMetrics(
                  metrics: ConsumptionMetrics(energyKwh: 0.5),
                ),
              },
            },
          ),
        };
        for (final MapEntry(key: difference, value: variant)
            in variants.entries) {
          expect(
            variant,
            isNot(equals(base)),
            reason: 'a differing $difference must break equality',
          );
        }
        expect(base, isNot(equals(Object())));
      },
    );
  });

  // ---------------------------------------------------------------------
  // Property-based tests (Glados)
  // ---------------------------------------------------------------------

  glados.Glados<ConsumptionMetrics>(glados.any.consumptionMetrics).test(
    'zero is the identity of +',
    (m) {
      expect(m + ConsumptionMetrics.zero, m);
      expect(ConsumptionMetrics.zero + m, m);
    },
    tags: 'glados',
  );

  glados.Glados2<ConsumptionMetrics, ConsumptionMetrics>(
    glados.any.consumptionMetrics,
    glados.any.consumptionMetrics,
  ).test('+ is commutative', (a, b) {
    expect(a + b, b + a);
  }, tags: 'glados');

  glados.Glados3<ConsumptionMetrics, ConsumptionMetrics, ConsumptionMetrics>(
    glados.any.consumptionMetrics,
    glados.any.consumptionMetrics,
    glados.any.consumptionMetrics,
  ).test('+ is associative (quarter-step doubles keep sums exact)', (a, b, c) {
    expect((a + b) + c, a + (b + c));
  }, tags: 'glados');

  glados.Glados<List<ConsumptionMetrics>>(
    glados.any.consumptionMetricsList,
  ).test('folding a list with + accumulates every field', (list) {
    final sum = list.fold(ConsumptionMetrics.zero, (acc, m) => acc + m);
    expect(sum.callCount, list.fold<int>(0, (s, m) => s + m.callCount));
    expect(sum.inputTokens, list.fold<int>(0, (s, m) => s + m.inputTokens));
    expect(sum.outputTokens, list.fold<int>(0, (s, m) => s + m.outputTokens));
    expect(
      sum.cachedInputTokens,
      list.fold<int>(0, (s, m) => s + m.cachedInputTokens),
    );
    expect(
      sum.thoughtsTokens,
      list.fold<int>(0, (s, m) => s + m.thoughtsTokens),
    );
    expect(sum.totalTokens, list.fold<int>(0, (s, m) => s + m.totalTokens));
    expect(sum.credits, list.fold<double>(0, (s, m) => s + m.credits));
    expect(sum.energyKwh, list.fold<double>(0, (s, m) => s + m.energyKwh));
    expect(sum.carbonGCo2, list.fold<double>(0, (s, m) => s + m.carbonGCo2));
    expect(sum.waterLiters, list.fold<double>(0, (s, m) => s + m.waterLiters));
  }, tags: 'glados');

  glados.Glados2<ConsumptionMetrics, int>(
    glados.any.consumptionMetrics,
    glados.any.intInRange(0, 100),
  ).test(
    'metrics and totals equality is structural (rebuild == original)',
    (m, impactCalls) {
      final metricsCopy = _copyMetrics(m);
      expect(identical(metricsCopy, m), isFalse);
      expect(metricsCopy, m);
      expect(metricsCopy.hashCode, m.hashCode);

      final totals = _totalsFromMetrics(m, impactCallCount: impactCalls);
      final totalsCopy = _totalsFromMetrics(m, impactCallCount: impactCalls);
      expect(identical(totalsCopy, totals), isFalse);
      expect(totalsCopy, totals);
      expect(totalsCopy.hashCode, totals.hashCode);
      expect(
        totals,
        isNot(equals(_totalsFromMetrics(m, impactCallCount: impactCalls + 1))),
      );
    },
    tags: 'glados',
  );

  glados.Glados<List<_BucketSpec>>(glados.any.bucketSpecs).test(
    'day buckets built independently from the same rows are deeply equal '
    'and one extra cell breaks equality',
    (specs) {
      final a = ConsumptionDayBuckets(
        windowStartDay: 20000,
        days: _buildDays(specs),
      );
      final b = ConsumptionDayBuckets(
        windowStartDay: 20000,
        days: _buildDays(specs),
      );
      expect(identical(a.days, b.days), isFalse);
      expect(a, b);
      expect(a.hashCode, b.hashCode);

      // 99999 lies outside the generated day range, so this always adds a day.
      final mutated = ConsumptionDayBuckets(
        windowStartDay: 20000,
        days: {
          ..._buildDays(specs),
          99999: const {null: ConsumptionMetrics(callCount: 1)},
        },
      );
      expect(mutated, isNot(equals(a)));
    },
    tags: 'glados',
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ConsumptionTotals _makeTotals({
  int callCount = 7,
  int impactCallCount = 5,
  int inputTokens = 1000,
  int outputTokens = 500,
  int cachedInputTokens = 200,
  int thoughtsTokens = 50,
  int totalTokens = 1750,
  double credits = 0.02,
  double energyKwh = 0.003,
  double carbonGCo2 = 1.2,
  double waterLiters = 0.4,
}) => ConsumptionTotals(
  callCount: callCount,
  impactCallCount: impactCallCount,
  inputTokens: inputTokens,
  outputTokens: outputTokens,
  cachedInputTokens: cachedInputTokens,
  thoughtsTokens: thoughtsTokens,
  totalTokens: totalTokens,
  credits: credits,
  energyKwh: energyKwh,
  carbonGCo2: carbonGCo2,
  waterLiters: waterLiters,
);

ConsumptionMetrics _makeMetrics({
  int callCount = 1,
  int inputTokens = 11,
  int outputTokens = 13,
  int cachedInputTokens = 17,
  int thoughtsTokens = 19,
  int totalTokens = 60,
  double credits = 0.25,
  double energyKwh = 0.625,
  double carbonGCo2 = 0.75,
  double waterLiters = 1.25,
}) => ConsumptionMetrics(
  callCount: callCount,
  inputTokens: inputTokens,
  outputTokens: outputTokens,
  cachedInputTokens: cachedInputTokens,
  thoughtsTokens: thoughtsTokens,
  totalTokens: totalTokens,
  credits: credits,
  energyKwh: energyKwh,
  carbonGCo2: carbonGCo2,
  waterLiters: waterLiters,
);

ConsumptionMetrics _copyMetrics(ConsumptionMetrics m) => ConsumptionMetrics(
  callCount: m.callCount,
  inputTokens: m.inputTokens,
  outputTokens: m.outputTokens,
  cachedInputTokens: m.cachedInputTokens,
  thoughtsTokens: m.thoughtsTokens,
  totalTokens: m.totalTokens,
  credits: m.credits,
  energyKwh: m.energyKwh,
  carbonGCo2: m.carbonGCo2,
  waterLiters: m.waterLiters,
);

ConsumptionTotals _totalsFromMetrics(
  ConsumptionMetrics m, {
  required int impactCallCount,
}) => ConsumptionTotals(
  callCount: m.callCount,
  impactCallCount: impactCallCount,
  inputTokens: m.inputTokens,
  outputTokens: m.outputTokens,
  cachedInputTokens: m.cachedInputTokens,
  thoughtsTokens: m.thoughtsTokens,
  totalTokens: m.totalTokens,
  credits: m.credits,
  energyKwh: m.energyKwh,
  carbonGCo2: m.carbonGCo2,
  waterLiters: m.waterLiters,
);

ConsumptionDayBuckets _makeBuckets({
  int windowStartDay = 20500,
  Map<int, Map<String?, ConsumptionMetrics>>? days,
  Map<int, Map<String?, ConsumptionMetrics>>? modelDays,
  Map<int, Map<ConsumptionLocationKey, ConsumptionLocationMetrics>>?
  locationDays,
}) => ConsumptionDayBuckets(
  windowStartDay: windowStartDay,
  days:
      days ??
      {
        20500: {
          'work': _makeMetrics(),
          null: _makeMetrics(callCount: 2),
        },
        20501: {'play': _makeMetrics(inputTokens: 99)},
      },
  modelDays: modelDays ?? const {},
  locationDays: locationDays ?? const {},
);

/// One generated (day, category, metrics) row for bucket-equality properties.
class _BucketSpec {
  const _BucketSpec({
    required this.day,
    required this.categorySeed,
    required this.metrics,
  });

  final int day;
  final int categorySeed;
  final ConsumptionMetrics metrics;

  String? get categoryId => categorySeed == 0 ? null : 'cat-$categorySeed';

  @override
  String toString() =>
      '_BucketSpec(day: $day, cat: $categoryId, calls: ${metrics.callCount})';
}

Map<int, Map<String?, ConsumptionMetrics>> _buildDays(
  List<_BucketSpec> specs,
) {
  final days = <int, Map<String?, ConsumptionMetrics>>{};
  for (final spec in specs) {
    final cells = days.putIfAbsent(spec.day, () => {});
    cells[spec.categoryId] =
        (cells[spec.categoryId] ?? ConsumptionMetrics.zero) + spec.metrics;
  }
  return days;
}

extension _AnyConsumption on glados.Any {
  /// Metrics whose doubles are quarter-integers, so `+` over up to a few
  /// thousand of them is exact and the algebraic laws hold under `==`
  /// (no approximate matchers needed).
  glados.Generator<ConsumptionMetrics> get consumptionMetrics => combine10(
    intInRange(0, 100),
    intInRange(0, 100000),
    intInRange(0, 100000),
    intInRange(0, 100000),
    intInRange(0, 100000),
    intInRange(0, 300000),
    intInRange(0, 4000),
    intInRange(0, 4000),
    intInRange(0, 4000),
    intInRange(0, 4000),
    (
      int callCount,
      int inputTokens,
      int outputTokens,
      int cachedInputTokens,
      int thoughtsTokens,
      int totalTokens,
      int creditsQuarters,
      int energyQuarters,
      int carbonQuarters,
      int waterQuarters,
    ) => ConsumptionMetrics(
      callCount: callCount,
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      cachedInputTokens: cachedInputTokens,
      thoughtsTokens: thoughtsTokens,
      totalTokens: totalTokens,
      credits: creditsQuarters / 4,
      energyKwh: energyQuarters / 4,
      carbonGCo2: carbonQuarters / 4,
      waterLiters: waterQuarters / 4,
    ),
  );

  glados.Generator<List<ConsumptionMetrics>> get consumptionMetricsList =>
      list(consumptionMetrics);

  glados.Generator<_BucketSpec> get bucketSpec => combine3(
    intInRange(20000, 20040),
    intInRange(0, 4),
    consumptionMetrics,
    (int day, int categorySeed, ConsumptionMetrics metrics) => _BucketSpec(
      day: day,
      categorySeed: categorySeed,
      metrics: metrics,
    ),
  );

  glados.Generator<List<_BucketSpec>> get bucketSpecs => list(bucketSpec);
}
