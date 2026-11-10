import 'package:material_ui/material_ui.dart';

/// Compact duration label used across the Daily OS Next surfaces:
/// `45m`, `2h`, `1h 20m`. Negative inputs keep a single leading sign
/// (`-1h 5m`).
String formatMinutesCompact(int minutes) {
  final sign = minutes < 0 ? '-' : '';
  final total = minutes.abs();
  final h = total ~/ 60;
  final m = total % 60;
  if (h == 0) return '$sign${m}m';
  if (m == 0) return '$sign${h}h';
  return '$sign${h}h ${m}m';
}

/// `start–end` clock range that follows both the app's language and the
/// *device's* clock: `9:14–10:05 AM` on a 12-hour device, `09:14–10:05` on
/// a 24-hour one.
///
/// Goes through [TimeOfDay.format] rather than `DateFormat.jm`, because only
/// the former consults the device setting on top of the locale's own default.
/// `DateFormat.jm('en_US')` is hard-wired to 12-hour, so a block planned for
/// 14:30 read back as "2:30 PM" for every user running an English app locale
/// on a 24-hour device. This is the same call the entry header makes.
///
/// A locale with no AM/PM form (German, Czech, …) stays 24-hour regardless of
/// the device flag — the locale wins, which is what [TimeOfDay.format] already
/// encodes.
///
/// A range within one half of the day writes its period once, at the end —
/// `1:00–2:30 PM`, not `1:00 PM–2:30 PM` — and one that crosses noon or
/// midnight keeps both.
String formatClockRange(BuildContext context, DateTime start, DateTime end) {
  final from = formatClock(context, start);
  final to = formatClock(context, end);
  final localizations = MaterialLocalizations.of(context);
  final period = TimeOfDay.fromDateTime(start).period;
  final meridiem = period == DayPeriod.am
      ? localizations.anteMeridiemAbbreviation
      : localizations.postMeridiemAbbreviation;
  final samePeriod = TimeOfDay.fromDateTime(end).period == period;
  // Only a clock that writes its period after the time ("2:30 PM") drops
  // the first one; a 24-hour or period-first clock is left as it is.
  if (samePeriod && from.endsWith(meridiem) && to.endsWith(meridiem)) {
    return '${from.substring(0, from.length - meridiem.length).trimRight()}'
        '–$to';
  }
  return '$from–$to';
}

/// A single clock reading on the app's language and the device's clock —
/// `2:30 PM` or `14:30`.
///
/// The one place every Daily OS surface reads a wall-clock time. It exists so
/// that the timeline block chips, the now-marker and the diff rows cannot
/// drift apart again: each previously rolled its own, and they disagreed —
/// the chips and the now-marker were hard-wired to 24-hour while the diff rows
/// were hard-wired to 12-hour, so one and the same block read `14:30` on the
/// timeline and `2:30p` in the diff that proposed it.
///
/// The hour rail reads the same clock, compacted to the hour
/// (`formatTimelineHourLabel`).
String formatClock(BuildContext context, DateTime moment) =>
    TimeOfDay.fromDateTime(moment).format(context);
