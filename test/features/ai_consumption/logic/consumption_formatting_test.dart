import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai_consumption/logic/consumption_formatting.dart';

void main() {
  group('formatCredits', () {
    test('formats each magnitude band exactly', () {
      const cases = <(double, String)>[
        (0, '€0.00'),
        (-0.5, '€0.00'), // negative dust clamps to zero
        (0.0099, '<€0.01'),
        (0.01, '€0.01'),
        (0.42, '€0.42'),
        (1.5, '€1.50'),
        (99.99, '€99.99'),
        (100, '€100'),
        (250.4, '€250'),
        (1234, '€1234'),
      ];
      for (final (input, expected) in cases) {
        expect(formatCredits(input), expected, reason: 'credits=$input');
      }
    });
  });

  group('formatEnergyKwh', () {
    test('formats each magnitude band exactly', () {
      const cases = <(double, String)>[
        (0, '0 Wh'),
        (-1, '0 Wh'), // negative clamps to zero
        (0.0005, '<1 Wh'),
        (0.001, '1.0 Wh'),
        (0.0034, '3.4 Wh'),
        (0.012, '12 Wh'),
        (0.5, '500 Wh'),
        (1, '1.0 kWh'),
        (1.2, '1.2 kWh'),
        (9.9, '9.9 kWh'),
        (10, '10 kWh'),
        (34, '34 kWh'),
      ];
      for (final (input, expected) in cases) {
        expect(formatEnergyKwh(input), expected, reason: 'kwh=$input');
      }
    });
  });

  group('formatCarbonGrams', () {
    test('formats each magnitude band exactly', () {
      const cases = <(double, String)>[
        (0, '0 g'),
        (-2, '0 g'), // negative clamps to zero
        (0.05, '<0.1 g'),
        (0.1, '0.1 g'),
        (0.4, '0.4 g'),
        (3.4, '3.4 g'),
        (12, '12 g'),
        (120, '120 g'),
        (999.4, '999 g'),
        (1000, '1.0 kg'),
        (1200, '1.2 kg'),
        (15000, '15 kg'),
      ];
      for (final (input, expected) in cases) {
        expect(formatCarbonGrams(input), expected, reason: 'grams=$input');
      }
    });
  });

  group('formatWaterLiters', () {
    test('formats each magnitude band exactly', () {
      const cases = <(double, String)>[
        (0, '0 mL'),
        (-1, '0 mL'), // negative clamps to zero
        (0.0005, '<1 mL'),
        (0.001, '1.0 mL'),
        (0.0034, '3.4 mL'),
        (0.012, '12 mL'),
        (0.5, '500 mL'),
        (1, '1.0 L'),
        (1.2, '1.2 L'),
        (12, '12 L'),
      ];
      for (final (input, expected) in cases) {
        expect(formatWaterLiters(input), expected, reason: 'liters=$input');
      }
    });
  });

  group('formatTokenCount', () {
    test('compacts token counts exactly', () {
      const cases = <(int, String)>[
        (0, '0'),
        (950, '950'),
        (999, '999'),
        (1000, '1K'),
        (1500, '1.5K'),
        (12300, '12.3K'),
        (4500000, '4.5M'),
      ];
      for (final (input, expected) in cases) {
        expect(formatTokenCount(input), expected, reason: 'tokens=$input');
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Properties: every output is non-empty and carries its unit token; the
  // unit escalates monotonically at the documented thresholds; and no
  // formatter ever leaks 'null'/'NaN' for non-negative finite input.
  // ---------------------------------------------------------------------------
  group('formatting properties', () {
    glados.Glados<double>(
      glados.any.doubleInRange(0, 1000000000),
      glados.ExploreConfig(numRuns: 200),
    ).test('outputs are non-empty, unit-carrying, and never null/NaN', (
      value,
    ) {
      final credits = formatCredits(value);
      final energy = formatEnergyKwh(value);
      final carbon = formatCarbonGrams(value);
      final water = formatWaterLiters(value);
      for (final output in [credits, energy, carbon, water]) {
        expect(output, isNotEmpty, reason: 'value=$value');
        expect(output, isNot(contains('null')), reason: 'value=$value');
        expect(output, isNot(contains('NaN')), reason: 'value=$value');
      }
      // Credits carry the currency as a prefix; the metrics carry their unit
      // as a suffix ('kWh' still ends in 'Wh', 'kg' in 'g', 'mL' in 'L').
      expect(credits, startsWith(value > 0 && value < 0.01 ? '<€' : '€'));
      expect(energy, endsWith('Wh'), reason: 'value=$value');
      expect(carbon, endsWith('g'), reason: 'value=$value');
      expect(water, endsWith('L'), reason: 'value=$value');
    }, tags: 'glados');

    glados.Glados<double>(
      glados.any.doubleInRange(1, 1000000),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'at or above the escalation threshold the big unit always wins',
      (
        value,
      ) {
        expect(formatEnergyKwh(value), endsWith(' kWh'), reason: 'kwh=$value');
        expect(
          formatWaterLiters(value),
          endsWith(' L'),
          reason: 'liters=$value',
        );
        expect(
          formatWaterLiters(value),
          isNot(contains('mL')),
          reason: 'liters=$value',
        );
        expect(
          formatCarbonGrams(value * 1000),
          endsWith(' kg'),
          reason: 'grams=${value * 1000}',
        );
      },
      tags: 'glados',
    );

    glados.Glados<double>(
      glados.any.doubleInRange(0.001, 0.999),
      glados.ExploreConfig(numRuns: 120),
    ).test('below the escalation threshold the small unit always wins', (
      value,
    ) {
      expect(formatEnergyKwh(value), endsWith(' Wh'), reason: 'kwh=$value');
      expect(
        formatEnergyKwh(value),
        isNot(contains('kWh')),
        reason: 'kwh=$value',
      );
      expect(formatWaterLiters(value), endsWith(' mL'), reason: 'l=$value');
      // Same band in grams stays in grams (0.1 g <= value < 1000 g).
      expect(formatCarbonGrams(value + 0.1), endsWith(' g'), reason: '$value');
      expect(
        formatCarbonGrams(value + 0.1),
        isNot(contains('kg')),
        reason: 'grams=${value + 0.1}',
      );
    }, tags: 'glados');

    glados.Glados<double>(
      glados.any.doubleInRange(1e-9, 0.00099),
      glados.ExploreConfig(numRuns: 120),
    ).test('sub-unit dust collapses to the documented floors', (value) {
      expect(formatEnergyKwh(value), '<1 Wh', reason: 'kwh=$value');
      expect(formatWaterLiters(value), '<1 mL', reason: 'liters=$value');
      expect(formatCarbonGrams(value), '<0.1 g', reason: 'grams=$value');
      expect(formatCredits(value), '<€0.01', reason: 'credits=$value');
    }, tags: 'glados');

    glados.Glados<double>(
      glados.any.doubleInRange(100, 1000000),
      glados.ExploreConfig(numRuns: 120),
    ).test('credits from €100 up are whole euros without decimals', (value) {
      expect(
        formatCredits(value),
        matches(RegExp(r'^€\d+$')),
        reason: 'credits=$value',
      );
    }, tags: 'glados');

    glados.Glados<int>(
      glados.any.intInRange(0, 1000000000),
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'token counts always compact to digits with an optional suffix',
      (
        tokens,
      ) {
        expect(
          formatTokenCount(tokens),
          matches(RegExp(r'^\d+(\.\d+)?[KMBT]?$')),
          reason: 'tokens=$tokens',
        );
      },
      tags: 'glados',
    );
  });
}
