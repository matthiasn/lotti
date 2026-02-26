import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/wake_run_time_series_utils.dart';

import '../test_utils.dart';

void main() {
  group('computeTimeSeries', () {
    test('returns empty buckets for empty input', () {
      final result = computeTimeSeries([]);
      expect(result.dailyBuckets, isEmpty);
      expect(result.versionBuckets, isEmpty);
    });

    group('daily buckets', () {
      test('groups runs by day and computes success rate', () {
        final day1 = DateTime(2024, 3, 15);
        final day2 = DateTime(2024, 3, 16);

        final runs = [
          makeTestWakeRun(
            runKey: 'r1',
            status: 'completed',
            createdAt: day1,
            startedAt: day1,
            completedAt: day1.add(const Duration(seconds: 10)),
          ),
          makeTestWakeRun(
            runKey: 'r2',
            status: 'failed',
            createdAt: day1.add(const Duration(hours: 2)),
            startedAt: day1.add(const Duration(hours: 2)),
            completedAt: day1.add(const Duration(hours: 2, seconds: 5)),
          ),
          makeTestWakeRun(
            runKey: 'r3',
            status: 'completed',
            createdAt: day2,
            startedAt: day2,
            completedAt: day2.add(const Duration(seconds: 20)),
          ),
        ];

        final result = computeTimeSeries(runs);

        expect(result.dailyBuckets, hasLength(2));

        // Day 1: 1 success, 1 failure
        final bucket1 = result.dailyBuckets[0];
        expect(bucket1.date, day1);
        expect(bucket1.successCount, 1);
        expect(bucket1.failureCount, 1);
        expect(bucket1.successRate, 0.5);
        // avg of 10s and 5s = 7.5s → 7500ms
        expect(bucket1.averageDuration.inMilliseconds, 7500);

        // Day 2: 1 success, 0 failures
        final bucket2 = result.dailyBuckets[1];
        expect(bucket2.date, day2);
        expect(bucket2.successCount, 1);
        expect(bucket2.failureCount, 0);
        expect(bucket2.successRate, 1.0);
        expect(bucket2.averageDuration.inSeconds, 20);
      });

      test('fills gaps with zero-count buckets', () {
        final day1 = DateTime(2024, 3, 15);
        final day3 = DateTime(2024, 3, 17);

        final runs = [
          makeTestWakeRun(
            runKey: 'r1',
            status: 'completed',
            createdAt: day1,
          ),
          makeTestWakeRun(
            runKey: 'r2',
            status: 'completed',
            createdAt: day3,
          ),
        ];

        final result = computeTimeSeries(runs);

        // Should be 3 days: 15, 16, 17
        expect(result.dailyBuckets, hasLength(3));

        // Gap day (March 16)
        final gapBucket = result.dailyBuckets[1];
        expect(gapBucket.date, DateTime(2024, 3, 16));
        expect(gapBucket.successCount, 0);
        expect(gapBucket.failureCount, 0);
        expect(gapBucket.successRate, 0);
        expect(gapBucket.averageDuration, Duration.zero);
      });

      test('handles single-day input without gaps', () {
        final day = DateTime(2024, 3, 15);
        final runs = [
          makeTestWakeRun(
            runKey: 'r1',
            status: 'completed',
            createdAt: day,
          ),
        ];

        final result = computeTimeSeries(runs);
        expect(result.dailyBuckets, hasLength(1));
        expect(result.dailyBuckets.first.date, day);
        expect(result.dailyBuckets.first.successCount, 1);
      });

      test('handles runs with pending status (neither success nor failure)',
          () {
        final day = DateTime(2024, 3, 15);
        final runs = [
          makeTestWakeRun(
            runKey: 'r1',
            createdAt: day,
          ),
          makeTestWakeRun(
            runKey: 'r2',
            status: 'completed',
            createdAt: day,
          ),
        ];

        final result = computeTimeSeries(runs);
        final bucket = result.dailyBuckets.first;
        expect(bucket.successCount, 1);
        expect(bucket.failureCount, 0);
        // pending doesn't count toward success/failure total
        expect(bucket.successRate, 1.0);
      });

      test('computes zero duration when startedAt/completedAt are null', () {
        final day = DateTime(2024, 3, 15);
        final runs = [
          makeTestWakeRun(
            runKey: 'r1',
            status: 'completed',
            createdAt: day,
            // No startedAt/completedAt
          ),
        ];

        final result = computeTimeSeries(runs);
        expect(result.dailyBuckets.first.averageDuration, Duration.zero);
      });
    });

    group('version buckets', () {
      test('groups runs by templateVersionId', () {
        final day = DateTime(2024, 3, 15);
        final runs = [
          makeTestWakeRun(
            runKey: 'r1',
            status: 'completed',
            createdAt: day,
            templateVersionId: 'v1',
            startedAt: day,
            completedAt: day.add(const Duration(seconds: 10)),
          ),
          makeTestWakeRun(
            runKey: 'r2',
            status: 'completed',
            createdAt: day,
            templateVersionId: 'v1',
            startedAt: day,
            completedAt: day.add(const Duration(seconds: 20)),
          ),
          makeTestWakeRun(
            runKey: 'r3',
            status: 'failed',
            createdAt: day,
            templateVersionId: 'v2',
            startedAt: day,
            completedAt: day.add(const Duration(seconds: 5)),
          ),
        ];

        final result = computeTimeSeries(runs);

        expect(result.versionBuckets, hasLength(2));

        final v1 = result.versionBuckets[0];
        expect(v1.versionId, 'v1');
        expect(v1.versionNumber, 1);
        expect(v1.totalRuns, 2);
        expect(v1.successRate, 1.0);
        expect(v1.averageDuration.inSeconds, 15);

        final v2 = result.versionBuckets[1];
        expect(v2.versionId, 'v2');
        expect(v2.versionNumber, 2);
        expect(v2.totalRuns, 1);
        expect(v2.successRate, 0.0);
        expect(v2.averageDuration.inSeconds, 5);
      });

      test('skips runs without templateVersionId', () {
        final day = DateTime(2024, 3, 15);
        final runs = [
          makeTestWakeRun(
            runKey: 'r1',
            status: 'completed',
            createdAt: day,
            // templateVersionId is null
          ),
          makeTestWakeRun(
            runKey: 'r2',
            status: 'completed',
            createdAt: day,
            templateVersionId: 'v1',
          ),
        ];

        final result = computeTimeSeries(runs);
        expect(result.versionBuckets, hasLength(1));
        expect(result.versionBuckets.first.versionId, 'v1');
      });

      test('returns empty version buckets when no runs have version IDs', () {
        final day = DateTime(2024, 3, 15);
        final runs = [
          makeTestWakeRun(
            runKey: 'r1',
            status: 'completed',
            createdAt: day,
          ),
        ];

        final result = computeTimeSeries(runs);
        expect(result.versionBuckets, isEmpty);
      });

      test('sorts version buckets chronologically by earliest wake run', () {
        final runs = [
          makeTestWakeRun(
            runKey: 'r1',
            status: 'completed',
            createdAt: DateTime(2024, 3, 17),
            templateVersionId: 'version-10',
          ),
          makeTestWakeRun(
            runKey: 'r2',
            status: 'completed',
            createdAt: DateTime(2024, 3, 16),
            templateVersionId: 'version-2',
          ),
          makeTestWakeRun(
            runKey: 'r3',
            status: 'completed',
            createdAt: DateTime(2024, 3, 15),
            templateVersionId: 'version-1',
          ),
        ];

        final result = computeTimeSeries(runs);
        final ids = result.versionBuckets.map((b) => b.versionId).toList();
        final numbers =
            result.versionBuckets.map((b) => b.versionNumber).toList();

        // Ordered by earliest run date, not lexicographically.
        expect(ids, ['version-1', 'version-2', 'version-10']);
        expect(numbers, [1, 2, 3]);
      });
    });
  });
}
