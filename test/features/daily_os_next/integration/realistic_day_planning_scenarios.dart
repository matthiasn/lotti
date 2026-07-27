import '../eval/framework/eval_scenario.dart';

const denseRestOfDayScenario = EvalScenario(
  id: 'dense-rest-of-day',
  intent: 'Retain every mentioned constraint while ignoring unrelated work.',
  captureTranscript:
      'For the rest of today, finish the migration first. Send the invoice '
      'before 15:00. The client call is at 13:00, and leave me a 15-minute '
      'break right after it. I want a 30-minute walk after lunch, and the '
      'dentist at 16:30 is fixed.',
  capacityMinutes: 300,
  startHour: 8,
  decidedTaskIds: [
    'task-migration',
    'task-invoice',
    'task-client-call',
    'task-reset',
    'task-walk',
    'task-dentist',
  ],
  tasks: [
    EvalTaskSpec(
      id: 'task-migration',
      title: 'Finish the database migration',
      estimateMinutes: 75,
      categoryId: 'cat-project',
      status: EvalTaskStatus.inProgress,
    ),
    EvalTaskSpec(
      id: 'task-invoice',
      title: 'Send the overdue client invoice',
      estimateMinutes: 20,
      dueOffsetDays: -2,
      categoryId: 'cat-admin',
    ),
    EvalTaskSpec(
      id: 'task-client-call',
      title: 'Client planning call',
      estimateMinutes: 45,
      dueOffsetDays: 0,
      categoryId: 'cat-client',
    ),
    EvalTaskSpec(
      id: 'task-reset',
      title: 'Take a reset after the client call',
      estimateMinutes: 15,
      categoryId: 'cat-wellbeing',
    ),
    EvalTaskSpec(
      id: 'task-walk',
      title: 'Take a 30-minute walk',
      estimateMinutes: 30,
      categoryId: 'cat-health',
    ),
    EvalTaskSpec(
      id: 'task-dentist',
      title: 'Dentist appointment',
      estimateMinutes: 60,
      dueOffsetDays: 0,
      categoryId: 'cat-personal',
    ),
    EvalTaskSpec(
      id: 'task-security-review',
      title: 'Review the security questionnaire',
      estimateMinutes: 90,
      dueOffsetDays: 0,
      categoryId: 'cat-security',
    ),
    EvalTaskSpec(
      id: 'task-release-notes',
      title: 'Write release notes',
      estimateMinutes: 60,
      categoryId: 'cat-product',
      status: EvalTaskStatus.inProgress,
    ),
    EvalTaskSpec(
      id: 'task-expenses',
      title: 'File travel expenses',
      estimateMinutes: 25,
      categoryId: 'cat-finance',
    ),
    EvalTaskSpec(
      id: 'task-groceries',
      title: 'Buy groceries',
      estimateMinutes: 40,
      categoryId: 'cat-home',
    ),
    EvalTaskSpec(
      id: 'task-training',
      title: 'Complete leadership training',
      estimateMinutes: 120,
      categoryId: 'cat-learning',
    ),
    EvalTaskSpec(
      id: 'task-team-replies',
      title: 'Reply to team messages',
      estimateMinutes: 30,
      categoryId: 'cat-comms',
    ),
  ],
);

const overcommittedRestOfDayScenario = EvalScenario(
  id: 'overcommitted-rest-of-day',
  intent: 'Name what cannot fit and escalate it back to the planner.',
  captureTranscript:
      'The board deck has to happen. Also do the interviews, release notes, '
      'support inbox, and a walk. I know the afternoon is tight.',
  capacityMinutes: 180,
  startHour: 12,
  decidedTaskIds: [
    'task-board-deck',
    'task-interviews',
    'task-release',
    'task-inbox',
    'task-afternoon-walk',
  ],
  tasks: [
    EvalTaskSpec(
      id: 'task-board-deck',
      title: 'Prepare the board deck',
      estimateMinutes: 90,
      categoryId: 'cat-leadership',
      status: EvalTaskStatus.inProgress,
    ),
    EvalTaskSpec(
      id: 'task-interviews',
      title: 'Interview two candidates',
      estimateMinutes: 60,
      dueOffsetDays: 0,
      categoryId: 'cat-people',
    ),
    EvalTaskSpec(
      id: 'task-release',
      title: 'Write the release notes',
      estimateMinutes: 45,
      dueOffsetDays: 0,
      categoryId: 'cat-product',
    ),
    EvalTaskSpec(
      id: 'task-inbox',
      title: 'Clear the support inbox',
      estimateMinutes: 30,
      categoryId: 'cat-support',
    ),
    EvalTaskSpec(
      id: 'task-afternoon-walk',
      title: 'Take an afternoon walk',
      estimateMinutes: 30,
      categoryId: 'cat-health',
    ),
    EvalTaskSpec(
      id: 'task-budget',
      title: 'Review next quarter budget',
      estimateMinutes: 80,
      categoryId: 'cat-finance',
    ),
    EvalTaskSpec(
      id: 'task-roadmap',
      title: 'Update the product roadmap',
      estimateMinutes: 75,
      categoryId: 'cat-strategy',
    ),
    EvalTaskSpec(
      id: 'task-gym',
      title: 'Gym session',
      estimateMinutes: 60,
      categoryId: 'cat-health',
      status: EvalTaskStatus.inProgress,
    ),
  ],
);

const List<EvalScenario> realisticDayPlanningScenarios = [
  denseRestOfDayScenario,
  overcommittedRestOfDayScenario,
];
