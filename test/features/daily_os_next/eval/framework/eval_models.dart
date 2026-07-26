import 'package:lotti/classes/day_plan.dart';
import 'package:meta/meta.dart';

/// Value types the day-planning eval scores over.
///
/// Deliberately small and provider-free: the scorers in
/// `eval_constraints.dart` are pure functions over these, so they can be
/// unit-tested against hand-built plans in ordinary CI without a model, a
/// database, or the pipeline.

/// One task as the model saw it in the corpus.
///
/// Mirrors the corpus row shape from `DayAgentCorpusService` closely enough to
/// score against, including the ADR 0043 `blockedBy` annotation.
@immutable
class EvalCorpusTask {
  const EvalCorpusTask({
    required this.taskId,
    required this.title,
    this.status = 'OPEN',
    this.blockedBy = const [],
    this.estimateMinutes,
    this.categoryId,
  });

  final String taskId;
  final String title;

  /// Corpus status string, e.g. `OPEN`, `IN PROGRESS`, `BLOCKED`.
  final String status;

  /// Task ids blocking this one (ADR 0043).
  final List<String> blockedBy;

  final int? estimateMinutes;
  final String? categoryId;

  /// ADR 0043's predicate, stated once.
  ///
  /// A union, not a choice: a manually blocked task shows `status: BLOCKED`
  /// with no links, so absence of [blockedBy] means link-ready, not free to
  /// schedule.
  bool get isBlocked =>
      status.toUpperCase() == 'BLOCKED' || blockedBy.isNotEmpty;
}

/// One commitment the coordinator handed down for a day.
///
/// Directive commitments are not tasks: they carry their own ids and titles
/// and never appear in the task corpus, so a scorer has to match them by what
/// the plan says rather than by `taskId`.
@immutable
class EvalDirectiveCommitment {
  const EvalDirectiveCommitment({
    required this.id,
    required this.title,
    required this.minutes,
  });

  final String id;
  final String title;
  final int minutes;
}

/// The `<day_directive>` a scenario seeds.
///
/// The prompt calls this BINDING, not a hint, and names exactly three
/// legitimate responses to a commitment: represent it in the plan, trade it
/// away in a diff whose reason names the colliding commitment, or escalate via
/// `raise_day_status` with reason `directiveUnsatisfiable`. Silently dropping
/// one is the failure.
@immutable
class EvalDirective {
  const EvalDirective({
    required this.commitments,
    required this.availableMinutes,
    this.alreadyScheduledMinutes = 0,
    this.attentionNotes = const [],
  });

  final List<EvalDirectiveCommitment> commitments;

  /// `capacityBudget.availableMinutes` as the coordinator stated it.
  final int availableMinutes;
  final int alreadyScheduledMinutes;
  final List<String> attentionNotes;

  int get requestedMinutes =>
      commitments.fold<int>(0, (sum, c) => sum + c.minutes);

  /// What the prompt asks the model to reconcile against before drafting.
  int get remainingMinutes => availableMinutes - alreadyScheduledMinutes;

  /// Whether the directive can be honoured in full as stated.
  bool get fits => requestedMinutes <= remainingMinutes;
}

/// The inputs a scenario handed the model, kept alongside the result so a
/// scorer never has to re-derive what the model was asked to do.
@immutable
class EvalFixtureInputs {
  const EvalFixtureInputs({
    required this.dayId,
    required this.planDate,
    this.corpus = const [],
    this.decidedTaskIds = const [],
    this.permittedOmissions = const {},
    this.expectedOmissions = const {},
    this.visibleTaskIds,
    this.requiredTaskIds = const {},
    this.requiresConflictSurfaced = false,
    this.forbidsInventedWork = false,
    this.conflictEscalationReasons = const {},
    this.capacityMinutes = 480,
    this.workingHoursStartHour = 9,
    this.workingHoursEndHour = 17,
    this.directive,
    this.now,
  });

  final String dayId;
  final DateTime planDate;
  final List<EvalCorpusTask> corpus;

  /// Tasks the user explicitly approved for placement.
  final List<String> decidedTaskIds;

  /// Decided tasks the model *may* leave out without it counting against it.
  ///
  /// Distinct from [expectedOmissions]: a blocked task may legitimately be
  /// placed behind its blocker, so omitting it is acceptable but not required.
  /// Requiring it would fail a model that correctly declined; forbidding it
  /// would fail a model that correctly sequenced.
  final Set<String> permittedOmissions;

