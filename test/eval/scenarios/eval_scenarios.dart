// Shared scenario catalog for the agent evaluation harness.
//
// Scenario definitions are plain data and intentionally contain no scripted
// model behaviour. Tests, scripted targets, and the future live runner all read
// from here so Level 1 and Level 2 cannot drift into separate datasets.

import '../harness/eval_harness.dart';

const kPlannerWorkflowDayId = 'dayplan-2026-06-09';
const kPlannerWorkflowCaptureId = 'capture-morning-plan';
const kPlannerWorkflowParsedRunId = 'parsed-morning-run';
const kPlannerCaptureOnlyDayId = 'dayplan-2026-06-10';
const kPlannerCaptureOnlyCaptureId = 'capture-parse-only';
const kPlannerAmbiguousCarryoverDayId = 'dayplan-2026-06-11';
const kPlannerFocusBoundaryDayId = 'dayplan-2026-06-12';
const kPlannerAmbiguousCaptureDayId = 'dayplan-2026-06-13';
const kPlannerAmbiguousCaptureId = 'capture-ambiguous-sam';

EvalScenario _reviewedScenario(
  EvalScenario scenario, {
  required String rationale,
}) {
  final json = scenario.toJson();
  final metadata = <String, dynamic>{
    ...(json['metadata'] as Map<String, dynamic>),
    'review': EvalScenarioReview(
      status: EvalScenarioReviewStatus.reviewed,
      reviewer: 'lotti-eval-reviewer',
      reviewedAt: '2026-06-10T12:00:00.000Z',
      subjectDigest: EvalProvenance.scenarioReviewSubjectDigest(scenario),
      rationale: rationale,
    ).toJson(),
  };
  json['metadata'] = metadata;
  return EvalScenario.fromJson(json);
}

final kEvalWorkCategory = MockCategoryDefinition(
  id: 'cat-001',
  name: 'Work',
  color: '#3366FF',
  isAvailableForDayPlan: true,
  correctionExamples: [
    MockCorrectionExample(
      before: 'mac OS',
      after: 'macOS',
      capturedAt: DateTime(2026, 6, 8, 12),
    ),
  ],
);

const kEvalAdminCategory = MockCategoryDefinition(
  id: 'cat-admin',
  name: 'Admin',
  color: '#AA00AA',
  isAvailableForDayPlan: true,
);

const kEvalReleaseLabel = MockLabelDefinition(
  id: 'lbl-release',
  name: 'Release Notes',
  color: '#2F80ED',
  applicableCategoryIds: ['cat-001'],
);

const kEvalAssignedLabel = MockLabelDefinition(
  id: 'lbl-docs',
  name: 'Documentation',
  color: '#27AE60',
  applicableCategoryIds: ['cat-001'],
);

const kEvalSuppressedLabel = MockLabelDefinition(
  id: 'lbl-legal',
  name: 'Legal',
  color: '#EB5757',
  applicableCategoryIds: ['cat-001'],
);

const kEvalOutOfScopeLabel = MockLabelDefinition(
  id: 'lbl-admin',
  name: 'Admin Follow-up',
  color: '#9B51E0',
  applicableCategoryIds: ['cat-admin'],
);

final plannerMorningCapacityScenario = EvalScenario(
  id: 'planner_morning_capacity',
  title: 'Morning capture: ADR + PR review + a run within capacity',
  agentKind: AgentKind.planningAgent,
  metadata: const EvalScenarioMetadata(
    capabilityIds: ['planner.drafting.capacity'],
    tags: {'planner', 'capacity', 'smoke'},
  ),
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
  metadata: const EvalScenarioMetadata(
    capabilityIds: [
      'planner.drafting.capacity',
      'planner.drafting.capturecontext',
    ],
    tags: {'planner', 'workflow', 'drafting'},
  ),
  appState: MockedAppState(
    now: DateTime(2026, 6, 9, 7),
    capacityMinutes: 240,
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
    captures: [
      MockCapture(
        id: kPlannerWorkflowCaptureId,
        transcript:
            'Finish the planner ADR, review the slow-query PR, and fit in '
            'a morning run before standup.',
        capturedAt: DateTime(2026, 6, 9, 7),
        dayId: kPlannerWorkflowDayId,
        parsedItems: [
          const MockParsedCaptureItem(
            id: 'parsed-planner-adr',
            kind: 'matched',
            title: 'Finish the planner ADR',
            categoryId: 'cat-work',
            matchedTaskId: 'task-adr',
            confidenceScore: 0.94,
            spokenPhrase: 'finish the planner ADR',
            estimateMinutes: 120,
          ),
          const MockParsedCaptureItem(
            id: kPlannerWorkflowParsedRunId,
            title: 'Morning run before standup',
            categoryId: 'cat-health',
            confidence: 'low',
            confidenceScore: 0.42,
            lowConfidence: true,
            spokenPhrase: 'fit in a morning run before standup',
            estimateMinutes: 40,
            timeAnchor: 'before standup',
          ),
        ],
      ),
    ],
    existingBlocks: [
      MockDayBlock(
        id: 'baseline-pr-review',
        categoryId: 'cat-work',
        start: DateTime(2026, 6, 9, 8),
        end: DateTime(2026, 6, 9, 8, 45),
        taskId: 'task-adr',
        title: 'Existing ADR review block',
        note: 'Seeded baseline block for eval context.',
      ),
    ],
  ),
  userInput: const UserInput(
    transcript: 'Finish the planner ADR and fit in a morning run.',
    triggerTokens: {
      'drafting:$kPlannerWorkflowDayId',
      'capture_submitted:$kPlannerWorkflowCaptureId',
      'decided_capture_item:$kPlannerWorkflowParsedRunId',
    },
  ),
  expectations: const EvalExpectations(mustCallTools: {'draft_day_plan'}),
);

