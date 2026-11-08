import 'package:lotti/classes/task.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_routing_index.dart';

/// The routing index every scenario is posed against: the penguin
/// logistics world in miniature. Fixtures come from the demo world only —
/// never from a user's own tasks, people or notes.
///
/// Two tasks share the words "Bay C" on purpose (the near-candidates case),
/// one goal and one person exist so a kind other than task can win, and the
/// closed sensor task is deliberately NOT listed: closed tasks are not
/// destinations, and a model that names one must say so, not invent an id.
final FrontRoutingIndex frontEvalIndex = FrontRoutingIndex(
  categories: const [
    FrontCategory(id: 'cat-colony', name: 'Colony care'),
    FrontCategory(id: 'cat-maintenance', name: 'Station maintenance'),
  ],
  tasks: const [
    FrontIndexRow(
      kind: FrontDestinationKind.task,
      id: 'task-bay-c-seam',
      title: 'Walk the Bay C seam for the leak',
      status: 'IN PROGRESS',
      oneLiner: 'Blocked on the sensor swap; the seam walk is next.',
      tldr:
          'The Bay C pump room leak: the seam has not been walked yet '
          'because the sensor swap blocks access.',
    ),
    FrontIndexRow(
      kind: FrontDestinationKind.task,
      id: 'task-bay-c-lighting',
      title: 'Replace the Bay C corridor lighting',
      status: 'OPEN',
      oneLiner: 'Waiting on the LED order to arrive.',
      tldr:
          'Corridor lighting in Bay C: the LED fixtures are ordered, '
          'nothing to do until they arrive.',
    ),
    FrontIndexRow(
      kind: FrontDestinationKind.task,
      id: 'task-fish-order',
      title: 'Order next month’s fish for the colony',
      status: 'OPEN',
      oneLiner: 'Quote from the supplier due Thursday.',
    ),
    FrontIndexRow(
      kind: FrontDestinationKind.task,
      id: 'task-iceberg-survey',
      title: 'Survey the north iceberg shelf',
      status: 'GROOMED',
    ),
  ],
  projects: const [
    FrontIndexRow(
      kind: FrontDestinationKind.project,
      id: 'project-relocation',
      title: 'Colony relocation to the north shelf',
      oneLiner: 'Surveys first, then the move in spring.',
    ),
  ],
  goals: const [
    FrontIndexRow(
      kind: FrontDestinationKind.goal,
      id: 'goal-swim',
      title: 'Swim 2 km a day on average over a rolling week',
      oneLiner: 'On track; two long swims this week.',
    ),
  ],
  people: const [
    FrontIndexRow(
      kind: FrontDestinationKind.person,
      id: 'person-pip',
      title: 'Pip',
    ),
  ],
);

/// What a correct turn does with one scenario's input.
enum FrontEvalOutcome {
  /// Ends with `dispatch`; every expected segment destination must appear.
  dispatch,

  /// Ends with `ask_user`; its options must be drawn from the candidates.
  ask,

  /// Ends with `reply_to_user` and no dispatch to an existing owner.
  reply,
}

/// One expected segment of a dispatch: the kind and, for an owner, the id.
typedef FrontEvalExpectedSegment = ({FrontDestinationKind kind, String? id});

/// One routing situation and what a correct turn does with it.
class FrontEvalScenario {
  const FrontEvalScenario({
    required this.id,
    required this.input,
    required this.outcome,
    this.expectedSegments = const [],
    this.askCandidates = const {},
    this.forbiddenDestinationIds = const {},
    this.maxLookups = 2,
    this.checkTask,
    this.recent = const [],
    this.conversationTasks = const [],
    this.note = '',
  });

  final String id;
  final String input;
  final FrontEvalOutcome outcome;

  /// For [FrontEvalOutcome.dispatch]: destinations that must each appear
  /// on some segment (order-free; extra `unrouted` segments are allowed).
  final List<FrontEvalExpectedSegment> expectedSegments;

  /// For [FrontEvalOutcome.ask]: the ids the question may offer; every
  /// option must be one of them.
  final Set<String> askCandidates;

  /// Ids that must not appear anywhere in the outcome.
  final Set<String> forbiddenDestinationIds;

  /// How many lookup calls a correct turn needs at most.
  final int maxLookups;

  /// For a turn that makes a task: the failures of the `new` task segment
  /// ([FrontDispatchSegment.task] and its intent), none when it is right;
  /// called with null when there is no such segment.
  final List<String> Function(FrontDispatchSegment? segment)? checkTask;

  /// The conversation so far, as `<recent_turns>` carries it.
  final List<({String role, String text})> recent;

  /// The tasks the conversation named, as `<conversation_tasks>` lists them.
  final List<FrontIndexRow> conversationTasks;

  /// Why the scenario exists; shown in the report.
  final String note;
}

