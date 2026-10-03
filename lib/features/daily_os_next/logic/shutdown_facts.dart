import 'package:collection/collection.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/tasks/util/time_range_utils.dart';

/// Pure computations behind the Shutdown screen. The service loads the day's
/// recorded time ([TimeBlock]s from the Actual lane), the tasks meant for it
/// and the session ratings; everything here is deterministic over those.
///
/// Recorded *work* means the manual recordings: calendar events are time the
/// user spent, and show in "What you did", but are not focus.

/// A run of work on one thing at least this long counts as a flow session.
const flowSessionMinimum = Duration(minutes: 45);

/// Two recordings of the same thing at most this far apart continue one run,
/// so pausing a timer for a coffee does not split a session or add a switch.
const workRunMaxGap = Duration(minutes: 5);

/// How many earlier days the week comparisons look back over.
const shutdownLookbackDays = 7;

/// A task the day touched, as the facts need it.
typedef ShutdownTask = ({
  String taskId,
  String title,
  DayAgentCategory category,
});

/// What a block's time went to: its task, or — for untasked recordings — the
/// title within its category.
String _workKey(TimeBlock block) =>
    block.taskId ?? 'untasked:${block.category.id}:${block.title}';

int _unionMinutes(Iterable<TimeBlock> blocks) => calculateUnionDuration([
  for (final block in blocks) TimeRange(start: block.start, end: block.end),
]).inMinutes;

/// "What you did": the day's recorded time grouped by what it went to,
/// longest first, followed by tasks marked done on the day without any
/// recorded time.
List<CompletedItem> completedItems({
  required List<TimeBlock> blocks,
  required List<ShutdownTask> doneToday,
}) {
  final doneIds = {for (final task in doneToday) task.taskId};
  final groups = groupBy(blocks, _workKey);
  final recorded = [
    for (final group in groups.values)
      CompletedItem(
        taskId: group.first.taskId,
        title: group.first.title,
        category: group.first.category,
        durationMinutes: _unionMinutes(group),
        sessionCount: group.length,
        doneToday: doneIds.contains(group.first.taskId),
      ),
  ]..sort((a, b) => b.durationMinutes.compareTo(a.durationMinutes));
  final withTime = {for (final item in recorded) item.taskId};
  return [
    ...recorded,
    for (final task in doneToday)
      if (!withTime.contains(task.taskId))
        CompletedItem(
          taskId: task.taskId,
          title: task.title,
          category: task.category,
          durationMinutes: 0,
          sessionCount: 0,
          doneToday: true,
        ),
  ];
}

/// "Carries forward": the still-open tasks meant for the day, each with the
/// minutes recorded against it and re-placed on the next day by default.
List<CarryoverItem> carryoverItems({
  required List<ShutdownTask> openTasks,
  required List<TimeBlock> blocks,
  required DateTime forDate,
}) {
  final nextDay = DateTime(forDate.year, forDate.month, forDate.day + 1);
  return [
    for (final task in openTasks)
      CarryoverItem(
        taskId: task.taskId,
        title: task.title,
        category: task.category,
        loggedMinutes: _unionMinutes(
          blocks.where((block) => block.taskId == task.taskId),
        ),
        suggestedDate: nextDay,
      ),
  ];
}

/// A maximal run of recorded work on one thing: same work key, consecutive
/// recordings at most [workRunMaxGap] apart.
class _WorkRun {
  _WorkRun(TimeBlock block) : key = _workKey(block), blocks = [block];

  final String key;
  final List<TimeBlock> blocks;

  DateTime get end => blocks.map((b) => b.end).max;
  Duration get length => Duration(minutes: _unionMinutes(blocks));
}

List<_WorkRun> _workRuns(List<TimeBlock> blocks) {
  final work = blocks
      .where((block) => block.type == TimeBlockType.manual)
      .sortedBy((block) => block.start);
  final runs = <_WorkRun>[];
  for (final block in work) {
    final last = runs.lastOrNull;
    if (last != null &&
        last.key == _workKey(block) &&
        block.start.difference(last.end) <= workRunMaxGap) {
      last.blocks.add(block);
    } else {
      runs.add(_WorkRun(block));
    }
  }
  return runs;
}

/// Times the user moved from one thing to another during the day's work.
int contextSwitches(List<TimeBlock> blocks) {
  final runs = _workRuns(blocks);
  var switches = 0;
  for (var i = 1; i < runs.length; i++) {
    if (runs[i].key != runs[i - 1].key) switches++;
  }
  return switches;
}

double? _mean(Iterable<double> values) =>
    values.isEmpty ? null : values.sum / values.length;

/// The Shutdown metrics card.
///
/// - **Focus** — recorded work minutes, overlaps counted once.
/// - **Flow sessions** — runs of work on one thing of at least
///   [flowSessionMinimum].
/// - **Context switches** — changes of what was worked on between runs;
///   compared with the mean over [priorDays] that had any recorded work.
/// - **Energy** — the mean `energy` dimension of the day's session ratings
///   (0–1) on a 0–10 scale, compared with the mean of [priorEnergy]. Null
///   when nothing was rated: there is no other measured energy signal.
ShutdownMetrics shutdownMetrics({
  required List<TimeBlock> blocks,
  required List<double> energy,
  required List<List<TimeBlock>> priorDays,
  required List<double> priorEnergy,
}) {
  final work = blocks.where((block) => block.type == TimeBlockType.manual);
  final runs = _workRuns(blocks);
  final energyScore = _mean(energy);
  final priorEnergyScore = _mean(priorEnergy);
  return ShutdownMetrics(
    focusMinutes: _unionMinutes(work),
    flowSessions: runs.where((run) => run.length >= flowSessionMinimum).length,
    contextSwitches: contextSwitches(blocks),
    contextSwitchesWeekAvg: _mean([
      for (final day in priorDays)
        if (day.any((block) => block.type == TimeBlockType.manual))
          contextSwitches(day).toDouble(),
    ]),
    energyScore: energyScore == null ? null : energyScore * 10,
    energyDeltaVsWeek: energyScore == null || priorEnergyScore == null
        ? null
        : (energyScore - priorEnergyScore) * 10,
  );
}
