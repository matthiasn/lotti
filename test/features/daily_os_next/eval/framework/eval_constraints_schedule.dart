part of 'eval_constraints.dart';

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
    // Every placed blocked task is judged, including one whose own blockers
    // were never rendered. Hiding the blocker removes both *exceptions* the
    // rule grants, but not compliance itself: omitting the task is always
    // available, and the prompt says so explicitly. Exempting these would
    // credit exactly the defect the constraint exists to catch — a plan that
    // schedules work the model was told cannot start.
    if (task != null && task.isBlocked) blocked[block] = task;
  }
  if (blocked.isEmpty) {
    return const EvalConstraintResult.notApplicable(
      id,
      'no blocked task was placed',
    );
  }
  final violations = <String>[];
  var usedProseBypass = false;
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
    if (namesBlocker) {
      usedProseBypass = true;
      continue;
    }
    // Says *why* it could not comply, so a judge reads the failure correctly.
    // When the blocker was never rendered, neither exception was reachable and
    // the compliant move was omission — a real defect in the plan, but not the
    // model ignoring an id it was shown.
    final blockersHidden =
        task.blockedBy.isNotEmpty &&
        !outcome.inputs.blockersShownFor(task.taskId);
    violations.add(
      '"${block.title ?? block.taskId}" is blocked by '
      '${task.blockedBy.isEmpty ? 'status BLOCKED' : task.blockedBy.join(', ')} '
      '${blockersHidden ? 'which was never shown to the model, so neither '
                'exception was available and it should have been left out' : 'but neither schedules the blocker earlier nor names it in the '
                'reason'}',
    );
  }
  return EvalConstraintResult(
    id: id,
    passed: violations.isEmpty,
    heuristic: violations.isEmpty && usedProseBypass,
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
  // for ids it could not have seen — plus whatever it created during the run,
  // which it equally could not have invented.
  final known = outcome.knownTaskIds;
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
