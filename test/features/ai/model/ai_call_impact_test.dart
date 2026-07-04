// ignore_for_file: prefer_const_literals_to_create_immutables

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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

  group('MeliousCallImpact value semantics', () {
    test('equality and hashCode are structural, not identity-based', () {
      final a = _makeImpact();
      final b = _makeImpact();
      expect(identical(a, b), isFalse);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('instances differing in exactly one field are unequal', () {
      final base = _makeImpact();
      final variants = <String, MeliousCallImpact>{
        'energyKwh': _makeImpact(energyKwh: 9.9),
        'carbonGCo2': _makeImpact(carbonGCo2: 9.9),
        'waterLiters': _makeImpact(waterLiters: 9.9),
        'renewablePercent': _makeImpact(renewablePercent: 9.9),
        'pue': _makeImpact(pue: 9.9),
        'dataCenter': _makeImpact(dataCenter: 'DE'),
        'providerId': _makeImpact(providerId: 'other'),
        'costCredits': _makeImpact(costCredits: 9.9),
      };
      for (final MapEntry(key: field, value: variant) in variants.entries) {
        expect(
          variant,
          isNot(equals(base)),
          reason: '$field must participate in equality',
        );
      }
    });

    test('toString reports every field by name, nulls included', () {
      const impact = MeliousCallImpact(energyKwh: 0.25, dataCenter: 'FI');
      expect(
        impact.toString(),
        'MeliousCallImpact(energyKwh: 0.25, carbonGCo2: null, '
        'waterLiters: null, renewablePercent: null, '
        'pue: null, dataCenter: FI, providerId: null, '
        'costCredits: null)',
      );
    });
  });

  group('hasData', () {
    test('is true when any single field is set and false when none are', () {
      const singles = <String, MeliousCallImpact>{
        'energyKwh': MeliousCallImpact(energyKwh: 0.1),
        'carbonGCo2': MeliousCallImpact(carbonGCo2: 0.1),
        'waterLiters': MeliousCallImpact(waterLiters: 0.1),
        'renewablePercent': MeliousCallImpact(renewablePercent: 50),
        'pue': MeliousCallImpact(pue: 1.1),
        'dataCenter': MeliousCallImpact(dataCenter: 'FI'),
        'providerId': MeliousCallImpact(providerId: 'nebius'),
        'costCredits': MeliousCallImpact(costCredits: 0.001),
      };
      for (final MapEntry(key: field, value: impact) in singles.entries) {
        expect(impact.hasData, isTrue, reason: 'only $field is set');
      }
      expect(const MeliousCallImpact().hasData, isFalse);
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

  // ---------------------------------------------------------------------
  // Property-based tests (Glados)
  // ---------------------------------------------------------------------

  glados.Glados<_ImpactSpec>(glados.any.impactSpec).test(
    'fromResponseJson round-trips every present/absent field combination '
    'and hasData mirrors field presence',
    (spec) {
      final json = spec.toResponseJson();
      final impact = MeliousCallImpact.fromResponseJson(json);

      expect(impact.energyKwh, spec.energyKwh);
      expect(impact.carbonGCo2, spec.carbonGCo2);
      expect(impact.waterLiters, spec.waterLiters);
      expect(impact.renewablePercent, spec.renewablePercent);
      expect(impact.pue, spec.pue);
      expect(impact.dataCenter, spec.dataCenter);
      expect(impact.providerId, spec.providerId);
      expect(impact.costCredits, spec.costCredits);
      expect(impact.hasData, spec.hasAnyField);

      // Parsing the same body twice yields structurally equal values.
      final reparsed = MeliousCallImpact.fromResponseJson(json);
      expect(identical(reparsed, impact), isFalse);
      expect(reparsed, impact);
      expect(reparsed.hashCode, impact.hashCode);
    },
    tags: 'glados',
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

MeliousCallImpact _makeImpact({
  double? energyKwh = 0.25,
  double? carbonGCo2 = 1.5,
  double? waterLiters = 0.03,
  double? renewablePercent = 80,
  double? pue = 1.2,
  String? dataCenter = 'FI',
  String? providerId = 'nebius',
  double? costCredits = 0.004,
}) => MeliousCallImpact(
  energyKwh: energyKwh,
  carbonGCo2: carbonGCo2,
  waterLiters: waterLiters,
  renewablePercent: renewablePercent,
  pue: pue,
  dataCenter: dataCenter,
  providerId: providerId,
  costCredits: costCredits,
);

/// One generated Melious response shape: each field is either absent
/// (negative/zero seed) or a quarter-integer double / seeded string, so the
/// expected parse result is computed exactly.
class _ImpactSpec {
  const _ImpactSpec({
    required this.energyQuarters,
    required this.carbonQuarters,
    required this.waterQuarters,
    required this.renewableQuarters,
    required this.pueQuarters,
    required this.locationSeed,
    required this.providerSeed,
    required this.creditsQuarters,
  });

  final int energyQuarters;
  final int carbonQuarters;
  final int waterQuarters;
  final int renewableQuarters;
  final int pueQuarters;
  final int locationSeed;
  final int providerSeed;
  final int creditsQuarters;

  static double? _quarter(int q) => q < 0 ? null : q / 4;

  double? get energyKwh => _quarter(energyQuarters);
  double? get carbonGCo2 => _quarter(carbonQuarters);
  double? get waterLiters => _quarter(waterQuarters);
  double? get renewablePercent => _quarter(renewableQuarters);
  double? get pue => _quarter(pueQuarters);
  String? get dataCenter => locationSeed == 0 ? null : 'DC-$locationSeed';
  String? get providerId => providerSeed == 0 ? null : 'provider-$providerSeed';
  double? get costCredits => _quarter(creditsQuarters);

  bool get hasAnyField =>
      energyKwh != null ||
      carbonGCo2 != null ||
      waterLiters != null ||
      renewablePercent != null ||
      pue != null ||
      dataCenter != null ||
      providerId != null ||
      costCredits != null;

  Map<String, dynamic> toResponseJson() => {
    'environment_impact': <String, dynamic>{
      if (energyKwh != null) 'energy_kwh': energyKwh,
      if (carbonGCo2 != null) 'carbon_g_co2': carbonGCo2,
      if (waterLiters != null) 'water_liters': waterLiters,
      if (renewablePercent != null) 'renewable_percent': renewablePercent,
      if (pue != null) 'pue': pue,
      if (dataCenter != null) 'location': dataCenter,
      if (providerId != null) 'provider_id': providerId,
    },
    'billing_cost': <String, dynamic>{
      if (costCredits != null) 'credits': costCredits,
    },
  };

  @override
  String toString() =>
      '_ImpactSpec(energy: $energyKwh, carbon: $carbonGCo2, '
      'water: $waterLiters, renewable: $renewablePercent, pue: $pue, '
      'location: $dataCenter, provider: $providerId, credits: $costCredits)';
}

extension _AnyImpact on glados.Any {
  glados.Generator<_ImpactSpec> get impactSpec => combine8(
    intInRange(-1, 4000),
    intInRange(-1, 4000),
    intInRange(-1, 400),
    intInRange(-1, 401),
    intInRange(-1, 13),
    intInRange(0, 4),
    intInRange(0, 4),
    intInRange(-1, 4000),
    (
      int energyQuarters,
      int carbonQuarters,
      int waterQuarters,
      int renewableQuarters,
      int pueQuarters,
      int locationSeed,
      int providerSeed,
      int creditsQuarters,
    ) => _ImpactSpec(
      energyQuarters: energyQuarters,
      carbonQuarters: carbonQuarters,
      waterQuarters: waterQuarters,
      renewableQuarters: renewableQuarters,
      pueQuarters: pueQuarters,
      locationSeed: locationSeed,
      providerSeed: providerSeed,
      creditsQuarters: creditsQuarters,
    ),
  );
}