final plannerCaptureOnlyScenario = EvalScenario(
  id: 'planner_capture_only_parse',
  title: 'Capture-only wake parses transcript without a day token',
  agentKind: AgentKind.planningAgent,
  metadata: const EvalScenarioMetadata(
    capabilityIds: ['planner.capture.parseonly'],
    tags: {'planner', 'capture', 'parse'},
  ),
  appState: MockedAppState(
    now: DateTime(2026, 6, 10, 7),
    categoryIds: const ['cat-work', 'cat-health'],
    tasks: [
      MockTask(
        id: 'task-adr-capture',
        title: 'Finish the planner ADR',
        status: 'OPEN',
        due: DateTime(2026, 6, 10),
        estimateMinutes: 90,
        categoryId: 'cat-work',
      ),
    ],
    captures: [
      MockCapture(
        id: kPlannerCaptureOnlyCaptureId,
        transcript:
            'Today I need to finish the planner ADR and take a quick walk.',
        capturedAt: DateTime(2026, 6, 10, 7),
        dayId: kPlannerCaptureOnlyDayId,
      ),
    ],
  ),
  userInput: const UserInput(
    transcript: 'Finish the planner ADR and take a quick walk.',
    triggerTokens: {'capture_submitted:$kPlannerCaptureOnlyCaptureId'},
  ),
  expectations: const EvalExpectations(
    mustCallTools: {'parse_capture_to_items'},
  ),
);

final EvalScenario
plannerWorkflowAmbiguousCarryoverScenario = _reviewedScenario(
  EvalScenario(
    id: 'planner_workflow_ambiguous_carryover',
    title:
        'Real workflow: resolve ambiguous carry-over without stale admin work',
    agentKind: AgentKind.planningAgent,
    metadata: const EvalScenarioMetadata(
      capabilityIds: [
        'planner.drafting.ambiguity',
        'planner.drafting.stalestate',
      ],
      split: EvalScenarioSplit.canary,
      source: EvalScenarioSource.adversarial,
      isAdversarial: true,
      tags: {
        'planner',
        'workflow',
        'adversarial',
        'ambiguous-reference',
        'scope-boundary',
        'stale-state',
      },
    ),
    appState: MockedAppState(
      now: DateTime(2026, 6, 11, 7),
      capacityMinutes: 180,
      categoryIds: const ['cat-work', 'cat-admin'],
      tasks: [
        MockTask(
          id: 'task-client-review',
          title: 'Client review follow-up',
          status: 'OPEN',
          due: DateTime(2026, 6, 11),
          estimateMinutes: 60,
          categoryId: 'cat-work',
        ),
        const MockTask(
          id: 'task-admin-followup',
          title: 'Old admin follow-up',
          status: 'OPEN',
          estimateMinutes: 30,
          categoryId: 'cat-admin',
        ),
        const MockTask(
          id: 'task-inbox-triage',
          title: 'Inbox triage',
          status: 'OPEN',
          estimateMinutes: 30,
          categoryId: 'cat-admin',
        ),
      ],
      existingBlocks: [
        MockDayBlock(
          id: 'stale-admin-followup',
          categoryId: 'cat-admin',
          start: DateTime(2026, 6, 10, 16),
          end: DateTime(2026, 6, 10, 16, 30),
          taskId: 'task-admin-followup',
          title: 'Old admin follow-up',
          note: 'Yesterday-only block; user says this was handled offline.',
        ),
      ],
    ),
    userInput: const UserInput(
      transcript:
          'For today, put the client review where the follow-up was. '
          'Do not bring back the old admin follow-up; I already handled it.',
      triggerTokens: {'drafting:$kPlannerAmbiguousCarryoverDayId'},
    ),
    expectations: const EvalExpectations(
      mustCallTools: {'draft_day_plan'},
      durableState: ExpectedDurableState(
        plannedBlockCount: 1,
        requiredPlannedBlocks: [
          ExpectedPlannedBlockState(
            taskId: 'task-client-review',
            categoryId: 'cat-work',
            minDurationMinutes: 45,
            maxDurationMinutes: 90,
          ),
        ],
        forbiddenPlannedBlocks: [
          ExpectedPlannedBlockState(taskId: 'task-admin-followup'),
        ],
      ),
    ),
  ),
  rationale:
      'Reviewed as a public adversarial planner case for ambiguous references, '
      'scope boundaries, and stale state suppression.',
);

