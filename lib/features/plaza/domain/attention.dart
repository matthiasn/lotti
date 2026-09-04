/// The attention score: which tasks deserve a billboard, a pulsing lantern
/// and a beacon, and why.
///
/// Pure Dart. Deterministic from merged task data plus the clock at day
/// granularity, so every device flags the same tasks on the same day.
library;

import 'package:lotti/features/plaza/domain/plaza_task.dart';

/// Score at or above which a task is an anomaly: it gets an attention
/// beacon, its lantern pulses, and it competes for a billboard.
const anomalyThreshold = 3;

/// Score at or above which a task may fill a remaining billboard slot.
const billboardThreshold = 2;

/// Billboard pylons on the frontier plaza.
const billboardSlots = 6;

/// An in-progress task untouched for this long is "stale".
const staleAfter = Duration(days: 14);

/// A due date within this window counts as "due soon".
const dueSoonWindow = Duration(days: 3);

/// A heavy task open for longer than this earns a point.
const oldAfter = Duration(days: 56);

/// What lights the roof lantern, in priority order.
enum LanternState { blocked, overdue, inProgress, open, off }

/// How a lantern's state is written where hue cannot carry it: a glyph
/// and a word, the same on a ticker band and in the HUD's legend.
extension LanternStateText on LanternState {
  /// A cross for blocked, a bang for overdue, a play mark for in
  /// progress, a ring for open, a tick for a lantern that is off.
  String get glyph => switch (this) {
    LanternState.blocked => '✕',
    LanternState.overdue => '!',
    LanternState.inProgress => '▶',
    LanternState.open => '○',
    LanternState.off => '✓',
  };

  String get word => switch (this) {
    LanternState.blocked => 'blocked',
    LanternState.overdue => 'overdue',
    LanternState.inProgress => 'in progress',
    LanternState.open => 'open',
    LanternState.off => 'done',
  };
}

/// The attention verdict for one task.
class TaskAttention {
  const TaskAttention({
    required this.task,
    required this.score,
    required this.reason,
    required this.lantern,
    required this.overdue,
    required this.dueSoon,
    required this.stale,
  });

  final PlazaTask task;

  /// Sum of the signal weights in [attentionFor].
  final int score;

  /// The headline reason shown on billboards and tickers; empty when the
  /// task is unremarkable.
  final String reason;
  final LanternState lantern;
  final bool overdue;
  final bool dueSoon;
  final bool stale;

  bool get anomalous => score >= anomalyThreshold;
}

/// The UTC calendar day of an instant: the same score on every device,
/// whatever zone the clock is in.
DateTime _day(DateTime t) {
  final u = t.toUtc();
  return DateTime.utc(u.year, u.month, u.day);
}

/// Scores [task] against [now] (day granularity).
///
/// Weights: blocked 3 · overdue 3 (+1 per week overdue, capped at 6) ·
/// due within three days 2 · in progress and untouched for two weeks 2 ·
/// high priority and open 1 · heavy and open for eight weeks 1.
TaskAttention attentionFor(PlazaTask task, DateTime now) {
  final today = _day(now);
  final finished =
      task.state == PlazaTaskState.done ||
      task.state == PlazaTaskState.cancelled ||
      task.deleted;
  final due = task.due == null ? null : _day(task.due!);

  var score = 0;
  var overdue = false;
  var dueSoon = false;
  var stale = false;
  var reason = '';

  if (!finished) {
    if (task.state == PlazaTaskState.blocked) {
      score += 3;
      reason = 'blocked — needs a decision';
    }
    if (due != null) {
      final late = today.difference(due);
      if (late.inDays > 0) {
        overdue = true;
        score += (3 + late.inDays ~/ 7).clamp(3, 6);
        if (reason.isEmpty) {
          reason = 'overdue since ${shortDate(due)} — finish or move it';
        }
      } else if (-late.inDays <= dueSoonWindow.inDays) {
        dueSoon = true;
        score += 2;
      }
    }
    if (task.state == PlazaTaskState.inProgress &&
        today.difference(_day(task.activityAt)) >= staleAfter) {
      stale = true;
      score += 2;
      if (reason.isEmpty) {
        final days = today.difference(_day(task.activityAt)).inDays;
        reason = 'quiet for $days days — pick it back up';
      }
    }
    if (task.priority <= 1 && task.state == PlazaTaskState.open) {
      score += 1;
    }
    if (task.heft >= 6 && today.difference(_day(task.createdAt)) >= oldAfter) {
      score += 1;
    }
    if (reason.isEmpty && dueSoon && due != null) {
      final days = due.difference(today).inDays;
      final when = days <= 0
          ? 'today'
          : days == 1
          ? 'tomorrow'
          : 'in $days days';
      reason = 'due $when — finish it';
    }
  }

  final lantern = finished
      ? LanternState.off
      : task.state == PlazaTaskState.blocked
      ? LanternState.blocked
      : overdue
      ? LanternState.overdue
      : task.state == PlazaTaskState.inProgress
      ? LanternState.inProgress
      : LanternState.open;

  return TaskAttention(
    task: task,
    score: score,
    reason: reason,
    lantern: lantern,
    overdue: overdue,
    dueSoon: dueSoon,
    stale: stale,
  );
}

/// Scores every task; the result keeps the input order.
List<TaskAttention> attentionForAll(List<PlazaTask> tasks, DateTime now) => [
  for (final task in tasks) attentionFor(task, now),
];

/// Highest score first, id as the stable tiebreak.
int compareAttention(TaskAttention a, TaskAttention b) {
  final byScore = b.score.compareTo(a.score);
  return byScore != 0 ? byScore : a.task.id.compareTo(b.task.id);
}

/// The anomalies (score ≥ [anomalyThreshold]), most urgent first.
List<TaskAttention> anomalies(List<TaskAttention> all) =>
    [...all.where((a) => a.anomalous)]..sort(compareAttention);

/// The tasks that fill the frontier plaza's billboards: anomalies first,
/// then anything scoring at least [billboardThreshold], up to
/// [billboardSlots]. Slot order is rank order, so the same task keeps the
/// same pylon until something outranks it.
List<TaskAttention> billboardCandidates(List<TaskAttention> all) => ([
  ...all.where((a) => a.score >= billboardThreshold),
]..sort(compareAttention)).take(billboardSlots).toList();

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// `Jul 18` — the short date used on facades, billboards and tickers.
String shortDate(DateTime date) => '${_months[date.month - 1]} ${date.day}';

/// The small print under a task's title, on its facade and in the side
/// panel: the due date and the link count, each only when there is one.
List<String> taskMetaBits(PlazaTask task) => [
  if (task.due != null) 'due ${shortDate(task.due!)}',
  if (task.linkedTaskIds.isNotEmpty) 'links ${task.linkedTaskIds.length}',
];
