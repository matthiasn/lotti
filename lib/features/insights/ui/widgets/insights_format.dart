/// Duration formatting for the Insights dashboard.
///
/// Two deliberate styles, per the dataviz review:
/// - [formatDurationCompact] (`2h 15m`) for KPIs, tooltips, and prose —
///   matching the Daily OS Next surfaces.
/// - [formatDurationTable] (`2:15`) zero-padded for right-aligned table
///   columns where digit alignment matters.
library;

/// `45m`, `2h`, `2h 15m`; `0m` for zero.
String formatDurationCompact(int seconds) {
  final minutes = seconds ~/ 60;
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

/// `0:05`, `2:15`, `134:07` — hours unbounded, minutes zero-padded.
String formatDurationTable(int seconds) {
  final minutes = seconds ~/ 60;
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return '$h:${m.toString().padLeft(2, '0')}';
}

/// Compact with a day rollup for long spans: `40d 7h`, otherwise `2h 15m` /
/// `45m`. Headline totals at quarter/year scale reach four-digit hour counts
/// ("966h 59m") that are hard to grasp; rolling into days makes the magnitude
/// legible. Kicks in at 100h (~4 days), below which `2h`-style reads fine.
String formatDurationWithDays(int seconds) {
  final totalHours = seconds ~/ 3600;
  if (totalHours < 100) return formatDurationCompact(seconds);
  final d = totalHours ~/ 24;
  final h = totalHours % 24;
  return h == 0 ? '${d}d' : '${d}d ${h}h';
}

/// `42%`; values under 1% render as `<1%` so small categories never show
/// a misleading `0%`.
String formatShare(double share) {
  final percent = share * 100;
  if (percent > 0 && percent < 1) return '<1%';
  return '${percent.round()}%';
}

/// Table style with a sub-minute guard: real-but-tiny averages render as
/// `<0:01` instead of a misleading `0:00` (mirrors the `<1%` share guard).
String formatAvgDuration(int seconds) {
  if (seconds > 0 && seconds < 60) return '<0:01';
  return formatDurationTable(seconds);
}
