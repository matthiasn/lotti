import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/goal_window.dart';

/// One category-attributed tracked-time session exposed as evidence to the
/// goal agent. It is deliberately not a success verdict: the deterministic
/// evaluator and, later, a user-approved daily assessment own that decision.
class GoalCategoryTimeSession {
  const GoalCategoryTimeSession({
    required this.categoryId,
    required this.dateFrom,
    required this.dateTo,
  });

  final String categoryId;
  final DateTime dateFrom;
  final DateTime dateTo;

  Duration get duration => dateTo.difference(dateFrom);
}

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
    this.habitCompletionsByDay = const {},
    this.measurableDailySums = const {},
    this.categoryTimeDailyHours = const {},
    this.categoryTimeSessionsByCategory = const {},
    this.categoryTimeEvidenceStart,
    this.categoryTimeEvidenceEnd,
    this.hasActiveCategoryTimer = false,
  });

  /// Journal quantitative data: data type string → day key → sum of that
  /// day's values (e.g. `cumulative_step_count` → 2026-08-08 → 6414).
  final Map<String, Map<DateTime, num>> quantitativeDailySums;

  /// Habit completions: habit id → day key → number of *successful*
  /// completions that day. Skips and fails are not successes and must not
  /// be included by the producer.
  final Map<String, Map<DateTime, int>> habitSuccessesByDay;

  /// Latest habit completion outcome per day. Evaluation still consumes only
  /// [habitSuccessesByDay]; this parallel projection lets interactive progress
  /// surfaces distinguish an explicit miss from an untouched day.
  final Map<String, Map<DateTime, HabitCompletionType>> habitCompletionsByDay;

  /// Measurable data: `MeasurableDataType` id → day key → daily sum.
  final Map<String, Map<DateTime, num>> measurableDailySums;

  /// Tracked category time: category-time criterion id → day key → hours.
  ///
  /// This map is criterion-scoped rather than category-scoped because two
  /// leaves may watch the same category through different local-time bands.
  final Map<String, Map<DateTime, num>> categoryTimeDailyHours;

  /// Every valid tracked-time session attributed to a watched category in
  /// the reader's evidence range. Sessions remain unfiltered by a criterion's
  /// optional daily time band so the agent can discuss patterns outside the
  /// strict threshold while never redefining the computed verdict.
  final Map<String, List<GoalCategoryTimeSession>>
  categoryTimeSessionsByCategory;

  /// Inclusive query start and exclusive query end for category session
  /// evidence. Null when the criteria tree watches no category time.
  final DateTime? categoryTimeEvidenceStart;
  final DateTime? categoryTimeEvidenceEnd;

  /// Whether a currently running timer contributes to a watched category.
  ///
  /// A report rendered from the current elapsed prefix must remain stale:
  /// in-memory timer ticks do not emit journal mutations, so the evidence can
  /// keep changing after the report is written.
  final bool hasActiveCategoryTimer;

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

  /// Tracked hours for category-time [criterionId] in [start]..[end].
  Map<DateTime, num> categoryTimeInRange(
    String criterionId,
    DateTime start,
    DateTime end,
  ) => _inRange(categoryTimeDailyHours[criterionId], start, end);

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