final EvalScenario plannerWorkflowFocusBoundaryScenario = _reviewedScenario(
  EvalScenario(
    id: 'planner_workflow_focus_boundary',
    title:
        'Real workflow: preserve fixed appointment while scheduling focus work',
    agentKind: AgentKind.planningAgent,
    metadata: const EvalScenarioMetadata(
      capabilityIds: [
        'planner.drafting.scopeboundary',
        'planner.drafting.stalestate',
      ],
      split: EvalScenarioSplit.canary,
      source: EvalScenarioSource.adversarial,
      isAdversarial: true,
      tags: {
        'planner',
        'workflow',
        'adversarial',
        'scope-boundary',
        'stale-state',
      },
    ),
    appState: MockedAppState(
      now: DateTime(2026, 6, 12, 7),
      capacityMinutes: 180,
      categoryIds: const ['cat-work', 'cat-health'],
      tasks: [
        MockTask(
          id: 'task-client-brief',
          title: 'Prepare client brief',
          status: 'OPEN',
          due: DateTime(2026, 6, 12),
          estimateMinutes: 75,
          categoryId: 'cat-work',
        ),
        const MockTask(
          id: 'task-doctor-appointment',
          title: 'Doctor appointment',
          status: 'OPEN',
          estimateMinutes: 60,
          categoryId: 'cat-health',
        ),
      ],
      existingBlocks: [
        MockDayBlock(
          id: 'fixed-doctor-appointment',
          categoryId: 'cat-health',
          start: DateTime(2026, 6, 12, 10),
          end: DateTime(2026, 6, 12, 11),
          taskId: 'task-doctor-appointment',
          title: 'Doctor appointment',
          note: 'Fixed calendar commitment; do not move.',
        ),
      ],
    ),
    userInput: const UserInput(
      transcript:
          'Schedule the client brief today, but do not move the doctor '
          'appointment at 10. Keep that appointment intact.',
      triggerTokens: {'drafting:$kPlannerFocusBoundaryDayId'},
    ),
    expectations: const EvalExpectations(
      mustCallTools: {'draft_day_plan'},
      durableState: ExpectedDurableState(
        plannedBlockCount: 2,
        requiredPlannedBlocks: [
          ExpectedPlannedBlockState(
            id: 'fixed-doctor-appointment',
            taskId: 'task-doctor-appointment',
            categoryId: 'cat-health',
            minDurationMinutes: 60,
            maxDurationMinutes: 60,
          ),
          ExpectedPlannedBlockState(
            taskId: 'task-client-brief',
            categoryId: 'cat-work',
            minDurationMinutes: 60,
            maxDurationMinutes: 90,
          ),
        ],
      ),
    ),
  ),
  rationale:
      'Reviewed as a public adversarial planner case for preserving fixed '
      'state while satisfying a new scheduling request.',
);

final EvalScenario plannerCaptureAmbiguousPersonScenario = _reviewedScenario(
  EvalScenario(
    id: 'planner_capture_ambiguous_person',
    title: 'Real workflow: parse ambiguous person reference as low confidence',
    agentKind: AgentKind.planningAgent,
    metadata: const EvalScenarioMetadata(
      capabilityIds: ['planner.capture.ambiguity'],
      split: EvalScenarioSplit.canary,
      source: EvalScenarioSource.adversarial,
      isAdversarial: true,
      tags: {
        'planner',
        'workflow',
        'capture',
        'adversarial',
        'ambiguous-reference',
        'scope-boundary',
      },
    ),
    appState: MockedAppState(
      now: DateTime(2026, 6, 13, 7),
      categoryIds: const ['cat-work', 'cat-admin'],
      tasks: const [
        MockTask(
          id: 'task-sam-invoice',
          title: 'Send Sam the invoice',
          status: 'OPEN',
          estimateMinutes: 20,
          categoryId: 'cat-admin',
        ),
        MockTask(
          id: 'task-samantha-feedback',
          title: "Review Samantha's design feedback",
          status: 'OPEN',
          estimateMinutes: 45,
          categoryId: 'cat-work',
        ),
      ],
      captures: [
        MockCapture(
          id: kPlannerAmbiguousCaptureId,
          transcript: 'Call Sam about the thing after lunch.',
          capturedAt: DateTime(2026, 6, 13, 7),
          dayId: kPlannerAmbiguousCaptureDayId,
        ),
      ],
    ),
    userInput: const UserInput(
      transcript: 'Call Sam about the thing after lunch.',
      triggerTokens: {'capture_submitted:$kPlannerAmbiguousCaptureId'},
    ),
    expectations: const EvalExpectations(
      mustCallTools: {'parse_capture_to_items'},
      durableState: ExpectedDurableState(
        parsedCaptureItemCount: 1,
        requiredParsedCaptureItems: [
          ExpectedParsedCaptureState(
            captureId: kPlannerAmbiguousCaptureId,
            kind: 'newTask',
            titleContains: 'Call Sam',
            categoryId: 'cat-admin',
            confidence: 'low',
            maxConfidenceScore: 0.5,
            lowConfidence: false,
          ),
        ],
        forbiddenParsedCaptureItems: [
          ExpectedParsedCaptureState(matchedTaskId: 'task-sam-invoice'),
          ExpectedParsedCaptureState(matchedTaskId: 'task-samantha-feedback'),
        ],
      ),
    ),
  ),
  rationale:
      'Reviewed as a public adversarial planner capture case for ambiguous '
      'person references that should remain low-confidence instead of binding '
      'to the wrong existing task.',
);

