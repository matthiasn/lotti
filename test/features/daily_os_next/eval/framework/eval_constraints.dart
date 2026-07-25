import 'package:lotti/classes/day_plan.dart';

import 'eval_models.dart';

/// Objective constraints the day planner's output is scored against.
///
/// Every scorer here is a pure function over an [EvalRunOutcome] — no I/O, no
/// provider, no pipeline — so they run in ordinary CI and can be exercised
/// against hand-built plans.
///
/// The set is split deliberately, because the two halves measure different
/// things:
///
/// **Unguarded** constraints are scored on the persisted plan. Nothing in the
/// write path checks them, so whatever the model produced is what the user
/// gets. These are the ones that can silently ship a bad day.
///
/// **Guarded** constraints are scored on the *rejection count*. The write path
/// throws on these and hands the message back to the model, which retries — so
/// the persisted plan is always legal and tells you nothing. What varies, and
/// what a better prompt improves, is how many corrections the model needed
/// first. Zero rejections means it complied unaided.

/// Ids of the unguarded constraints, in report order.
abstract final class EvalConstraintIds {
  static const noOverlappingBlocks = 'noOverlappingBlocks';
  static const withinCapacity = 'withinCapacity';
  static const decidedTasksPlaced = 'decidedTasksPlaced';
  static const blockerBeforeBlocked = 'blockerBeforeBlocked';
  static const noFabricatedTaskIds = 'noFabricatedTaskIds';
  static const noHistoryFabrication = 'noHistoryFabrication';
  static const uniqueBlockIds = 'uniqueBlockIds';
  static const expectedOmissionsHonoured = 'expectedOmissionsHonoured';
  static const withinWorkingHours = 'withinWorkingHours';
  static const respectsEstimates = 'respectsEstimates';
  static const withinCapacityByEstimate = 'withinCapacityByEstimate';
  static const requiredWorkPlaced = 'requiredWorkPlaced';
  static const surfacedConflict = 'surfacedConflict';
  static const noInventedWork = 'noInventedWork';

  /// Guarded — scored on rejections rather than on the plan.
  static const compliedWithoutRejection = 'compliedWithoutRejection';

  static const all = <String>[
    noOverlappingBlocks,
    withinCapacity,
    decidedTasksPlaced,
    blockerBeforeBlocked,
    noFabricatedTaskIds,
    noHistoryFabrication,
    uniqueBlockIds,
    expectedOmissionsHonoured,
    withinWorkingHours,
    respectsEstimates,
    withinCapacityByEstimate,
    requiredWorkPlaced,
    surfacedConflict,
    noInventedWork,
    compliedWithoutRejection,
  ];
}

/// Scores every constraint against [outcome], in report order.
List<EvalConstraintResult> scoreAll(EvalRunOutcome outcome) => [
  scoreNoOverlappingBlocks(outcome),
  scoreWithinCapacity(outcome),
  scoreDecidedTasksPlaced(outcome),
  scoreBlockerBeforeBlocked(outcome),
  scoreNoFabricatedTaskIds(outcome),
  scoreNoHistoryFabrication(outcome),
  scoreUniqueBlockIds(outcome),
  scoreExpectedOmissionsHonoured(outcome),
  scoreWithinWorkingHours(outcome),
  scoreRespectsEstimates(outcome),
  scoreWithinCapacityByEstimate(outcome),
  scoreRequiredWorkPlaced(outcome),
  scoreSurfacedConflict(outcome),
  scoreNoInventedWork(outcome),
  scoreCompliedWithoutRejection(outcome),
];

