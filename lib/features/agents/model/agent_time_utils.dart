import 'package:lotti/features/agents/model/agent_enums.dart';

/// Truncates a [DateTime] to midnight of the same day.
DateTime truncateToDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// Accumulates success/failure/duration stats from a list of wake runs.
///
/// Returns a record with the computed statistics. The [statusAccessor] and
/// [timingAccessor] callbacks extract the relevant fields from each run entry,
/// allowing reuse across both daily buckets and version buckets.
({
  int successCount,
  int failureCount,
  double successRate,
  Duration averageDuration,
}) computeRunStats<T>(
  List<T> runs, {
  required String Function(T run) statusAccessor,
  required ({DateTime? startedAt, DateTime? completedAt}) Function(T run)
      timingAccessor,
}) {
  var successCount = 0;
  var failureCount = 0;
  var totalDurationMs = 0;
  var durationCount = 0;

  for (final run in runs) {
    final status = statusAccessor(run);
    if (status == WakeRunStatus.completed.name) {
      successCount++;
    } else if (status == WakeRunStatus.failed.name) {
      failureCount++;
    }

    final timing = timingAccessor(run);
    if (timing.startedAt != null && timing.completedAt != null) {
      totalDurationMs +=
          timing.completedAt!.difference(timing.startedAt!).inMilliseconds;
      durationCount++;
    }
  }

  final total = successCount + failureCount;
  final successRate = total > 0 ? successCount / total : 0.0;
  final avgDuration = durationCount > 0
      ? Duration(milliseconds: totalDurationMs ~/ durationCount)
      : Duration.zero;

  return (
    successCount: successCount,
    failureCount: failureCount,
    successRate: successRate,
    averageDuration: avgDuration,
  );
}
