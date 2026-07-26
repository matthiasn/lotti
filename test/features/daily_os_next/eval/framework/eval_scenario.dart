import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_config.dart';
import 'package:lotti/features/tasks/repository/task_dependency_resolver.dart';
import 'package:meta/meta.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import 'eval_journal_fixture.dart';
import 'eval_models.dart';

/// Declarative day-planning scenarios.
///
/// The point of a scenario is *tension* — a day the planner has to resolve
/// rather than transcribe. A fixture with nothing in it measures only that the
/// pipeline runs: the first live run against glm-5.2 produced a single generic
/// buffer block, which was the right answer to an empty corpus and told us
/// nothing about planning. Every scenario below therefore gives the model
/// something it must actually choose between.
///
/// Fixtures seed through the `journalDb` stubs the pipeline harness already
/// installs, plus a fixture-backed [TaskDependencyResolver] for the ADR 0043
/// cases.

/// A task as the scenario seeds it, in the shape the corpus builder reads.
@immutable
class EvalTaskSpec {
  const EvalTaskSpec({
    required this.id,
    required this.title,
    this.estimateMinutes,
    this.dueOffsetDays,
    this.categoryId = evalDefaultCategoryId,
    this.status = EvalTaskStatus.open,
    this.blockedBy = const [],
  });

  final String id;
  final String title;
  final int? estimateMinutes;

  /// Days relative to the plan date; negative is overdue. Null means no due
  /// date, which is the common case for open work.
  final int? dueOffsetDays;

  final String categoryId;
  final EvalTaskStatus status;

  /// Task ids blocking this one (ADR 0043).
  final List<String> blockedBy;
}

enum EvalTaskStatus { open, inProgress, blocked }

const String evalDefaultCategoryId = 'cat-work';

/// One day the planner is asked to handle.
@immutable
class EvalScenario {
  const EvalScenario({
    required this.id,
    required this.intent,
    required this.tasks,
    this.decidedTaskIds = const [],
    this.permittedOmissions = const {},
    this.expectedOmissions = const {},
    this.requiredTaskIds = const {},
    this.requiresConflictSurfaced = false,
    this.forbidsInventedWork = false,
    this.conflictEscalationReasons = const {},
    this.capacityMinutes = 480,
    this.startHour,
    this.includeCapture = true,
    this.captureTranscript,
    this.directive,
  });

  final String id;

  /// What this scenario is trying to find out. Read this before the data.
  final String intent;

  final List<EvalTaskSpec> tasks;
  final List<String> decidedTaskIds;

  /// Decided tasks the planner *may* leave out without penalty.
  ///
  /// A blocked task belongs here rather than in [expectedOmissions]: placing
  /// it behind its blocker is equally correct, so neither requiring nor
  /// forbidding it would be right.
  final Set<String> permittedOmissions;

  /// Decided tasks the planner is expected to leave out, where placing them is
  /// the failure being measured.
  final Set<String> expectedOmissions;

  /// Work any competent plan for this day must include, independent of what
  /// the user decided. Without it a prioritisation scenario cannot tell a
  /// good plan from one that scheduled the least urgent thing available.
  final Set<String> requiredTaskIds;

  /// Whether this day is impossible as stated, so the planner must say so
  /// rather than quietly absorbing it.
  final bool requiresConflictSurfaced;

  /// Whether this day has no real work, so anything substantive the planner
  /// adds was invented rather than scheduled.
  final bool forbidsInventedWork;

  /// `raise_day_status` reasons that would genuinely describe *this* day's
  /// conflict. Scenario-specific: a day with no directive cannot honestly be
  /// escalated as `directiveUnsatisfiable`.
  final Set<String> conflictEscalationReasons;

  final int capacityMinutes;

  /// Local hour the draft runs at, for same-day scenarios. Null drafts a
  /// future day, where "the past" has no meaning and the guard is inert.
  final int? startHour;

  /// Whether a capture accompanies the wake.
  ///
  /// Load-bearing, not cosmetic: `buildTaskCorpusSnapshot` is only called from
  /// the capture context, so a wake without one receives **no task corpus at
  /// all** — and therefore no `blockedBy` — while still being told ADR 0043's
  /// blocked-work rule.
  final bool includeCapture;