final taskReleaseNotesScenario = EvalScenario(
  id: 'task_release_notes',
  title: 'Groom release-notes task: estimate, status, checklist, labels',
  agentKind: AgentKind.taskAgent,
  metadata: const EvalScenarioMetadata(
    capabilityIds: ['task.grooming.basic'],
    tags: {'task', 'grooming', 'smoke'},
  ),
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
  metadata: const EvalScenarioMetadata(
    capabilityIds: ['task.grooming.labels'],
    tags: {'task', 'workflow', 'labels'},
  ),
  appState: MockedAppState(
    now: DateTime(2026, 6, 9, 9),
    categoryIds: const ['cat-001'],
    categories: [kEvalWorkCategory, kEvalAdminCategory],
    labels: const [
      kEvalReleaseLabel,
      kEvalAssignedLabel,
      kEvalSuppressedLabel,
      kEvalOutOfScopeLabel,
    ],
    tasks: const [
      MockTask(
        id: 'task-notes',
        title: 'Write release notes for 0.x',
        status: 'IN PROGRESS',
        categoryId: 'cat-001',
        labelIds: ['lbl-docs'],
        aiSuppressedLabelIds: {'lbl-legal'},
        checklist: [MockChecklistItem(id: 'ci-1', title: 'Draft summary')],
      ),
    ],
  ),
  userInput: const UserInput(
    transcript: 'Help me get the release notes ready.',
    triggerTokens: {'decided_task:task-notes'},
  ),
);

final EvalScenario taskWorkflowStructuredUpdateScenario = _reviewedScenario(
  EvalScenario(
    id: 'task_workflow_structured_update',
    title:
        'Real workflow: extract due date, priority, estimate, labels, checklist',
    agentKind: AgentKind.taskAgent,
    metadata: const EvalScenarioMetadata(
      capabilityIds: [
        'task.grooming.structuredfields',
        'task.labels.scopeboundary',
      ],
      split: EvalScenarioSplit.canary,
      tags: {
        'task',
        'workflow',
        'structured-fields',
        'relative-date',
        'priority',
        'estimate',
        'labels',
        'checklist',
      },
    ),
    appState: MockedAppState(
      now: DateTime(2026, 6, 10, 9),
      categoryIds: const ['cat-001'],
      categories: [kEvalWorkCategory, kEvalAdminCategory],
      labels: const [
        kEvalReleaseLabel,
        kEvalAssignedLabel,
        kEvalSuppressedLabel,
        kEvalOutOfScopeLabel,
      ],
      tasks: const [
        MockTask(
          id: 'task-launch',
          title: 'Prepare launch follow-up',
          status: 'OPEN',
          categoryId: 'cat-001',
          aiSuppressedLabelIds: {'lbl-legal'},
          checklist: [
            MockChecklistItem(id: 'ci-existing', title: 'Draft outline'),
          ],
        ),
      ],
    ),
    userInput: const UserInput(
      transcript:
          'For the launch follow-up, make it due tomorrow, mark priority P1, '
          'estimate 45 minutes, tag it as release work, and add checklist '
          'items: write the customer update, confirm screenshots, and send '
          'to Sam.',
      triggerTokens: {'decided_task:task-launch'},
    ),
    expectations: const EvalExpectations(
      mustCallTools: {
        'update_report',
        'update_task_due_date',
        'update_task_priority',
        'update_task_estimate',
        'assign_task_labels',
        'add_multiple_checklist_items',
      },
      requiredToolCalls: [
        ExpectedToolCallState(
          toolName: 'update_task_due_date',
          argsContain: {'dueDate': '2026-06-11'},
        ),
        ExpectedToolCallState(
          toolName: 'update_task_priority',
          argsContain: {'priority': 'P1'},
        ),
        ExpectedToolCallState(
          toolName: 'update_task_estimate',
          argsContain: {'minutes': 45},
        ),
        ExpectedToolCallState(
          toolName: 'assign_task_labels',
          argsContain: {
            'labels': [
              {'id': 'lbl-release', 'confidence': 'high'},
            ],
          },
        ),
        ExpectedToolCallState(
          toolName: 'add_multiple_checklist_items',
          argsContain: {
            'items': [
              {'title': 'Write the customer update'},
              {'title': 'Confirm screenshots'},
              {'title': 'Send to Sam'},
            ],
          },
        ),
      ],
      forbiddenToolCalls: [
        ExpectedToolCallState(
          toolName: 'assign_task_labels',
          argsContain: {
            'labels': [
              {'id': 'lbl-docs'},
            ],
          },
        ),
        ExpectedToolCallState(
          toolName: 'assign_task_labels',
          argsContain: {
            'labels': [
              {'id': 'lbl-legal'},
            ],
          },
        ),
        ExpectedToolCallState(
          toolName: 'assign_task_labels',
          argsContain: {
            'labels': [
              {'id': 'lbl-admin'},
            ],
          },
        ),
        ExpectedToolCallState(
          toolName: 'add_multiple_checklist_items',
          argsContain: {
            'items': [
              {'title': 'Draft outline'},
            ],
          },
        ),
      ],
      durableState: ExpectedDurableState(
        proposalCount: 7,
        requiredProposals: [
          ExpectedProposalState(
            toolName: 'update_task_due_date',
            targetId: 'task-launch',
            status: 'pending',
            argsContain: {'dueDate': '2026-06-11'},
          ),
          ExpectedProposalState(
            toolName: 'update_task_priority',
            targetId: 'task-launch',
            status: 'pending',
            argsContain: {'priority': 'P1'},
          ),
          ExpectedProposalState(
            toolName: 'update_task_estimate',
            targetId: 'task-launch',
            status: 'pending',
            argsContain: {'minutes': 45},
          ),
          ExpectedProposalState(
            toolName: 'assign_task_label',
            targetId: 'task-launch',
            status: 'pending',
            argsContain: {'id': 'lbl-release', 'confidence': 'high'},
          ),
          ExpectedProposalState(
            toolName: 'add_checklist_item',
            targetId: 'task-launch',
            status: 'pending',
            argsContain: {'title': 'Write the customer update'},
          ),
          ExpectedProposalState(
            toolName: 'add_checklist_item',
            targetId: 'task-launch',
            status: 'pending',
            argsContain: {'title': 'Confirm screenshots'},
          ),
          ExpectedProposalState(
            toolName: 'add_checklist_item',
            targetId: 'task-launch',
            status: 'pending',
            argsContain: {'title': 'Send to Sam'},
          ),
        ],
        forbiddenProposals: [
          ExpectedProposalState(argsContain: {'id': 'lbl-docs'}),
          ExpectedProposalState(argsContain: {'id': 'lbl-legal'}),
          ExpectedProposalState(argsContain: {'id': 'lbl-admin'}),
          ExpectedProposalState(
            toolName: 'add_checklist_item',
            argsContain: {'title': 'Draft outline'},
          ),
        ],
      ),
    ),
  ),
  rationale:
      'Reviewed as a public hand-authored task-agent case for deterministic '
      'relative-date extraction, priority/estimate updates, in-scope label '
      'selection, and checklist proposal creation.',
);

