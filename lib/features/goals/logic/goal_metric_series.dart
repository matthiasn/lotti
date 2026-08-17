import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/features/goals/model/goal_health_data_types.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/widgets/charts/utils.dart';

/// The day-series maths a goal metric is drawn and reported from.
///
/// Extracted from the progress card because the reflection sheet needs the
/// same numbers: it prints a day's step count beside the trailing average that
/// day belongs to, and computing that a second time is how the sheet and the
/// chart end up quoting two different averages for one date.

/// The observed days of [metric], oldest first. Unobserved days are dropped —
/// a gap in the record is not a zero.
List<Observation> goalMetricObservations(GoalMetricProgressView metric) =>
    metric.days
        .where((day) => day.isObserved)
        .map((day) => Observation(day.day, day.value))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

/// Whether [metric] is one of the daily quantities a trailing seven-day mean
/// actually says something about: a step total swings day to day, and a body
/// weight moves with hydration, so the average is the honest read of both.
bool goalMetricShowsSevenDayAverage(GoalMetricProgressView metric) =>
    metric.aggregation == GoalAggregation.dailySumThenAverage &&
    (metric.sourceId == GoalHealthDataTypes.weight ||
        metric.sourceId == GoalHealthDataTypes.steps);

/// The trailing seven-day mean of [metric], one point per day from the first
/// day with a full week behind it up to (and including) [today].
///
/// Days with no observation are skipped rather than counted as zero, so a
/// missed weigh-in lowers nothing; a window with no observation at all yields
/// no point rather than a fabricated one.
List<Observation> goalMetricSevenDayAverage(
  GoalMetricProgressView metric, {
  required DateTime today,
}) {
  final todayUtc = goalMetricUtcDay(today);
  final days =
      metric.days
          .where((day) => !goalMetricUtcDay(day.day).isAfter(todayUtc))
          .toList()
        ..sort((a, b) => a.day.compareTo(b.day));
  if (days.isEmpty) return const [];
  final firstDay = goalMetricUtcDay(days.first.day);
  final observations = days.where((day) => day.isObserved).toList();
  final averages = <Observation>[];
  for (final day in days) {
    final currentDay = goalMetricUtcDay(day.day);
    if (currentDay.difference(firstDay).inDays < 6) continue;
    final windowStart = currentDay.subtract(const Duration(days: 6));
    final available = observations.where((observation) {
      final observationDay = goalMetricUtcDay(observation.day);
      return !observationDay.isBefore(windowStart) &&
          !observationDay.isAfter(currentDay);
    }).toList();
    if (available.isEmpty) continue;
    averages.add(
      Observation(
        day.day,
        available.fold<num>(0, (sum, sample) => sum + sample.value) /
            available.length,
      ),
    );
  }
  return averages;
}

/// The trailing seven-day mean ENDING on [day], or null when that window holds
/// no observation (or the series does not reach back a full week yet).
num? goalMetricSevenDayAverageOn(
  GoalMetricProgressView metric, {
  required DateTime day,
}) {
  final target = goalMetricUtcDay(day);
  for (final average in goalMetricSevenDayAverage(metric, today: day)) {
    if (goalMetricUtcDay(average.dateTime) == target) return average.value;
  }
  return null;
}

/// The canonical midnight-UTC key for a day.
DateTime goalMetricUtcDay(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);