/// No two blocks may occupy the same time.
///
/// Nothing in the write path checks this, and overlaps additionally
/// double-count against capacity because `scheduledMinutesFor` naively sums
/// durations.
EvalConstraintResult scoreNoOverlappingBlocks(EvalRunOutcome outcome) {
  const id = EvalConstraintIds.noOverlappingBlocks;
  final noPlan = _requirePlan(outcome, id);
  if (noPlan != null) return noPlan;
  final blocks = _scheduled(outcome);
  if (blocks.length < 2) {
    return const EvalConstraintResult.notApplicable(
      id,
      'fewer than two scheduled blocks',
    );
  }
  final sorted = [...blocks]
    ..sort((a, b) => a.startTime.compareTo(b.startTime));
  final clashes = <String>[];
  for (var i = 1; i < sorted.length; i++) {
    final previous = sorted[i - 1];
    final current = sorted[i];
    // Touching is fine: one block ending exactly when the next begins is a
    // back-to-back day, not a conflict.
    if (current.startTime.isBefore(previous.endTime)) {
      clashes.add(
        '"${previous.title ?? previous.id}" '
        '(${_hhmm(previous.startTime)}-${_hhmm(previous.endTime)}) '
        'overlaps "${current.title ?? current.id}" '
        '(${_hhmm(current.startTime)}-${_hhmm(current.endTime)})',
      );
    }
  }
  return EvalConstraintResult(
    id: id,
    passed: clashes.isEmpty,
    detail: clashes.isEmpty
        ? '${sorted.length} blocks, no overlap'
        : clashes.join('; '),
  );
}

/// Scheduled minutes must fit the day's capacity.
///
/// Prompt-contract only in production: the two numbers are stored side by side
/// and never compared, and `capacityMinutes` is itself a model-supplied tool
/// argument.
EvalConstraintResult scoreWithinCapacity(EvalRunOutcome outcome) {
  const id = EvalConstraintIds.withinCapacity;
  final noPlan = _requirePlan(outcome, id);
  if (noPlan != null) return noPlan;
  final blocks = _scheduled(outcome);
  if (blocks.isEmpty) {
    return const EvalConstraintResult.notApplicable(id, 'no scheduled blocks');
  }
  final scheduled = blocks.fold<int>(
    0,
    (sum, block) => sum + block.endTime.difference(block.startTime).inMinutes,
  );
  final capacity = outcome.inputs.capacityMinutes;
  return EvalConstraintResult(
    id: id,
    passed: scheduled <= capacity,
    detail:
        '$scheduled min scheduled against $capacity min capacity'
        '${scheduled > capacity ? ' (over by ${scheduled - capacity})' : ''}',
  );
}

/// Every task the user decided on should appear in the plan.
///
/// `decidedTaskIds` is only a permission set in production — nothing checks
/// that any of them were actually placed, so a plan can honour none of them
/// and still persist.
EvalConstraintResult scoreDecidedTasksPlaced(EvalRunOutcome outcome) {
  const id = EvalConstraintIds.decidedTasksPlaced;
  final noPlan = _requirePlan(outcome, id);
  if (noPlan != null) return noPlan;
  // Only the decided tasks the scenario actually requires. One it expects to
  // be left out — already done, or blocked — must not be scored as a miss.
  final required = [
    for (final taskId in outcome.inputs.decidedTaskIds)
      if (!outcome.inputs.permittedOmissions.contains(taskId)) taskId,
  ];
  if (required.isEmpty) {
    return const EvalConstraintResult.notApplicable(
      id,
      'no decided task is required to be placed',
    );
  }
  final placed = _placedTaskIds(outcome);
  final missing = [
    for (final taskId in required)
      if (!placed.contains(taskId)) taskId,
  ];
  return EvalConstraintResult(
    id: id,
    passed: missing.isEmpty,
    detail: missing.isEmpty
        ? 'all ${required.length} required decided task(s) placed'
        : 'not placed: ${missing.join(', ')}',
  );
}