final EvalScenario taskWorkflowReportRecoveryScenario = _reviewedScenario(
  EvalScenario(
    id: 'task_workflow_report_recovery',
    title: 'Real workflow: recover after an invalid report tool call',
    agentKind: AgentKind.taskAgent,
    metadata: const EvalScenarioMetadata(
      capabilityIds: ['task.reporting.toolrecovery'],
      split: EvalScenarioSplit.canary,
      source: EvalScenarioSource.adversarial,
      isAdversarial: true,
      tags: {
        'task',
        'workflow',
        'report',
        'adversarial',
        'tool-recovery',
      },
    ),
    appState: MockedAppState(
      now: DateTime(2026, 6, 9, 9, 45),
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
      transcript:
          'Update the release-note task and recover cleanly if a report draft '
          'is rejected.',
      triggerTokens: {'decided_task:task-notes'},
    ),
    expectations: const EvalExpectations(
      mustCallTools: {'update_report'},
      allowedFailedToolNames: {'update_report'},
      maxAllowedToolResultFailures: 1,
      durableState: ExpectedDurableState(
        reportContains: {'Recovered release-note report'},
      ),
    ),
  ),
  rationale:
      'Reviewed as a public adversarial task-agent case for bounded recovery '
      'after a failed report tool result.',
);

final EvalScenario taskWorkflowLabelScopeBoundaryScenario = _reviewedScenario(
  EvalScenario(
    id: 'task_workflow_label_scope_boundary',
    title: 'Real workflow: assign only in-scope, unsuppressed labels',
    agentKind: AgentKind.taskAgent,
    metadata: const EvalScenarioMetadata(
      capabilityIds: ['task.labels.scopeboundary'],
      split: EvalScenarioSplit.canary,
      source: EvalScenarioSource.adversarial,
      isAdversarial: true,
      tags: {
        'task',
        'workflow',
        'labels',
        'adversarial',
        'scope-boundary',
        'stale-state',
      },
    ),
    appState: MockedAppState(
      now: DateTime(2026, 6, 9, 11),
      categoryIds: const ['cat-001'],
      categories: [kEvalWorkCategory, kEvalAdminCategory],
      labels: const [
        kEvalReleaseLabel,
        kEvalAssignedLabel,
        kEvalSuppressedLabel,
        kEvalOutOfScopeLabel,
      ],
      tasks: const [
        MockTask(
          id: 'task-notes',
          title: 'Write release notes for 0.x',
          status: 'IN PROGRESS',
          categoryId: 'cat-001',
          labelIds: ['lbl-docs'],
          aiSuppressedLabelIds: {'lbl-legal'},
          checklist: [MockChecklistItem(id: 'ci-1', title: 'Draft summary')],
        ),
      ],
    ),
    userInput: const UserInput(
      transcript:
          'Tag this as release work. Do not add admin or legal labels, and '
          'do not duplicate labels that are already on the task.',
      triggerTokens: {'decided_task:task-notes'},
    ),
    expectations: const EvalExpectations(
      mustCallTools: {'update_report', 'assign_task_labels'},
      durableState: ExpectedDurableState(
        proposalCount: 1,
        requiredProposals: [
          ExpectedProposalState(
            toolName: 'assign_task_label',
            targetId: 'task-notes',
            status: 'pending',
            argsContain: {'id': 'lbl-release', 'confidence': 'high'},
            humanSummaryContains: {'Release Notes', 'high'},
          ),
        ],
        forbiddenProposals: [
          ExpectedProposalState(argsContain: {'id': 'lbl-docs'}),
          ExpectedProposalState(argsContain: {'id': 'lbl-legal'}),
          ExpectedProposalState(argsContain: {'id': 'lbl-admin'}),
        ],
      ),
    ),
  ),
  rationale:
      'Reviewed as a public adversarial task-agent case for label scope, '
      'suppressed-label memory, and already-assigned label suppression.',
);

