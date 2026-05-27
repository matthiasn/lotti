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
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) return null;

  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    return null;
  }
  return parsed;
}
