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
      end: last
          .add(const Duration(days: 1))
          .subtract(const Duration(microseconds: 1)),
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
      day = day.add(const Duration(days: 1));
    }
    return result;
  }

  /// Whether [instant] lies inside the window.
  bool contains(DateTime instant) {
    return !instant.isBefore(start) && !instant.isAfter(end);
  }
}
