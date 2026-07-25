import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/tasks/repository/task_dependency_resolver.dart';
import 'package:meta/meta.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
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
    this.capacityMinutes = 480,
    this.startHour,
    this.includeCapture = true,
    this.captureTranscript,
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
              ),
          ],
    };
  }

  /// The scorers' view of what the model was given.
  EvalFixtureInputs inputsFor(DateTime planDate) => EvalFixtureInputs(
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
    // Without a capture the task corpus is never rendered, so the only ids
    // the model can name are its decided ones. The corpus above stays as
    // ground truth for constraints that need to know what is actually true.
    visibleTaskIds: includeCapture ? null : {...decidedTaskIds},
    capacityMinutes: capacityMinutes,
    now: startHour == null
        ? null
        : DateTime(planDate.year, planDate.month, planDate.day, startHour!),
  );

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

/// A [TaskDependencyResolver] that answers from a fixture instead of the
/// journal, so blocked-work scenarios do not need real typed links.
class EvalFixtureDependencyResolver implements TaskDependencyResolver {
  EvalFixtureDependencyResolver(this.blockedStatus);

  final Map<String, List<ResolvedBlocker>> blockedStatus;

  @override
  Future<Map<String, List<ResolvedBlocker>>> resolveBlockedStatus(
    Set<String> taskIds,
  ) async => {
    for (final entry in blockedStatus.entries)
      if (taskIds.contains(entry.key)) entry.key: entry.value,
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
  captureTranscript: 'I want to get the vendor integration shipped today.',
);

/// The rule arrives; the data does not.
const _blockedWithoutCorpus = EvalScenario(
  id: 'blockedWithoutCorpus',
  intent:
      'Same blocked work, but no capture — so the corpus (and its '
      'blockedBy) is never rendered while the blocked-work rule still is. '
      'Measures what the model does when told a rule it cannot apply.',
  tasks: _vendorChainTasks,
  decidedTaskIds: ['task-c-leaf'],
  permittedOmissions: {'task-c-leaf'},
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

/// Stubs the corpus reads on [journalDb] from [scenario].
///
/// The pipeline harness installs empty defaults for all four task sources;
/// this replaces them so the model is given something to plan. Kept beside the
/// fixtures rather than in the runner so a scenario is seeded exactly one way.
void seedScenarioCorpus({
  required MockJournalDb journalDb,
  required EvalScenario scenario,
  required DateTime planDate,
}) {
  when(
    () => journalDb.getOpenTasksForDayAgentCorpus(
      categoryIds: any(named: 'categoryIds'),
      limit: any(named: 'limit'),
    ),
  ).thenAnswer((_) async => scenario.tasksFor(planDate));
  when(
    () => journalDb.getTasksDueOnOrBefore(any()),
  ).thenAnswer((_) async => scenario.overdueOrDueTodayFor(planDate));
  when(
    () => journalDb.getTasksDueOn(any()),
  ).thenAnswer((_) async => scenario.overdueOrDueTodayFor(planDate));
  when(
    () => journalDb.getInProgressTasks(
      categoryIds: any(named: 'categoryIds'),
      limit: any(named: 'limit'),
    ),
  ).thenAnswer((_) async => scenario.inProgressFor(planDate));
  when(
    () => journalDb.journalEntityMapForIds(any()),
  ).thenAnswer(
    (_) async => {
      for (final task in scenario.tasksFor(planDate)) task.id: task,
    },
  );
}
