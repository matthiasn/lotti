import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/features/agents/database/agent_database.dart'
    show WakeRunLogData;

part 'wake_run_time_series.freezed.dart';

/// Aggregated time-series data computed from [WakeRunLogData] entries,
/// grouped by day and by template version.
@freezed
abstract class WakeRunTimeSeries with _$WakeRunTimeSeries {
  const factory WakeRunTimeSeries({
    required List<DailyWakeBucket> dailyBuckets,
    required List<VersionPerformanceBucket> versionBuckets,
  }) = _WakeRunTimeSeries;
}

/// One day's worth of wake-run statistics.
@freezed
abstract class DailyWakeBucket with _$DailyWakeBucket {
  const factory DailyWakeBucket({
    required DateTime date,
    required int successCount,
    required int failureCount,
    required double successRate,
    required Duration averageDuration,
  }) = _DailyWakeBucket;
}

/// Aggregate performance for a single template version.
@freezed
abstract class VersionPerformanceBucket with _$VersionPerformanceBucket {
  const factory VersionPerformanceBucket({
    required String versionId,
    required int versionNumber,
    required int totalRuns,
    required double successRate,
    required Duration averageDuration,
  }) = _VersionPerformanceBucket;
}
