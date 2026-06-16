/// One bucket of the rolling 24-hour wake-activity chart.
///
/// [hour] is the local hour the bucket starts at, [count] the total wake runs
/// that began in it, and [reasons] a breakdown of that count keyed by the
/// run's `reason` (e.g. how many were scheduled vs. user-triggered).
class HourlyWakeActivity {
  const HourlyWakeActivity({
    required this.hour,
    required this.count,
    required this.reasons,
  });

  final DateTime hour;
  final int count;
  final Map<String, int> reasons;
}
