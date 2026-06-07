import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/dashboards/config/dashboard_health_config.dart';
import 'package:lotti/features/dashboards/state/health_data.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/charts/utils.dart';

import '../test_utils.dart';

// ---------------------------------------------------------------------------
// Generators for Glados property tests.
// ---------------------------------------------------------------------------

/// A single generated entry spec: (dayOffset in [0..6], value in [1..1000]).
typedef _EntrySpec = ({int dayOffset, int value});

extension _AnyHealthData on glados.Any {
  glados.Generator<_EntrySpec> get entrySpec =>
      glados.CombinableAny(this).combine2(
        glados.any.intInRange(0, 6),
        glados.any.intInRange(1, 1000),
        (int dayOffset, int value) => (dayOffset: dayOffset, value: value),
      );

  glados.Generator<List<_EntrySpec>> get entrySpecs =>
      glados.ListAnys(this).listWithLengthInRange(1, 12, entrySpec);

  /// A threshold-to-hex-color map with 1–4 entries.
  glados.Generator<Map<num, String>> get thresholdMap =>
      glados.CombinableAny(this).combine4(
        glados.any.intInRange(0, 300),
        glados.any.intInRange(301, 600),
        glados.any.intInRange(601, 900),
        glados.AnyUtils(this).choose(const [true, false]),
        (int t1, int t2, int t3, bool includeThird) => <num, String>{
          0: '#FF0000',
          t1: '#FFAA00',
          t2: '#00FF00',
          if (includeThird) t3: '#0000FF',
        },
      );
}

/// Converts an [_EntrySpec] list to [QuantitativeEntry] items anchored at
/// [base].
List<JournalEntity> _makeEntries(
  List<_EntrySpec> specs,
  DateTime base,
) {
  return <JournalEntity>[
    for (var i = 0; i < specs.length; i++)
      makeQuantitativeEntry(
        dateFrom: base.add(Duration(days: specs[i].dayOffset)),
        value: specs[i].value,
        dataType: 'HealthDataType.WEIGHT',
        id: 'e$i',
      ),
  ];
}