/// A blocked task may only be placed when its blocker is scheduled earlier the
/// same day, or when the block's reason names the blocker (ADR 0043).
///
/// Enforced by prompt contract alone — the writer never consults the
/// dependency resolver, by explicit ADR decision.
EvalConstraintResult scoreBlockerBeforeBlocked(EvalRunOutcome outcome) {
  const id = EvalConstraintIds.blockerBeforeBlocked;
  final noPlan = _requirePlan(outcome, id);
  if (noPlan != null) return noPlan;
  final blocked = <PlannedBlock, EvalCorpusTask>{};
  for (final block in _scheduled(outcome)) {
    final taskId = block.taskId;
    if (taskId == null) continue;
    final task = outcome.inputs.taskById(taskId);
    if (task != null && task.isBlocked) blocked[block] = task;
  }
  if (blocked.isEmpty) {
    return const EvalConstraintResult.notApplicable(
      id,
      'no blocked task was placed',
    );
  }
  final violations = <String>[];
  for (final entry in blocked.entries) {
    final block = entry.key;
    final task = entry.value;
    final blockerScheduledEarlier = _scheduled(outcome).any(
      (other) =>
          other.taskId != null &&
          task.blockedBy.contains(other.taskId) &&
          other.startTime.isBefore(block.startTime),
    );
    if (blockerScheduledEarlier) continue;
    // The escape hatch the rule grants: place it anyway, but say which
    // blocker and why it can proceed regardless.
    final reason = block.reason?.toLowerCase() ?? '';
    final namesBlocker = task.blockedBy.any((blockerId) {
      final blocker = outcome.inputs.taskById(blockerId);
      final title = blocker?.title.toLowerCase();
      return reason.contains(blockerId.toLowerCase()) ||
          (title != null && title.isNotEmpty && reason.contains(title));
    });
    if (namesBlocker) continue;
    violations.add(
      '"${block.title ?? block.taskId}" is blocked by '
      '${task.blockedBy.isEmpty ? 'status BLOCKED' : task.blockedBy.join(', ')} '
      'but neither schedules the blocker earlier nor names it in the reason',
    );
  }
  return EvalConstraintResult(
    id: id,
    passed: violations.isEmpty,
    detail: violations.isEmpty
        ? '${blocked.length} blocked task(s) placed, all justified'
        : violations.join('; '),
  );
}

/// Every `taskId` on the plan must be a task the model was actually shown.
///
/// A real hole in production: a taskId is accepted if it appears in the
/// model's *own* `decidedTaskIds` argument, which is never verified against
/// the wake context or the database.
EvalConstraintResult scoreNoFabricatedTaskIds(EvalRunOutcome outcome) {
  const id = EvalConstraintIds.noFabricatedTaskIds;
  final noPlan = _requirePlan(outcome, id);
  if (noPlan != null) return noPlan;
  final referenced = [for (final block in outcome.blocks) ?block.taskId];
  if (referenced.isEmpty) {
    return const EvalConstraintResult.notApplicable(
      id,
      'no block references a task',
    );
  }
  // What the model was SHOWN, not what is true. Without a capture the corpus
  // is never rendered, so grading against it would credit or punish the model
  // for ids it could not have seen.
  final known = outcome.inputs.referenceableTaskIds;
  final fabricated = {
    for (final taskId in referenced)
      if (!known.contains(taskId)) taskId,
  };
  return EvalConstraintResult(
    id: id,
    passed: fabricated.isEmpty,
    detail: fabricated.isEmpty
        ? '${referenced.length} task reference(s), all known'
        : 'unknown task id(s): ${fabricated.join(', ')}',
  );
}

