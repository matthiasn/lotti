import 'package:lotti/classes/goal_enums.dart';
import 'package:lotti/classes/goal_window.dart';
import 'package:lotti/features/goals/model/goal_health_data_types.dart';
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/widgets/charts/utils.dart';

/// The day-series maths a goal metric is drawn and reported from.
///
/// Extracted from the progress card because the reflection sheet needs the
/// same numbers: it prints a day's step count beside the trailing average that
/// day belongs to, and computing that a second time is how the sheet and the
/// chart end up quoting two different averages for one date.
///
/// Day keys come from [GoalWindow.dayUtc] — the goal domain's one canonical
/// day-key function — so these series line up with the window arithmetic and
/// the signal reader's maps.

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
///
/// One pass: the series is already sorted, so the window is advanced with a
/// running sum instead of re-scanning the observations for every day — the
/// re-scan made a 90-day chart quadratic in the middle of `build`.
List<Observation> goalMetricSevenDayAverage(
  GoalMetricProgressView metric, {
  required DateTime today,
}) {
  final todayUtc = GoalWindow.dayUtc(today);
  final days =
      metric.days
          .where((day) => !GoalWindow.dayUtc(day.day).isAfter(todayUtc))
          .toList()
        ..sort((a, b) => a.day.compareTo(b.day));
  if (days.isEmpty) return const [];
  final firstDay = GoalWindow.dayUtc(days.first.day);
  // The run-up, so the first VISIBLE day can already carry a full window.
  // Without it the mean could not be computed until six days into the
  // chart, and the line began a week late — the earliest part of the range
  // read as having no trend rather than one nobody had drawn.
  final warmup = [
    for (final entry in metric.warmupValues.entries)
      if (entry.key.isBefore(firstDay))
        (day: GoalWindow.dayUtc(entry.key), value: entry.value),
  ]..sort((a, b) => a.day.compareTo(b.day));
  final observed = [
    ...warmup,
    for (final day in days)
      if (day.isObserved) (day: GoalWindow.dayUtc(day.day), value: day.value),
  ];

  final averages = <Observation>[];
  var entered = 0;
  var left = 0;
  num sum = 0;
  var count = 0;
  // With a run-up present the series starts on the first visible day; with
  // none (a metric whose history genuinely does not reach back) it still
  // waits for a full window rather than averaging two days and calling it a
  // week.
  final needsRunIn = warmup.isEmpty;
  for (final day in days) {
    final currentDay = GoalWindow.dayUtc(day.day);
    if (needsRunIn && currentDay.difference(firstDay).inDays < 6) continue;
    final windowStart = currentDay.subtract(const Duration(days: 6));
    while (entered < observed.length &&
        !observed[entered].day.isAfter(currentDay)) {
      sum += observed[entered].value;
      count++;
      entered++;
    }
    while (left < entered && observed[left].day.isBefore(windowStart)) {
      sum -= observed[left].value;
      count--;
      left++;
    }
    if (count == 0) continue;
    averages.add(Observation(day.day, sum / count));
  }
  return averages;
}

/// The trailing seven-day mean ENDING on [day], or null when that window holds
/// no observation, when [day] is not in the series, or when the series does not
/// reach back a full week yet.
///
/// Computed directly rather than by building the whole series and reading one
/// point out of it: the reflection sheet asks this once per metric row, and it
/// rebuilds on every rating tap.
num? goalMetricSevenDayAverageOn(
  GoalMetricProgressView metric, {
  required DateTime day,
}) {
  final target = GoalWindow.dayUtc(day);
  final windowStart = target.subtract(const Duration(days: 6));
  DateTime? first;
  var seenTarget = false;
  num sum = 0;
  var count = 0;
  for (final entry in metric.days) {
    final key = GoalWindow.dayUtc(entry.day);
    if (key.isAfter(target)) continue;
    if (first == null || key.isBefore(first)) first = key;
    if (key == target) seenTarget = true;
    if (entry.isObserved && !key.isBefore(windowStart)) {
      sum += entry.value;
      count++;
    }
  }
  // The SAME run-up the series consumes, under the SAME filter — entries
  // strictly BEFORE the first rendered day, which is why this pass has to
  // follow the one above rather than lead it. Without any run-up the helper
  // answered "no average" for exactly the days the chart had just started
  // drawing one. Without the filter it went wrong the other way: an entry
  // that also appears among the rendered days was counted TWICE, once as
  // run-up and once as an observation, and one falling inside the rendered
  // range stood in for the full week of history the series still insists on.
  var hasRunUp = false;
  for (final entry in metric.warmupValues.entries) {
    final key = GoalWindow.dayUtc(entry.key);
    if (first == null || !key.isBefore(first)) continue;
    hasRunUp = true;
    if (!key.isBefore(windowStart)) {
      sum += entry.value;
      count++;
    }
  }
  // The same conditions the series itself applies: the day has to be one of
  // the rendered days, the window has to hold at least one real observation,
  // and — only where no run-up is available — it needs a full week of
  // rendered history behind it.
  if (!seenTarget || count == 0) return null;
  if (!hasRunUp && (first == null || target.difference(first).inDays < 6)) {
    return null;
  }
  return sum / count;
}
