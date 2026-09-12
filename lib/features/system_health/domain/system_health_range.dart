/// Preset windows offered by the system-health tool.
///
/// [custom] means the caller supplied explicit bounds; every other value is
/// resolved relative to "now" by [SystemHealthRange.forPreset].
enum SystemHealthPreset {
  last24Hours(Duration(hours: 24)),
  last7Days(Duration(days: 7)),
  last14Days(Duration(days: 14)),
  custom(null);

  const SystemHealthPreset(this.window);

  /// Length of the window, or `null` for [custom].
  final Duration? window;
}

/// A closed date-time window the analysis covers.
///
/// [start] and [end] are inclusive instants. Daily log files are selected by
/// calendar day, and individual lines are then filtered against the exact
/// instants, so a window that starts at 14:00 does not report the morning.
class SystemHealthRange {
  SystemHealthRange({
    required this.preset,
    required this.start,
    required this.end,
  }) : assert(!start.isAfter(end), 'start must not be after end');

  /// Resolves a non-custom [preset] against [now].
  factory SystemHealthRange.forPreset(
    SystemHealthPreset preset, {
    required DateTime now,
  }) {
    final window = preset.window;
    if (window == null) {
      throw ArgumentError.value(
        preset,
        'preset',
        'custom ranges need explicit bounds',
      );
    }
    return SystemHealthRange(
      preset: preset,
      start: now.subtract(window),
      end: now,
    );
  }

  /// A custom window covering whole calendar days from [firstDay] to
  /// [lastDay] inclusive.
  factory SystemHealthRange.days({
    required DateTime firstDay,
    required DateTime lastDay,
  }) {
    final a = DateTime(firstDay.year, firstDay.month, firstDay.day);
    final b = DateTime(lastDay.year, lastDay.month, lastDay.day);
    final first = a.isAfter(b) ? b : a;
    final last = a.isAfter(b) ? a : b;
    return SystemHealthRange(
      preset: SystemHealthPreset.custom,
      start: first,
      end: nextCalendarDay(last).subtract(const Duration(microseconds: 1)),
    );
  }

  final SystemHealthPreset preset;
  final DateTime start;
  final DateTime end;

  /// The calendar days whose daily files can hold lines inside the window,
  /// oldest first. Day granularity is what the file naming offers.
  List<DateTime> get days {
    var day = DateTime(start.year, start.month, start.day);
    final last = DateTime(end.year, end.month, end.day);
    final result = <DateTime>[];
    while (!day.isAfter(last)) {
      result.add(day);
      day = nextCalendarDay(day);
    }
    return result;
  }

  /// Local midnight of the calendar day after [day].
  ///
  /// Built from components rather than by adding 24 hours: on a
  /// daylight-saving switch a day is 23 or 25 hours long, and a fixed step
  /// would land on the wrong date.
  static DateTime nextCalendarDay(DateTime day) =>
      DateTime(day.year, day.month, day.day + 1);

  /// Local midnight [days] calendar days before [day].
  static DateTime calendarDaysBefore(DateTime day, int days) =>
      DateTime(day.year, day.month, day.day - days);

  /// Whether [instant] lies inside the window.
  bool contains(DateTime instant) {
    return !instant.isBefore(start) && !instant.isAfter(end);
  }
}
