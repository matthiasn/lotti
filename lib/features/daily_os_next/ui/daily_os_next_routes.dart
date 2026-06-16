/// The deep-linkable sub-surfaces of Daily OS Next. Each value maps to a
/// `/calendar/<name>/<date>` route the day flow can push to (refine the
/// plan, commit/lock-in the day, run the evening shutdown).
enum DailyOsNextRouteTarget { refine, commit, shutdown }

/// Builds the deep-link path for [target] on the local calendar day [date],
/// e.g. `/calendar/refine/2026-06-16`.
String dailyOsNextRoutePath(
  DailyOsNextRouteTarget target,
  DateTime date,
) {
  return '/calendar/${target.name}/${dailyOsNextRouteDate(date)}';
}

/// Formats [date] as the canonical `YYYY-MM-DD` route segment, using only its
/// local year/month/day (time-of-day and time zone are discarded).
String dailyOsNextRouteDate(DateTime date) {
  final local = DateTime(date.year, date.month, date.day);
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// Parses a `YYYY-MM-DD` route segment back into a local-midnight [DateTime],
/// or `null` when [value] is malformed or names a non-existent calendar date
/// (e.g. `2026-02-30`, which the `DateTime` constructor would silently roll
/// over).
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
