import 'package:lotti/features/agents/model/task_resolution_time_series.dart';

/// Computes resolution time-series data from [TaskResolutionEntry] entries.
///
/// Groups resolved entries by the day they were resolved, computes the average
/// MTTR (agent creation → task resolution) per day, and fills gaps between the
/// first and last day with zero-count buckets for a continuous X-axis.
TaskResolutionTimeSeries computeResolutionTimeSeries(
  List<TaskResolutionEntry> entries,
) {
  // Only consider entries that have been resolved.
  final resolved = entries.where((e) => e.resolvedAt != null).toList();

  if (resolved.isEmpty) {
    return const TaskResolutionTimeSeries(dailyBuckets: []);
  }

  // Group by resolved date (truncated to midnight).
  final byDay = <DateTime, List<TaskResolutionEntry>>{};
  for (final entry in resolved) {
    final day = _truncateToDay(entry.resolvedAt!);
    byDay.putIfAbsent(day, () => []).add(entry);
  }

  // Find date range.
  final days = byDay.keys.toList()..sort();
  final firstDay = days.first;
  final lastDay = days.last;

  // Fill gaps and build buckets.
  final buckets = <DailyResolutionBucket>[];
  var current = firstDay;
  while (!current.isAfter(lastDay)) {
    final dayEntries = byDay[current];
    if (dayEntries != null && dayEntries.isNotEmpty) {
      buckets.add(_bucketFromEntries(current, dayEntries));
    } else {
      buckets.add(
        DailyResolutionBucket(
          date: current,
          resolvedCount: 0,
          averageMttr: Duration.zero,
        ),
      );
    }
    current = current.add(const Duration(days: 1));
  }

  return TaskResolutionTimeSeries(dailyBuckets: buckets);
}

DailyResolutionBucket _bucketFromEntries(
  DateTime day,
  List<TaskResolutionEntry> entries,
) {
  var totalMs = 0;
  for (final entry in entries) {
    totalMs +=
        entry.resolvedAt!.difference(entry.agentCreatedAt).inMilliseconds;
  }
  final avgMttr = Duration(milliseconds: totalMs ~/ entries.length);

  return DailyResolutionBucket(
    date: day,
    resolvedCount: entries.length,
    averageMttr: avgMttr,
  );
}

DateTime _truncateToDay(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