final EvalScenario taskWorkflowCompletionBoundaryScenario = _reviewedScenario(
  EvalScenario(
    id: 'task_workflow_completion_boundary',
    title: 'Real workflow: add approval note without changing status',
    agentKind: AgentKind.taskAgent,
    metadata: const EvalScenarioMetadata(
      capabilityIds: ['task.status.scopeboundary'],
      split: EvalScenarioSplit.canary,
      source: EvalScenarioSource.adversarial,
      isAdversarial: true,
      tags: {
        'task',
        'workflow',
        'status',
        'adversarial',
        'scope-boundary',
      },
    ),
    appState: MockedAppState(
      now: DateTime(2026, 6, 9, 11, 30),
      categoryIds: const ['cat-001'],
      categories: [kEvalWorkCategory],
      tasks: const [
        MockTask(
          id: 'task-approval',
          title: 'Prepare release approval',
          status: 'IN PROGRESS',
          categoryId: 'cat-001',
          checklist: [
            MockChecklistItem(id: 'ci-approval', title: 'Draft approval note'),
          ],
        ),
      ],
    ),
    userInput: const UserInput(
      transcript:
          'This is ready for my review, but do not change the status yet. '
          'Add an approval-note checklist item so I can approve it later.',
      triggerTokens: {'decided_task:task-approval'},
    ),
    expectations: const EvalExpectations(
      mustCallTools: {'update_report', 'add_multiple_checklist_items'},
      mustNotCallTools: {'set_task_status'},
      durableState: ExpectedDurableState(
        proposalCount: 1,
        requiredProposals: [
          ExpectedProposalState(
            toolName: 'add_checklist_item',
            targetId: 'task-approval',
            status: 'pending',
            argsContain: {'title': 'Prepare approval note'},
            humanSummaryContains: {'Prepare approval note'},
          ),
        ],
        reportContains: {'Ready for approval'},
      ),
    ),
  ),
  rationale:
      'Reviewed as a public adversarial task-agent case for respecting '
      'status-change boundaries while still producing a concrete next-step '
      'proposal.',
);

final taskWorkflowPendingProposalMergeScenario = EvalScenario(
  id: 'task_workflow_pending_proposal_merge',
  title: 'Real workflow: consolidate existing pending proposals',
  agentKind: AgentKind.taskAgent,
  metadata: const EvalScenarioMetadata(
    capabilityIds: ['task.proposals.mergepending'],
    tags: {'task', 'workflow', 'proposals'},
  ),
  appState: MockedAppState(
    now: DateTime(2026, 6, 9, 9, 30),
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
    proposalSets: [
      MockProposalSet(
        id: 'existing-old',
        createdAt: DateTime(2026, 6, 9, 9, 5),
        items: const [
          MockProposalItem(
            toolName: 'add_checklist_item',
            args: {'title': 'Review changelog'},
            humanSummary: 'Add: "Review changelog"',
          ),
        ],
      ),
      MockProposalSet(
        id: 'existing-new',
        createdAt: DateTime(2026, 6, 9, 9, 10),
        items: const [
          MockProposalItem(
            toolName: 'add_checklist_item',
            args: {'title': 'Check smoke tests'},
            humanSummary: 'Add: "Check smoke tests"',
          ),
        ],
      ),
    ],
  ),
  userInput: const UserInput(
    transcript:
        'Review the pending release-note suggestions and add anything missing.',
    triggerTokens: {'decided_task:task-notes'},
  ),
);