  final String? captureTranscript;

  /// A binding `<day_directive>` the coordinator issued for this day.
  ///
  /// Seeded as a real `DayDirectiveEntity`, so the wake reads it through the
  /// production path and renders the real prompt section.
  final EvalDirective? directive;

  /// Blocker map for the fixture-backed resolver.
  Map<String, List<ResolvedBlocker>> get blockedStatus {
    final byId = {for (final task in tasks) task.id: task};
    return {
      for (final task in tasks)
        if (task.blockedBy.isNotEmpty)
          task.id: [
            for (final blockerId in task.blockedBy)
              ResolvedBlocker(
                taskId: blockerId,
                title: byId[blockerId]?.title,
                status: byId[blockerId] == null
                    ? null
                    : _statusString(byId[blockerId]!.status),
                // Production carries the blocker's own category, because
                // `draft_day_plan` requires a categoryId on every block and
                // the nested blocker is the model's only description of it on
                // a capture-less wake. Omitting it here would send the model a
                // materially different prompt than the app does, and force it
                // to guess a value the app would have supplied — inflating
                // rejected tool calls and corrupting the comparison.
                categoryId: byId[blockerId]?.categoryId,
              ),
          ],
    };
  }

  /// The planning contract this scenario asks for, before any variant.
  DayAgentConfig get baseConfig =>
      DayAgentConfig(capacityMinutes: capacityMinutes);

  /// The scorers' view of what the model was given.
  ///
  /// [config] is the contract actually rendered into the system prompt, so the
  /// capacity and working hours the scorers grade against are the ones the
  /// model was told — otherwise a variant that changes the contract would be
  /// scored against the default one. Defaults to [baseConfig].
  EvalFixtureInputs inputsFor(
    DateTime planDate, {
    DayAgentConfig? config,
  }) {
    final effective = config ?? baseConfig;
    return EvalFixtureInputs(
      dayId: 'dayplan-${planDate.toIso8601String().substring(0, 10)}',
      planDate: planDate,
      corpus: [
        for (final task in tasks)
          EvalCorpusTask(
            taskId: task.id,
            title: task.title,
            status: _statusString(task.status),
            blockedBy: task.blockedBy,
            estimateMinutes: task.estimateMinutes,
            categoryId: task.categoryId,
          ),
      ],
      decidedTaskIds: decidedTaskIds,
      // Expected omissions are permitted by construction — a task that must not
      // be placed is obviously not required to be.
      permittedOmissions: {...permittedOmissions, ...expectedOmissions},
      expectedOmissions: expectedOmissions,
      requiredTaskIds: requiredTaskIds,
      requiresConflictSurfaced: requiresConflictSurfaced,
      forbidsInventedWork: forbidsInventedWork,
      conflictEscalationReasons: conflictEscalationReasons,
      // Without a capture the task corpus is never rendered, so the only ids
      // the model can name are its decided ones. The corpus above stays as
      // ground truth for constraints that need to know what is actually true.
      visibleTaskIds: includeCapture ? null : {...decidedTaskIds},
      directive: directive,
      capacityMinutes: effective.capacityMinutes,
      workingHoursStartHour: evalWholeHourOf(
        effective.workingHoursStart,
        field: 'workingHoursStart',
      ),
      workingHoursEndHour: evalWholeHourOf(
        effective.workingHoursEnd,
        field: 'workingHoursEnd',
      ),
      now: startHour == null
          ? null
          : DateTime(planDate.year, planDate.month, planDate.day, startHour!),
    );
  }

  /// Journal [Task] rows for the corpus reads.
  List<Task> tasksFor(DateTime planDate) => [
    for (final spec in tasks) _taskFrom(spec, planDate),
  ];

  List<Task> overdueOrDueTodayFor(DateTime planDate) => [
    for (final spec in tasks)
      if (spec.dueOffsetDays != null && spec.dueOffsetDays! <= 0)
        _taskFrom(spec, planDate),
  ];

  List<Task> inProgressFor(DateTime planDate) => [
    for (final spec in tasks)
      if (spec.status == EvalTaskStatus.inProgress) _taskFrom(spec, planDate),
  ];

