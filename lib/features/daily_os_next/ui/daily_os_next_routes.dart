enum DailyOsNextRouteTarget { refine, commit, shutdown }

String dailyOsNextRoutePath(
  DailyOsNextRouteTarget target,
  DateTime date,
) {
  return '/calendar/${target.name}/${dailyOsNextRouteDate(date)}';
}

String dailyOsNextRouteDate(DateTime date) {
  final local = DateTime(date.year, date.month, date.day);
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

DateTime? parseDailyOsNextRouteDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}
