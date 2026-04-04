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