/// A freshly drafted plan must not claim work already happened.
///
/// `state` is a model-writable enum that nothing validates, so a model can
/// assert `completed`, `inProgress` or `committed` on a brand-new draft. That
/// both fabricates history the user never made — commitment is the user's word,
/// not the model's — and slips the same-day past-start guard, which fires only
/// for `drafted`.
EvalConstraintResult scoreNoHistoryFabrication(EvalRunOutcome outcome) {
  const id = EvalConstraintIds.noHistoryFabrication;
  final noPlan = _requirePlan(outcome, id);
  if (noPlan != null) return noPlan;
  if (outcome.blocks.isEmpty) {
    return const EvalConstraintResult.notApplicable(id, 'no blocks');
  }
  final fabricated = [
    for (final block in outcome.blocks)
      if (block.state == PlannedBlockState.completed ||
          block.state == PlannedBlockState.inProgress ||
          block.state == PlannedBlockState.committed)
        '"${block.title ?? block.id}" as ${block.state.name}',
  ];
  return EvalConstraintResult(
    id: id,
    passed: fabricated.isEmpty,
    detail: fabricated.isEmpty
        ? 'no fabricated history'
        : 'claims history: ${fabricated.join(', ')}',
  );
}

/// Block ids must be unique within a plan.
///
/// Model-supplied ids are taken verbatim with no uniqueness check; duplicates
/// make later `move_block` / `drop_block` targeting ambiguous.
EvalConstraintResult scoreUniqueBlockIds(EvalRunOutcome outcome) {
  const id = EvalConstraintIds.uniqueBlockIds;
  final noPlan = _requirePlan(outcome, id);
  if (noPlan != null) return noPlan;
  if (outcome.blocks.length < 2) {
    return const EvalConstraintResult.notApplicable(
      id,
      'fewer than two blocks',
    );
  }
  final seen = <String>{};
  final duplicates = <String>{};
  for (final block in outcome.blocks) {
    if (!seen.add(block.id)) duplicates.add(block.id);
  }
  return EvalConstraintResult(
    id: id,
    passed: duplicates.isEmpty,
    detail: duplicates.isEmpty
        ? '${outcome.blocks.length} unique block ids'
        : 'duplicate id(s): ${duplicates.join(', ')}',
  );
}

/// Work the scenario expects to be left out must actually be left out.
///
/// The complement to [EvalFixtureInputs.permittedOmissions]: dropping a task
/// from the positive requirement stops a correct omission failing, but on its
/// own it also lets a model place the task and still score clean — so the
/// scenario could not distinguish the behaviour it was built to measure.
EvalConstraintResult scoreExpectedOmissionsHonoured(EvalRunOutcome outcome) {
  const id = EvalConstraintIds.expectedOmissionsHonoured;
  final noPlan = _requirePlan(outcome, id);
  if (noPlan != null) return noPlan;
  final expected = outcome.inputs.expectedOmissions;
  if (expected.isEmpty) {
    return const EvalConstraintResult.notApplicable(
      id,
      'no omission is expected',
    );
  }
  final placed = _placedTaskIds(outcome);
  final wronglyPlaced = [
    for (final taskId in expected)
      if (placed.contains(taskId)) taskId,
  ];
  return EvalConstraintResult(
    id: id,
    passed: wronglyPlaced.isEmpty,
    detail: wronglyPlaced.isEmpty
        ? 'left out ${expected.length} task(s) it was meant to'
        : 'placed work it should have left out: ${wronglyPlaced.join(', ')}',
  );
}