final EvalScenario
taskWorkflowRejectedProposalStickinessScenario = _reviewedScenario(
  EvalScenario(
    id: 'task_workflow_rejected_proposal_stickiness',
    title: 'Real workflow: do not repropose rejected checklist item',
    agentKind: AgentKind.taskAgent,
    metadata: const EvalScenarioMetadata(
      capabilityIds: ['task.proposals.rejectedhistory'],
      split: EvalScenarioSplit.canary,
      source: EvalScenarioSource.adversarial,
      isAdversarial: true,
      tags: {
        'task',
        'workflow',
        'proposals',
        'adversarial',
        'scope-boundary',
        'stale-state',
      },
    ),
    appState: MockedAppState(
      now: DateTime(2026, 6, 9, 10),
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
      proposalSets: [
        MockProposalSet(
          id: 'rejected-legal-review',
          status: 'resolved',
          createdAt: DateTime(2026, 6, 9, 9, 35),
          resolvedAt: DateTime(2026, 6, 9, 9, 40),
          items: const [
            MockProposalItem(
              toolName: 'add_checklist_item',
              args: {'title': 'Legal review'},
              humanSummary: 'Add: "Legal review"',
              status: 'rejected',
            ),
          ],
        ),
      ],
      proposalDecisions: [
        MockProposalDecision(
          id: 'decision-reject-legal-review',
          changeSetId: 'rejected-legal-review',
          itemIndex: 0,
          toolName: 'add_checklist_item',
          verdict: 'rejected',
          createdAt: DateTime(2026, 6, 9, 9, 40),
          reason: 'Not needed for this release.',
          humanSummary: 'Add: "Legal review"',
          args: const {'title': 'Legal review'},
        ),
      ],
    ),
    userInput: const UserInput(
      transcript:
          'Keep grooming the release-note task, but respect earlier rejected '
          'suggestions.',
      triggerTokens: {'decided_task:task-notes'},
    ),
    expectations: const EvalExpectations(
      durableState: ExpectedDurableState(
        proposalCount: 1,
        requiredProposals: [
          ExpectedProposalState(
            toolName: 'add_checklist_item',
            status: 'rejected',
            changeSetStatus: 'resolved',
            argsContain: {'title': 'Legal review'},
            humanSummaryContains: {'Legal review'},
          ),
        ],
        forbiddenProposals: [
          ExpectedProposalState(
            status: 'pending',
            argsContain: {'title': 'Legal review'},
          ),
        ],
      ),
    ),
  ),
  rationale:
      'Reviewed as a public adversarial task-agent case for scope boundaries '
      'and stale rejected-history suppression.',
);

final EvalScenario taskWorkflowCheckedChecklistNoopScenario = _reviewedScenario(
  EvalScenario(
    id: 'task_workflow_checked_checklist_noop',
    title: 'Real workflow: suppress already-checked checklist update',
    agentKind: AgentKind.taskAgent,
    metadata: const EvalScenarioMetadata(
      capabilityIds: ['task.checklist.noopsuppression'],
      split: EvalScenarioSplit.canary,
      source: EvalScenarioSource.adversarial,
      isAdversarial: true,
      tags: {
        'task',
        'workflow',
        'checklist',
        'adversarial',
        'stale-state',
      },
    ),
    appState: MockedAppState(
      now: DateTime(2026, 6, 9, 10, 30),
      categoryIds: const ['cat-001'],
      tasks: const [
        MockTask(
          id: 'task-notes',
          title: 'Write release notes for 0.x',
          status: 'IN PROGRESS',
          categoryId: 'cat-001',
          checklist: [
            MockChecklistItem(
              id: 'ci-1',
              title: 'Draft summary',
              isChecked: true,
            ),
          ],
        ),
      ],
    ),
    userInput: const UserInput(
      transcript:
          'Review the release-note checklist and avoid proposing work that is '
          'already done.',
      triggerTokens: {'decided_task:task-notes'},
    ),
    expectations: const EvalExpectations(
      durableState: ExpectedDurableState(proposalCount: 0),
    ),
  ),
  rationale:
      'Reviewed as a public adversarial task-agent case for stale-state no-op '
      'suppression on already-checked checklist work.',
);