  static String _statusString(EvalTaskStatus status) => switch (status) {
    EvalTaskStatus.open => 'OPEN',
    EvalTaskStatus.inProgress => 'IN PROGRESS',
    EvalTaskStatus.blocked => 'BLOCKED',
  };

  static Task _taskFrom(EvalTaskSpec spec, DateTime planDate) {
    final createdAt = planDate.subtract(const Duration(days: 7));
    final due = spec.dueOffsetDays == null
        ? null
        : DateTime(
            planDate.year,
            planDate.month,
            planDate.day + spec.dueOffsetDays!,
            17,
          );
    return Task(
      meta: Metadata(
        id: spec.id,
        createdAt: createdAt,
        updatedAt: createdAt,
        dateFrom: createdAt,
        dateTo: createdAt,
        categoryId: spec.categoryId,
      ),
      data: TaskData(
        status: switch (spec.status) {
          EvalTaskStatus.inProgress => TaskStatus.inProgress(
            id: '${spec.id}-status',
            createdAt: createdAt,
            utcOffset: 0,
          ),
          EvalTaskStatus.blocked => TaskStatus.blocked(
            id: '${spec.id}-status',
            createdAt: createdAt,
            utcOffset: 0,
            reason: 'waiting on a dependency',
          ),
          EvalTaskStatus.open => TaskStatus.open(
            id: '${spec.id}-status',
            createdAt: createdAt,
            utcOffset: 0,
          ),
        },
        dateFrom: createdAt,
        dateTo: createdAt,
        statusHistory: const [],
        title: spec.title,
        due: due,
        estimate: spec.estimateMinutes == null
            ? null
            : Duration(minutes: spec.estimateMinutes!),
      ),
      entryText: EntryText(plainText: spec.title),
    );
  }
}

/// Parses `HH:mm` down to a whole hour, rejecting anything else.
///
/// [EvalFixtureInputs] carries working hours as integers, so a config of
/// `09:30` would silently be graded as `09:00` — a scorer half an hour more
/// lenient than the contract the model was handed. Rather than ship that
/// leniency invisibly, a non-whole hour is a configuration error.
int evalWholeHourOf(String value, {required String field}) {
  final parts = value.split(':');
  final hour = parts.length == 2 ? int.tryParse(parts.first) : null;
  final minute = parts.length == 2 ? int.tryParse(parts.last) : null;
  if (hour == null || minute == null || hour < 0 || hour > 23) {
    throw ArgumentError.value(value, field, 'expected HH:mm');
  }
  if (minute != 0) {
    throw ArgumentError.value(
      value,
      field,
      'the eval grades working hours as whole hours; use HH:00',
    );
  }
  return hour;
}

/// A [TaskDependencyResolver] that answers from a fixture instead of the
/// journal, so blocked-work scenarios do not need real typed links.
class EvalFixtureDependencyResolver implements TaskDependencyResolver {
  EvalFixtureDependencyResolver(this.blockedStatus);

  final Map<String, List<ResolvedBlocker>> blockedStatus;

