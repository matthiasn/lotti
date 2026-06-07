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
/// presets never touches the database.
int windowStartDayFor(InsightsRange range) {
  final start = dayStart(range.startDay);
  return epochDay(DateTime(start.year));
}

/// Fetch-window key for a range: a cheap value-equal record used as the
/// Riverpod family argument.
///
/// The record's `endYear` bounds the fetch for ranges that end in a past
/// year — a 3-day custom range in 2020 loads only 2020, not every year
/// through today. Current-year ranges all share one key (their fetch end
/// tracks the moving "now"), so preset switching stays a pure memory
/// slice.
typedef InsightsWindow = ({int startDay, int endYear});

InsightsWindow insightsWindowFor(InsightsRange range) {
  final lastDay = dayStart(range.endDayExclusive - 1);
  return (startDay: windowStartDayFor(range), endYear: lastDay.year);
}