  /// Decided tasks the model is expected to leave out, where placing them is
  /// itself the failure.
  ///
  /// The stale-task case: the capture says the work is already done, and the
  /// prompt tells the model not to force the placement. Merely dropping these
  /// from the positive requirement would let a model place them and still
  /// score clean, so the scenario could not measure the behaviour it exists
  /// for.
  final Set<String> expectedOmissions;

  /// Task ids the model could actually reference.
  ///
  /// Not the same as [corpus]: the task corpus is rendered only inside the
  /// capture context, so a wake without a capture sees nothing but its decided
  /// tasks. [corpus] stays ground truth — it is what makes a scenario's
  /// blocked work knowable to the *scorer* — while this is what the model was
  /// shown. Null means everything in [corpus] was visible.
  final Set<String>? visibleTaskIds;

  /// Tasks the scenario expects to appear in any competent plan.
  ///
  /// Distinct from [decidedTaskIds], which is an *input* the user approved.
  /// These are the scenario's own expectations — the overdue invoice a
  /// crowded day must not ignore — and without them a scenario about
  /// prioritisation cannot tell a good plan from one that scheduled the least
  /// urgent thing on the list.
  final Set<String> requiredTaskIds;

  /// Whether the scenario is impossible as stated, so a competent plan has to
  /// say so rather than quietly absorb it.
  final bool requiresConflictSurfaced;

  /// Whether the scenario has no real work, so any substantive block the
  /// planner adds is invented rather than scheduled.
  final bool forbidsInventedWork;

  /// `raise_day_status` reasons that count as escalating *this* conflict.
  ///
  /// Scenario-specific on purpose. A shared default accepting both
  /// `overCommitted` and `directiveUnsatisfiable` would let a model escalate
  /// an over-committed day — which seeds no directive — by claiming its
  /// directive was unsatisfiable, and be credited for a reason that cannot be
  /// true. The tool's `userDivergence` and `processingBlocked` describe
  /// different problems again.
  final Set<String> conflictEscalationReasons;

  final int capacityMinutes;

  /// Local hour the working day starts, mirroring `DayAgentConfig`'s 09:00.
  ///
  /// Enforced as well as the end: on a future-day draft the same-day guard is
  /// deliberately inert, so without a lower bound a plan could run overnight
  /// and still score clean.
  final int workingHoursStartHour;

  /// Local hour the working day ends, mirroring the planner's own default
  /// (`DayAgentConfig.workingHoursEnd`, 17:00).
  ///
  /// Carried here because capacity alone cannot catch a model that pushes work
  /// past the end of the day: a 180-minute block from 15:00 consumes only 180
  /// of 480 minutes and stays inside the calendar day, so every other
  /// constraint is satisfied while the plan is unusable.
  final int workingHoursEndHour;

  /// The binding directive the wake was given, if any.
  final EvalDirective? directive;

  /// Wall instant the draft ran at, for same-day scenarios. Null for a
  /// future-day draft, where "the past" has no meaning.
  final DateTime? now;

  /// Ids the model could legitimately have used.
  ///
  /// On a capture-less wake the decided tasks are not the whole story: each
  /// carries its one-hop `blockedBy`, which names the blocker's `taskId`, and
  /// the blocked-work rule explicitly tells the model to schedule that blocker
  /// first. Omitting those ids would make `noFabricatedTaskIds` fail a model
  /// for doing exactly what the prompt asked — and the judge bundle would mark
  /// an id the model was shown as unreferenceable.
  Set<String> get referenceableTaskIds => visibleTaskIds == null
      ? {for (final task in corpus) task.taskId, ...decidedTaskIds}
      : {...visibleTaskIds!, ..._blockersOfVisibleTasks};

  /// Blocker ids reachable through a visible task's `blockedBy` projection.
  ///
  /// One hop only, matching ADR 0043: a blocker's own blockers are never
  /// rendered, so naming one of those really would be fabrication.
  Set<String> get _blockersOfVisibleTasks => {
    for (final id in visibleTaskIds ?? const <String>{})
      for (final blocker in taskById(id)?.blockedBy ?? const <String>[])
        blocker,
  };