  @override
  Future<Map<String, List<ResolvedBlocker>>> resolveBlockedStatus(
    Set<String> taskIds, {
    Set<String> allowedCategoryIds = const {},
  }) async => {
    for (final entry in blockedStatus.entries)
      if (taskIds.contains(entry.key))
        entry.key: [
          for (final blocker in entry.value)
            // Mirrors production's `categoryAllowed`: an empty allow-set is
            // unrestricted, and a blocker outside the set still blocks but
            // describes nothing about itself. Scenarios stay in-scope today,
            // so this guards a future cross-category scenario from being
            // measured against a prompt the app would never have sent.
            if (allowedCategoryIds.isEmpty ||
                allowedCategoryIds.contains(blocker.categoryId))
              blocker
            else
              ResolvedBlocker(taskId: blocker.taskId),
        ],
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The scenario set.
///
/// Ordered roughly by how much tension they put on the planner.
const List<EvalScenario> evalScenarios = [
  _restraint,
  _crowdedDay,
  _lateStart,
  _overCommitted,
  _blockedChain,
  _blockedWithoutCorpus,
  _staleDecidedTask,
  _bindingDirective,
];

/// Does it invent work when there is none to do?
///
/// Kept from the original scenario list but reframed: an empty day tests
/// restraint, not planning. A model that fabricates tasks here is worse than
/// one that produces a single buffer block.
const _restraint = EvalScenario(
  id: 'restraint',
  intent:
      'With nothing to schedule, does the planner stay quiet rather than '
      'inventing work?',
  tasks: [],
  // The whole point of the control. Without it a confident "Write a proposal"
  // block scores identically to staying quiet: it has no taskId, so
  // fabrication scoring is inapplicable, and every other constraint passes.
  forbidsInventedWork: true,
  captureTranscript: 'Nothing much on today.',
);

/// The bread-and-butter day: more candidates than time, mixed shapes.
const _crowdedDay = EvalScenario(
  id: 'crowdedDay',
  intent:
      'Given more work than fits, does it prioritise overdue and '
      'in-progress work, batch the small items, and stay inside capacity?',
  // Named explicitly, because generic constraints are all satisfied by a plan
  // containing one well-formed block — a model could schedule only the
  // onboarding guide due in two weeks and score clean.
  requiredTaskIds: {
    'task-overdue-invoice',
    'task-due-today-review',
    'task-inprogress-migration',
  },
  tasks: [
    EvalTaskSpec(
      id: 'task-overdue-invoice',
      title: 'Send the overdue client invoice',
      estimateMinutes: 30,
      dueOffsetDays: -3,
    ),
    EvalTaskSpec(
      id: 'task-due-today-review',
      title: 'Review the security questionnaire',
      estimateMinutes: 90,
      dueOffsetDays: 0,
    ),
    EvalTaskSpec(
      id: 'task-inprogress-migration',
      title: 'Finish the database migration',
      estimateMinutes: 180,
      status: EvalTaskStatus.inProgress,
    ),
    EvalTaskSpec(
      id: 'task-deep-architecture',
      title: 'Draft the sync architecture proposal',
      estimateMinutes: 150,
    ),
    // The three small items are here as batching material for the qualitative
    // read, not as scored expectations: requiring them would push the day past
    // capacity (the corpus totals 635 minutes against 480), and any adjacency
    // rule I could write would encode a preference I cannot justify.
    EvalTaskSpec(
      id: 'task-small-expenses',
      title: 'File expenses',
      estimateMinutes: 20,
    ),
    EvalTaskSpec(
      id: 'task-small-replies',
      title: 'Reply to the three outstanding emails',
      estimateMinutes: 25,
    ),
    EvalTaskSpec(
      id: 'task-small-booking',
      title: 'Book the conference travel',
      estimateMinutes: 20,
    ),
    EvalTaskSpec(
      id: 'task-later-onboarding',
      title: 'Write the onboarding guide',
      estimateMinutes: 120,
      dueOffsetDays: 14,
    ),
  ],
  captureTranscript:
      'Busy one today. The invoice is late and the migration is half done.',
);

/// Half the day is already gone.
const _lateStart = EvalScenario(
  id: 'lateStart',
  intent:
      'Drafted mid-afternoon with a 3-hour task on the list: does it '
      'defer what cannot fit, or cram it in past the end of the day?',
  tasks: [
    EvalTaskSpec(
      id: 'task-long-migration',
      title: 'Finish the database migration',
      estimateMinutes: 180,
      status: EvalTaskStatus.inProgress,
    ),
    EvalTaskSpec(
      id: 'task-short-invoice',
      title: 'Send the overdue client invoice',
      estimateMinutes: 30,
      dueOffsetDays: -1,
    ),
    EvalTaskSpec(
      id: 'task-short-replies',
      title: 'Reply to the outstanding emails',
      estimateMinutes: 25,
    ),
  ],
  // Without these a single 15:00-16:00 buffer passed everything: no decided
  // tasks, no required work, no conflict to surface, and the buffer satisfies
  // capacity and working hours. Silently ignoring all three seeded tasks read
  // as clean. The two short items fit comfortably in what remains (55 of ~120
  // minutes), so requiring them makes the real question measurable — defer the
  // migration and do the urgent short work, or cram it and fail working hours.
  requiredTaskIds: {'task-short-invoice', 'task-short-replies'},
  // 235 minutes of work against under two hours of clock, so the day cannot
  // hold it and the planner has to say so rather than quietly shrink the
  // migration to fit. Without this the scenario had no check on *saying* it:
  // `respectsEstimates` stands down on a day that cannot fit — truncation
  // there is the honest plan, not compression — and nothing else asked whether
  // the model admitted the squeeze.
  requiresConflictSurfaced: true,
  conflictEscalationReasons: {'overCommitted'},
  startHour: 15,
  captureTranscript: 'Late start, only the afternoon left.',
);

/// Everything was decided, and it does not fit.
const _overCommitted = EvalScenario(
  id: 'overCommitted',
  intent:
      'Twelve hours of explicitly decided work against 480 minutes of '
      'capacity. Nothing enforces capacity, so does it overpack silently or '
      'surface the conflict?',
  tasks: [
    EvalTaskSpec(
      id: 'task-a',
      title: 'Rewrite the ingestion pipeline',
      estimateMinutes: 240,
    ),
    EvalTaskSpec(
      id: 'task-b',
      title: 'Prepare the board deck',
      estimateMinutes: 180,
    ),
    EvalTaskSpec(
      id: 'task-c',
      title: 'Interview two candidates',
      estimateMinutes: 120,
    ),
    EvalTaskSpec(
      id: 'task-d',
      title: 'Close out the quarterly report',
      estimateMinutes: 180,
    ),
  ],
  decidedTaskIds: ['task-a', 'task-b', 'task-c', 'task-d'],
  // Dropping work is how a planner surfaces an impossible day, so it must not
  // be scored as a miss — but silence is not surfacing. requiresConflictSurfaced
  // makes the planner say what it left out, and the estimate-based capacity
  // check stops it faking the fit by writing four multi-hour tasks as short
  // blocks. Together those are what make this scenario measurable.
  permittedOmissions: {'task-a', 'task-b', 'task-c', 'task-d'},
  requiresConflictSurfaced: true,
  // Only this one: the scenario seeds no directive, so escalating as
  // `directiveUnsatisfiable` would be a reason that cannot be true.
  conflictEscalationReasons: {'overCommitted'},
  captureTranscript: 'I want all four of these done today.',
);

/// Shared by the blocked pair below, so the only difference between them is
/// whether a capture accompanies the wake. Anything else varying would
/// confound the comparison the pair exists to make.
const _vendorChainTasks = [
  EvalTaskSpec(
    id: 'task-a-root',
    title: 'Get the vendor API credentials',
    estimateMinutes: 30,
  ),
  EvalTaskSpec(
    id: 'task-b-middle',
    title: 'Wire up the vendor integration',
    estimateMinutes: 120,
    status: EvalTaskStatus.blocked,
    blockedBy: ['task-a-root'],
  ),
  EvalTaskSpec(
    id: 'task-c-leaf',
    title: 'Ship the vendor integration to staging',
    estimateMinutes: 60,
    status: EvalTaskStatus.blocked,
    blockedBy: ['task-b-middle'],
  ),
  EvalTaskSpec(
    id: 'task-unrelated',
    title: 'Review the security questionnaire',
    estimateMinutes: 90,
  ),
];

/// A chain, not a pair — ADR 0043 resolves one hop only.
const _blockedChain = EvalScenario(
  id: 'blockedChain',
  intent:
      'C is blocked by B, which is blocked by A. ADR 0043 resolves one '
      'hop with no transitive closure, so B looks blocked and C looks blocked '
      'by B — does the plan reach A first, and does it avoid placing C?',
  tasks: _vendorChainTasks,
  decidedTaskIds: ['task-c-leaf'],
  // Leaving the blocked leaf out is a correct outcome, not a miss — the rule
  // says place it only behind its blocker or with the blocker named.
  permittedOmissions: {'task-c-leaf'},
  // But omitting the leaf and scheduling something unrelated would leave both
  // hops untouched while every constraint reported clean. The ready root is
  // the thing a competent plan reaches for, whether or not it gets to the
  // leaf, so requiring it is what makes the chain measurable.
  requiredTaskIds: {'task-a-root'},
  captureTranscript: 'I want to get the vendor integration shipped today.',
);

/// The same blocked work with the corpus hidden: how far does one hop get you?
///
/// This scenario found a production bug and then outlived it. Originally the
/// rule arrived with *no* data behind it — the corpus was the only carrier of
/// `status`/`blockedBy` and it renders inside `<capture>` alone, so every
/// sample of every model failed `blockerBeforeBlocked` here while the
/// capture-carrying twin passed every one. `DecidedTaskRef` now projects
/// `status` and `blockedBy` on every drafting wake, and the models switched to
/// declining the blocked leaf outright.
///
/// What it measures now is the residual gap. ADR 0043 resolves **one hop**, so
/// the decided leaf arrives naming `task-b-middle` as its blocker — and
/// nothing reveals that *that* task is itself blocked by `task-a-root`, whose
/// id never reaches the prompt. Keeping the twin's ground truth means this
/// scenario still fails `requiredWorkPlaced`, and that failure is the finding:
/// it is the measured cost of hiding the corpus, not a model defect. Weakening
/// it to match what the model can see would delete the signal.
const _blockedWithoutCorpus = EvalScenario(
  id: 'blockedWithoutCorpus',
  intent:
      'Same blocked work, but no capture. The decided leaf still carries its '
      'one-hop blocker; the corpus that would reveal the second hop does not '
      'render. Does the planner reach the ready root, or stop at what it was '
      'handed?',
  tasks: _vendorChainTasks,
  decidedTaskIds: ['task-c-leaf'],
  permittedOmissions: {'task-c-leaf'},
  // Identical to blockedChain on purpose. Ground truth must not move with
  // visibility: if this scenario asked less of the model, an identical plan
  // would be graded differently in the two reports and the rate gap could no
  // longer be attributed to the corpus being hidden — which is the entire
  // point of the pair.
  requiredTaskIds: {'task-a-root'},
  includeCapture: false,
);

/// A decided task the evidence does not support.
const _staleDecidedTask = EvalScenario(
  id: 'staleDecidedTask',
  intent:
      'A decided task that reads as already handled. The prompt says not '
      'to force a stale placement — does it obey, or place everything it was '
      'handed?',
  tasks: [
    EvalTaskSpec(
      id: 'task-stale-invoice',
      title: 'Send the client invoice',
      estimateMinutes: 30,
      dueOffsetDays: -5,
    ),
    EvalTaskSpec(
      id: 'task-real-review',
      title: 'Review the security questionnaire',
      estimateMinutes: 90,
      dueOffsetDays: 0,
    ),
  ],
  decidedTaskIds: ['task-stale-invoice', 'task-real-review'],
  // The transcript says the invoice is already sent, and the prompt tells the
  // model not to force a stale placement. Requiring it would fail the model
  // when it obeys; merely permitting the omission would let it place the work
  // and still score clean. Placing it is the failure.
  expectedOmissions: {'task-stale-invoice'},
  captureTranscript:
      'I already sent that invoice last week, it is done. Today I need to get '
      'through the security questionnaire.',
);

/// Orders from the coordinator that do not fit the day.
const _bindingDirective = EvalScenario(
  id: 'bindingDirective',
  intent:
      'A directive the prompt calls BINDING asks for 390 minutes against a '
      '240-minute budget. Does the planner represent what fits and answer for '
      'the rest — trading with the collision named, or escalating as '
      'directiveUnsatisfiable — or does it quietly drop a commitment the user '
      'asked for?',
  tasks: [
    EvalTaskSpec(
      id: 'task-inbox',
      title: 'Clear the support inbox',
      estimateMinutes: 45,
    ),
    EvalTaskSpec(
      id: 'task-release-notes',
      title: 'Write the release notes',
      estimateMinutes: 60,
      dueOffsetDays: 0,
    ),
  ],
  // Deliberately over budget: 180 + 120 + 90 against 240 remaining. A day that
  // fits would let a model honour everything by accident and prove nothing
  // about the contract, which only bites when something has to give.
  // An over-committed directive is honestly `overCommitted` as well as
  // `directiveUnsatisfiable`, and both live runs reached for the former. The
  // allowlist is fixture-declared so a model still cannot escalate under a
  // reason that could not be true of this day.
  conflictEscalationReasons: {'overCommitted'},
  directive: EvalDirective(
    commitments: [
      EvalDirectiveCommitment(
        id: 'commit-board-deck',
        title: 'Prepare the board deck',
        minutes: 180,
      ),
      EvalDirectiveCommitment(
        id: 'commit-interviews',
        title: 'Interview two candidates',
        minutes: 120,
      ),
      EvalDirectiveCommitment(
        id: 'commit-weekly-1-1s',
        title: 'Run the weekly 1:1s',
        minutes: 90,
      ),
    ],
    availableMinutes: 300,
    alreadyScheduledMinutes: 60,
    attentionNotes: ['Board deck is the one that cannot slip.'],
  ),
  captureTranscript:
      'The board deck has to land today. Not sure how the rest fits.',
);

/// Tasks due on or before [planDate], read live so a triage update shows.
List<Task> _dueBy(DateTime planDate) => [
  for (final task in currentEvalJournal.tasks)
    if (task.data.due case final due?)
      if (!due.isAfter(
        DateTime(planDate.year, planDate.month, planDate.day, 23, 59),
      ))
        task,
];

/// Stubs the corpus reads on [journalDb] from [scenario].
///
/// The pipeline harness installs empty defaults for all four task sources;
/// this replaces them so the model is given something to plan. Kept beside the
/// fixtures rather than in the runner so a scenario is seeded exactly one way.
void seedScenarioCorpus({
  required MockJournalDb journalDb,
  required EvalScenario scenario,
  required DateTime planDate,
  MockJournalRepository? journalRepository,
}) {
  // One journal for the cell, shared with the persistence stub so a task the
  // model creates mid-wake is findable afterwards. Reset here, which is the
  // once-per-cell seeding point.
  currentEvalJournal.reset(scenario.tasksFor(planDate));
  // Every corpus read derives from the mutable per-cell store, not from a
  // fresh `scenario.tasksFor` each time. A model that runs `apply_triage` and
  // then re-checks pending work must see what it just changed; recreating the
  // original lists would show a task it marked done as still in progress, and
  // every later decision — and the rejection and compliance scores that follow
  // — would rest on state the tool said it had changed.
  when(
    () => journalDb.getOpenTasksForDayAgentCorpus(
      categoryIds: any(named: 'categoryIds'),
      limit: any(named: 'limit'),
    ),
  ).thenAnswer((_) async => currentEvalJournal.tasks);
  when(
    () => journalDb.getTasksDueOnOrBefore(any()),
  ).thenAnswer((_) async => _dueBy(planDate));
  when(
    () => journalDb.getTasksDueOn(any()),
  ).thenAnswer((_) async => _dueBy(planDate));
  when(
    () => journalDb.getInProgressTasks(
      categoryIds: any(named: 'categoryIds'),
      limit: any(named: 'limit'),
    ),
  ).thenAnswer(
    (_) async => [
      for (final task in currentEvalJournal.tasks)
        if (task.data.status is TaskInProgress) task,
    ],
  );
  when(
    () => journalDb.getJournalEntitiesForIdsUnordered(any()),
  ).thenAnswer((invocation) async {
    final ids = invocation.positionalArguments.first as List<String>;
    return currentEvalJournal.mapForIds(ids).values.toList();
  });

  when(
    () => journalDb.journalEntityMapForIds(any()),
  ).thenAnswer((invocation) async {
    final ids = invocation.positionalArguments.first as List<String>;
    return currentEvalJournal.mapForIds(ids);
  });
  // Single-id lookup, reached by `apply_triage` and `create_task_from_phrase`
  // — tools a model is free to call on a drafting wake, and glm-5.2 did.
  // Without this the harness answers "task <id> not found" for a task the
  // scenario put in the corpus and the model correctly named, and that lands
  // on the model as a rejection, corrupting the one constraint that measures
  // whether it needed correcting.
  when(
    () => journalDb.journalEntityById(any()),
  ).thenAnswer((invocation) async {
    final id = invocation.positionalArguments.first as String;
    return currentEvalJournal.byId(id);
  });
  // An update that reports success without changing anything leaves the model
  // reading stale state after its own `apply_triage` — the harness agreeing
  // out loud and doing nothing.
  if (journalRepository != null) {
    when(
      () => journalRepository.updateJournalEntity(any()),
    ).thenAnswer((invocation) async {
      final updated = invocation.positionalArguments.first as JournalEntity;
      currentEvalJournal.add(updated);
      return true;
    });
  }
}