/// The catalogue the slice-0 plan names, plus the owner's regression case
/// slot (decision 6) once its input is known.
final List<FrontEvalScenario> frontEvalScenarios = [
  const FrontEvalScenario(
    id: 'asked_task_started',
    input:
        'Make a task to recalibrate the hatchery heaters, it is a station '
        'maintenance job, high priority, due 2026-10-27, about two hours. '
        'Start the timer, I began ten minutes ago. Check the north heater '
        'first, it drifts the most.',
    outcome: FrontEvalOutcome.dispatch,
    expectedSegments: [(kind: FrontDestinationKind.newThing, id: null)],
    maxLookups: 1,
    checkTask: _startedHeaterTask,
    note:
        'A task asked for with every field said aloud: drafted for the '
        'tap, in progress, its timer from ten minutes back.',
  ),
  const FrontEvalScenario(
    id: 'asked_task_among_topics',
    input:
        'Swam 3 km this morning. Also create a task to repaint the signs '
        'at the feeding station, no rush, I started on it at 9:15.',
    outcome: FrontEvalOutcome.dispatch,
    expectedSegments: [
      (kind: FrontDestinationKind.goal, id: 'goal-swim'),
      (kind: FrontDestinationKind.newThing, id: null),
    ],
    maxLookups: 1,
    checkTask: _signsTask,
    note:
        'Two topics in one voice note: only the task part is the task, its '
        'category is inferred, and a clock time is a start too.',
  ),
  const FrontEvalScenario(
    id: 'mentioned_task',
    input: 'I need to check the snow fences before the storm on Friday.',
    outcome: FrontEvalOutcome.dispatch,
    expectedSegments: [(kind: FrontDestinationKind.newThing, id: null)],
    maxLookups: 1,
    checkTask: _mentionedTask,
    note:
        'A task only mentioned is drafted too, with no timer nobody asked '
        'for.',
  ),
  const FrontEvalScenario(
    id: 'category_from_conversation',
    input: "Make a task to write up today's notes.",
    outcome: FrontEvalOutcome.dispatch,
    expectedSegments: [(kind: FrontDestinationKind.newThing, id: null)],
    maxLookups: 1,
    recent: [
      (role: 'user', text: 'What did I work on today?'),
      (
        role: 'assistant',
        text:
            'Today you logged 3h 10m, all in Station maintenance:\n'
            '- [Walk the Bay C seam](lotti://task/task-bay-c-seam)\n'
            '- [Replace the Bay C lighting](lotti://task/task-bay-c-lighting)',
      ),
    ],
    conversationTasks: [
      FrontIndexRow(
        kind: FrontDestinationKind.task,
        id: 'task-bay-c-seam',
        title: 'Walk the Bay C seam for the leak',
        status: 'IN PROGRESS',
        categoryId: 'cat-maintenance',
      ),
      FrontIndexRow(
        kind: FrontDestinationKind.task,
        id: 'task-bay-c-lighting',
        title: 'Replace the Bay C corridor lighting',
        status: 'OPEN',
        categoryId: 'cat-maintenance',
      ),
    ],
    checkTask: _maintenanceNotesTask,
    note:
        'No category said, but the whole conversation and all of today is '
        'one category: she files it there.',
  ),
  const FrontEvalScenario(
    id: 'category_nowhere',
    input: "Make a task to write up today's notes.",
    outcome: FrontEvalOutcome.dispatch,
    expectedSegments: [(kind: FrontDestinationKind.newThing, id: null)],
    maxLookups: 1,
    checkTask: _uncategorizedTask,
    note:
        'The same words with no conversation behind them point nowhere: '
        'no category guessed.',
  ),
  const FrontEvalScenario(
    id: 'asked_task_duplicate',
    input: "Create a task to order next month's fish for the colony.",
    outcome: FrontEvalOutcome.ask,
    askCandidates: {'task-fish-order'},
    maxLookups: 1,
    note:
        'An open task is already this work: she asks rather than making '
        'a second.',
  ),
  const FrontEvalScenario(
    id: 'single_strong',
    input: 'The fish supplier sent the quote, it is 12% up on last month.',
    outcome: FrontEvalOutcome.dispatch,
    expectedSegments: [
      (kind: FrontDestinationKind.task, id: 'task-fish-order'),
    ],
    maxLookups: 0,
    note: 'One task owns this unmistakably; no lookup should be needed.',
  ),
  const FrontEvalScenario(
    id: 'two_near_candidates',
    input: 'Bay C is sorted, we can close that out.',
    outcome: FrontEvalOutcome.ask,
    askCandidates: {'task-bay-c-seam', 'task-bay-c-lighting'},
    note:
        'Two open tasks are about Bay C and the message names neither; '
        'a correct turn asks rather than guessing.',
  ),
  const FrontEvalScenario(
    id: 'closed_task_named',
    input: 'Add a note to the sensor swap task: the spare arrived.',
    outcome: FrontEvalOutcome.reply,
    forbiddenDestinationIds: {'task-bay-c-seam', 'task-bay-c-lighting'},
    maxLookups: 1,
    note:
        'The sensor swap is closed and not listed. The one allowed move '
        'is a corpus match, which finds nothing; then she says so.',
  ),
  const FrontEvalScenario(
    id: 'three_intents',
    input:
        'Walked the seam this morning and found the leak at the third '
        'weld. Swam 3 km. Ask Pip whether Thursday still works for the '
        'survey.',
    outcome: FrontEvalOutcome.dispatch,
    expectedSegments: [
      (kind: FrontDestinationKind.task, id: 'task-bay-c-seam'),
      (kind: FrontDestinationKind.goal, id: 'goal-swim'),
      (kind: FrontDestinationKind.person, id: 'person-pip'),
    ],
    maxLookups: 1,
    note: 'One voice note, three owners.',
  ),
  const FrontEvalScenario(
    id: 'nothing_matches',
    input: 'Thinking about learning the accordion this winter.',
    outcome: FrontEvalOutcome.dispatch,
    expectedSegments: [(kind: FrontDestinationKind.newThing, id: null)],
    forbiddenDestinationIds: {
      'task-bay-c-seam',
      'task-bay-c-lighting',
      'task-fish-order',
      'task-iceberg-survey',
      'project-relocation',
      'goal-swim',
      'person-pip',
    },
    maxLookups: 1,
    note: 'Nothing owns this; it is new or a note, never a forced match.',
  ),
  const FrontEvalScenario(
    id: 'move_today',
    input: 'Push the survey to tomorrow, today is a write-off.',
    outcome: FrontEvalOutcome.dispatch,
    expectedSegments: [(kind: FrontDestinationKind.day, id: null)],
    maxLookups: 0,
    note: "Today's plan is the Daily OS door, not the task.",
  ),
  const FrontEvalScenario(
    id: 'project_statement',
    input: 'The relocation as a whole is slipping, we lost two weeks.',
    outcome: FrontEvalOutcome.dispatch,
    expectedSegments: [
      (kind: FrontDestinationKind.project, id: 'project-relocation'),
    ],
    forbiddenDestinationIds: {'task-iceberg-survey', 'task-bay-c-seam'},
    maxLookups: 0,
    note:
        'A statement about a project as a whole files under the project '
        '(the project door); no single task owns it.',
  ),
];