/// Blocks must not run past the end of the working day.
///
/// Capacity cannot catch this on its own: a 180-minute block starting at 15:00
/// consumes 180 of 480 minutes and stays inside the calendar day, so every
/// other constraint passes while the plan runs to 18:00.
EvalConstraintResult scoreWithinWorkingHours(EvalRunOutcome outcome) {
  const id = EvalConstraintIds.withinWorkingHours;
  final noPlan = _requirePlan(outcome, id);
  if (noPlan != null) return noPlan;
  final blocks = _scheduled(outcome);
  if (blocks.isEmpty) {
    return const EvalConstraintResult.notApplicable(id, 'no scheduled blocks');
  }
  final planDate = outcome.inputs.planDate;
  final workingStart = DateTime(
    planDate.year,
    planDate.month,
    planDate.day,
    outcome.inputs.workingHoursStartHour,
  );
  // On a same-day draft the day effectively starts *now*. Without this the
  // scenario enforces 09:00 rather than its actual draft time, so a model can
  // place work at 10:00 on a 15:00 draft — and evade the production guard
  // entirely by labelling the block with any state other than `drafted`.
  final now = outcome.inputs.now;
  final startOfDay = now != null && now.isAfter(workingStart)
      ? now
      : workingStart;
  final endOfDay = DateTime(
    planDate.year,
    planDate.month,
    planDate.day,
    outcome.inputs.workingHoursEndHour,
  );
  final outside = [
    for (final block in blocks)
      if (block.endTime.isAfter(endOfDay))
        '"${block.title ?? block.id}" ends ${_hhmm(block.endTime)}'
      else if (block.startTime.isBefore(startOfDay))
        '"${block.title ?? block.id}" starts ${_hhmm(block.startTime)}',
  ];
  return EvalConstraintResult(
    id: id,
    passed: outside.isEmpty,
    detail: outside.isEmpty
        ? 'all blocks inside ${_hhmm(startOfDay)}-${_hhmm(endOfDay)}'
        : 'outside ${_hhmm(startOfDay)}-${_hhmm(endOfDay)}: '
              '${outside.join(', ')}',
  );
}

/// A block for an estimated task must reflect that estimate.
///
/// The cheapest way to make an impossible day look feasible is to shrink the
/// work: four multi-hour tasks become four short blocks, capacity is
/// satisfied, and nothing surfaces the conflict the scenario was built to
/// provoke. Allows generous slack — the point is catching compression, not
/// policing estimation.
EvalConstraintResult scoreRespectsEstimates(EvalRunOutcome outcome) {
  const id = EvalConstraintIds.respectsEstimates;
  final noPlan = _requirePlan(outcome, id);
  if (noPlan != null) return noPlan;
  // Summed per task, not per block: splitting a 180-minute task into 60 + 120
  // is a legitimate shape, and comparing each block against the whole estimate
  // would fail the first half of a correctly scheduled task.
  final allocatedByTask = <String, int>{};
  final titleByTask = <String, String>{};
  for (final block in _scheduled(outcome)) {
    final taskId = block.taskId;
    if (taskId == null) continue;
    allocatedByTask.update(
      taskId,
      (minutes) =>
          minutes + block.endTime.difference(block.startTime).inMinutes,
      ifAbsent: () => block.endTime.difference(block.startTime).inMinutes,
    );
    titleByTask.putIfAbsent(taskId, () => block.title ?? taskId);
  }
  final compressed = <String>[];
  var checked = 0;
  for (final entry in allocatedByTask.entries) {
    final estimate = outcome.inputs.taskById(entry.key)?.estimateMinutes;
    if (estimate == null || estimate <= 0) continue;
    checked++;
    if (entry.value * 2 < estimate) {
      compressed.add(
        '"${titleByTask[entry.key]}" allocated ${entry.value}min '
        'across its blocks against a ${estimate}min estimate',
      );
    }
  }
  if (checked == 0) {
    return const EvalConstraintResult.notApplicable(
      id,
      'no placed task carries an estimate',
    );
  }
  return EvalConstraintResult(
    id: id,
    passed: compressed.isEmpty,
    detail: compressed.isEmpty
        ? '$checked estimated task(s) placed at a plausible length'
        : compressed.join('; '),
  );
}

