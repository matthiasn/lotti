// Shared scenario catalog for the agent evaluation harness.
//
// Scenario definitions are plain data and intentionally contain no scripted
// model behaviour. Tests, scripted targets, and the future live runner all read
// from here so Level 1 and Level 2 cannot drift into separate datasets.

import '../harness/eval_harness.dart';

const kPlannerWorkflowDayId = 'dayplan-2026-06-09';

final plannerMorningCapacityScenario = EvalScenario(
  id: 'planner_morning_capacity',
  title: 'Morning capture: ADR + PR review + a run within capacity',
  agentKind: AgentKind.planningAgent,
  appState: MockedAppState(
    now: DateTime(2026, 6, 9, 7),
    categoryIds: const ['cat-work', 'cat-health', 'cat-admin'],
    tasks: [
      MockTask(
        id: 'task-adr',
        title: 'Finish the planner ADR',
        status: 'IN PROGRESS',
        due: DateTime(2026, 6, 9),
        estimateMinutes: 120,
        categoryId: 'cat-work',
      ),
      MockTask(
        id: 'task-pr',
        title: 'Review the slow-query PR',
        status: 'OPEN',
        due: DateTime(2026, 6, 10),
        estimateMinutes: 45,
        categoryId: 'cat-work',
      ),
      const MockTask(
        id: 'task-run',
        title: 'Morning run',
        status: 'OPEN',
        estimateMinutes: 40,
        categoryId: 'cat-health',
      ),
    ],
  ),
  userInput: const UserInput(
    transcript:
        "Here's what I want to get done today: finish the planner "
        'ADR, review the slow-query PR, and fit in a morning run before '
        'standup.',
    triggerTokens: {'drafting:$kPlannerWorkflowDayId'},
  ),
  expectations: const EvalExpectations(mustCallTools: {'draft_day_plan'}),
);

final plannerWorkflowDraftingScenario = EvalScenario(
  id: 'planner_workflow_drafting',
  title: 'Real workflow drafting wake within capacity',
  agentKind: AgentKind.planningAgent,
  appState: MockedAppState(
    now: DateTime(2026, 6, 9, 7),
    categoryIds: const ['cat-work', 'cat-health'],
    tasks: [
      MockTask(
        id: 'task-adr',
        title: 'Finish the planner ADR',
        status: 'IN PROGRESS',
        due: DateTime(2026, 6, 9),
        estimateMinutes: 120,
        categoryId: 'cat-work',
      ),
      const MockTask(
        id: 'task-run',
        title: 'Morning run',
        status: 'OPEN',
        estimateMinutes: 40,
        categoryId: 'cat-health',
      ),
    ],
  ),
  userInput: const UserInput(
    transcript: 'Finish the planner ADR and fit in a morning run.',
    triggerTokens: {'drafting:$kPlannerWorkflowDayId'},
  ),
  expectations: const EvalExpectations(mustCallTools: {'draft_day_plan'}),
);

final taskReleaseNotesScenario = EvalScenario(
  id: 'task_release_notes',
  title: 'Groom release-notes task: estimate, status, checklist, labels',
  agentKind: AgentKind.taskAgent,
  appState: MockedAppState(
    now: DateTime(2026, 6, 9, 9),
    categoryIds: const ['cat-work'],
    tasks: const [
      MockTask(
        id: 'task-notes',
        title: 'Write release notes for 0.x',
        status: 'IN PROGRESS',
        categoryId: 'cat-work',
        checklist: [
          MockChecklistItem(id: 'ci-1', title: 'Draft summary'),
        ],
      ),
    ],
  ),
  userInput: const UserInput(
    transcript: 'Help me get the release notes ready.',
    triggerTokens: {'decided_task:task-notes'},
  ),
);

final taskWorkflowReleaseNotesScenario = EvalScenario(
  id: 'task_workflow_release_notes',
  title: 'Real workflow: groom the release-notes task',
  agentKind: AgentKind.taskAgent,
  appState: MockedAppState(
    now: DateTime(2026, 6, 9, 9),
    categoryIds: const ['cat-001'],
    tasks: const [
      MockTask(
        id: 'task-notes',
        title: 'Write release notes for 0.x',
        status: 'IN PROGRESS',
        categoryId: 'cat-001',
        checklist: [MockChecklistItem(id: 'ci-1', title: 'Draft summary')],
      ),
    ],
  ),
  userInput: const UserInput(
    transcript: 'Help me get the release notes ready.',
    triggerTokens: {'decided_task:task-notes'},
  ),
);

final allEvalScenarios = <EvalScenario>[
  plannerMorningCapacityScenario,
  plannerWorkflowDraftingScenario,
  taskReleaseNotesScenario,
  taskWorkflowReleaseNotesScenario,
];

final List<EvalScenario> planningEvalScenarios = allEvalScenarios
    .where((scenario) => scenario.agentKind == AgentKind.planningAgent)
    .toList(growable: false);

final List<EvalScenario> taskEvalScenarios = allEvalScenarios
    .where((scenario) => scenario.agentKind == AgentKind.taskAgent)
    .toList(growable: false);
