import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';

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
  static const taskWorkIsTyped = 'taskWorkIsTyped';
  static const noFabricatedCalendarBlocks = 'noFabricatedCalendarBlocks';
  static const directiveHonoured = 'directiveHonoured';

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
    taskWorkIsTyped,
    noFabricatedCalendarBlocks,
    directiveHonoured,
    compliedWithoutRejection,
  ];
}

/// How strongly each constraint result should be interpreted.
///
/// Most constraints compare structured data and are objective. The always
/// heuristic constraints below deliberately accept string or structural
/// presence as an inexpensive indifference detector. A mixed constraint may
/// also mark only the result that used its semantic escape hatch. Such a green
/// is useful evidence that the model did not stay silent, but not that it
/// understood the dependency, capacity trade, or directive it answered.
abstract final class EvalConstraintSignals {
  static const heuristicIds = <String>{
    EvalConstraintIds.surfacedConflict,
    EvalConstraintIds.directiveHonoured,
  };

  static const mixedIds = <String>{
    EvalConstraintIds.blockerBeforeBlocked,
  };

  static const caveats = <String, String>{
    EvalConstraintIds.blockerBeforeBlocked:
        'Structured blocker ordering is objective. A pass that instead relies '
        'on a reason naming the blocker is heuristic: the match does not prove '
        'that the model understood the dependency or justified bypassing it; '
        'inspect the plan and reason in the judge bundle.',
    EvalConstraintIds.surfacedConflict:
        'Checks whether the output names omitted work or uses an accepted '
        'escalation reason. A match does not prove that the model understood '
        'the capacity trade; inspect the plan, reasons, and status note in the '
        'judge bundle.',
    EvalConstraintIds.directiveHonoured:
        'Checks whether commitments are named in plan or trade prose, or uses '
        'an accepted escalation whose status note may be non-empty but '
        'unrelated. A match does not prove that the model understood or '
        'answered the directive; inspect the plan, changes, reasons, and '
        'status note in the judge bundle.',
  };

  static bool isHeuristic(String id) => heuristicIds.contains(id);

  static bool isHeuristicResult(EvalConstraintResult result) =>
      isHeuristic(result.id) || result.heuristic;

  static String kindFor(String id) => isHeuristic(id)
      ? 'heuristic'
      : mixedIds.contains(id)
      ? 'mixed'
      : 'objective';

  static String kindForResult(EvalConstraintResult result) =>
      isHeuristicResult(result) ? 'heuristic' : 'objective';

