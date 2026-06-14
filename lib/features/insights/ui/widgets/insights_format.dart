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

/// The KPI summary figure: compact `2h 15m` / `45m` for normal spans, a single
/// rounded whole-hour count for long ones (`967h`). At quarter/year scale the
/// total reaches a four-digit hour count whose trailing minutes are noise
/// ("966h 59m"); collapsing to whole hours keeps the magnitude legible. Days
/// are deliberately avoided — "10d" is ambiguous (a 24h day? an 8h workday?)
/// for tracked time nobody logs around the clock. Rounds rather than truncates
/// so a ~59-minute remainder isn't silently dropped. The 100h cut-in (~4 days)
/// is where the minute detail stops earning its place.
String formatDurationSummary(int seconds) {
  final totalHours = seconds ~/ 3600;
  if (totalHours < 100) return formatDurationCompact(seconds);
  return '${(seconds / 3600).round()}h';
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
