import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

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

/// Locale-aware `start–end` clock range, e.g. `9:14 AM–10:05 AM`.
String formatClockRange(BuildContext context, DateTime start, DateTime end) {
  final locale = Localizations.localeOf(context).toString();
  final formatter = DateFormat.jm(locale);
  return '${formatter.format(start)}–${formatter.format(end)}';
}
