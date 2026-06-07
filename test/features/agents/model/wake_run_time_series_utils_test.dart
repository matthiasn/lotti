import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/database/agent_database.dart'
    show WakeRunLogData;
import 'package:lotti/features/agents/model/wake_run_time_series.dart';
import 'package:lotti/features/agents/model/wake_run_time_series_utils.dart';

import '../test_utils.dart';

enum _GeneratedWakeRunStatusShape { completed, failed, pending }

enum _GeneratedWakeRunTimingShape { none, valid, negative }

enum _GeneratedWakeVersionSlot { none, first, second, third }

final _generatedWakeSeriesBase = DateTime(2026, 5, 20, 8);

class _GeneratedWakeRunSpec {
  const _GeneratedWakeRunSpec({
    required this.statusShape,
    required this.timingShape,
    required this.versionSlot,
    required this.dayOffset,
    required this.minuteOffset,
    required this.durationMilliseconds,
    required this.seed,
  });

  final _GeneratedWakeRunStatusShape statusShape;
  final _GeneratedWakeRunTimingShape timingShape;
  final _GeneratedWakeVersionSlot versionSlot;
  final int dayOffset;
  final int minuteOffset;
  final int durationMilliseconds;
  final int seed;

  String get status => switch (statusShape) {
    _GeneratedWakeRunStatusShape.completed => 'completed',
    _GeneratedWakeRunStatusShape.failed => 'failed',
    _GeneratedWakeRunStatusShape.pending => 'pending',
  };

  String? get versionId => switch (versionSlot) {
    _GeneratedWakeVersionSlot.none => null,
    _GeneratedWakeVersionSlot.first => 'generated-version-first',
    _GeneratedWakeVersionSlot.second => 'generated-version-second',
    _GeneratedWakeVersionSlot.third => 'generated-version-third',
  };

  DateTime createdAt(int index) => _generatedWakeSeriesBase.add(
    Duration(days: dayOffset, minutes: minuteOffset, seconds: index),
  );

  DateTime? startedAt(int index) => switch (timingShape) {
    _GeneratedWakeRunTimingShape.none => null,
    _ => createdAt(index).add(const Duration(minutes: 1)),
  };

  DateTime? completedAt(int index) => switch (timingShape) {
    _GeneratedWakeRunTimingShape.none => null,
    _GeneratedWakeRunTimingShape.valid => startedAt(
      index,
    )!.add(Duration(milliseconds: durationMilliseconds)),
    _GeneratedWakeRunTimingShape.negative => startedAt(
      index,
    )!.subtract(const Duration(milliseconds: 1)),
  };

  @override
  String toString() {
    return '_GeneratedWakeRunSpec('
        'statusShape: $statusShape, timingShape: $timingShape, '
        'versionSlot: $versionSlot, dayOffset: $dayOffset, '
        'minuteOffset: $minuteOffset, '
        'durationMilliseconds: $durationMilliseconds, seed: $seed)';
  }
}

class _GeneratedWakeSeriesScenario {
  const _GeneratedWakeSeriesScenario({required this.runs});

  final List<_GeneratedWakeRunSpec> runs;

  List<WakeRunLogData> get wakeRuns => runs.indexed.map((entry) {
    final index = entry.$1;
    final run = entry.$2;
    return makeTestWakeRun(
      runKey: 'generated-wake-series-$index-${run.seed}',
      status: run.status,
      createdAt: run.createdAt(index),
      startedAt: run.startedAt(index),
      completedAt: run.completedAt(index),
      templateVersionId: run.versionId,
    );
  }).toList();

  List<DailyWakeBucket> get expectedDailyBuckets {
    if (wakeRuns.isEmpty) return [];

    final byDay = <DateTime, List<WakeRunLogData>>{};
    for (final run in wakeRuns) {
      final day = DateTime(
        run.createdAt.year,
        run.createdAt.month,
        run.createdAt.day,
      );
      byDay.putIfAbsent(day, () => []).add(run);
    }

    final days = byDay.keys.toList()..sort();
    final buckets = <DailyWakeBucket>[];
    var current = days.first;
    while (!current.isAfter(days.last)) {
      final dayRuns = byDay[current];
      if (dayRuns == null) {
        buckets.add(
          DailyWakeBucket(
            date: current,
            successCount: 0,
            failureCount: 0,
            successRate: 0,
            averageDuration: Duration.zero,
          ),
        );
      } else {
        final stats = _expectedWakeStats(dayRuns);
        buckets.add(
          DailyWakeBucket(
            date: current,
            successCount: stats.successCount,
            failureCount: stats.failureCount,
            successRate: stats.successRate,
            averageDuration: stats.averageDuration,
          ),
        );
      }
      current = current.add(const Duration(days: 1));
    }
    return buckets;
  }

