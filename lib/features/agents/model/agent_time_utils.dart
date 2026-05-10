import 'package:lotti/features/agents/model/agent_enums.dart';

/// Truncates a [DateTime] to midnight of the same day.
DateTime truncateToDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// Returns the next local calendar day at the given [hour] and [minute].
///
/// Useful for recurring daily cadences like "tomorrow at 09:00 local".
DateTime nextLocalDayAtTime(
  DateTime dt, {
  required int hour,
  int minute = 0,
}) => DateTime(dt.year, dt.month, dt.day + 1, hour, minute);

/// Returns the next local-clock occurrence of [hour]:[minute] strictly
/// after [dt]. If today's [hour]:[minute] hasn't passed yet, returns
/// today; otherwise returns the same time tomorrow.
///
/// This differs from [nextLocalDayAtTime], which always rolls forward to
/// the next day even if today's slot is still in the future. Used by the
/// wake orchestrator to defer subscription-driven wakes to the next
/// 06:00 — at 03:00 we want today's 06:00, not tomorrow's.
DateTime nextOccurrenceOf(
  DateTime dt, {
  required int hour,
  int minute = 0,
}) {
  final today = DateTime(dt.year, dt.month, dt.day, hour, minute);
  return today.isAfter(dt)
      ? today
      : DateTime(dt.year, dt.month, dt.day + 1, hour, minute);
}

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
})
computeRunStats<T>(
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
      final durationMs = timing.completedAt!
          .difference(timing.startedAt!)
          .inMilliseconds;
      // Skip malformed entries where completedAt precedes startedAt.
      if (durationMs >= 0) {
        totalDurationMs += durationMs;
        durationCount++;
      }
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