  static String? caveatFor(String id) => caveats[id];
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
  scoreTaskWorkIsTyped(outcome),
  scoreNoFabricatedCalendarBlocks(outcome),
  scoreDirectiveHonoured(outcome),
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
  // On a day that cannot hold the work, truncation is not compression — it is
  // the only honest plan, and the prompt explicitly asks for it ("place a task
  // for less than its estimate and say so"). Judging allocation against a full
  // estimate there fails a model for obeying, which is what it did: every
  // `lateStart` sample placed "Finish the database migration (partial — 60 of
  // 180 min)" and was marked down for the label it was told to write.
  //
  // The premise of this constraint is a day with room. `surfacedConflict`
  // carries the other half — whether the model *said* the day does not fit —
  // so nothing is lost by standing down here.
  final placedEstimate = allocatedByTask.keys.fold<int>(
    0,
    (sum, taskId) =>
        sum + (outcome.inputs.taskById(taskId)?.estimateMinutes ?? 0),
  );
  if (placedEstimate > outcome.inputs.plannableMinutes) {
    // Standing down entirely was wrong: it let a plan of one-minute tokens
    // score as clean as an honest partial one, since nothing else on an
    // impossible day objects to under-filling. So the question changes rather
    // than disappearing — not "did each task get its estimate", which is
    // impossible here, but "did the plan use the time it had".
    final allocated = allocatedByTask.values.fold<int>(0, (a, b) => a + b);
    final plannable = outcome.inputs.plannableMinutes;
    if (allocated * 2 < plannable) {
      return EvalConstraintResult(
        id: id,
        passed: false,
        detail:
            'the day cannot hold this work, but the plan only fills '
            '${allocated}min of $plannable plannable — shortening every '
            'task to a token is not a partial placement',
      );
    }
    // The aggregate is not enough on its own: one long task can supply the
    // fill while the work the scenario actually requires is reduced to
    // one-minute tokens, and nothing else objects — `requiredWorkPlaced` only
    // checks that the id appears. So required work keeps a per-task floor. It
    // is deliberately generous, since a genuinely partial placement is the
    // point here; it only catches a token.
    final tokenised = <String>[];
    for (final taskId in outcome.inputs.requiredTaskIds) {
      final minutes = allocatedByTask[taskId];
      if (minutes == null) continue;
      final estimate = outcome.inputs.taskById(taskId)?.estimateMinutes;
      if (estimate == null || estimate <= 0) continue;
      if (minutes * 10 < estimate) {
        tokenised.add(
          '"${titleByTask[taskId]}" got ${minutes}min of a ${estimate}min '
          'estimate',
        );
      }
    }
    if (tokenised.isNotEmpty) {
      return EvalConstraintResult(
        id: id,
        passed: false,
        detail:
            'the day cannot hold this work, but required work was reduced to '
            'a token: ${tokenised.join('; ')}',
      );
    }
    return EvalConstraintResult(
      id: id,
      passed: true,
      detail:
          'the day cannot hold this work ($placedEstimate min of estimates '
          'against $plannable plannable), and the plan fills ${allocated}min '
          'of it — a partial placement rather than a compressed one',
    );
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

/// Placed work must fit the day at its *estimated* length, except for an
/// explicitly auditable partial placement.
///
/// The per-task [scoreRespectsEstimates] check cannot catch a coordinated
/// shrink: 240/180/120/180-minute tasks written as 160/120/80/120 all clear a
/// per-task ratio while summing to exactly the 480-minute capacity. Summing
/// estimates instead makes the arithmetic honest — 720 minutes of work does
/// not fit in 480 however the blocks are labelled. A shortened task is charged
/// at its represented minutes only when its reason gives concrete minute
/// arithmetic that agrees with both the block duration and corpus estimate;
/// vague or contradictory partial prose keeps the full-estimate charge.
EvalConstraintResult scoreWithinCapacityByEstimate(EvalRunOutcome outcome) {
  const id = EvalConstraintIds.withinCapacityByEstimate;
  final noPlan = _requirePlan(outcome, id);
  if (noPlan != null) return noPlan;
  final placements = _estimatedTaskPlacements(outcome);
  if (placements.isEmpty) {
    return const EvalConstraintResult.notApplicable(
      id,
      'no placed task carries an estimate',
    );
  }
  var chargedMinutes = 0;
  final partials = <String>[];
  final undisclosedShortenings = <String>[];
  for (final entry in placements.entries) {
    final taskId = entry.key;
    final allocated = entry.value.allocatedMinutes;
    final estimate = entry.value.estimateMinutes;
    if (_isAuditedPartial(entry.value)) {
      chargedMinutes += allocated;
      partials.add(
        '$taskId ${allocated}min partial of ${estimate}min '
        '(${estimate - allocated}min remain)',
      );
    } else {
      chargedMinutes += estimate;
      if (allocated > 0 && allocated < estimate) {
        undisclosedShortenings.add(
          '$taskId allocated ${allocated}min of ${estimate}min',
        );
      }
    }
  }
  final capacity = outcome.inputs.capacityMinutes;
  final evidence = [
    if (partials.isNotEmpty) 'audited partials: ${partials.join(', ')}',
    if (undisclosedShortenings.isNotEmpty)
      'charged at full estimate without a matching concrete partial disclosure: ${undisclosedShortenings.join(', ')}',
  ];
  return EvalConstraintResult(
    id: id,
    passed: chargedMinutes <= capacity,
    detail:
        '${placements.length} placed task(s) charged at ${chargedMinutes}min against '
        '${capacity}min capacity'
        '${chargedMinutes > capacity ? ' (over by ${chargedMinutes - capacity})' : ''}'
        '${evidence.isEmpty ? '' : '; ${evidence.join('; ')}'}',
  );
}

final _partialOfEstimatePattern = RegExp(
  r'\b(\d+)(?:\s*(?:m|mins?|minutes?))?\s+of\s+(?:the\s+)?'
  r'(\d+)(?:\s+estimated)?\s*[-–—]?\s*(?:m|mins?|minutes?)\b',
  caseSensitive: false,
);

final _partialRemainingPattern = RegExp(
  r'\b(\d+)\s*(?:m|mins?|minutes?)\s+'
  r'(?:(?:is|are)\s+)?(?:left|remain(?:s|ing)?)\b',
  caseSensitive: false,
);

final _partialLeadingRemainingPattern = RegExp(
  r'\b(?:remaining|remainder(?:\s+is)?)\s*:?\s*'
  r'(\d+)\s*(?:m|mins?|minutes?)\b',
  caseSensitive: false,
);

final _partialMentionPattern = RegExp(r'\bpartial\b', caseSensitive: false);

final _negationWordPattern = RegExp(
  r'\b(?:not|no|never|(?:isn|wasn|weren|aren|doesn|don|didn|can|couldn|'
  r'won|wouldn|shouldn|hasn|haven|hadn)[\x27’]?t)\b',
  caseSensitive: false,
);

typedef _EstimatedTaskPlacement = ({
  int allocatedMinutes,
  int estimateMinutes,
  bool hasOverlappingBlocks,
  List<String> reasons,
});

/// Estimated scheduled work grouped by task, with all disclosure prose.
///
/// Both capacity accounting and conflict surfacing use this view so a partial
/// cannot be credited by one constraint while its deferred remainder is
/// invisible to the other.
Map<String, _EstimatedTaskPlacement> _estimatedTaskPlacements(
  EvalRunOutcome outcome,
) {
  final allocatedByTask = <String, int>{};
  final blocksByTask = <String, List<PlannedBlock>>{};
  final reasonsByTask = <String, List<String>>{};
  for (final block in _scheduled(outcome)) {
    if (block.type != PlannedBlockType.ai &&
        block.type != PlannedBlockType.manual) {
      continue;
    }
    final taskId = block.taskId;
    if (taskId == null) continue;
    allocatedByTask.update(
      taskId,
      (minutes) =>
          minutes + block.endTime.difference(block.startTime).inMinutes,
      ifAbsent: () => block.endTime.difference(block.startTime).inMinutes,
    );
    blocksByTask.putIfAbsent(taskId, () => []).add(block);
    final reason = block.reason?.trim();
    if (reason != null && reason.isNotEmpty) {
      reasonsByTask.putIfAbsent(taskId, () => []).add(reason);
    }
  }
  return {
    for (final entry in allocatedByTask.entries)
      if (outcome.inputs.taskById(entry.key)?.estimateMinutes
          case final int estimate when estimate > 0)
        entry.key: (
          allocatedMinutes: entry.value,
          estimateMinutes: estimate,
          hasOverlappingBlocks: _hasOverlappingIntervals(
            blocksByTask[entry.key] ?? const [],
          ),
          reasons: reasonsByTask[entry.key] ?? const [],
        ),
  };
}

bool _hasOverlappingIntervals(List<PlannedBlock> blocks) {
  if (blocks.length < 2) return false;
  final ordered = [...blocks]
    ..sort((a, b) => a.startTime.compareTo(b.startTime));
  var latestEnd = ordered.first.endTime;
  for (final block in ordered.skip(1)) {
    if (block.startTime.isBefore(latestEnd)) return true;
    if (block.endTime.isAfter(latestEnd)) latestEnd = block.endTime;
  }
  return false;
}

/// Whether a placement is substantial and its partial arithmetic is auditable.
///
/// The 10% floor matches the token-placement boundary used by
/// [scoreRespectsEstimates]. Keeping it here prevents capacity and conflict
/// scoring from treating a one-minute task marker as genuine partial work.
/// Overlapping blocks are likewise ineligible because summed intervals can
/// manufacture represented minutes without adding wall-clock work.
bool _isAuditedPartial(_EstimatedTaskPlacement placement) =>
    placement.allocatedMinutes > 0 &&
    placement.allocatedMinutes < placement.estimateMinutes &&
    placement.allocatedMinutes * 10 >= placement.estimateMinutes &&
    !placement.hasOverlappingBlocks &&
    _hasAuditablePartialDisclosure(
      reasons: placement.reasons,
      allocatedMinutes: placement.allocatedMinutes,
      estimateMinutes: placement.estimateMinutes,
    );

/// Whether prose makes a shortened placement safe to charge as partial.
///
/// Block duration remains the authority. A reason earns partial accounting
/// only when its concrete minute arithmetic agrees with both that duration and
/// the corpus estimate. This accepts either an explicit `60m of 120m` split or
/// the prompt's `partial` plus `60m remain` form; vague prose and contradictory
/// numbers anywhere in the task's disclosure keep the conservative
/// full-estimate charge.
bool _hasAuditablePartialDisclosure({
  required List<String> reasons,
  required int allocatedMinutes,
  required int estimateMinutes,
}) {
  final remainingMinutes = estimateMinutes - allocatedMinutes;
  var mentionsPartial = false;
  var hasMatchingSplit = false;
  var hasMatchingRemainder = false;
  for (final reason in reasons) {
    for (final match in _partialMentionPattern.allMatches(reason)) {
      if (_matchClauseIsNegated(reason, match)) return false;
      mentionsPartial = true;
    }
    for (final match in _partialOfEstimatePattern.allMatches(reason)) {
      if (_matchClauseIsNegated(reason, match)) return false;
      final declaredAllocated = int.tryParse(match.group(1) ?? '');
      final declaredEstimate = int.tryParse(match.group(2) ?? '');
      if (declaredAllocated != allocatedMinutes ||
          declaredEstimate != estimateMinutes) {
        return false;
      }
      hasMatchingSplit = true;
    }
    for (final match in _partialRemainingPattern.allMatches(reason)) {
      if (_matchClauseIsNegated(reason, match)) return false;
      final declaredRemaining = int.tryParse(match.group(1) ?? '');
      if (declaredRemaining != remainingMinutes) return false;
      hasMatchingRemainder = true;
    }
    for (final match in _partialLeadingRemainingPattern.allMatches(reason)) {
      if (_matchClauseIsNegated(reason, match)) return false;
      final declaredRemaining = int.tryParse(match.group(1) ?? '');
      if (declaredRemaining != remainingMinutes) return false;
      hasMatchingRemainder = true;
    }
  }
  return hasMatchingSplit || (mentionsPartial && hasMatchingRemainder);
}

bool _matchClauseIsNegated(String reason, Match match) {
  const boundaries = '.;!?\n';
  var clauseStart = 0;
  for (var i = match.start - 1; i >= 0; i--) {
    if (boundaries.contains(reason[i])) {
      clauseStart = i + 1;
      break;
    }
  }
  var clauseEnd = reason.length;
  for (var i = match.end; i < reason.length; i++) {
    if (boundaries.contains(reason[i])) {
      clauseEnd = i;
      break;
    }
  }
  return _negationWordPattern.hasMatch(
    reason.substring(clauseStart, clauseEnd),
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
  // The prompt asks for "which commitments collide and what trade would make
  // it fit", so a bare "Deferred" is not surfacing anything — it names no
  // casualty and gives the user nothing to act on. Require the text to
  // identify at least one piece of work that was actually left out or only
  // partially represented.
  final placed = _placedTaskIds(outcome);
  final auditedPartials = {
    for (final entry in _estimatedTaskPlacements(outcome).entries)
      if (_isAuditedPartial(entry.value)) entry.key,
  };
  final deferred = [
    for (final taskId in outcome.inputs.decidedTaskIds)
      if (!placed.contains(taskId) || auditedPartials.contains(taskId)) taskId,
  ];
  if (deferred.isEmpty) {
    return const EvalConstraintResult.notApplicable(
      id,
      'nothing was left out or partially deferred, so there is no trade to name',
    );
  }
  final prose = [
    for (final block in outcome.blocks)
      '${block.reason ?? ''} ${block.note ?? ''}',
  ].join(' ').toLowerCase();
  final namedCasualties = [
    for (final taskId in deferred)
      if (prose.contains(taskId.toLowerCase()) ||
          _titleNamed(outcome, taskId, prose))
        taskId,
  ];
  return EvalConstraintResult(
    id: id,
    passed: namedCasualties.isNotEmpty,
    detail: namedCasualties.isNotEmpty
        ? 'named deferred work: ${namedCasualties.join(', ')}'
        : 'absorbed an impossible day without naming a casualty — '
              '${deferred.length} decided task(s) dropped or partially '
              'deferred in silence',
  );
}

/// The planner must not invent work that was never asked for.
///
/// Fabrication scoring only catches invented task *ids*; a block with no
/// `taskId` at all escapes it entirely. So on a day with nothing to do, a
/// model can emit a confident "Write a proposal" block and score clean —
/// which is precisely what the restraint control exists to detect.
///
/// Only `buffer` is exempt: structuring open time is not inventing work. A
/// `cal` block is not, because the prompt defines `cal` as mirroring a real
/// calendar event and no scenario seeds one — so on these days an invented
/// "Dentist appointment" is exactly the hallucination this control exists to
/// catch. The exemption comes back with calendar-seeding, which needs it for
/// a different reason anyway (a `cal` block is the one remaining way past the
/// production same-day guard).
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
      if (block.taskId == null && block.type != PlannedBlockType.buffer)
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

/// Buffer and calendar blocks must not carry a task.
///
/// The prompt is explicit that `taskId` belongs on work blocks and is omitted
/// for buffer and calendar ones, but the parser does not enforce it. Scoring
/// it separately means a model that attaches tasks to buffers is reported for
/// that specifically, rather than silently losing placement credit and looking
/// like it simply skipped the work.
EvalConstraintResult scoreTaskWorkIsTyped(EvalRunOutcome outcome) {
  const id = EvalConstraintIds.taskWorkIsTyped;
  final noPlan = _requirePlan(outcome, id);
  if (noPlan != null) return noPlan;
  final mistyped = <String>[];
  for (final block in outcome.blocks) {
    if (block.taskId == null) continue;
    if (block.type != PlannedBlockType.buffer &&
        block.type != PlannedBlockType.cal) {
      continue;
    }
    mistyped.add(
      '"${block.title ?? block.id}" is a ${block.type.name} block carrying '
      'task ${block.taskId}',
    );
  }
  if (mistyped.isEmpty && outcome.blocks.every((b) => b.taskId == null)) {
    return const EvalConstraintResult.notApplicable(
      id,
      'no block references a task',
    );
  }
  return EvalConstraintResult(
    id: id,
    passed: mistyped.isEmpty,
    detail: mistyped.isEmpty
        ? 'task work is on work blocks'
        : mistyped.join('; '),
  );
}

/// Whether [call] escalates under the reason the prompt names for an
/// unsatisfiable directive, which needs no further explanation to count.
bool _namesDirectiveReason(EvalToolCall call, Set<String> answering) =>
    switch (call.arguments['reasons']) {
      final List<Object?> list =>
        list.map((r) => '$r').contains('directiveUnsatisfiable'),
      _ => false,
    };

/// Every directive commitment is represented, traded away, or escalated —
/// never silently dropped.
///
/// This is the strongest contract in the prompt. The directive is stated as
/// "BINDING, not a hint", and the three legitimate responses are spelled out:
/// represent the commitment in the plan, trade it away in a proposed diff
/// whose reason names the colliding commitment, or escalate via
/// `raise_day_status` with reason `directiveUnsatisfiable`. Nothing in the
/// write path enforces any of it — the directive is prompt text and the plan
/// writer never reads it back — so a model can drop a commitment the user
/// asked for and the plan persists clean.
///
/// Escalation is directive-level: a model that says the directive cannot be
/// satisfied has answered for every commitment it did not place, which is what
/// the prompt asks of it. Trades are per-commitment and must name their
/// casualty, because "traded something away" without saying what gives the
/// user nothing to act on.
EvalConstraintResult scoreDirectiveHonoured(EvalRunOutcome outcome) {
  const id = EvalConstraintIds.directiveHonoured;
  final directive = outcome.inputs.directive;
  if (directive == null || directive.commitments.isEmpty) {
    return const EvalConstraintResult.notApplicable(
      id,
      'the wake was given no directive',
    );
  }
  // Escalations that reached the user, with the reason enum and the note kept
  // apart. The first live run produced the case that matters: glm-5.2 raised
  // `attentionNeeded` with reason `overCommitted` and a note reading "Cannot
  // fit: interviews (120 min)" — naming the exact casualty. Requiring the
  // enum to be `directiveUnsatisfiable` scored that as SILENTLY DROPPED,
  // which is the one thing it demonstrably was not. Silence is the failure
  // this constraint exists to catch; using a different-but-true reason label
  // is a separate, much weaker observation, so it is reported rather than
  // failed.
  // Reasons that can honestly describe *this* directive failing. The prompt
  // names `directiveUnsatisfiable`; a scenario may declare others that are
  // also true of it (an over-committed directive is genuinely `overCommitted`).
  // An allowlist rather than free text, and rather than any reason at all:
  // `processingBlocked` says the pipeline is stuck and answers for nothing.
  final answeringReasons = {
    'directiveUnsatisfiable',
    ...outcome.inputs.conflictEscalationReasons,
  };
  final escalations = [
    for (final call in outcome.toolCalls)
      if (call.accepted &&
          call.name.contains('raise_day_status') &&
          call.arguments['status'] == 'attentionNeeded' &&
          switch (call.arguments['reasons']) {
            final List<Object?> list =>
              list.map((r) => '$r').any(answeringReasons.contains),
            _ => false,
          } &&
          // Under the prompt's own reason, the call speaks for itself. Under
          // any other, it has to actually say something: a bare
          // `overCommitted` with no note is a day-level remark that never
          // mentions the directive, and crediting it would let a model drop
          // every commitment and still pass. The bar is structural — a note
          // exists or it does not — rather than semantic, because refereeing
          // what a note *means* by substring match is what got this scorer
          // wrong twice already.
          (_namesDirectiveReason(call, answeringReasons) ||
              '${call.arguments['note'] ?? ''}'.trim().isNotEmpty))
        call,
  ];
  final escalatedAsDirective = escalations.any(
    (call) => switch (call.arguments['reasons']) {
      final List<Object?> list =>
        list.map((r) => '$r').contains('directiveUnsatisfiable'),
      _ => false,
    },
  );

  // Prose the model attached to the plan, where a representation names its
  // commitment.
  final planProse = [
    for (final block in _scheduled(outcome))
      '${block.title ?? ''} ${block.reason ?? ''} ${block.note ?? ''}',
  ].join(' ').toLowerCase();
  // Reasons on any proposed diff, which is where the prompt puts a trade.
  final tradeProse = [
    for (final call in outcome.toolCalls)
      if (call.accepted && call.name.contains('propose_plan_diff'))
        switch (call.arguments['changes']) {
          final List<Object?> changes => [
            for (final change in changes)
              if (change is Map) '${change['reason'] ?? ''}',
          ].join(' '),
          _ => '',
        },
  ].join(' ').toLowerCase();

  final dispositions = <String>[];
  final dropped = <String>[];
  for (final commitment in directive.commitments) {
    final title = commitment.title.toLowerCase();
    final identifier = commitment.id.toLowerCase();
    bool named(String prose) =>
        (title.isNotEmpty && prose.contains(title)) ||
        (identifier.isNotEmpty && prose.contains(identifier));
    if (named(planProse)) {
      dispositions.add('${commitment.id}: represented');
    } else if (named(tradeProse)) {
      dispositions.add('${commitment.id}: traded, naming the collision');
    } else if (escalations.isNotEmpty) {
      // Escalation is directive-level in the prompt — option (c) is "escalate
      // via raise_day_status", not "name each commitment in the note" — so
      // raising `attentionNeeded` answers for everything left unplaced.
      //
      // Two live runs pushed this here. Requiring the reason enum to be
      // `directiveUnsatisfiable` reported a model that escalated as SILENTLY
      // DROPPED; requiring the note to contain each commitment's *title* did
      // the same to "Interviews and 1:1s cannot fit — user must defer one or
      // both", which names both casualties in the words a person would use.
      // Substring matching cannot referee that, and a false "silently
      // dropped" is worse than a coarse pass: it accuses the model of the one
      // thing it visibly did not do.
      //
      // The counterweight is above, in what qualifies as an escalation at
      // all: under a reason other than the prompt's, the call must carry a
      // note. Delegating that to `surfacedConflict` would have been delegating
      // to a scorer this scenario never runs — it leaves
      // `requiresConflictSurfaced` false.
      dispositions.add(
        escalatedAsDirective
            ? '${commitment.id}: escalated'
            : '${commitment.id}: escalated, though not under the '
                  'directiveUnsatisfiable reason the prompt specifies',
      );
    } else {
      dispositions.add('${commitment.id}: SILENTLY DROPPED');
      dropped.add(commitment.id);
    }
  }
  return EvalConstraintResult(
    id: id,
    passed: dropped.isEmpty,
    detail: dropped.isEmpty
        ? 'every commitment answered for — ${dispositions.join('; ')}'
        : 'dropped without a word: ${dropped.join(', ')} '
              '(${dispositions.join('; ')})',
  );
}

/// A `cal` block claims an imported calendar event, and the day agent has
/// none to import.
///
/// `PlannedBlockType.cal` means "imported calendar event", and the plan editor
/// treats such a block as owned elsewhere — it refuses in-app edits with
/// "block is cal-owned — edit it in the source calendar". So a model-emitted
/// `cal` block leaves the user with a block they cannot edit here and cannot
/// find in their calendar either.
///
/// It can never be legitimate today: the day agent is shown **no calendar
/// events at all**. `DayAgentInterface.draftDayPlan` documents its
/// `calendarBlocks` parameter as deferred, `RealDayAgent` drops the argument
/// on the floor, and no context section renders events into the prompt. The
/// drafting rules nonetheless tell the model that "only `cal` blocks mirroring
/// real calendar events may span" the current time — an exemption whose
/// precondition cannot hold.
///
/// That matters most on a same-day draft, where the exemption is the one
/// remaining hole in the past-start guard (`day_agent_plan_parser.dart`
/// exempts `cal` alone, after a model was observed relabelling a past-starting
/// block `buffer` to slip an earlier version). Such a block *is* already
/// caught by [scoreWithinWorkingHours] — it starts before the draft's own
/// clock — but reported there as a working-hours violation, which is a
/// different failure with a different fix. Scoring it here names what actually
/// happened.
///
/// When calendar integration lands, this needs the seeded events to compare
/// against; until then "unbacked" is not an assumption but the only
/// possibility.
EvalConstraintResult scoreNoFabricatedCalendarBlocks(EvalRunOutcome outcome) {
  const id = EvalConstraintIds.noFabricatedCalendarBlocks;
  final noPlan = _requirePlan(outcome, id);
  if (noPlan != null) return noPlan;
  // Every block, not just the scheduled ones. A dropped `cal` block is still
  // persisted, still projected by `_projectDayPlan` (only the capacity meter
  // filters dropped), still drawn by the timeline, and still refused by the
  // plan editor — so the user sees an uneditable phantom calendar event either
  // way. Dropping is the model declining *work*; it does not retract the
  // claim that an external event exists.
  final calendarBlocks = [
    for (final block in outcome.blocks)
      if (block.type == PlannedBlockType.cal) block,
  ];
  if (calendarBlocks.isEmpty) {
    // A plan with real blocks and no calendar claim is a *pass*, not an
    // absence of evidence: the prompt explicitly offers `cal` as the way to
    // place work before the current time, so declining it is the behaviour
    // being measured. Only a plan with no blocks at all says nothing.
    return outcome.blocks.isEmpty
        ? const EvalConstraintResult.notApplicable(id, 'the plan has no blocks')
        : EvalConstraintResult(
            id: id,
            passed: true,
            detail:
                '${outcome.blocks.length} block(s), none claiming to be a '
                'calendar event',
          );
  }
  final now = outcome.inputs.now;
  final described = [
    for (final block in calendarBlocks) _describeCalendarClaim(block, now),
  ];
  return EvalConstraintResult(
    id: id,
    passed: false,
    detail:
        '${calendarBlocks.length} calendar block(s) with no calendar to '
        'mirror: ${described.join('; ')}',
  );
}

/// Describes one fabricated calendar claim, naming the *actual* reason it
/// evaded the same-day guard.
///
/// The guard fires only for `state == drafted` and exempts `cal`, so a drafted
/// past-starting calendar block slipped through on its type, while a
/// `committed`/`completed`/`inProgress` one would have slipped through as `ai`
/// or `manual` just as well. Blaming the calendar type in that second case
/// would point a reader at the wrong fix.
String _describeCalendarClaim(PlannedBlock block, DateTime? now) {
  final name = '"${block.title ?? block.id}"';
  final start = _hhmm(block.startTime);
  if (now == null || !block.startTime.isBefore(now)) return '$name at $start';
  if (block.state == PlannedBlockState.drafted) {
    return '$name starts $start, before the ${_hhmm(now)} draft — the '
        'past-start guard exempts `cal`, so this is how a model plans the past';
  }
  return '$name starts $start, before the ${_hhmm(now)} draft, in state '
      '${block.state.name} — the past-start guard only covers drafted blocks, '
      'so the state bypassed it here, not the type';
}

/// Whether the model produced a legal plan without being corrected.
///
/// This is the guarded half. The persisted plan is always legal — the write
/// path rejected anything that was not — so the only observable difference
/// between a model that got it right and one that needed four attempts is the
/// rejections it collected on the way.
EvalConstraintResult scoreCompliedWithoutRejection(EvalRunOutcome outcome) {
  const id = EvalConstraintIds.compliedWithoutRejection;
  final attemptedDraft = outcome.toolCalls.any(
    (call) => call.name == DayAgentToolNames.draftDayPlan,
  );
  if (!attemptedDraft) {
    // A run that never reached for the required tool cannot have complied with
    // anything. Without this the empty rejection list reads as "accepted on
    // the first attempt", so a model that was never reached, answered in
    // prose, or called only `raise_day_status` and stopped, collects a
    // compliance *pass* it did nothing to earn — and aggregate scores reward
    // failing loudest. Failing to call the tool is a real failure, but it is
    // the wake's, and it shows up in the job status.
    return const EvalConstraintResult.notApplicable(
      id,
      'the model never attempted draft_day_plan',
    );
  }
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
  for (final block in _scheduled(outcome))
    // Only work blocks carry a placement. The prompt tells the model to omit
    // `taskId` on buffer and calendar blocks, but nothing enforces it — so
    // without this a model could label a plausible-length buffer with every
    // required task id and satisfy placement, capacity and estimate scoring
    // without scheduling any actual work.
    if (block.type == PlannedBlockType.ai ||
        block.type == PlannedBlockType.manual)
      ?block.taskId,
};

/// Whether [prose] mentions the title of [taskId].
bool _titleNamed(EvalRunOutcome outcome, String taskId, String prose) {
  final title = outcome.inputs.taskById(taskId)?.title.toLowerCase();
  return title != null && title.isNotEmpty && prose.contains(title);
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
