import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';

/// Resolves [preset] to a day-aligned range relative to [now].
///
/// All presets end after today (today is always included):
/// - `d1`: today only.
/// - `d7`/`d30`: trailing 7/30 calendar days including today.
/// - `mtd`: from the 1st of the current month.
/// - `ytd`: from January 1st of the current year.
/// - `lastMonth`: the full previous calendar month (December of the prior
///   year when [now] is in January).
///
/// `now` is injected (callers use `clock.now()`) so resolution is
/// deterministic in tests and consistent within a frame.
InsightsRange resolvePreset(InsightsRangePreset preset, DateTime now) {
  final today = epochDay(now);
  final tomorrow = today + 1;
  switch (preset) {
    case InsightsRangePreset.d1:
      return InsightsRange(
        startDay: today,
        endDayExclusive: tomorrow,
        preset: preset,
      );
    case InsightsRangePreset.d7:
      return InsightsRange(
        startDay: today - 6,
        endDayExclusive: tomorrow,
        preset: preset,
      );
    case InsightsRangePreset.d30:
      return InsightsRange(
        startDay: today - 29,
        endDayExclusive: tomorrow,
        preset: preset,
      );
    case InsightsRangePreset.mtd:
      return InsightsRange(
        startDay: epochDay(DateTime(now.year, now.month)),
        endDayExclusive: tomorrow,
        preset: preset,
      );
    case InsightsRangePreset.ytd:
      return InsightsRange(
        startDay: epochDay(DateTime(now.year)),
        endDayExclusive: tomorrow,
        preset: preset,
      );
    case InsightsRangePreset.lastMonth:
      // DateTime normalizes month 0 to December of the previous year.
      return InsightsRange(
        startDay: epochDay(DateTime(now.year, now.month - 1)),
        endDayExclusive: epochDay(DateTime(now.year, now.month)),
        preset: preset,
      );
  }
}

/// Builds a custom range from two picked local dates (inclusive on both
/// ends, in either order).
InsightsRange customRange(DateTime a, DateTime b) {
  final dayA = epochDay(a);
  final dayB = epochDay(b);
  final start = dayA < dayB ? dayA : dayB;
  final end = dayA < dayB ? dayB : dayA;
  return InsightsRange(startDay: start, endDayExclusive: end + 1);
}

/// First epoch day of the fetch window that serves [range]: January 1st of
/// the year containing the range start.
///
/// The window is deliberately wider than the range so every preset within
/// the same year is served from the same in-memory buckets — switching
/// presets never touches the database. The key is a single int, which makes
/// it a cheap, stable Riverpod family argument.
int windowStartDayFor(InsightsRange range) {
  final start = dayStart(range.startDay);
  return epochDay(DateTime(start.year));
}
