import 'package:flutter/material.dart' show DateUtils;
import 'package:lotti/features/goals/state/goal_progress_view.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';

/// How one day's criteria actually turned out, per the evidence.
typedef GoalDayOutcome = ({int met, int total});

/// Counts how many of the goal's criteria were met on [day].
///
/// A criterion with no observation for that day counts toward the total but not
/// the met count: "not recorded" is not the same as "met", and a day nobody logged
/// must not read as a clean sweep.
GoalDayOutcome goalDayOutcome(GoalProgressView progress, DateTime day) {
  var met = 0;
  var total = 0;
  for (final habit in progress.habits) {
    total++;
    final entry = habit.days
        .where((value) => DateUtils.isSameDay(value.day, day))
        .firstOrNull;
    if (entry?.hasValue ?? false) met++;
  }
  for (final metric in progress.metrics) {
    total++;
    final entry = metric.days
        .where((value) => DateUtils.isSameDay(value.day, day))
        .firstOrNull;
    // The shared per-day policy (`GoalMetricProgressView.dayMark`): a
    // per-day target is met by the day's own value, or for the rolling
    // average by the window verdict as of that day; a period total only by
    // the window verdict — a single day's hours cannot be judged against a
    // weekly total.
    if (entry != null && metric.dayMark(entry)) met++;
  }
  return (met: met, total: total);
}

/// The verdict the evidence suggests for [day], or null when there is nothing
/// to judge.
///
/// Deterministic on purpose. The user is being offered a starting point for
/// their own reflection, and a starting point that costs a model call — and
/// could disagree with the very numbers printed above it in the same sheet —
/// would be worse than no suggestion at all.
///
/// The rules, in order:
///
///  * Nothing tracked, or nothing recorded all day → **null**. Suggesting
///    "missed" for a day the user simply did not open the app would be the app
///    passing judgement on its own blind spot.
///  * Everything met → [DayVerdict.met].
///  * Nothing met → [DayVerdict.missed].
///  * Some met, and more than the day before →
///    [DayVerdict.improving]. This is the case the three-way verdict
///    could not express: not a clean day, but a better one.
///  * Some met otherwise → [DayVerdict.mixed].
///
/// The user can always override; the suggestion only decides what the sheet
/// opens on.
DayVerdict? suggestedDayVerdict(
  GoalProgressView progress,
  DateTime day,
) {
  final today = goalDayOutcome(progress, day);
  if (today.total == 0 || today.met == 0 && !_anyEvidence(progress, day)) {
    return null;
  }
  if (today.met == today.total) return DayVerdict.met;
  if (today.met == 0) return DayVerdict.missed;
  // Improving is a comparison, so it needs something to compare against. With
  // no observations yesterday its met count is zero for want of DATA, not for
  // want of effort, and calling today an improvement on it would be inventing
  // a baseline — then recording that invention as a suggestion the user
  // accepted.
  final previousDay = day.subtract(const Duration(days: 1));
  if (!_anyEvidence(progress, previousDay)) return DayVerdict.mixed;
  return today.met > goalDayOutcome(progress, previousDay).met
      ? DayVerdict.improving
      : DayVerdict.mixed;
}

/// Whether the day carries any observation at all, met or not.
///
/// Separates "logged everything and missed every target" — a real Missed —
/// from "never opened the app", which the app has no standing to judge.
bool _anyEvidence(GoalProgressView progress, DateTime day) {
  for (final habit in progress.habits) {
    final entry = habit.days
        .where((value) => DateUtils.isSameDay(value.day, day))
        .firstOrNull;
    // A deliberately recorded FAILURE is evidence too. It carries no value,
    // so checking `hasValue` alone read a day the user explicitly marked as
    // missed as a day they never opened — and the sheet then fell back to
    // suggesting Met.
    if (entry != null &&
        (entry.hasValue || entry.habitCompletionType != null)) {
      return true;
    }
  }
  for (final metric in progress.metrics) {
    final entry = metric.days
        .where((value) => DateUtils.isSameDay(value.day, day))
        .firstOrNull;
    if (entry != null && entry.isObserved) return true;
  }
  return false;
}
