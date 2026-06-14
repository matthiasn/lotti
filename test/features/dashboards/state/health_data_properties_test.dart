import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/dashboards/state/health_data.dart';

import 'health_data_test_helpers.dart';

void main() {
  // Deterministic anchor date shared by example and Glados property tests.
  final propertyBase = DateTime(2024, 3, 10);

  group('aggregateDailySum — properties', () {
    glados.Glados(
      glados.any.entrySpecs,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'sum of all daily buckets equals sum of all input values',
      (specs) {
        final entities = makeEntries(specs, propertyBase);
        final result = aggregateDailySum(entities);
        final bucketTotal = result.fold<num>(0, (acc, o) => acc + o.value);
        final inputTotal = entities.fold<num>(
          0,
          (acc, e) {
            if (e is QuantitativeEntry) {
              return acc + e.data.value;
            }
            return acc;
          },
        );
        expect(
          bucketTotal,
          closeTo(inputTotal, 1e-9),
          reason: 'bucket sums must match total input',
        );
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.entrySpecs,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'output length is at most the number of distinct calendar days',
      (specs) {
        final entities = makeEntries(specs, propertyBase);
        final distinctDays = specs.map((s) => s.dayOffset).toSet().length;
        final result = aggregateDailySum(entities);
        expect(result.length, lessThanOrEqualTo(distinctDays));
      },
      tags: 'glados',
    );
  });

  group('aggregateDailyMax — properties', () {
    glados.Glados(
      glados.any.entrySpecs,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'each bucket value is >= any single input for the same day',
      (specs) {
        final entities = makeEntries(specs, propertyBase);
        final result = aggregateDailyMax(entities);
        // Build a map from date → max value from the result.
        final maxByDate = {for (final o in result) o.dateTime: o.value};

        for (var i = 0; i < entities.length; i++) {
          final entity = entities[i];
          if (entity is! QuantitativeEntry) continue;
          final day = propertyBase.add(Duration(days: specs[i].dayOffset));
          final bucketMax = maxByDate[day];
          if (bucketMax == null) continue;
          expect(
            bucketMax,
            greaterThanOrEqualTo(entity.data.value),
            reason: 'bucket max must be >= individual entry',
          );
        }
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.entrySpecs,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'output length is at most the number of distinct calendar days',
      (specs) {
        final entities = makeEntries(specs, propertyBase);
        final distinctDays = specs.map((s) => s.dayOffset).toSet().length;
        final result = aggregateDailyMax(entities);
        expect(result.length, lessThanOrEqualTo(distinctDays));
      },
      tags: 'glados',
    );
  });
}