/// Placed work must fit the day at its *estimated* length, not its written
/// one.
///
/// The per-task [scoreRespectsEstimates] check cannot catch a coordinated
/// shrink: 240/180/120/180-minute tasks written as 160/120/80/120 all clear a
/// per-task ratio while summing to exactly the 480-minute capacity. Summing
/// estimates instead makes the arithmetic honest — 720 minutes of work does
/// not fit in 480 however the blocks are labelled.
EvalConstraintResult scoreWithinCapacityByEstimate(EvalRunOutcome outcome) {
  const id = EvalConstraintIds.withinCapacityByEstimate;
  final noPlan = _requirePlan(outcome, id);
  if (noPlan != null) return noPlan;
  var estimated = 0;
  var counted = 0;
  final seen = <String>{};
  for (final block in _scheduled(outcome)) {
    final taskId = block.taskId;
    if (taskId == null || !seen.add(taskId)) continue;
    final estimate = outcome.inputs.taskById(taskId)?.estimateMinutes;
    if (estimate == null || estimate <= 0) continue;
    estimated += estimate;
    counted++;
  }
  if (counted == 0) {
    return const EvalConstraintResult.notApplicable(
      id,
      'no placed task carries an estimate',
    );
  }
  final capacity = outcome.inputs.capacityMinutes;
  return EvalConstraintResult(
    id: id,
    passed: estimated <= capacity,
    detail:
        '$counted placed task(s) estimated at ${estimated}min against '
        '${capacity}min capacity'
        '${estimated > capacity ? ' (over by ${estimated - capacity})' : ''}',
  );
}

/// Work the scenario says any competent plan must include.
///
/// Without this a prioritisation scenario cannot tell a good plan from one
/// that scheduled the least urgent thing on the list: generic constraints are
/// all satisfied by a plan containing a single well-formed block.
EvalConstraintResult scoreRequiredWorkPlaced(EvalRunOutcome outcome) {
  const id = EvalConstraintIds.requiredWorkPlaced;
  final required = outcome.inputs.requiredTaskIds;
  if (required.isEmpty) {
    return const EvalConstraintResult.notApplicable(
      id,
      'the scenario names no required work',
    );
  }
  final noPlan = _requirePlan(outcome, id);
  if (noPlan != null) return noPlan;
  final placed = _placedTaskIds(outcome);
  final missing = [
    for (final taskId in required)
      if (!placed.contains(taskId)) taskId,
  ];
  return EvalConstraintResult(
    id: id,
    passed: missing.isEmpty,
    detail: missing.isEmpty
        ? 'placed all ${required.length} task(s) the day turns on'
        : 'ignored: ${missing.join(', ')}',
  );
}

/// An impossible day has to be named, not quietly absorbed.
///
/// Permitting omissions stops a planner being punished for dropping work it
/// cannot fit — but on its own it also lets one emit a single buffer block,
/// ignore twelve hours of requested work, and score clean. The prompt gives
/// two legitimate ways out: escalate via `raise_day_status`, or state the
/// trade in a block reason. Either satisfies this; silence does not.
EvalConstraintResult scoreSurfacedConflict(EvalRunOutcome outcome) {
  const id = EvalConstraintIds.surfacedConflict;
  if (!outcome.inputs.requiresConflictSurfaced) {
    return const EvalConstraintResult.notApplicable(
      id,
      'the scenario is satisfiable as stated',
    );
  }
  // The tool accepts onTrack and dayClosed too, and attentionNeeded with
  // reasons like processingBlocked that say nothing about this conflict.
  // Matching the call by name alone would let any of those pass.
  final escalated = outcome.toolCalls.any((call) {
    if (!call.accepted || !call.name.contains('raise_day_status')) return false;
    if (call.arguments['status'] != 'attentionNeeded') return false;
    final reasons = switch (call.arguments['reasons']) {
      final List<Object?> list => list.map((r) => '$r').toSet(),
      _ => const <String>{},
    };
    return reasons.any(outcome.inputs.conflictEscalationReasons.contains);
  });
  if (escalated) {
    return const EvalConstraintResult(
      id: id,
      passed: true,
      detail: 'escalated through raise_day_status',
    );
  }
  final noPlan = _requirePlan(outcome, id);
  if (noPlan != null) return noPlan;
  const conflictTerms = [
    'not fit',
    "won't fit",
    'does not fit',
    'capacity',
    'defer',
    'deferred',
    'trade',
    'drop',
    'dropped',
    'postpone',
    'tomorrow',
    'over-committed',
    'overcommitted',
    'too much',
  ];
  final named = outcome.blocks.any((block) {
    final reason = '${block.reason ?? ''} ${block.note ?? ''}'.toLowerCase();
    return conflictTerms.any(reason.contains);
  });
  return EvalConstraintResult(
    id: id,
    passed: named,
    detail: named
        ? 'named the trade in a block reason'
        : 'absorbed an impossible day silently — no escalation and no reason '
              'naming what was left out',
  );
}

