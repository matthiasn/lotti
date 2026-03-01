import 'package:lotti/features/agents/database/agent_database.dart'
    show WakeRunLogData;
import 'package:lotti/features/agents/model/agent_time_utils.dart';
import 'package:lotti/features/agents/model/wake_run_time_series.dart';

/// Computes time-series data from raw [WakeRunLogData] entries.
///
/// Groups runs by day (truncated to midnight) and by template version.
/// Empty days between the first and last run are filled with zero-count
/// buckets to produce a continuous X-axis.
WakeRunTimeSeries computeTimeSeries(List<WakeRunLogData> runs) {
  if (runs.isEmpty) {
    return const WakeRunTimeSeries(
      dailyBuckets: [],
      versionBuckets: [],
    );
  }

  final dailyBuckets = _computeDailyBuckets(runs);
  final versionBuckets = _computeVersionBuckets(runs);

  return WakeRunTimeSeries(
    dailyBuckets: dailyBuckets,
    versionBuckets: versionBuckets,
  );
}

List<DailyWakeBucket> _computeDailyBuckets(List<WakeRunLogData> runs) {
  // Group by day
  final byDay = <DateTime, List<WakeRunLogData>>{};
  for (final run in runs) {
    final day = truncateToDay(run.createdAt);
    byDay.putIfAbsent(day, () => []).add(run);
  }

  // Find min/max day
  final days = byDay.keys.toList()..sort();
  final firstDay = days.first;
  final lastDay = days.last;

  // Fill gaps and build buckets
  final result = <DailyWakeBucket>[];
  var current = firstDay;
  while (!current.isAfter(lastDay)) {
    final dayRuns = byDay[current];
    if (dayRuns != null && dayRuns.isNotEmpty) {
      result.add(_bucketFromRuns(current, dayRuns));
    } else {
      result.add(
        DailyWakeBucket(
          date: current,
          successCount: 0,
          failureCount: 0,
          successRate: 0,
          averageDuration: Duration.zero,
        ),
      );
    }
    current = current.add(const Duration(days: 1));
  }

  return result;
}

DailyWakeBucket _bucketFromRuns(DateTime day, List<WakeRunLogData> runs) {
  final stats = computeRunStats(
    runs,
    statusAccessor: (r) => r.status,
    timingAccessor: (r) => (startedAt: r.startedAt, completedAt: r.completedAt),
  );

  return DailyWakeBucket(
    date: day,
    successCount: stats.successCount,
    failureCount: stats.failureCount,
    successRate: stats.successRate,
    averageDuration: stats.averageDuration,
  );
}

List<VersionPerformanceBucket> _computeVersionBuckets(
  List<WakeRunLogData> runs,
) {
  final byVersion = <String, List<WakeRunLogData>>{};
  for (final run in runs) {
    final versionId = run.templateVersionId;
    if (versionId == null) continue;
    byVersion.putIfAbsent(versionId, () => []).add(run);
  }

  // Pre-compute the earliest run date per version to avoid redundant
  // reduce calls inside the sort comparator (O(N*M) → O(N*M + N log N)).
  final versionFirstRunDates = byVersion.map((versionId, runs) {
    final firstRunDate =
        runs.map((r) => r.createdAt).reduce((a, b) => a.isBefore(b) ? a : b);
    return MapEntry(versionId, firstRunDate);
  });
  final sortedVersionIds = byVersion.keys.toList()
    ..sort((a, b) {
      final aFirst = versionFirstRunDates[a]!;
      final bFirst = versionFirstRunDates[b]!;
      return aFirst.compareTo(bFirst);
    });

  return sortedVersionIds.indexed.map((entry) {
    final (index, versionId) = entry;
    final versionRuns = byVersion[versionId]!;

    final stats = computeRunStats(
      versionRuns,
      statusAccessor: (r) => r.status,
      timingAccessor: (r) =>
          (startedAt: r.startedAt, completedAt: r.completedAt),
    );

    return VersionPerformanceBucket(
      versionId: versionId,
      versionNumber: index + 1,
      totalRuns: versionRuns.length,
      successRate: stats.successRate,
      averageDuration: stats.averageDuration,
    );
  }).toList();
}
