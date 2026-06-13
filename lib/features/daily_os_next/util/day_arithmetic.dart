/// Pure calendar-day arithmetic helpers for the daily_os_next feature.
library;

/// Number of whole calendar days between [from] and [to].
///
/// Counts the difference in calendar dates, ignoring the time of day, and is
/// signed: positive when [to] is later than [from], negative when earlier, and
/// zero when both fall on the same calendar day.
///
/// The dates are normalised to UTC midnight before subtracting. This is
/// deliberate: a local `DateTime.difference().inDays` truncates across the DST
/// spring-forward (a 23-hour day) and under-counts by one. UTC days are
/// uniformly 24 hours, so the subtraction is exact — the same pattern used by
/// `daysAtNoonForRange` in the daily_os feature.
int daysBetween(DateTime from, DateTime to) {
  final fromDay = DateTime.utc(from.year, from.month, from.day);
  final toDay = DateTime.utc(to.year, to.month, to.day);
  return toDay.difference(fromDay).inDays;
}