void main() {
  group('aggregateNone', () {
    test('returns one observation per quantitative entity', () {
      final entities = [
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 15, 10),
          value: 72.5,
          dataType: 'HealthDataType.WEIGHT',
        ),
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 16, 11),
          value: 73.0,
          dataType: 'HealthDataType.WEIGHT',
        ),
      ];

      final result = aggregateNone(entities, 'HealthDataType.WEIGHT');

      expect(result, hasLength(2));
      expect(result[0].dateTime, DateTime(2024, 3, 15, 10));
      expect(result[0].value, 72.5);
      expect(result[1].dateTime, DateTime(2024, 3, 16, 11));
      expect(result[1].value, 73.0);
    });

    test('multiplies by 100 for PERCENTAGE types', () {
      final entities = [
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 15),
          value: 0.25,
          dataType: 'HealthDataType.BODY_FAT_PERCENTAGE',
        ),
      ];

      final result = aggregateNone(
        entities,
        'HealthDataType.BODY_FAT_PERCENTAGE',
      );

      expect(result, hasLength(1));
      expect(result[0].value, 25.0);
    });

    test('does not multiply for non-PERCENTAGE types', () {
      final entities = [
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 15),
          value: 72.0,
          dataType: 'HealthDataType.WEIGHT',
        ),
      ];

      final result = aggregateNone(entities, 'HealthDataType.WEIGHT');

      expect(result[0].value, 72.0);
    });

    test('returns empty list for empty entities', () {
      final result = aggregateNone([], 'HealthDataType.WEIGHT');
      expect(result, isEmpty);
    });
  });

  group('aggregateDailyMax', () {
    test('takes max value per calendar day', () {
      final entities = [
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 15, 8),
          value: 5000,
          dataType: 'cumulative_step_count',
          id: 'a',
        ),
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 15, 18),
          value: 12000,
          dataType: 'cumulative_step_count',
          id: 'b',
        ),
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 16, 20),
          value: 8000,
          dataType: 'cumulative_step_count',
          id: 'c',
        ),
      ];

      final result = aggregateDailyMax(entities);

      expect(result, hasLength(2));

      final day15 = result.firstWhere(
        (o) => o.dateTime == DateTime(2024, 3, 15),
      );
      expect(day15.value, 12000);

      final day16 = result.firstWhere(
        (o) => o.dateTime == DateTime(2024, 3, 16),
      );
      expect(day16.value, 8000);
    });

    test('returns empty list for empty entities', () {
      expect(aggregateDailyMax([]), isEmpty);
    });
  });

  group('aggregateDailySum', () {
    test('sums values per calendar day', () {
      final entities = [
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 15, 8),
          value: 30,
          dataType: 'HealthDataType.SLEEP_ASLEEP',
          id: 'a',
        ),
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 15, 9),
          value: 20,
          dataType: 'HealthDataType.SLEEP_ASLEEP',
          id: 'b',
        ),
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 16, 10),
          value: 45,
          dataType: 'HealthDataType.SLEEP_ASLEEP',
          id: 'c',
        ),
      ];

      final result = aggregateDailySum(entities);

      expect(result, hasLength(2));

      final day15 = result.firstWhere(
        (o) => o.dateTime == DateTime(2024, 3, 15),
      );
      expect(day15.value, 50);

      final day16 = result.firstWhere(
        (o) => o.dateTime == DateTime(2024, 3, 16),
      );
      expect(day16.value, 45);
    });

    test('returns empty list for empty entities', () {
      expect(aggregateDailySum([]), isEmpty);
    });
  });

  group('transformToHours', () {
    test('divides each value by 60', () {
      final observations = [
        Observation(DateTime(2024, 3, 15), 120),
        Observation(DateTime(2024, 3, 16), 90),
      ];

      final result = transformToHours(observations);

      expect(result, hasLength(2));
      expect(result[0].value, 2.0);
      expect(result[1].value, 1.5);
    });

    test('preserves date times', () {
      final dt = DateTime(2024, 3, 15, 12);
      final result = transformToHours([Observation(dt, 60)]);
      expect(result[0].dateTime, dt);
    });

    test('returns empty list for empty input', () {
      expect(transformToHours([]), isEmpty);
    });
  });

  group('aggregateByType', () {
    test('routes to aggregateNone for none aggregation type', () {
      final entities = [
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 15, 10),
          value: 72.5,
          dataType: 'HealthDataType.WEIGHT',
        ),
      ];

      final result = aggregateByType(entities, 'HealthDataType.WEIGHT');

      expect(result, hasLength(1));
      expect(result[0].value, 72.5);
    });

    test('routes to aggregateDailyMax for dailyMax aggregation type', () {
      final entities = [
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 15, 8),
          value: 5000,
          dataType: 'cumulative_step_count',
          id: 'a',
        ),
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 15, 18),
          value: 12000,
          dataType: 'cumulative_step_count',
          id: 'b',
        ),
      ];

      final result = aggregateByType(entities, 'cumulative_step_count');

      expect(result, hasLength(1));
      expect(result[0].value, 12000);
    });

    test(
      'routes to dailyTimeSum and transforms to hours',
      () {
        final entities = [
          makeQuantitativeEntry(
            dateFrom: DateTime(2024, 3, 15),
            value: 120,
            dataType: 'HealthDataType.SLEEP_ASLEEP',
          ),
        ];

        final result = aggregateByType(entities, 'HealthDataType.SLEEP_ASLEEP');

        expect(result, hasLength(1));
        expect(result[0].value, 2.0);
      },
    );

    test('returns empty list for unknown data type', () {
      final result = aggregateByType([], 'UNKNOWN_TYPE');
      expect(result, isEmpty);
    });

    test('returns empty for unknown type even with non-empty entities', () {
      // No HealthTypeConfig resolves for the type, so the entities must be
      // ignored entirely rather than routed through a default aggregation.
      final entities = [
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 15),
          value: 10,
          dataType: 'UNKNOWN_TYPE',
          id: 'u0',
        ),
        makeQuantitativeEntry(
          dateFrom: DateTime(2024, 3, 16),
          value: 20,
          dataType: 'UNKNOWN_TYPE',
          id: 'u1',
        ),
      ];

      final result = aggregateByType(entities, 'UNKNOWN_TYPE');
      expect(result, isEmpty);
    });
  });

  group('colorByValueAndType', () {
    test('returns default color when config is null', () {
      final obs = Observation(DateTime(2024, 3, 15), 10000);
      final color = colorByValueAndType(obs, null);
      expect(color, isA<Color>());
    });

    test('returns default color when colorByValue is null', () {
      final config = HealthTypeConfig(
        displayName: 'Weight',
        healthType: 'HealthDataType.WEIGHT',
        chartType: HealthChartType.lineChart,
        aggregationType: HealthAggregationType.none,
        unit: 'kg',
      );
      final obs = Observation(DateTime(2024, 3, 15), 72);
      final color = colorByValueAndType(obs, config);
      expect(color, isA<Color>());
    });

    test('selects color based on threshold', () {
      final config = HealthTypeConfig(
        displayName: 'Steps',
        healthType: 'cumulative_step_count',
        chartType: HealthChartType.barChart,
        aggregationType: HealthAggregationType.dailyMax,
        unit: 'steps',
        colorByValue: {
          10000: '#82E6CE',
          6000: '#C4ECE2',
          0: '#FF9595',
        },
      );

      // Above 10000 → should get '#82E6CE'
      final highObs = Observation(DateTime(2024, 3, 15), 15000);
      final highColor = colorByValueAndType(highObs, config);
      expect(highColor, isA<Color>());

      // Between 6000 and 10000 → should get '#C4ECE2'
      final midObs = Observation(DateTime(2024, 3, 15), 7000);
      final midColor = colorByValueAndType(midObs, config);
      expect(midColor, isA<Color>());

      // Below 6000 → should get '#FF9595'
      final lowObs = Observation(DateTime(2024, 3, 15), 3000);
      final lowColor = colorByValueAndType(lowObs, config);
      expect(lowColor, isA<Color>());

      // All three colors should be different
      expect(highColor, isNot(equals(lowColor)));
      expect(highColor, isNot(equals(midColor)));
      expect(midColor, isNot(equals(lowColor)));
    });
  });

  group('findExtreme', () {
    test('returns 0 for empty observations', () {
      expect(findExtreme([], (a, b) => a > b ? a : b), 0.0);
    });

    test('finds extreme using given function', () {
      final obs = [
        Observation(DateTime(2024, 3, 15), 10),
        Observation(DateTime(2024, 3, 16), 5),
        Observation(DateTime(2024, 3, 17), 20),
      ];
      // Use max
      final result = findExtreme(obs, (a, b) => a > b ? a : b);
      expect(result, 20);
    });
  });

  group('findMin', () {
    test('returns 0 for empty list', () {
      expect(findMin([]), 0.0);
    });

    test('finds minimum value', () {
      final obs = [
        Observation(DateTime(2024, 3, 15), 10),
        Observation(DateTime(2024, 3, 16), 3),
        Observation(DateTime(2024, 3, 17), 7),
      ];
      expect(findMin(obs), 3);
    });

    test('works with single observation', () {
      final obs = [Observation(DateTime(2024, 3, 15), 42)];
      expect(findMin(obs), 42);
    });
  });

  group('findMax', () {
    test('returns 0 for empty list', () {
      expect(findMax([]), 0.0);
    });

    test('finds maximum value', () {
      final obs = [
        Observation(DateTime(2024, 3, 15), 10),
        Observation(DateTime(2024, 3, 16), 25),
        Observation(DateTime(2024, 3, 17), 7),
      ];
      expect(findMax(obs), 25);
    });

    test('works with negative values', () {
      final obs = [
        Observation(DateTime(2024, 3, 15), -10),
        Observation(DateTime(2024, 3, 16), -3),
        Observation(DateTime(2024, 3, 17), -7),
      ];
      expect(findMax(obs), -3);
    });
  });

  // -------------------------------------------------------------------------
  // Glados property tests.
  // -------------------------------------------------------------------------

  final propertyBase = DateTime(2024, 3, 10);

  group('aggregateDailySum — properties', () {
    glados.Glados(
      glados.any.entrySpecs,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'sum of all daily buckets equals sum of all input values',
      (specs) {
        final entities = _makeEntries(specs, propertyBase);
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
        final entities = _makeEntries(specs, propertyBase);
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
        final entities = _makeEntries(specs, propertyBase);
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
        final entities = _makeEntries(specs, propertyBase);
        final distinctDays = specs.map((s) => s.dayOffset).toSet().length;
        final result = aggregateDailyMax(entities);
        expect(result.length, lessThanOrEqualTo(distinctDays));
      },
      tags: 'glados',
    );
  });

  group('colorByValueAndType — properties', () {
    glados.Glados2<int, Map<num, String>>(
      glados.any.intInRange(0, 1200),
      glados.any.thresholdMap,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'returned color is always from the provided colorByValue map',
      (value, thresholds) {
        final config = HealthTypeConfig(
          displayName: 'Test',
          healthType: 'test_type',
          chartType: HealthChartType.barChart,
          aggregationType: HealthAggregationType.dailyMax,
          unit: 'u',
          colorByValue: thresholds,
        );
        final obs = Observation(DateTime(2024, 3, 15), value);
        final color = colorByValueAndType(obs, config);
        expect(color, isA<Color>());
        // The color must correspond to one of the hex values in the map.
        final validColors = thresholds.values.map(colorFromCssHex).toList();
        expect(validColors, contains(color));
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.intInRange(0, 1200),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'returns default color when config is null regardless of value',
      (value) {
        final obs = Observation(DateTime(2024, 3, 15), value);
        final color = colorByValueAndType(obs, null);
        expect(color, isA<Color>());
      },
      tags: 'glados',
    );
  });
}
