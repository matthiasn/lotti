// ignore_for_file: prefer_const_literals_to_create_immutables

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_call_impact.dart';

void main() {
  group('MeliousCallImpact.fromResponseJson', () {
    test('parses a full non-streaming Melious response', () {
      final impact = MeliousCallImpact.fromResponseJson({
        'usage': {'prompt_tokens': 1000, 'completion_tokens': 500},
        'environment_impact': {
          'energy_kwh': 0.0003,
          'carbon_g_co2': 0.12,
          'water_liters': 0.01,
          'location': 'FI',
          'provider_id': 'nebius',
          'renewable_percent': 100,
          'pue': 1.1,
        },
        'billing_cost': {'credits': 0.002},
      });

      expect(impact.energyKwh, 0.0003);
      expect(impact.carbonGCo2, 0.12);
      expect(impact.waterLiters, 0.01);
      expect(impact.dataCenter, 'FI');
      expect(impact.providerId, 'nebius');
      expect(impact.renewablePercent, 100);
      expect(impact.pue, 1.1);
      expect(impact.costCredits, 0.002);
      expect(impact.hasData, isTrue);
    });

    test('returns all-null (hasData false) when impact blocks are absent', () {
      final impact = MeliousCallImpact.fromResponseJson({
        'usage': {'prompt_tokens': 10},
      });

      expect(impact.hasData, isFalse);
      expect(impact.energyKwh, isNull);
      expect(impact.costCredits, isNull);
      expect(impact.dataCenter, isNull);
    });

    test('coerces numeric strings and ignores blank/oddly-typed fields', () {
      final impact = MeliousCallImpact.fromResponseJson({
        'environment_impact': {
          'energy_kwh': '0.0005',
          'location': '  ',
          'provider_id': 'x',
          'pue': 'not-a-number',
        },
        'billing_cost': {'credits': 3},
      });

      expect(impact.energyKwh, 0.0005);
      expect(impact.dataCenter, isNull); // blank → null
      expect(impact.providerId, 'x');
      expect(impact.pue, isNull); // unparseable → null
      expect(impact.costCredits, 3.0);
    });

    test('tolerates non-map impact blocks', () {
      final impact = MeliousCallImpact.fromResponseJson({
        'environment_impact': 'oops',
        'billing_cost': 42,
      });

      expect(impact.hasData, isFalse);
    });
  });

  group('InferenceImpactCollector', () {
    test('carries the impact for later out-of-band reads', () {
      final collector = InferenceImpactCollector();
      expect(collector.impact, isNull);

      const impact = MeliousCallImpact(energyKwh: 0.1, costCredits: 0.5);
      collector.impact = impact;

      expect(collector.impact, impact);
    });
  });
}
