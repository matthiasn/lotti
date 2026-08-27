import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:health/health.dart';
import 'package:lotti/logic/health_daily_steps.dart';

void main() {
  final day = DateTime(2026, 8, 26);

  HealthDataPoint steps(
    num value, {
    required String sourceId,
    String? sourceName,
  }) => HealthDataPoint(
    uuid: '$sourceId-${sourceName ?? ''}-$value',
    value: NumericHealthValue(numericValue: value),
    type: HealthDataType.STEPS,
    unit: HealthDataUnit.COUNT,
    dateFrom: day,
    dateTo: day.add(const Duration(hours: 1)),
    sourcePlatform: HealthPlatformType.appleHealth,
    sourceDeviceId: sourceId,
    sourceId: sourceId,
    sourceName: sourceName ?? sourceId,
  );

  group('resolveDailySteps', () {
    // The reported scenario: the phone under-counts a day spent without it,
    // the band synced its full day overnight, and HealthKit's merged sum sided
    // with the phone wherever the two overlapped.
    test(
      'takes the wearable count when the merged total sided with the phone',
      () {
        final result = resolveDailySteps(9800, [
          steps(4000, sourceId: 'phone'),
          steps(5800, sourceId: 'phone'),
          steps(11600, sourceId: 'whoop'),
        ]);

        expect(result, 11600);
      },
    );

    test('keeps the merged total when no single source beats it', () {
      // Two sources that genuinely cover different hours: the store merged
      // them correctly, and neither alone tells the whole day.
      final result = resolveDailySteps(9000, [
        steps(4000, sourceId: 'phone'),
        steps(5000, sourceId: 'watch'),
      ]);

      expect(result, 9000);
    });

    test('never sums across sources', () {
      expect(
        resolveDailySteps(null, [
          steps(6000, sourceId: 'phone'),
          steps(6000, sourceId: 'whoop'),
        ]),
        6000,
      );
    });

    // Health Connect step records arrive with an empty `sourceId` and the
    // provider's package name as `sourceName`. Keyed on the id alone, every
    // provider pooled into one "source" and their counts were summed.
    test('falls back to the source name when the source id is empty', () {
      final result = resolveDailySteps(7000, [
        steps(
          6000,
          sourceId: '',
          sourceName: 'com.google.android.apps.fitness',
        ),
        steps(7000, sourceId: '', sourceName: 'com.whoop.android'),
      ]);

      expect(result, 7000);
    });

    test('a missing merged total counts as zero', () {
      expect(resolveDailySteps(null, const []), 0);
      expect(resolveDailySteps(null, [steps(12, sourceId: 'a')]), 12);
    });

    test('ignores samples without a numeric value', () {
      final result = resolveDailySteps(100, [
        HealthDataPoint(
          uuid: 'audiogram',
          value: AudiogramHealthValue(
            frequencies: [1],
            leftEarSensitivities: [1],
            rightEarSensitivities: [1],
          ),
          type: HealthDataType.AUDIOGRAM,
          unit: HealthDataUnit.DECIBEL_HEARING_LEVEL,
          dateFrom: day,
          dateTo: day,
          sourcePlatform: HealthPlatformType.appleHealth,
          sourceDeviceId: 'a',
          sourceId: 'a',
          sourceName: 'a',
        ),
      ]);

      expect(result, 100);
    });
  });

  group('resolveDailySteps — Glados properties', () {
    final samplesAny = glados.ListAnys(glados.any).listWithLengthInRange(
      0,
      12,
      glados.IntAnys(glados.any).intInRange(0, 5000),
    );
    final mergedAny = glados.IntAnys(glados.any).intInRange(0, 30000);

    glados.Glados2<int, List<int>>(
      mergedAny,
      samplesAny,
      glados.ExploreConfig(numRuns: 150),
    ).test('equals max(merged, best single-source total)', (merged, values) {
      // Alternate two sources so both per-source sums are non-trivial.
      final samples = [
        for (var i = 0; i < values.length; i++)
          steps(values[i], sourceId: i.isEven ? 'phone' : 'band'),
      ];
      var phone = 0;
      var band = 0;
      for (var i = 0; i < values.length; i++) {
        if (i.isEven) {
          phone += values[i];
        } else {
          band += values[i];
        }
      }
      final best = phone > band ? phone : band;

      expect(
        resolveDailySteps(merged, samples),
        best > merged ? best : merged,
        reason: 'merged=$merged values=$values',
      );
    }, tags: 'glados');

    glados.Glados2<int, List<int>>(
      mergedAny,
      samplesAny,
      glados.ExploreConfig(numRuns: 150),
    ).test('is never below the merged total and never above the sum of all', (
      merged,
      values,
    ) {
      final samples = [
        for (var i = 0; i < values.length; i++)
          steps(values[i], sourceId: 'source-${i % 3}'),
      ];
      final total = values.fold<int>(0, (a, b) => a + b);
      final result = resolveDailySteps(merged, samples);

      expect(result, greaterThanOrEqualTo(merged));
      expect(result, lessThanOrEqualTo(total > merged ? total : merged));
    }, tags: 'glados');
  });
}
