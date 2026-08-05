part of 'eval_constraints.dart';

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
  final title = outcome.inputs.taskById(taskId)?.title.trim();
  if (title == null || title.isEmpty) return false;
  if (RegExp(
    r'\btask\s+' + RegExp.escape(title) + r'\b',
    caseSensitive: false,
  ).hasMatch(prose)) {
    return true;
  }
  return _allowsBareTaskTitle(title) &&
      RegExp(
        r'(?:^|[^\w-])' + RegExp.escape(title) + r'(?=$|[^\w-])',
        caseSensitive: false,
      ).hasMatch(prose);
}

bool _taskIdNamed(String taskId, String prose) => RegExp(
  r'(?:^|[^\w-])' + RegExp.escape(taskId) + r'(?=$|[^\w-])',
  caseSensitive: false,
).hasMatch(prose);

/// Blocks that consume capacity — `dropped` ones are recorded but not
/// scheduled, matching `scheduledMinutesFor` in the parser.
List<PlannedBlock> _scheduled(EvalRunOutcome outcome) => [
  for (final block in outcome.blocks)
    if (block.state != PlannedBlockState.dropped) block,
];

String _hhmm(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';
