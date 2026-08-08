import 'package:freezed_annotation/freezed_annotation.dart';

part 'goal_window.freezed.dart';
part 'goal_window.g.dart';

/// The time window a goal criterion is evaluated over.
///
/// All period math is **date-only, in UTC**: any instant is first collapsed
/// to its local calendar date via [GoalWindow.dayUtc], and every subsequent
/// computation happens on midnight-UTC day keys. That makes window arithmetic
/// immune to DST transitions by construction — there is no 23- or 25-hour day
/// in the space the math runs in.
@freezed
sealed class GoalWindow with _$GoalWindow {
  /// A single calendar day.
  const factory GoalWindow.day() = GoalWindowDay;

  /// A trailing window of [count] days ending on the evaluation day.
  ///
  /// Each evaluation day anchors its own period ("rolling 7-day average"),
  /// so [periodKey] is the day key of the reference date.
  const factory GoalWindow.rollingDays({required int count}) =
      GoalWindowRollingDays;

  /// An ISO-8601 calendar week, Monday through Sunday.
  const factory GoalWindow.calendarWeek() = GoalWindowCalendarWeek;

  /// A calendar month.
  const factory GoalWindow.calendarMonth() = GoalWindowCalendarMonth;

  const GoalWindow._();

  factory GoalWindow.fromJson(Map<String, dynamic> json) =>
      _$GoalWindowFromJson(json);

  /// Collapses [instant] to its local calendar date as a midnight-UTC key.
  ///
  /// This is the one canonical day-key function of the goal domain; signal
  /// series and window math must both use it so map lookups line up.
  static DateTime dayUtc(DateTime instant) =>
      DateTime.utc(instant.year, instant.month, instant.day);

  /// Inclusive first and last day of the period containing [reference].
  ({DateTime start, DateTime end}) periodRange(DateTime reference) {
    final day = dayUtc(reference);
    switch (this) {
      case GoalWindowDay():
        return (start: day, end: day);
      case GoalWindowRollingDays(:final count):
        return (start: day.subtract(Duration(days: count - 1)), end: day);
      case GoalWindowCalendarWeek():
        final monday = day.subtract(Duration(days: day.weekday - 1));
        return (start: monday, end: monday.add(const Duration(days: 6)));
      case GoalWindowCalendarMonth():
        return (
          start: DateTime.utc(day.year, day.month),
          end: DateTime.utc(
            day.year,
            day.month + 1,
          ).subtract(const Duration(days: 1)),
        );
    }
  }

  /// Number of days in the period containing [reference].
  int lengthInDays(DateTime reference) {
    final range = periodRange(reference);
    return range.end.difference(range.start).inDays + 1;
  }

  /// Days of the period that have already elapsed at [reference], inclusive
  /// of the reference day itself. Zero when the period lies in the future.
  int elapsedDays(DateTime reference) {
    final day = dayUtc(reference);
    final range = periodRange(reference);
    if (day.isBefore(range.start)) return 0;
    final effectiveEnd = day.isBefore(range.end) ? day : range.end;
    return effectiveEnd.difference(range.start).inDays + 1;
  }

  /// Stable identity of the period containing [reference].
  ///
  /// `2026-08-08` for day and rolling windows (each day anchors its own
  /// trailing period), `2026-W32` for ISO calendar weeks, `2026-08` for
  /// calendar months. These keys are the `periodKey` of `goalProgress`
  /// register rows, so their format is load-bearing.
  String periodKey(DateTime reference) {
    final day = dayUtc(reference);
    switch (this) {
      case GoalWindowDay():
      case GoalWindowRollingDays():
        return '${_pad4(day.year)}-${_pad2(day.month)}-${_pad2(day.day)}';
      case GoalWindowCalendarWeek():
        final week = _isoWeek(day);
        return '${_pad4(week.year)}-W${_pad2(week.week)}';
      case GoalWindowCalendarMonth():
        return '${_pad4(day.year)}-${_pad2(day.month)}';
    }
  }

  /// ISO-8601 week number: the week containing [day]'s Thursday, counted in
  /// that Thursday's year. Handles year-boundary weeks correctly (Jan 1 can
  /// belong to week 52/53 of the prior year, Dec 31 to week 1 of the next).
  static ({int year, int week}) _isoWeek(DateTime day) {
    final thursday = day.add(Duration(days: 4 - day.weekday));
    final firstDayOfYear = DateTime.utc(thursday.year);
    final ordinal = thursday.difference(firstDayOfYear).inDays + 1;
    return (year: thursday.year, week: ((ordinal - 1) ~/ 7) + 1);
  }

  static String _pad2(int value) => value.toString().padLeft(2, '0');

  static String _pad4(int value) => value.toString().padLeft(4, '0');
}