  /// Whether [taskId] was rendered as some visible task's blocker.
  ///
  /// Such a task shows its *status* — `ResolvedBlocker` carries it — but never
  /// its own `blockedBy`, because ADR 0043 resolves one hop. That asymmetry is
  /// why the judge bundle reports status and dependency visibility apart.
  bool isBlockerOfVisibleTask(String taskId) =>
      visibleTaskIds != null && _blockersOfVisibleTasks.contains(taskId);

  /// Whether the model was shown what [taskId] is waiting on.
  ///
  /// True through a rendered corpus row or a `DecidedTaskRef`. **Not** true for
  /// a task reached only as somebody else's blocker: one-hop resolution never
  /// renders that task's own `blockedBy`.
  ///
  /// Load-bearing for scoring, not just reporting. `blockerBeforeBlocked`
  /// offers two ways to place blocked work — schedule its blocker earlier, or
  /// name that blocker in the reason — and **both require knowing the blocker's
  /// id**. Judging a task whose blockers were never rendered asks for something
  /// no plan could supply, and rewards a model that placed nothing over one
  /// that engaged. Shared with the judge bundle so the two can never disagree
  /// about what the model saw.
  bool blockersShownFor(String taskId) =>
      visibleTaskIds == null || decidedTaskIds.contains(taskId);

  /// Whether the model was shown [taskId]'s own status.
  ///
  /// Weaker than [blockersShownFor]: a task rendered as another task's blocker
  /// carries its status but not its dependencies.
  bool statusShownFor(String taskId) =>
      blockersShownFor(taskId) || isBlockerOfVisibleTask(taskId);

  EvalCorpusTask? taskById(String id) {
    for (final task in corpus) {
      if (task.taskId == id) return task;
    }
    return null;
  }
}

/// One tool call the model made, in order, including rejected ones.
///
/// Rejections are first-class: the write path throws on a violated hard
/// constraint and hands the message back to the model, which then retries. A
/// plan that only became legal on the fourth attempt is indistinguishable from
/// a first-time-right plan if you look at the persisted result alone, so the
/// rejection text is where guarded constraints are actually scored.
@immutable
class EvalToolCall {
  const EvalToolCall({
    required this.name,
    required this.accepted,
    this.rejectionMessage,
    this.arguments = const {},
  });

  final String name;
  final bool accepted;

  /// The failure text the model received. Null when [accepted].
  final String? rejectionMessage;

  final Map<String, Object?> arguments;
}

/// Everything one run produced, as the scorers see it.
@immutable
class EvalRunOutcome {
  const EvalRunOutcome({
    required this.inputs,
    this.blocks = const [],
    this.toolCalls = const [],
    this.planPersisted = true,
    this.createdTaskIds = const {},
  });

  final EvalFixtureInputs inputs;

  /// Blocks on the persisted plan, in whatever order they were stored.
  final List<PlannedBlock> blocks;

  final List<EvalToolCall> toolCalls;

  /// False when the run ended without a plan at all — every constraint that
  /// reads the plan is then inapplicable rather than failed.
  final bool planPersisted;

  /// Task ids that came into existence *during* the run.
  ///
  /// A drafting wake can call `create_task_from_phrase`, and the model may
  /// then schedule what it just created. Those ids cannot be in
  /// [EvalFixtureInputs.referenceableTaskIds], which is fixed before the run,
  /// so without them a legitimately created-and-placed task reads as a
  /// fabricated id.
  final Set<String> createdTaskIds;

  /// Every task id the model could legitimately reference — what it was shown,
  /// plus what it created along the way.
  Set<String> get knownTaskIds => {
    ...inputs.referenceableTaskIds,
    ...createdTaskIds,
  };

  Iterable<EvalToolCall> get rejections =>
      toolCalls.where((call) => !call.accepted);
}

/// Outcome of one constraint against one run.
///
/// [passed] is nullable because "not applicable" is a distinct answer from
/// "failed": a scenario with no blocked tasks says nothing about whether the
/// model respects blockers, and averaging that in as a pass would flatter it.
@immutable
class EvalConstraintResult {
  const EvalConstraintResult({
    required this.id,
    required this.passed,
    required this.detail,
  });

  const EvalConstraintResult.notApplicable(this.id, this.detail)
    : passed = null;

  final String id;
  final bool? passed;

  /// Human-readable, and specific enough to act on — names the offending
  /// block or task rather than restating the rule.
  final String detail;

  bool get isApplicable => passed != null;
}