/// The planner must not invent work that was never asked for.
///
/// Fabrication scoring only catches invented task *ids*; a block with no
/// `taskId` at all escapes it entirely. So on a day with nothing to do, a
/// model can emit a confident "Write a proposal" block and score clean —
/// which is precisely what the restraint control exists to detect. Buffer and
/// calendar blocks are exempt: structuring open time is not inventing work.
EvalConstraintResult scoreNoInventedWork(EvalRunOutcome outcome) {
  const id = EvalConstraintIds.noInventedWork;
  if (!outcome.inputs.forbidsInventedWork) {
    return const EvalConstraintResult.notApplicable(
      id,
      'the scenario has real work to schedule',
    );
  }
  final noPlan = _requirePlan(outcome, id);
  if (noPlan != null) return noPlan;
  final invented = [
    for (final block in _scheduled(outcome))
      if (block.taskId == null &&
          block.type != PlannedBlockType.buffer &&
          block.type != PlannedBlockType.cal)
        '"${block.title ?? block.id}" (${block.type.name})',
  ];
  return EvalConstraintResult(
    id: id,
    passed: invented.isEmpty,
    detail: invented.isEmpty
        ? 'added no work of its own'
        : 'invented work nobody asked for: ${invented.join(', ')}',
  );
}

/// Whether the model produced a legal plan without being corrected.
///
/// This is the guarded half. The persisted plan is always legal — the write
/// path rejected anything that was not — so the only observable difference
/// between a model that got it right and one that needed four attempts is the
/// rejections it collected on the way.
EvalConstraintResult scoreCompliedWithoutRejection(EvalRunOutcome outcome) {
  const id = EvalConstraintIds.compliedWithoutRejection;
  final rejections = outcome.rejections.toList();
  return EvalConstraintResult(
    id: id,
    passed: rejections.isEmpty,
    detail: rejections.isEmpty
        ? 'accepted on the first attempt'
        : '${rejections.length} rejection(s): '
              '${rejections.map((r) => r.rejectionMessage ?? 'unknown').join(' | ')}',
  );
}

/// Guard for every constraint that reads the plan.
///
/// A run that produced no plan has not demonstrated anything about plan
/// quality — its empty block list would otherwise read as "no overlaps, no
/// fabricated ids, every omission honoured", handing a failed run a clean
/// sweep. Those constraints are inapplicable, not passed.
EvalConstraintResult? _requirePlan(EvalRunOutcome outcome, String id) =>
    outcome.planPersisted
    ? null
    : EvalConstraintResult.notApplicable(id, 'no plan was persisted');

/// Task ids the plan actually commits to.
///
/// Derived from scheduled blocks, not every block: a `dropped` block is the
/// model explicitly declining the work, and production's `scheduledMinutesFor`
/// excludes it from the day too. Counting it as placed was inconsistent in
/// both directions at once — a dropped stale task failed the omission
/// constraint while a dropped required task satisfied the placement one.
Set<String> _placedTaskIds(EvalRunOutcome outcome) => {
  for (final block in _scheduled(outcome)) ?block.taskId,
};

/// Blocks that consume capacity — `dropped` ones are recorded but not
/// scheduled, matching `scheduledMinutesFor` in the parser.
List<PlannedBlock> _scheduled(EvalRunOutcome outcome) => [
  for (final block in outcome.blocks)
    if (block.state != PlannedBlockState.dropped) block,
];

String _hhmm(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';