  Map<String, VersionPerformanceBucket> get expectedVersionBucketsById {
    final byVersion = <String, List<WakeRunLogData>>{};
    for (final run in wakeRuns) {
      final versionId = run.templateVersionId;
      if (versionId == null) continue;
      byVersion.putIfAbsent(versionId, () => []).add(run);
    }

    final firstRunByVersion = byVersion.map(
      (versionId, runs) => MapEntry(
        versionId,
        runs
            .map((run) => run.createdAt)
            .reduce((a, b) => a.isBefore(b) ? a : b),
      ),
    );
    final sortedVersionIds = byVersion.keys.toList()
      ..sort((a, b) => firstRunByVersion[a]!.compareTo(firstRunByVersion[b]!));

    return {
      for (final entry in sortedVersionIds.indexed)
        entry.$2: VersionPerformanceBucket(
          versionId: entry.$2,
          versionNumber: entry.$1 + 1,
          totalRuns: byVersion[entry.$2]!.length,
          successRate: _expectedWakeStats(byVersion[entry.$2]!).successRate,
          averageDuration: _expectedWakeStats(
            byVersion[entry.$2]!,
          ).averageDuration,
        ),
    };
  }

  ({
    int successCount,
    int failureCount,
    double successRate,
    Duration averageDuration,
  })
  _expectedWakeStats(List<WakeRunLogData> runs) {
    final successCount = runs.where((run) => run.status == 'completed').length;
    final failureCount = runs.where((run) => run.status == 'failed').length;
    final durations = runs
        .where((run) => run.startedAt != null && run.completedAt != null)
        .map((run) => run.completedAt!.difference(run.startedAt!))
        .where((duration) => !duration.isNegative)
        .toList();
    return (
      successCount: successCount,
      failureCount: failureCount,
      successRate: successCount + failureCount == 0
          ? 0
          : successCount / (successCount + failureCount),
      averageDuration: durations.isEmpty
          ? Duration.zero
          : Duration(
              milliseconds:
                  durations
                      .map((duration) => duration.inMilliseconds)
                      .reduce(
                        (a, b) => a + b,
                      ) ~/
                  durations.length,
            ),
    );
  }

  @override
  String toString() {
    return '_GeneratedWakeSeriesScenario(runs: $runs)';
  }
}

extension _AnyGeneratedWakeSeriesScenario on glados.Any {
  glados.Generator<_GeneratedWakeRunStatusShape> get wakeRunStatusShape =>
      glados.AnyUtils(this).choose(_GeneratedWakeRunStatusShape.values);

  glados.Generator<_GeneratedWakeRunTimingShape> get wakeRunTimingShape =>
      glados.AnyUtils(this).choose(_GeneratedWakeRunTimingShape.values);

  glados.Generator<_GeneratedWakeVersionSlot> get wakeVersionSlot =>
      glados.AnyUtils(this).choose(_GeneratedWakeVersionSlot.values);

  glados.Generator<_GeneratedWakeRunSpec> get wakeRunSpec =>
      glados.CombinableAny(this).combine7(
        wakeRunStatusShape,
        wakeRunTimingShape,
        wakeVersionSlot,
        glados.IntAnys(this).intInRange(0, 5),
        glados.IntAnys(this).intInRange(0, 1439),
        glados.IntAnys(this).intInRange(0, 120000),
        glados.IntAnys(this).intInRange(0, 10000),
        (
          _GeneratedWakeRunStatusShape statusShape,
          _GeneratedWakeRunTimingShape timingShape,
          _GeneratedWakeVersionSlot versionSlot,
          int dayOffset,
          int minuteOffset,
          int durationMilliseconds,
          int seed,
        ) => _GeneratedWakeRunSpec(
          statusShape: statusShape,
          timingShape: timingShape,
          versionSlot: versionSlot,
          dayOffset: dayOffset,
          minuteOffset: minuteOffset,
          durationMilliseconds: durationMilliseconds,
          seed: seed,
        ),
      );

  glados.Generator<_GeneratedWakeSeriesScenario> get wakeSeriesScenario =>
      glados.ListAnys(this)
          .listWithLengthInRange(0, 14, wakeRunSpec)
          .map(
            (runs) => _GeneratedWakeSeriesScenario(runs: runs),
          );
}

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

      test(
        'handles runs with pending status (neither success nor failure)',
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
        },
      );

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
        final numbers = result.versionBuckets
            .map((b) => b.versionNumber)
            .toList();

        // Ordered by earliest run date, not lexicographically.
        expect(ids, ['version-1', 'version-2', 'version-10']);
        expect(numbers, [1, 2, 3]);
      });
    });

    glados.Glados(
      glados.any.wakeSeriesScenario,
      glados.ExploreConfig(numRuns: 140),
    ).test('matches generated wake time-series semantics', (scenario) {
      final result = computeTimeSeries(scenario.wakeRuns);

      expect(
        result.dailyBuckets,
        scenario.expectedDailyBuckets,
        reason: '$scenario',
      );
      expect(
        result.versionBuckets,
        scenario.expectedVersionBucketsById.values.toList(),
        reason: '$scenario',
      );
    }, tags: 'glados');
  });
}
