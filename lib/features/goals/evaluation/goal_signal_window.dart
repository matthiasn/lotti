import 'package:lotti/classes/goal_window.dart';

/// The pre-fetched daily aggregates a goal evaluation runs over.
///
/// This value object is the seam between the pure evaluator and whatever
/// fetches data (the journal-backed reader arrives with the runtime
/// increment; tests and the eval harness construct windows directly). All
/// day keys are canonical midnight-UTC dates produced by [GoalWindow.dayUtc]
/// — series built with any other key shape simply won't match.
///
/// Days without data are **absent**, never zero-filled: a dead step tracker
/// is missing signal, not a sedentary day. The evaluator decides what
/// absence means per aggregation and via data coverage.
class GoalSignalWindow {
  const GoalSignalWindow({
    this.quantitativeDailySums = const {},
    this.habitSuccessesByDay = const {},
    this.measurableDailySums = const {},
  });

  /// Journal quantitative data: data type string → day key → sum of that
  /// day's values (e.g. `cumulative_step_count` → 2026-08-08 → 6414).
  final Map<String, Map<DateTime, num>> quantitativeDailySums;

  /// Habit completions: habit id → day key → number of *successful*
  /// completions that day. Skips and fails are not successes and must not
  /// be included by the producer.
  final Map<String, Map<DateTime, int>> habitSuccessesByDay;

  /// Measurable data: `MeasurableDataType` id → day key → daily sum.
  final Map<String, Map<DateTime, num>> measurableDailySums;

  /// Daily sums for [dataType] restricted to [start]..[end] (inclusive).
  Map<DateTime, num> quantitativeInRange(
    String dataType,
    DateTime start,
    DateTime end,
  ) => _inRange(quantitativeDailySums[dataType], start, end);

  /// Daily success counts for [habitId] restricted to [start]..[end].
  Map<DateTime, int> habitSuccessesInRange(
    String habitId,
    DateTime start,
    DateTime end,
  ) => _inRange(habitSuccessesByDay[habitId], start, end);

  /// Daily sums for measurable [dataTypeId] restricted to [start]..[end].
  Map<DateTime, num> measurableInRange(
    String dataTypeId,
    DateTime start,
    DateTime end,
  ) => _inRange(measurableDailySums[dataTypeId], start, end);

  static Map<DateTime, V> _inRange<V>(
    Map<DateTime, V>? series,
    DateTime start,
    DateTime end,
  ) {
    if (series == null || series.isEmpty) return const {};
    return {
      for (final entry in series.entries)
        if (!entry.key.isBefore(start) && !entry.key.isAfter(end))
          entry.key: entry.value,
    };
  }
}
