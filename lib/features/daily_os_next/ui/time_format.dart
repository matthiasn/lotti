import 'package:flutter/material.dart';

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
/// *device's* clock: `9:14 AM–10:05 AM` on a 12-hour device, `09:14–10:05` on
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
String formatClockRange(BuildContext context, DateTime start, DateTime end) =>
    '${formatClock(context, start)}–${formatClock(context, end)}';

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
/// Not for the hour rail: `formatTimelineHourLabel` stays a 24-hour axis
/// because its `24:00` end-of-day marker has no 12-hour spelling that a reader
/// could tell apart from midnight.
String formatClock(BuildContext context, DateTime moment) =>
    TimeOfDay.fromDateTime(moment).format(context);
