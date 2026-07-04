import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai_consumption/logic/consumption_formatting.dart';
import 'package:lotti/features/ai_consumption/model/consumption_aggregation_models.dart';
import 'package:lotti/features/ai_consumption/model/impact_dashboard_models.dart';
import 'package:lotti/features/insights/model/insights_models.dart'
    show InsightsGranularity;

void main() {
  const metrics = ConsumptionMetrics(
    callCount: 3,
    inputTokens: 100,
    outputTokens: 50,
    cachedInputTokens: 5,
    thoughtsTokens: 7,
    totalTokens: 150,
    credits: 1.25,
    energyKwh: 0.5,
    carbonGCo2: 12,
    waterLiters: 0.2,
  );

  group('ConsumptionMetric.valueOf', () {
    test('projects the metric-specific field out of the bundle', () {
      expect(ConsumptionMetric.cost.valueOf(metrics), 1.25);
      expect(ConsumptionMetric.energy.valueOf(metrics), 0.5);
      expect(ConsumptionMetric.carbon.valueOf(metrics), 12.0);
      expect(ConsumptionMetric.tokens.valueOf(metrics), 150.0);
    });
  });

  group('ConsumptionMetric.formatValue', () {
    test('delegates to the metric-specific adaptive-unit formatter', () {
      expect(ConsumptionMetric.cost.formatValue(1.25), '€1.25');
      expect(ConsumptionMetric.cost.formatValue(1.25), formatCredits(1.25));
      expect(ConsumptionMetric.energy.formatValue(0.5), '500 Wh');
      expect(
        ConsumptionMetric.energy.formatValue(0.5),
        formatEnergyKwh(0.5),
      );
      expect(ConsumptionMetric.carbon.formatValue(12), '12 g');
      expect(ConsumptionMetric.carbon.formatValue(12), formatCarbonGrams(12));
      expect(ConsumptionMetric.tokens.formatValue(12345.6), '12.3K');
      expect(
        ConsumptionMetric.tokens.formatValue(12345.6),
        formatTokenCount(12346),
      );
    });
  });

  group('ImpactChartData', () {
    ImpactChartData chart(List<List<double>> values) => ImpactChartData(
      granularity: InsightsGranularity.day,
      bucketStarts: [DateTime(2024, 3, 4), DateTime(2024, 3, 5)],
      seriesKeys: [for (var s = 0; s < values.length; s++) 'cat-$s'],
      values: values,
    );

    test('isEmpty is true with no series or all-zero values', () {
      expect(
        const ImpactChartData(
          granularity: InsightsGranularity.day,
          bucketStarts: [],
          seriesKeys: [],
          values: [],
        ).isEmpty,
        isTrue,
      );
      expect(
        chart([
          [0, 0],
          [0, 0],
        ]).isEmpty,
        isTrue,
      );
    });

    test('isEmpty is false once any value is positive', () {
      expect(
        chart([
          [0, 0.01],
          [0, 0],
        ]).isEmpty,
        isFalse,
      );
    });

    test('deep value equality covers nested values and flags', () {
      final a = chart([
        [1.5, 2.5],
      ]);
      final b = chart([
        [1.5, 2.5],
      ]);
      final c = chart([
        [1.5, 2.6],
      ]);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(
        a,
        isNot(
          ImpactChartData(
            granularity: InsightsGranularity.day,
            bucketStarts: a.bucketStarts,
            seriesKeys: a.seriesKeys,
            values: a.values,
            partialFirstBucket: true,
          ),
        ),
      );
    });
  });

  // ---------------------------------------------------------------------
  // Property-based tests (Glados)
  // ---------------------------------------------------------------------

  glados.Glados2<ConsumptionMetrics, ConsumptionMetrics>(
    glados.any.consumptionMetrics,
    glados.any.consumptionMetrics,
    glados.ExploreConfig(numRuns: 200),
  ).test('valueOf distributes over metric addition for every metric', (a, b) {
    for (final metric in ConsumptionMetric.values) {
      // Integer-valued doubles: the sum is fp-exact, so strict equality is
      // deterministic.
      expect(metric.valueOf(a + b), metric.valueOf(a) + metric.valueOf(b));
    }
  }, tags: 'glados');

  glados.Glados<int>(
    glados.any.intInRange(0, 1 << 40),
    glados.ExploreConfig(numRuns: 200),
  ).test('tokens formatting matches the shared compact token formatter', (v) {
    expect(
      ConsumptionMetric.tokens.formatValue(v.toDouble()),
      formatTokenCount(v),
    );
  }, tags: 'glados');
}

extension on glados.Any {
  /// Metric bundles whose double fields hold integer values, so additive
  /// properties can assert exact equality without fp tolerance.
  glados.Generator<ConsumptionMetrics> get consumptionMetrics => combine4(
    intInRange(0, 100000),
    intInRange(0, 100000),
    intInRange(0, 100000),
    intInRange(0, 100000),
    (int tokens, int credits, int energy, int carbon) => ConsumptionMetrics(
      callCount: 1,
      totalTokens: tokens,
      credits: credits.toDouble(),
      energyKwh: energy.toDouble(),
      carbonGCo2: carbon.toDouble(),
    ),
  );
}
