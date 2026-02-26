import 'package:freezed_annotation/freezed_annotation.dart';

part 'task_resolution_time_series.freezed.dart';

/// Aggregated time-series data for task resolution times (MTTR).
///
/// Each bucket represents one day and contains the count of resolved tasks
/// and the average time from agent creation to task resolution.
@freezed
abstract class TaskResolutionTimeSeries with _$TaskResolutionTimeSeries {
  const factory TaskResolutionTimeSeries({
    required List<DailyResolutionBucket> dailyBuckets,
  }) = _TaskResolutionTimeSeries;
}

/// One day's worth of task resolution statistics.
@freezed
abstract class DailyResolutionBucket with _$DailyResolutionBucket {
  const factory DailyResolutionBucket({
    required DateTime date,
    required int resolvedCount,
    required Duration averageMttr,
  }) = _DailyResolutionBucket;
}

/// A single agent→task resolution measurement.
@freezed
abstract class TaskResolutionEntry with _$TaskResolutionEntry {
  const factory TaskResolutionEntry({
    required String agentId,
    required String taskId,
    required DateTime agentCreatedAt,

    /// First DONE/REJECTED timestamp, null if unresolved.
    DateTime? resolvedAt,

    /// 'done' or 'rejected', null if unresolved.
    String? resolution,
  }) = _TaskResolutionEntry;
}
