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

  /// Why the scenario exists; shown in the report.
  final String note;
}

/// The catalogue the slice-0 plan names, plus the owner's regression case
/// slot (decision 6) once its input is known.
final List<FrontEvalScenario> frontEvalScenarios = [
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
