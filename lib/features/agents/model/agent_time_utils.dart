import 'package:lotti/features/agents/model/agent_enums.dart';

/// Truncates a [DateTime] to midnight of the same day.
DateTime truncateToDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// Returns the next local calendar day at the given [hour] and [minute].
///
/// Useful for recurring daily cadences like "tomorrow at 06:00 local".
DateTime nextLocalDayAtTime(
  DateTime dt, {
  required int hour,
  int minute = 0,
}) => DateTime(dt.year, dt.month, dt.day + 1, hour, minute);

/// Returns the next local occurrence of [weekday] at the given [hour] and
/// [minute], strictly after [dt].
///
/// Example: from a Saturday timestamp, requesting Monday at 10:00 returns the
/// upcoming Monday at 10:00. If [dt] is already Monday after 10:00, returns
/// the following Monday.
DateTime nextLocalWeekdayAtTime(
  DateTime dt, {
  required int weekday,
  required int hour,
  int minute = 0,
}) {
  final daysUntilWeekday =
      (weekday - dt.weekday + DateTime.daysPerWeek) % DateTime.daysPerWeek;
  var candidate = DateTime(
    dt.year,
    dt.month,
    dt.day + daysUntilWeekday,
    hour,
    minute,
  );
  if (!candidate.isAfter(dt)) {
    candidate = candidate.add(const Duration(days: DateTime.daysPerWeek));
  }
  return candidate;
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
