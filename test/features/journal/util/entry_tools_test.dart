import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';

/// Glados generators for entry-tools property tests.
extension _AnyDuration on glados.Any {
  /// Generates non-negative durations up to 99 hours 59 minutes 59 seconds,
  /// which keeps the formatted string predictably 8 or 9 characters wide.
  glados.Generator<Duration> get boundedDuration =>
      glados.any.intInRange(0, 359999).map((s) => Duration(seconds: s));
}

void main() {
  // ---------------------------------------------------------------------------
  // formatDuration — worked examples
  // ---------------------------------------------------------------------------

  group('formatDuration — worked examples', () {
    test('returns empty string for null', () {
      expect(formatDuration(null), '');
    });

    test('formats zero duration as 00:00:00 (zero-padded)', () {
      expect(formatDuration(Duration.zero), '00:00:00');
    });

    test('pads single-digit hours with leading zero (e.g. 1h → 01:…)', () {
      // 1 hour, 5 minutes, 3 seconds
      const d = Duration(hours: 1, minutes: 5, seconds: 3);
      final result = formatDuration(d);
      expect(result, '01:05:03');
      expect(result.length, 8);
    });

    test('does not pad double-digit hours (e.g. 10h → 10:…)', () {
      const d = Duration(hours: 10);
      final result = formatDuration(d);
      expect(result, '10:00:00');
      expect(result.length, 8);
    });

    test('formats sub-1-hour duration with leading zero (e.g. 0h30m45s)', () {
      const d = Duration(minutes: 30, seconds: 45);
      // '0:30:45'.substring(1,2) == ':' → padded to '00:30:45'
      expect(formatDuration(d), '00:30:45');
    });

    test('formats 9h 59m 59s correctly', () {
      const d = Duration(hours: 9, minutes: 59, seconds: 59);
      expect(formatDuration(d), '09:59:59');
    });

    test(
      'does not truncate sub-second precision (only integer seconds shown)',
      () {
        const d = Duration(hours: 2, milliseconds: 500);
        // Duration.toString strips sub-second: "2:00:00.500000" → first split
        // on '.' → "2:00:00", then padded to "02:00:00".
        expect(formatDuration(d), '02:00:00');
      },
    );
  });

  // ---------------------------------------------------------------------------
  // formatDuration — Glados property tests
  // ---------------------------------------------------------------------------

  group('formatDuration — properties', () {
    glados.Glados(
      glados.any.boundedDuration,
      glados.ExploreConfig(numRuns: 120),
    ).test('output is never empty for a non-null Duration', (d) {
      expect(formatDuration(d), isNotEmpty);
    }, tags: 'glados');

    glados.Glados(
      glados.any.boundedDuration,
      glados.ExploreConfig(numRuns: 120),
    ).test('output always matches HH:MM:SS or H:MM:SS pattern', (d) {
      final result = formatDuration(d);
      // Must match either "H:MM:SS" (7 chars) or "HH:MM:SS" (8 chars) etc.
      // The important invariant is that it ends with :XX:XX (seconds and
      // minutes each have exactly 2 digits after the first colon boundary).
      final parts = result.split(':');
      expect(parts, hasLength(3), reason: 'result=$result');
      expect(parts[1].length, 2, reason: 'minutes field must be 2 digits');
      expect(parts[2].length, 2, reason: 'seconds field must be 2 digits');
    }, tags: 'glados');

    glados.Glados(
      glados.any.boundedDuration,
      glados.ExploreConfig(numRuns: 120),
    ).test('durations below 10 hours are padded to start with a two-character '
        'hour field', (d) {
      if (d.inHours >= 10) return; // only test the padding branch
      final result = formatDuration(d);
      // The hour part is always at least 2 characters (zero-padded by the
      // padding branch).
      final hourPart = result.split(':').first;
      expect(hourPart.length, greaterThanOrEqualTo(2));
    }, tags: 'glados');
  });

  // ---------------------------------------------------------------------------
  // formatRangeDuration
  // ---------------------------------------------------------------------------

  group('formatRangeDuration — worked examples', () {
    test('non-positive spans render as 0m', () {
      expect(formatRangeDuration(Duration.zero), '0m');
      expect(formatRangeDuration(const Duration(minutes: -5)), '0m');
    });

    test('sub-hour spans show only minutes', () {
      expect(formatRangeDuration(const Duration(minutes: 45)), '45m');
    });

    test('whole hours omit the minute component', () {
      expect(formatRangeDuration(const Duration(hours: 1)), '1h');
    });

    test('hours and minutes combine', () {
      expect(
        formatRangeDuration(const Duration(hours: 1, minutes: 30)),
        '1h 30m',
      );
    });

    test('multi-day spans roll whole days into a d component', () {
      expect(
        formatRangeDuration(const Duration(days: 2, hours: 2)),
        '2d 2h',
      );
      expect(formatRangeDuration(const Duration(days: 1)), '1d');
      expect(
        formatRangeDuration(const Duration(days: 1, minutes: 5)),
        '1d 5m',
      );
      // 25h normalizes to 1d 1h.
      expect(formatRangeDuration(const Duration(hours: 25)), '1d 1h');
    });

    test('seconds are dropped', () {
      expect(
        formatRangeDuration(const Duration(hours: 1, minutes: 30, seconds: 45)),
        '1h 30m',
      );
    });
  });

  group('formatRangeDuration — properties', () {
    int parseMinutes(String s) {
      if (s == '0m') return 0;
      var total = 0;
      for (final part in s.split(' ')) {
        final n = int.parse(part.substring(0, part.length - 1));
        switch (part[part.length - 1]) {
          case 'd':
            total += n * 1440;
          case 'h':
            total += n * 60;
          case 'm':
            total += n;
        }
      }
      return total;
    }

    glados.Glados(
      glados.any.intInRange(0, 900000).map((s) => Duration(seconds: s)),
      glados.ExploreConfig(numRuns: 200),
    ).test('round-trips to the input truncated to whole minutes', (d) {
      final parsed = parseMinutes(formatRangeDuration(d));
      expect(parsed, d.inMinutes);
    }, tags: 'glados');

    glados.Glados(
      glados.any.intInRange(60, 900000).map((s) => Duration(seconds: s)),
      glados.ExploreConfig(numRuns: 200),
    ).test('emits no zero-valued components and keeps h<24, m<60', (d) {
      final out = formatRangeDuration(d);
      for (final part in out.split(' ')) {
        final n = int.parse(part.substring(0, part.length - 1));
        expect(n, greaterThan(0), reason: 'no zero components in "$out"');
        if (part.endsWith('h')) expect(n, lessThan(24));
        if (part.endsWith('m')) expect(n, lessThan(60));
      }
    }, tags: 'glados');
  });

  // ---------------------------------------------------------------------------
  // fromNullableBool
  // ---------------------------------------------------------------------------

  group('fromNullableBool', () {
    test('returns false for null', () {
      expect(fromNullableBool(null), isFalse);
    });

    test('returns true for true', () {
      expect(fromNullableBool(true), isTrue);
    });

    test('returns false for false', () {
      expect(fromNullableBool(false), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // formatType / formatUnit
  // ---------------------------------------------------------------------------

  group('formatType', () {
    test('strips HealthDataType. prefix', () {
      expect(formatType('HealthDataType.STEPS'), 'STEPS');
    });

    test('leaves string without prefix unchanged', () {
      expect(formatType('HEART_RATE'), 'HEART_RATE');
    });

    test('uses replaceAll: removes all occurrences of the prefix', () {
      // The function uses replaceAll, so both prefixes are stripped.
      expect(
        formatType('HealthDataType.HealthDataType.SLEEP'),
        'SLEEP',
      );
    });
  });

  group('formatUnit', () {
    test('strips HealthDataUnit. prefix', () {
      expect(formatUnit('HealthDataUnit.COUNT'), 'COUNT');
    });

    test('leaves string without prefix unchanged', () {
      expect(formatUnit('KILOCALORIE'), 'KILOCALORIE');
    });
  });

  group('formatEntryTimestamp', () {
    test('renders the full date and time for the locale', () {
      final result = formatEntryTimestamp(
        DateTime(2024, 3, 15, 10, 30),
        locale: 'en_US',
      );
      // A full timestamp keeps both the date and the time of day.
      expect(result, contains('Mar 15, 2024'));
      expect(result, contains('10:30'));
    });

    test('keeps the date and time for an afternoon timestamp', () {
      final result = formatEntryTimestamp(
        DateTime(2024, 12, 1, 14, 5),
        locale: 'en_US',
      );
      expect(result, contains('Dec 1, 2024'));
      expect(result, contains('2:05'));
    });
  });

  group('humanHealthTypeName', () {
    test('uses the curated display name for a known type', () {
      expect(
        humanHealthTypeName('HealthDataType.BLOOD_PRESSURE_SYSTOLIC'),
        'Systolic Blood Pressure',
      );
    });

    test('falls back to a title-cased name for an unknown type', () {
      expect(
        humanHealthTypeName('HealthDataType.SOME_NEW_METRIC'),
        'Some New Metric',
      );
    });

    test('title-cases a single-character token', () {
      expect(humanHealthTypeName('HealthDataType.X'), 'X');
    });
  });

  group('humanHealthUnit', () {
    QuantitativeData data(String dataType, String unit) =>
        QuantitativeData.discreteQuantityData(
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
          value: 1,
          dataType: dataType,
          unit: unit,
        );

    test('uses the curated unit for a known type', () {
      expect(
        humanHealthUnit(
          data('HealthDataType.BLOOD_PRESSURE_SYSTOLIC', 'whatever'),
        ),
        'mmHg',
      );
    });

    test('falls back to a cleaned, lower-cased unit for an unknown type', () {
      expect(
        humanHealthUnit(
          data('HealthDataType.SOME_NEW_METRIC', 'HealthDataUnit.SOME_UNIT'),
        ),
        'some unit',
      );
    });
  });

  group('humanWorkoutType', () {
    test('title-cases a simple type', () {
      expect(humanWorkoutType('running'), 'Running');
    });

    test('splits camelCase into title-cased words', () {
      expect(
        humanWorkoutType('functionalStrengthTraining'),
        'Functional Strength Training',
      );
    });
  });

  group('entryTextForQuant', () {
    QuantitativeEntry quant({
      required String dataType,
      required String unit,
      required double value,
    }) =>
        JournalEntity.quantitative(
              meta: Metadata(
                id: 'quant-id',
                createdAt: DateTime(2024, 3, 15),
                updatedAt: DateTime(2024, 3, 15),
                dateFrom: DateTime(2024, 3, 15),
                dateTo: DateTime(2024, 3, 15),
              ),
              data: QuantitativeData.discreteQuantityData(
                dateFrom: DateTime(2024, 3, 15),
                dateTo: DateTime(2024, 3, 15),
                value: value,
                dataType: dataType,
                unit: unit,
              ),
            )
            as QuantitativeEntry;

    test('uses curated name + unit for a known type', () {
      expect(
        entryTextForQuant(
          quant(
            dataType: 'HealthDataType.BLOOD_PRESSURE_SYSTOLIC',
            unit: 'whatever',
            value: 120,
          ),
        ),
        'Systolic Blood Pressure: 120 mmHg',
      );
    });

    test('rounds the value to a single decimal and cleans an unknown unit', () {
      expect(
        entryTextForQuant(
          quant(
            dataType: 'HealthDataType.SOME_NEW_METRIC',
            unit: 'HealthDataUnit.KG',
            value: 94.49,
          ),
        ),
        'Some New Metric: 94.5 kg',
      );
    });
  });

  group('entryTextForWorkout', () {
    WorkoutData workout({
      required String workoutType,
      required double? energy,
      required int minutes,
    }) => WorkoutData(
      id: 'workout-id',
      workoutType: workoutType,
      energy: energy,
      distance: null,
      dateFrom: DateTime.fromMillisecondsSinceEpoch(0),
      dateTo: DateTime.fromMillisecondsSinceEpoch(minutes * 60 * 1000),
      source: '',
    );

    test('capitalizes the type and rounds energy to a whole number', () {
      expect(
        entryTextForWorkout(
          workout(workoutType: 'running', energy: 632.02, minutes: 30),
        ),
        'Running\nEnergy: 632 kcal\nDuration: 30 min',
      );
    });

    test('omits the title line and treats null energy as zero', () {
      expect(
        entryTextForWorkout(
          workout(workoutType: '', energy: null, minutes: 12),
          includeTitle: false,
        ),
        'Energy: 0 kcal\nDuration: 12 min',
      );
    });
  });

  group('entryTextForMeasurable', () {
    MeasurableDataType dataType({
      required String displayName,
      required String unitName,
    }) => MeasurableDataType(
      id: 'measurable-id',
      displayName: displayName,
      description: '',
      unitName: unitName,
      createdAt: DateTime(2024, 3, 15),
      updatedAt: DateTime(2024, 3, 15),
      vectorClock: null,
      version: 1,
      aggregationType: AggregationType.dailySum,
    );

    MeasurementData measurement(double value) => MeasurementData(
      value: value,
      dateFrom: DateTime(2024, 3, 15),
      dateTo: DateTime(2024, 3, 15),
      dataTypeId: 'measurable-id',
    );

    test('separates a word unit from the value with a space', () {
      expect(
        entryTextForMeasurable(
          measurement(94.49),
          dataType(displayName: 'Weight', unitName: 'kg'),
        ),
        'Weight: 94.49 kg',
      );
    });

    test('drops the space before a percent unit', () {
      expect(
        entryTextForMeasurable(
          measurement(55),
          dataType(displayName: 'Body Fat', unitName: '%'),
        ),
        'Body Fat: 55%',
      );
    });
  });
}
