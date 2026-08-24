import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// 24h, mono date-time formatting for the relationships surface (design
/// plan §0.5 — "All date/time strings render in `--ff-mono` (Inconsolata)
/// at caption sizes: `Today 14:20`, `Fri 15 Aug 19:05`. Never `Aug 18, 2026
/// 12:44 PM` in body type").
///
/// All formatters here are pure functions of a [DateTime] (and the clock),
/// so they are unit-testable without a widget pump.

/// The mono [TextStyle] for a relationship timestamp, derived from the
/// design-system caption token with the Inconsolata override.
TextStyle relationshipTimestampStyle(DsTokens tokens, {Color? color}) =>
    monoMetaStyle(tokens, tokens.colors, color: color);

/// `HH:mm` in 24h, mono — the time component shared by every relationship
/// timestamp.
String _hhMm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:'
    '${t.minute.toString().padLeft(2, '0')}';

/// The short weekday + day + month used when the timestamp is not today
/// (e.g. `Fri 15 Aug`, `Fr. 15 Aug.` in German).
///
/// The abbreviations come from the locale's own date symbols rather than a
/// hard-coded English table: a German reader gets `Fr.`, not `Fri`. The
/// order stays weekday-day-month in every locale, because the design's mono
/// column has to line up.
String _shortDayMonth(DateTime t, String? locale) =>
    DateFormat('E d MMM', locale).format(t);

/// A mono timestamp label for a single point in time, anchored to [now].
///
/// Same day → `Today 14:20`. The day before → `Yesterday 19:05`. Otherwise →
/// `Fri 15 Aug 19:05`.
///
/// "Yesterday" earns its own case because it is the single most common
/// non-today value on this surface — a check-in logged the previous evening
/// reads as `Yesterday 18:00` rather than making the reader decode
/// `Wed 12 Aug 18:00` against today's date.
///
/// The two relative words arrive as [todayLabel] and [yesterdayLabel] and
/// the date symbols follow [locale], so the function stays a pure function
/// of its inputs — [relationshipTimestampLabelOf] is the widget-side
/// convenience that reads both off a [BuildContext].
String relationshipTimestampLabel(
  DateTime at, {
  required String todayLabel,
  required String yesterdayLabel,
  String? locale,
  DateTime? now,
}) {
  final anchor = now ?? clock.now();
  if (_isSameDay(at, anchor)) return '$todayLabel ${_hhMm(at)}';
  if (_isSameDay(at, _dayBefore(anchor))) {
    return '$yesterdayLabel ${_hhMm(at)}';
  }
  return '${_shortDayMonth(at, locale)} ${_hhMm(at)}';
}

/// [relationshipTimestampLabel] with the relative words and the date symbols
/// resolved against the widget tree's locale.
String relationshipTimestampLabelOf(
  BuildContext context,
  DateTime at, {
  DateTime? now,
}) => relationshipTimestampLabel(
  at,
  todayLabel: context.messages.relationshipTimestampToday,
  yesterdayLabel: context.messages.relationshipTimestampYesterday,
  locale: Localizations.localeOf(context).toString(),
  now: now,
);

/// The calendar day before [anchor]. Built from components rather than by
/// subtracting a `Duration`, so the 23- and 25-hour days either side of a DST
/// change still resolve to the previous date.
DateTime _dayBefore(DateTime anchor) =>
    DateTime(anchor.year, anchor.month, anchor.day - 1);

/// A mono time-only label (`14:20`), used in the detail beat header where
/// the date is already implied by the beat's position.
String relationshipTimeLabel(DateTime at) => _hhMm(at);

/// A mono weekday-only label (`Thu`), used by the cadence due pill, in the
/// locale's own abbreviation.
String relationshipWeekdayLabel(DateTime at, {String? locale}) =>
    DateFormat.E(locale).format(at);

/// [relationshipWeekdayLabel] resolved against the widget tree's locale.
String relationshipWeekdayLabelOf(BuildContext context, DateTime at) =>
    relationshipWeekdayLabel(
      at,
      locale: Localizations.localeOf(context).toString(),
    );

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// The cadence due date: the next date by which a check-in should land,
/// given the [lastCheckInAt] (or [trackingStartedAt] when none exists yet)
/// and the [cadenceDays]. `null` when the person has no cadence.
DateTime? cadenceDueDate({
  required DateTime? lastCheckInAt,
  required DateTime? trackingStartedAt,
  required int? cadenceDays,
  DateTime? now,
}) {
  if (cadenceDays == null || cadenceDays <= 0) return null;
  final anchor = now ?? clock.now();
  final base = lastCheckInAt ?? trackingStartedAt ?? anchor;
  return base.add(Duration(days: cadenceDays));
}

/// Whole days between the cadence due date and [now]. Positive when the
/// cadence is overdue (due in the past), negative when it is still ahead.
/// `null` when there is no cadence.
int? cadenceOverdueDays({
  required DateTime? lastCheckInAt,
  required DateTime? trackingStartedAt,
  required int? cadenceDays,
  DateTime? now,
}) {
  final due = cadenceDueDate(
    lastCheckInAt: lastCheckInAt,
    trackingStartedAt: trackingStartedAt,
    cadenceDays: cadenceDays,
    now: now,
  );
  if (due == null) return null;
  final anchor = now ?? clock.now();
  // Positive when the cadence is overdue (the due date is in the past): the
  // days from the due date up to now.
  return _wholeDaysBetween(due, anchor);
}

/// The number of whole days since the last check-in, or since tracking
/// started when no check-in exists yet. Used for the "Quiet for N days"
/// quiet-streak caption (design plan §0.8).
int quietStreakDays({
  required DateTime? lastCheckInAt,
  required DateTime? trackingStartedAt,
  DateTime? now,
}) {
  final anchor = now ?? clock.now();
  final base = lastCheckInAt ?? trackingStartedAt;
  if (base == null) return 0;
  final days = _wholeDaysBetween(base, anchor);
  return days < 0 ? 0 : days;
}

/// Whole days from [from] to [to], floored (a check-in 6 hours ago is 0
/// days ago, not "today = 1"). Never negative when [from] is before [to].
int _wholeDaysBetween(DateTime from, DateTime to) {
  final fromMidnight = DateTime(from.year, from.month, from.day);
  final toMidnight = DateTime(to.year, to.month, to.day);
  return toMidnight.difference(fromMidnight).inDays;
}
