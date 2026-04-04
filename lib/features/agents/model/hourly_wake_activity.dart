/// Hourly wake-run activity bucket for debugging spike investigations.
class HourlyWakeActivity {
  const HourlyWakeActivity({
    required this.hour,
    required this.count,
    required this.reasons,
  });

  /// The start of the hour bucket (minutes, seconds, milliseconds zeroed).
  final DateTime hour;

  /// Total wake runs created within this hour.
  final int count;

  /// Breakdown by wake reason (e.g. 'subscription': 5, 'creation': 2).
  final Map<String, int> reasons;
}
