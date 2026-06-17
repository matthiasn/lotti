import 'package:lotti/features/habits/state/habits_state.dart';

/// Aggregates behind the completion-rate card's headline + trend line, derived
/// purely from [HabitsState] so they are deterministic and unit-testable.
///
/// The raw daily completion rate (share of that day's active habits kept) is
/// noisy on a small habit set — one miss is a big step — so the card leads with
/// a rolling 7-day average (smoother, shows direction). The companion framing
/// is deliberately gain-oriented and forward-looking: how far the average is
/// from the goal (not how many days "failed" an absolute bar), and a gentle
/// gain-framed pointer ("kept X of Y") at the single habit most worth a focus.
class HabitChartStats {
  const HabitChartStats({
    required this.dailyRates,
    required this.rollingAverage,
    required this.currentAverage,
    required this.trendDelta,
    required this.windowDays,
    required this.target,
    this.laggardName,
    this.laggardKept = 0,
    this.laggardActive = 0,
  });

  /// Per-day completion rate (0–100), one per `state.days`, oldest first.
  final List<double> dailyRates;

  /// Trailing 7-day average of [dailyRates] (0–100), one per day; the early
  /// days use the partial window available so the line starts at day 0.
  final List<double> rollingAverage;

  /// The most recent rolling average — the card's headline number.
  final double currentAverage;

  /// Headline average minus the average of the prior window (the trend).
  final double trendDelta;

  /// Total days in the window.
  final int windowDays;

  /// The on-track threshold (percent).
  final double target;

  /// The single habit most worth a focus: the lowest in-window completion
  /// that's below [target] and was active for at least half the window (so a
  /// brand-new, barely-active habit is never singled out). Null when nothing
  /// clearly lags. [laggardKept]/[laggardActive] frame it as a gain
  /// ("kept K of A"), never a deficit.
  final String? laggardName;
  final int laggardKept;
  final int laggardActive;

  /// Whole-number percentage points from [currentAverage] up to [target]
  /// (0 when already at or above it) — the "N points from your goal" framing.
  int get pointsToGoal =>
      currentAverage >= target ? 0 : (target - currentAverage).round();

  /// Whether the rolling average has reached the goal band.
  bool get isAtGoal => currentAverage >= target;
}

/// Builds [HabitChartStats] from [state] over its `days` window.
HabitChartStats habitChartStats(HabitsState state, {double target = 80}) {
  final days = state.days;
  final dailyRates = <double>[
    for (final day in days)
      () {
        final total = totalForDay(day, state);
        final success = state.successfulByDay[day]?.length ?? 0;
        return total > 0 ? (success * 100 / total).clamp(0.0, 100.0) : 0.0;
      }(),
  ];

  const window = 7;
  final rolling = <double>[
    for (var i = 0; i < dailyRates.length; i++)
      () {
        final start = (i - window + 1).clamp(0, dailyRates.length);
        final slice = dailyRates.sublist(start, i + 1);
        return slice.reduce((a, b) => a + b) / slice.length;
      }(),
  ];

  final n = dailyRates.length;
  double avgOf(int start, int end) {
    if (start >= end) return 0;
    final slice = dailyRates.sublist(start.clamp(0, n), end.clamp(0, n));
    if (slice.isEmpty) return 0;
    return slice.reduce((a, b) => a + b) / slice.length;
  }

  final currentAverage = n == 0 ? 0.0 : avgOf(n - window, n);
  final priorAverage = n <= window
      ? currentAverage
      : avgOf(n - 2 * window, n - window);
  final trendDelta = currentAverage - priorAverage;

  // The single habit most worth a focus: lowest in-window completion below
  // target, but only if it was active for at least half the window — so a
  // sparsely-tracked or brand-new habit is never the one we single out.
  String? laggardName;
  var laggardKept = 0;
  var laggardActive = 0;
  var worstRate = 1.0;
  for (final habit in state.habitDefinitions) {
    var active = 0;
    var kept = 0;
    for (final day in days) {
      if (!(state.allByDay[day]?.contains(habit.id) ?? false)) continue;
      active++;
      if (state.successfulByDay[day]?.contains(habit.id) ?? false) kept++;
    }
    if (active == 0 || active * 2 < n) continue;
    final rate = kept / active;
    if (rate < worstRate && rate < target / 100) {
      worstRate = rate;
      laggardName = habit.name;
      laggardKept = kept;
      laggardActive = active;
    }
  }

  return HabitChartStats(
    dailyRates: dailyRates,
    rollingAverage: rolling,
    currentAverage: currentAverage,
    trendDelta: trendDelta,
    windowDays: n,
    target: target,
    laggardName: laggardName,
    laggardKept: laggardKept,
    laggardActive: laggardActive,
  );
}