/// The clock every scenario's turn shows the model (`<current_local_time>`).
final DateTime frontEvalNow = DateTime(2026, 10, 23, 9, 30);

/// How far back from the turn's clock a draft's start lies, in minutes.
int? _minutesBack(FrontDispatchSegment segment) {
  final started = segment.task?.startedAt;
  return started == null ? null : frontEvalNow.difference(started).inMinutes;
}

List<String> _taskShape(FrontDispatchSegment? segment) => [
  if (segment == null) 'no new task segment',
  if (segment != null && segment.task == null) 'no task object',
];

List<String> _startedHeaterTask(FrontDispatchSegment? segment) {
  final shape = _taskShape(segment);
  if (shape.isNotEmpty) return shape;
  final task = segment!.task!;
  final back = _minutesBack(segment);
  return [
    if (task.categoryId != 'cat-maintenance') 'category ${task.categoryId}',
    if (task.priority != TaskPriority.p1High) 'priority ${task.priority}',
    if (task.due != DateTime(2026, 10, 27)) 'due ${task.due}',
    if (task.estimate != const Duration(hours: 2)) 'estimate ${task.estimate}',
    if (back == null || (back - 10).abs() > 1) 'started $back minutes back',
    if (!(task.instructions ?? '').toLowerCase().contains('north'))
      'instructions lost the north heater',
  ];
}

List<String> _signsTask(FrontDispatchSegment? segment) {
  final shape = _taskShape(segment);
  if (shape.isNotEmpty) return shape;
  final task = segment!.task!;
  final back = _minutesBack(segment);
  return [
    if (task.categoryId != 'cat-colony' && task.categoryId != 'cat-maintenance')
      'no category inferred',
    // 9:15 against the turn's 09:30.
    if (back == null || (back - 15).abs() > 1) 'started $back minutes back',
    if ('${task.title} ${task.instructions ?? ''}'.toLowerCase().contains(
      'swam',
    ))
      'the swim leaked into the task',
    if (segment.text.toLowerCase().contains('swam'))
      'the span took in the swim',
  ];
}

List<String> _maintenanceNotesTask(FrontDispatchSegment? segment) {
  final shape = _taskShape(segment);
  if (shape.isNotEmpty) return shape;
  final categoryId = segment!.task!.categoryId;
  return [
    if (categoryId != 'cat-maintenance')
      'category $categoryId, not the conversation one',
  ];
}

List<String> _uncategorizedTask(FrontDispatchSegment? segment) {
  final shape = _taskShape(segment);
  if (shape.isNotEmpty) return shape;
  return [
    if (segment!.task!.categoryId case final id?) 'guessed category $id',
  ];
}

List<String> _mentionedTask(FrontDispatchSegment? segment) {
  final shape = _taskShape(segment);
  if (shape.isNotEmpty) return shape;
  return [
    if (segment!.task!.startedAt != null) 'a timer nobody asked for',
  ];
}