final EvalScenario taskWorkflowChecklistTranscriptCascadeScenario =
    _reviewedScenario(
      EvalScenario(
        id: 'task_workflow_checklist_transcript_cascade',
        title:
            'Real workflow: incremental transcripts update one checklist item',
        agentKind: AgentKind.taskAgent,
        metadata: const EvalScenarioMetadata(
          capabilityIds: [
            'task.checklist.transcriptcascade',
            'task.cache.stableprefix',
          ],
          split: EvalScenarioSplit.canary,
          tags: {
            'task',
            'workflow',
            'checklist',
            'transcript',
            'cascade',
            'cache',
          },
        ),
        appState: MockedAppState(
          now: DateTime(2026, 6, 10, 11),
          categoryIds: const ['cat-001'],
          categories: [kEvalWorkCategory],
          tasks: const [
            MockTask(
              id: 'task-redesign',
              title: 'Ship notification redesign',
              status: 'IN PROGRESS',
              categoryId: 'cat-001',
              checklist: [
                MockChecklistItem(
                  id: 'ci-pr',
                  title: 'Create pull request',
                ),
                MockChecklistItem(
                  id: 'ci-review',
                  title: 'Address review feedback',
                ),
                MockChecklistItem(
                  id: 'ci-release',
                  title: 'Prepare release note',
                ),
              ],
            ),
          ],
          taskLogEntries: [
            MockTaskLogEntry(
              id: 'audio-redesign-estimate',
              taskId: 'task-redesign',
              transcript:
                  'The remaining notification redesign work is about two '
                  'hours.',
              createdAt: DateTime(2026, 6, 10, 10, 10),
            ),
            MockTaskLogEntry(
              id: 'audio-redesign-pr-open',
              taskId: 'task-redesign',
              transcript:
                  'I created the pull request. That checks off the Create '
                  'pull request item, but review feedback is not done yet.',
              createdAt: DateTime(2026, 6, 10, 10, 40),
            ),
            MockTaskLogEntry(
              id: 'audio-redesign-review-pending',
              taskId: 'task-redesign',
              transcript:
                  'I still need to address review feedback and write the '
                  'release note.',
              createdAt: DateTime(2026, 6, 10, 10, 55),
            ),
          ],
        ),
        userInput: const UserInput(
          transcript:
              'Wake the task agent after each short linked audio transcript.',
          triggerTokens: {'decided_task:task-redesign'},
        ),
        expectations: const EvalExpectations(
          mustNotCallTools: {'set_task_status'},
          cascadeWakes: [
            ExpectedCascadeWakeState(
              wakeIndex: 0,
              durableState: ExpectedDurableState(
                requiredProposals: [
                  ExpectedProposalState(
                    toolName: 'update_task_estimate',
                    targetId: 'task-redesign',
                    status: 'pending',
                    argsContain: {'minutes': 120},
                  ),
                ],
              ),
            ),
            ExpectedCascadeWakeState(
              wakeIndex: 1,
              requiredToolCalls: [
                ExpectedToolCallState(
                  toolName: 'update_checklist_items',
                  argsContain: {
                    'items': [
                      {'id': 'ci-pr', 'isChecked': true},
                    ],
                  },
                ),
              ],
              durableState: ExpectedDurableState(
                requiredProposals: [
                  ExpectedProposalState(
                    toolName: 'update_task_estimate',
                    targetId: 'task-redesign',
                    status: 'pending',
                    argsContain: {'minutes': 120},
                  ),
                  ExpectedProposalState(
                    toolName: 'update_checklist_item',
                    targetId: 'task-redesign',
                    status: 'pending',
                    argsContain: {'id': 'ci-pr', 'isChecked': true},
                  ),
                ],
                forbiddenProposals: [
                  ExpectedProposalState(
                    toolName: 'update_checklist_item',
                    argsContain: {'id': 'ci-review', 'isChecked': true},
                  ),
                  ExpectedProposalState(
                    toolName: 'update_checklist_item',
                    argsContain: {'id': 'ci-release', 'isChecked': true},
                  ),
                ],
              ),
            ),
            ExpectedCascadeWakeState(
              wakeIndex: 2,
              durableState: ExpectedDurableState(
                requiredProposals: [
                  ExpectedProposalState(
                    toolName: 'update_task_estimate',
                    targetId: 'task-redesign',
                    status: 'pending',
                    argsContain: {'minutes': 120},
                  ),
                  ExpectedProposalState(
                    toolName: 'update_checklist_item',
                    targetId: 'task-redesign',
                    status: 'pending',
                    argsContain: {'id': 'ci-pr', 'isChecked': true},
                  ),
                ],
                forbiddenProposals: [
                  ExpectedProposalState(
                    toolName: 'update_checklist_item',
                    argsContain: {'id': 'ci-review', 'isChecked': true},
                  ),
                  ExpectedProposalState(
                    toolName: 'update_checklist_item',
                    argsContain: {'id': 'ci-release', 'isChecked': true},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      rationale:
          'Reviewed as a public same-task task-agent cascade case: short '
          'linked audio transcripts should add narrow checklist evidence while '
          'the broader task remains in progress.',
    );

final allEvalScenarios = <EvalScenario>[
  plannerMorningCapacityScenario,
  plannerWorkflowDraftingScenario,
  plannerCaptureOnlyScenario,
  plannerWorkflowAmbiguousCarryoverScenario,
  plannerWorkflowFocusBoundaryScenario,
  plannerCaptureAmbiguousPersonScenario,
  taskReleaseNotesScenario,
  taskWorkflowReleaseNotesScenario,
  taskWorkflowStructuredUpdateScenario,
  taskWorkflowReportRecoveryScenario,
  taskWorkflowLabelScopeBoundaryScenario,
  taskWorkflowCompletionBoundaryScenario,
  taskWorkflowPendingProposalMergeScenario,
  taskWorkflowRejectedProposalStickinessScenario,
  taskWorkflowCheckedChecklistNoopScenario,
  taskWorkflowChecklistTranscriptCascadeScenario,
];

final List<EvalScenario> planningEvalScenarios = allEvalScenarios
    .where((scenario) => scenario.agentKind == AgentKind.planningAgent)
    .toList(growable: false);

final List<EvalScenario> taskEvalScenarios = allEvalScenarios
    .where((scenario) => scenario.agentKind == AgentKind.taskAgent)
    .toList(growable: false);
