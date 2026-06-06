import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Compact duration label used across the Daily OS Next surfaces:
/// `45m`, `2h`, `1h 20m`.
String formatMinutesCompact(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

/// Locale-aware `start–end` clock range, e.g. `9:14 AM–10:05 AM`.
String formatClockRange(BuildContext context, DateTime start, DateTime end) {
  final locale = Localizations.localeOf(context).toString();
  final formatter = DateFormat.jm(locale);
  return '${formatter.format(start)}–${formatter.format(end)}';
}
