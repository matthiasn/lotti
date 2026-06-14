import 'package:lotti/features/insights/logic/time_bucketing.dart';
import 'package:lotti/features/insights/model/insights_models.dart';

/// Pure calendar navigation for the Time Analysis period stepper.
///
/// Every function returns a day-aligned [InsightsRange] snapped to the
/// boundaries of [InsightsPeriodUnit]: region-aware weeks (first weekday set
/// by `firstDayOfWeekIndex`, `0 = Sunday` … `6 = Saturday`, default Monday),
/// and calendar month / quarter / year bounds. All arithmetic goes through
/// the `DateTime` constructor (which normalizes overflow and is DST-safe)
/// and [epochDay], so stepping never drifts across daylight-saving changes.

/// Monday in Flutter's `firstDayOfWeekIndex` convention; the default first
/// weekday when no device region is known. Shared across the feature so the
/// `0 = Sunday … 6 = Saturday` fallback is written in exactly one place.
const int defaultFirstDayOfWeekIndex = DateTime.monday % 7;

/// The period of [unit] that contains [anchor] (a local date).
///
/// [firstDayOfWeekIndex] (`0 = Sunday` … `6 = Saturday`) sets which weekday a
/// week starts on; it is ignored for non-week units.
InsightsRange periodContaining(
  InsightsPeriodUnit unit,
  DateTime anchor, {
  int firstDayOfWeekIndex = defaultFirstDayOfWeekIndex,
}) {
  final day = DateTime(anchor.year, anchor.month, anchor.day);
  switch (unit) {
    case InsightsPeriodUnit.day:
      final start = epochDay(day);
      return InsightsRange(startDay: start, endDayExclusive: start + 1);
    case InsightsPeriodUnit.week:
      // `weekday` is 1 (Mon) … 7 (Sun); `% 7` gives the same 0 (Sun) … 6
      // (Sat) frame as firstDayOfWeekIndex. Walk back to the week's first
      // day.
      final offset = (day.weekday % 7 - firstDayOfWeekIndex + 7) % 7;
      final first = DateTime(day.year, day.month, day.day - offset);
      final start = epochDay(first);
      return InsightsRange(startDay: start, endDayExclusive: start + 7);
    case InsightsPeriodUnit.month:
      return _bounds(
        DateTime(day.year, day.month),
        DateTime(day.year, day.month + 1),
      );
    case InsightsPeriodUnit.quarter:
      final firstMonth = ((day.month - 1) ~/ 3) * 3 + 1; // 1, 4, 7, or 10
      return _bounds(
        DateTime(day.year, firstMonth),
        DateTime(day.year, firstMonth + 3),
      );
    case InsightsPeriodUnit.year:
      return _bounds(DateTime(day.year), DateTime(day.year + 1));
  }
}

/// Shifts [range] (assumed aligned to [unit]) by [delta] whole periods —
/// negative to go back, positive to go forward.
///
/// Week shifting moves the bounds by whole weeks directly rather than
/// re-snapping through [periodContaining]: an aligned week stays aligned
/// under a ±7-day shift regardless of which weekday it starts on, so this is
/// independent of the device-region first weekday. That matters because the
/// first weekday resolves asynchronously — re-snapping with an index that
/// changed after [range] was built could drift the result by up to six days.
InsightsRange shiftPeriod(
  InsightsRange range,
  InsightsPeriodUnit unit,
  int delta,
) {
  final start = dayStart(range.startDay);
  switch (unit) {
    case InsightsPeriodUnit.day:
      return periodContaining(
        unit,
        DateTime(start.year, start.month, start.day + delta),
      );
    case InsightsPeriodUnit.week:
      return InsightsRange(
        startDay: range.startDay + 7 * delta,
        endDayExclusive: range.endDayExclusive + 7 * delta,
      );
    case InsightsPeriodUnit.month:
      return periodContaining(unit, DateTime(start.year, start.month + delta));
    case InsightsPeriodUnit.quarter:
      return periodContaining(
        unit,
        DateTime(start.year, start.month + 3 * delta),
      );
    case InsightsPeriodUnit.year:
      return periodContaining(unit, DateTime(start.year + delta));
  }
}

/// The to-date portion of the period of [unit] containing [now]: from the
/// period start through today inclusive. Powers the MTD/YTD shortcuts.
///
/// On the period's first day this is a single-day range; on its last day it
/// equals the full period.
InsightsRange periodToDate(
  InsightsPeriodUnit unit,
  DateTime now, {
  int firstDayOfWeekIndex = defaultFirstDayOfWeekIndex,
}) {
  final full = periodContaining(
    unit,
    now,
    firstDayOfWeekIndex: firstDayOfWeekIndex,
  );
  return InsightsRange(
    startDay: full.startDay,
    endDayExclusive: epochDay(now) + 1,
  );
}

/// The elapsed slice of [range] as of [now]: clipped so it never extends past
/// today (inclusive). A fully-past period returns unchanged; an in-progress
/// period (contains today and runs into the future) ends at today; a
/// fully-future period collapses to an empty range at its start.
///
/// This is what makes comparison honest: the current week's *full* range is
/// seven days even on its first day, so without clipping the compare baseline
/// would weigh one elapsed day against a complete prior week.
InsightsRange elapsedPortion(InsightsRange range, DateTime now) {
  final todayExclusive = epochDay(now) + 1;
  if (range.endDayExclusive <= todayExclusive) return range;
  final end = todayExclusive < range.startDay ? range.startDay : todayExclusive;
  return InsightsRange(startDay: range.startDay, endDayExclusive: end);
}

/// Whether [range] still reaches today — i.e. it is the current, still-
/// unfolding period (today's data isn't final) rather than a completed one.
/// Drives both the "(so far)" period-label suffix and the compare basis
/// ("same days" vs "full period"); using one predicate keeps the label and the
/// comparison from ever disagreeing (e.g. a current week reading "(so far)" yet
/// comparing on the "full period").
bool isInProgress(InsightsRange range, DateTime now) =>
    range.endDayExclusive > epochDay(now) && range.startDay <= epochDay(now);

/// The period immediately before [range] (one whole [unit] earlier). Used by
/// the comparison mode to derive the "previous period".
///
/// When [range] is a partial to-date period (see [periodToDate]), the
/// previous period is truncated to the same number of elapsed days, so MTD
/// compares against the same days of last month and YTD against the same
/// days of last year — never a 10-day range against a full month.
InsightsRange previousPeriod(InsightsRange range, InsightsPeriodUnit unit) {
  final shifted = shiftPeriod(range, unit, -1);
  if (range.dayCount < shifted.dayCount) {
    return InsightsRange(
      startDay: shifted.startDay,
      endDayExclusive: shifted.startDay + range.dayCount,
    );
  }
  return shifted;
}

InsightsRange _bounds(DateTime startInclusive, DateTime endExclusive) =>
    InsightsRange(
      startDay: epochDay(startInclusive),
      endDayExclusive: epochDay(endExclusive),
    );
