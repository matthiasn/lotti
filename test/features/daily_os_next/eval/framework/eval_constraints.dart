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
  scoreCompliedWithoutRejection(outcome),
];

/// No two blocks may occupy the same time.
///
/// Nothing in the write path checks this, and overlaps additionally
/// double-count against capacity because `scheduledMinutesFor` naively sums
/// durations.
EvalConstraintResult scoreNoOverlappingBlocks(EvalRunOutcome outcome) {
  const id = EvalConstraintIds.noOverlappingBlocks;
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
  final placed = {for (final block in outcome.blocks) ?block.taskId};
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
  final blocked = <PlannedBlock, EvalCorpusTask>{};
  for (final block in outcome.blocks) {
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
    final blockerScheduledEarlier = outcome.blocks.any(
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
/// assert `completed`/`inProgress` on a brand-new draft — which both fabricates
/// history and slips the same-day past-start guard, since that guard only
/// fires for `drafted`.
EvalConstraintResult scoreNoHistoryFabrication(EvalRunOutcome outcome) {
  const id = EvalConstraintIds.noHistoryFabrication;
  if (outcome.blocks.isEmpty) {
    return const EvalConstraintResult.notApplicable(id, 'no blocks');
  }
  final fabricated = [
    for (final block in outcome.blocks)
      if (block.state == PlannedBlockState.completed ||
          block.state == PlannedBlockState.inProgress)
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
  final expected = outcome.inputs.expectedOmissions;
  if (expected.isEmpty) {
    return const EvalConstraintResult.notApplicable(
      id,
      'no omission is expected',
    );
  }
  final placed = {for (final block in outcome.blocks) ?block.taskId};
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
  final blocks = _scheduled(outcome);
  if (blocks.isEmpty) {
    return const EvalConstraintResult.notApplicable(id, 'no scheduled blocks');
  }
  final planDate = outcome.inputs.planDate;
  final endOfDay = DateTime(
    planDate.year,
    planDate.month,
    planDate.day,
    outcome.inputs.workingHoursEndHour,
  );
  final overruns = [
    for (final block in blocks)
      if (block.endTime.isAfter(endOfDay))
        '"${block.title ?? block.id}" ends ${_hhmm(block.endTime)}',
  ];
  return EvalConstraintResult(
    id: id,
    passed: overruns.isEmpty,
    detail: overruns.isEmpty
        ? 'all blocks end by ${_hhmm(endOfDay)}'
        : 'past ${_hhmm(endOfDay)}: ${overruns.join(', ')}',
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
  final compressed = <String>[];
  var checked = 0;
  for (final block in _scheduled(outcome)) {
    final taskId = block.taskId;
    if (taskId == null) continue;
    final estimate = outcome.inputs.taskById(taskId)?.estimateMinutes;
    if (estimate == null || estimate <= 0) continue;
    checked++;
    final allocated = block.endTime.difference(block.startTime).inMinutes;
    if (allocated * 2 < estimate) {
      compressed.add(
        '"${block.title ?? taskId}" allocated ${allocated}min '
        'against a ${estimate}min estimate',
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

/// Blocks that consume capacity — `dropped` ones are recorded but not
/// scheduled, matching `scheduledMinutesFor` in the parser.
List<PlannedBlock> _scheduled(EvalRunOutcome outcome) => [
  for (final block in outcome.blocks)
    if (block.state != PlannedBlockState.dropped) block,
];

String _hhmm(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';
