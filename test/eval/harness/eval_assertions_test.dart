import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';

import '../scenarios/eval_scenarios.dart';
import 'eval_harness.dart';

void main() {
  test(
    'durable-state oracle matches task proposals, reports, and mutations',
    () {
      final scenario = _withExpectations(
        taskWorkflowReleaseNotesScenario,
        const EvalExpectations(
          durableState: ExpectedDurableState(
            reportContains: {'release notes'},
            allowedMutatedEntryIds: {'task-notes'},
            requiredMutatedEntryIds: {'task-notes'},
            forbiddenMutatedEntryIds: {'task-other'},
            requiredProposals: [
              ExpectedProposalState(
                toolName: 'assign_task_label',
                targetId: 'task-notes',
                status: 'pending',
                argsContain: {'id': 'lbl-release'},
                humanSummaryContains: {'Release Notes'},
              ),
            ],
            forbiddenProposals: [
              ExpectedProposalState(
                toolName: 'add_checklist_item',
                argsContain: {'title': 'Legal review'},
              ),
            ],
          ),
        ),
      );

      final checks = runLevel1(
        scenario,
        const AgentRunOutput(
          success: true,
          usage: InferenceUsage(inputTokens: 800, outputTokens: 120),
          report: AgentReportRecord(
            oneLiner: 'Prepared release notes',
            tldr: 'The release notes task now has a useful label.',
          ),
          proposals: [
            ProposalRecord(
              changeSetId: 'cs-label',
              changeSetStatus: 'pending',
              targetId: 'task-notes',
              itemIndex: 0,
              toolName: 'assign_task_label',
              args: {'id': 'lbl-release'},
              humanSummary: 'Assign Release Notes label',
              status: 'pending',
            ),
          ],
          mutatedEntryIds: {'task-notes'},
        ),
        profile: kLocalOllamaProfile,
      );

      expect(_named(checks, 'expected_durable_state').passed, isTrue);
    },
  );

  test('durable-state oracle reports missing and forbidden task state', () {
    final scenario = _withExpectations(
      taskWorkflowReleaseNotesScenario,
      const EvalExpectations(
        requiredToolCalls: [
          ExpectedToolCallState(
            toolName: 'assign_task_labels',
            argsContain: {
              'labels': [
                {'id': 'lbl-release', 'confidence': 'high'},
              ],
            },
          ),
        ],
        forbiddenToolCalls: [
          ExpectedToolCallState(
            toolName: 'assign_task_labels',
            argsContain: {
              'labels': [
                {'id': 'lbl-legal'},
              ],
            },
          ),
        ],
        durableState: ExpectedDurableState(
          reportContains: {'release notes'},
          allowedMutatedEntryIds: {'task-notes'},
          requiredMutatedEntryIds: {'task-notes'},
          requiredProposals: [
            ExpectedProposalState(
              toolName: 'assign_task_label',
              targetId: 'task-notes',
              argsContain: {'id': 'lbl-release'},
            ),
          ],
          forbiddenProposals: [
            ExpectedProposalState(
              toolName: 'add_checklist_item',
              argsContain: {'title': 'Legal review'},
            ),
          ],
        ),
      ),
    );

    final checks = runLevel1(
      scenario,
      const AgentRunOutput(
        success: true,
        usage: InferenceUsage(inputTokens: 800, outputTokens: 120),
        report: AgentReportRecord(
          oneLiner: 'Handled',
          tldr: 'No relevant durable task state was produced.',
        ),
        proposals: [
          ProposalRecord(
            changeSetId: 'cs-forbidden',
            changeSetStatus: 'pending',
            targetId: 'task-notes',
            itemIndex: 0,
            toolName: 'add_checklist_item',
            args: {'title': 'Legal review'},
            humanSummary: 'Add Legal review',
            status: 'pending',
          ),
        ],
        mutatedEntryIds: {'task-other'},
      ),
      profile: kLocalOllamaProfile,
    );

    final oracle = _named(checks, 'expected_durable_state');
    expect(oracle.passed, isFalse);
    expect(oracle.detail, contains('report missing'));
    expect(oracle.detail, contains('missing mutations: task-notes'));
    expect(oracle.detail, contains('unexpected mutations: task-other'));
    expect(oracle.detail, contains('missing distinct proposal expectations'));
    expect(oracle.detail, contains('forbidden proposal'));
  });

  test('durable-state required proposals consume distinct actual records', () {
    final scenario = _withExpectations(
      taskWorkflowReleaseNotesScenario,
      const EvalExpectations(
        durableState: ExpectedDurableState(
          requiredProposals: [
            ExpectedProposalState(
              toolName: 'assign_task_label',
              targetId: 'task-notes',
            ),
            ExpectedProposalState(
              toolName: 'assign_task_label',
              targetId: 'task-notes',
            ),
          ],
        ),
      ),
    );

    final checks = runLevel1(
      scenario,
      const AgentRunOutput(
        success: true,
        usage: InferenceUsage(inputTokens: 800, outputTokens: 120),
        report: AgentReportRecord(
          oneLiner: 'Prepared release notes',
          tldr: 'Prepared the task.',
        ),
        proposals: [
          ProposalRecord(
            changeSetId: 'cs-label',
            changeSetStatus: 'pending',
            targetId: 'task-notes',
            itemIndex: 0,
            toolName: 'assign_task_label',
            args: {'id': 'lbl-release'},
            humanSummary: 'Assign Release Notes label',
            status: 'pending',
          ),
        ],
      ),
      profile: kLocalOllamaProfile,
    );

    final oracle = _named(checks, 'expected_durable_state');
    expect(oracle.passed, isFalse);
    expect(oracle.detail, contains('missing distinct proposal expectations'));
  });

  test('scenario can allow bounded recoverable tool-result failures', () {
    final scenario = _withExpectations(
      plannerWorkflowDraftingScenario,
      const EvalExpectations(
        allowedFailedToolNames: {'propose_plan_diff'},
        maxAllowedToolResultFailures: 1,
      ),
    );

    final checks = runLevel1(
      scenario,
      AgentRunOutput(
        success: true,
        usage: const InferenceUsage(inputTokens: 800, outputTokens: 120),
        toolCalls: const [ToolCallRecord(name: 'draft_day_plan')],
        toolResults: const [
          ToolResultRecord(
            name: 'propose_plan_diff',
            success: false,
            error: '`to.end` must be after `to.start`',
          ),
        ],
        plannedBlocks: [
          PlannedBlockRecord(
            id: 'recovered-block',
            taskId: 'task-adr',
            categoryId: 'cat-work',
            start: DateTime(2026, 6, 9, 9),
            end: DateTime(2026, 6, 9, 10),
          ),
        ],
        plannedCapacityMinutes:
            plannerWorkflowDraftingScenario.appState.capacityMinutes,
      ),
      profile: kLocalOllamaProfile,
    );

    final toolResults = _named(checks, 'tool_results_succeeded');
    expect(toolResults.passed, isTrue);
    expect(toolResults.detail, contains('allowed recoverable failure'));
  });

  test('unexpected or excessive tool-result failures still fail', () {
    final scenario = _withExpectations(
      plannerWorkflowDraftingScenario,
      const EvalExpectations(
        allowedFailedToolNames: {'draft_day_plan'},
        maxAllowedToolResultFailures: 1,
      ),
    );

    final checks = runLevel1(
      scenario,
      const AgentRunOutput(
        success: true,
        usage: InferenceUsage(inputTokens: 800, outputTokens: 120),
        toolCalls: [ToolCallRecord(name: 'draft_day_plan')],
        toolResults: [
          ToolResultRecord(
            name: 'propose_plan_diff',
            success: false,
            error: '`to.end` must be after `to.start`',
          ),
          ToolResultRecord(
            name: 'record_observations',
            success: false,
            error: 'empty observation',
          ),
        ],
      ),
      profile: kLocalOllamaProfile,
    );

    final toolResults = _named(checks, 'tool_results_succeeded');
    expect(toolResults.passed, isFalse);
    expect(toolResults.detail, contains('failed tool result count 2 > 1'));
  });

  test('raw tool-call oracle checks exact scalar args', () {
    final scenario = _withExpectations(
      taskWorkflowStructuredUpdateScenario,
      const EvalExpectations(
        requiredToolCalls: [
          ExpectedToolCallState(
            toolName: 'update_task_due_date',
            argsContain: {'dueDate': '2026-06-11'},
          ),
          ExpectedToolCallState(
            toolName: 'update_task_estimate',
            argsContain: {'minutes': 45},
          ),
        ],
      ),
    );

    final checks = runLevel1(
      scenario,
      const AgentRunOutput(
        success: true,
        usage: InferenceUsage(inputTokens: 800, outputTokens: 120),
        toolCalls: [
          ToolCallRecord(
            name: 'update_task_due_date',
            args: {'dueDate': '2026-06-12'},
          ),
          ToolCallRecord(
            name: 'update_task_estimate',
            args: {'minutes': '45'},
          ),
        ],
      ),
      profile: kLocalOllamaProfile,
    );

    final oracle = _named(checks, 'expected_tool_calls');
    expect(oracle.passed, isFalse);
    expect(oracle.detail, contains('update_task_due_date'));
    expect(oracle.detail, contains('update_task_estimate'));
  });

  test('raw required tool-call matchers consume distinct calls', () {
    final scenario = _withExpectations(
      taskWorkflowStructuredUpdateScenario,
      const EvalExpectations(
        requiredToolCalls: [
          ExpectedToolCallState(
            toolName: 'update_task_estimate',
            argsContain: {'minutes': 45},
          ),
          ExpectedToolCallState(
            toolName: 'update_task_estimate',
            argsContain: {'minutes': 45},
          ),
        ],
      ),
    );

    final checks = runLevel1(
      scenario,
      const AgentRunOutput(
        success: true,
        usage: InferenceUsage(inputTokens: 800, outputTokens: 120),
        toolCalls: [
          ToolCallRecord(
            name: 'update_task_estimate',
            args: {'minutes': 45},
          ),
        ],
      ),
      profile: kLocalOllamaProfile,
    );

    final oracle = _named(checks, 'expected_tool_calls');
    expect(oracle.passed, isFalse);
    expect(oracle.detail, contains('missing distinct tool-call expectations'));
  });

  test('raw tool-call oracle matches nested batch args by containment', () {
    final scenario = _withExpectations(
      taskWorkflowStructuredUpdateScenario,
      const EvalExpectations(
        requiredToolCalls: [
          ExpectedToolCallState(
            toolName: 'add_multiple_checklist_items',
            argsContain: {
              'items': [
                {'title': 'Write the customer update'},
                {'title': 'Send to Sam'},
              ],
            },
          ),
        ],
      ),
    );

    final checks = runLevel1(
      scenario,
      const AgentRunOutput(
        success: true,
        usage: InferenceUsage(inputTokens: 800, outputTokens: 120),
        toolCalls: [
          ToolCallRecord(
            name: 'add_multiple_checklist_items',
            args: {
              'items': [
                {
                  'title': 'Send to Sam',
                  'notes': 'extra fields do not break containment',
                },
                {'title': 'Confirm screenshots'},
                {'title': 'Write the customer update'},
              ],
            },
          ),
        ],
      ),
      profile: kLocalOllamaProfile,
    );

    expect(_named(checks, 'expected_tool_calls').passed, isTrue);
  });

  test('raw forbidden tool-call oracle inspects nested batch args', () {
    final scenario = _withExpectations(
      taskWorkflowStructuredUpdateScenario,
      const EvalExpectations(
        forbiddenToolCalls: [
          ExpectedToolCallState(
            toolName: 'assign_task_labels',
            argsContain: {
              'labels': [
                {'id': 'lbl-legal'},
              ],
            },
          ),
        ],
      ),
    );

    final checks = runLevel1(
      scenario,
      const AgentRunOutput(
        success: true,
        usage: InferenceUsage(inputTokens: 800, outputTokens: 120),
        toolCalls: [
          ToolCallRecord(
            name: 'assign_task_labels',
            args: {
              'labels': [
                {'id': 'lbl-release', 'confidence': 'high'},
                {'id': 'lbl-legal', 'confidence': 'medium'},
              ],
            },
          ),
        ],
      ),
      profile: kLocalOllamaProfile,
    );

    final oracle = _named(checks, 'expected_tool_calls');
    expect(oracle.passed, isFalse);
    expect(oracle.detail, contains('forbidden tool call'));
    expect(oracle.detail, contains('lbl-legal'));
  });

  test(
    'durable-state anyOf groups and exact counts share distinct records',
    () {
      final scenario = _withExpectations(
        taskWorkflowReleaseNotesScenario,
        const EvalExpectations(
          durableState: ExpectedDurableState(
            proposalCount: 2,
            requiredProposals: [
              ExpectedProposalState(
                toolName: 'assign_task_label',
                argsContain: {'id': 'lbl-release'},
              ),
            ],
            requiredProposalAnyOf: [
              ExpectedProposalStateAnyOf(
                anyOf: [
                  ExpectedProposalState(
                    toolName: 'add_checklist_item',
                    argsContain: {'title': 'Smoke test build'},
                  ),
                  ExpectedProposalState(
                    toolName: 'add_checklist_item',
                    argsContain: {'title': 'QA release notes'},
                  ),
                ],
              ),
            ],
            proposalCounts: [
              ExpectedProposalCount(
                matcher: ExpectedProposalState(
                  toolName: 'add_checklist_item',
                  status: 'pending',
                ),
                exactCount: 1,
              ),
            ],
          ),
        ),
      );

      final checks = runLevel1(
        scenario,
        const AgentRunOutput(
          success: true,
          usage: InferenceUsage(inputTokens: 800, outputTokens: 120),
          report: AgentReportRecord(
            oneLiner: 'Prepared release notes',
            tldr: 'Prepared the task.',
          ),
          proposals: [
            ProposalRecord(
              changeSetId: 'cs-label',
              changeSetStatus: 'pending',
              targetId: 'task-notes',
              itemIndex: 0,
              toolName: 'assign_task_label',
              args: {'id': 'lbl-release'},
              humanSummary: 'Assign Release Notes label',
              status: 'pending',
            ),
            ProposalRecord(
              changeSetId: 'cs-checklist',
              changeSetStatus: 'pending',
              targetId: 'task-notes',
              itemIndex: 0,
              toolName: 'add_checklist_item',
              args: {'title': 'QA release notes'},
              humanSummary: 'Add QA release notes',
              status: 'pending',
            ),
          ],
        ),
        profile: kLocalOllamaProfile,
      );

      expect(_named(checks, 'expected_durable_state').passed, isTrue);

      final overProducedChecks = runLevel1(
        scenario,
        const AgentRunOutput(
          success: true,
          usage: InferenceUsage(inputTokens: 800, outputTokens: 120),
          report: AgentReportRecord(
            oneLiner: 'Prepared release notes',
            tldr: 'Prepared the task.',
          ),
          proposals: [
            ProposalRecord(
              changeSetId: 'cs-label',
              changeSetStatus: 'pending',
              targetId: 'task-notes',
              itemIndex: 0,
              toolName: 'assign_task_label',
              args: {'id': 'lbl-release'},
              humanSummary: 'Assign Release Notes label',
              status: 'pending',
            ),
            ProposalRecord(
              changeSetId: 'cs-checklist',
              changeSetStatus: 'pending',
              targetId: 'task-notes',
              itemIndex: 0,
              toolName: 'add_checklist_item',
              args: {'title': 'QA release notes'},
              humanSummary: 'Add QA release notes',
              status: 'pending',
            ),
            ProposalRecord(
              changeSetId: 'cs-extra',
              changeSetStatus: 'pending',
              targetId: 'task-notes',
              itemIndex: 0,
              toolName: 'add_checklist_item',
              args: {'title': 'Extra review'},
              humanSummary: 'Add Extra review',
              status: 'pending',
            ),
          ],
        ),
        profile: kLocalOllamaProfile,
      );

      final oracle = _named(overProducedChecks, 'expected_durable_state');
      expect(oracle.passed, isFalse);
      expect(oracle.detail, contains('proposal count 3 != 2'));
    },
  );

  test('durable-state scoped counts ignore non-matching proposal rows', () {
    final scenario = _withExpectations(
      taskWorkflowReleaseNotesScenario,
      const EvalExpectations(
        durableState: ExpectedDurableState(
          proposalCounts: [
            ExpectedProposalCount(
              matcher: ExpectedProposalState(
                toolName: 'assign_task_label',
                status: 'pending',
                changeSetStatus: 'pending',
              ),
              exactCount: 1,
            ),
          ],
        ),
      ),
    );

    final checks = runLevel1(
      scenario,
      const AgentRunOutput(
        success: true,
        usage: InferenceUsage(inputTokens: 800, outputTokens: 120),
        report: AgentReportRecord(
          oneLiner: 'Prepared release notes',
          tldr: 'Prepared the task.',
        ),
        proposals: [
          ProposalRecord(
            changeSetId: 'cs-label',
            changeSetStatus: 'pending',
            targetId: 'task-notes',
            itemIndex: 0,
            toolName: 'assign_task_label',
            args: {'id': 'lbl-release'},
            humanSummary: 'Assign Release Notes label',
            status: 'pending',
          ),
          ProposalRecord(
            changeSetId: 'cs-retired',
            changeSetStatus: 'resolved',
            targetId: 'task-notes',
            itemIndex: 0,
            toolName: 'assign_task_label',
            args: {'id': 'lbl-admin'},
            humanSummary: 'Retired Admin label',
            status: 'rejected',
          ),
        ],
      ),
      profile: kLocalOllamaProfile,
    );

    expect(_named(checks, 'expected_durable_state').passed, isTrue);
  });

  test('durable-state oracle matches planned blocks and parsed captures', () {
    final scenario = _withExpectations(
      plannerCaptureOnlyScenario,
      EvalExpectations(
        durableState: ExpectedDurableState(
          observationContains: const {'walk before standup'},
          requiredParsedCaptureItems: const [
            ExpectedParsedCaptureState(
              captureId: kPlannerCaptureOnlyCaptureId,
              titleContains: 'walk',
              categoryId: 'cat-health',
              confidence: 'low',
              minConfidenceScore: 0.4,
              maxConfidenceScore: 0.5,
              lowConfidence: true,
            ),
          ],
          forbiddenParsedCaptureItems: const [
            ExpectedParsedCaptureState(
              captureId: kPlannerCaptureOnlyCaptureId,
              matchedTaskId: 'task-ghost',
            ),
          ],
          requiredPlannedBlocks: [
            ExpectedPlannedBlockState(
              taskId: 'task-adr-capture',
              categoryId: 'cat-work',
              minDurationMinutes: 60,
              maxDurationMinutes: 120,
              startAtOrAfter: DateTime(2026, 6, 10, 8),
              endAtOrBefore: DateTime(2026, 6, 10, 12),
            ),
          ],
        ),
      ),
    );

    final checks = runLevel1(
      scenario,
      AgentRunOutput(
        success: true,
        usage: const InferenceUsage(inputTokens: 900, outputTokens: 120),
        toolCalls: const [ToolCallRecord(name: 'parse_capture_to_items')],
        observations: const ['User wants a walk before standup.'],
        plannedBlocks: [
          PlannedBlockRecord(
            id: 'block-adr',
            categoryId: 'cat-work',
            start: DateTime(2026, 6, 10, 8, 30),
            end: DateTime(2026, 6, 10, 10),
            taskId: 'task-adr-capture',
          ),
        ],
        parsedCaptureItems: const [
          ParsedCaptureItemRecord(
            id: 'parsed-walk',
            captureId: kPlannerCaptureOnlyCaptureId,
            kind: 'newTask',
            title: 'Take a quick walk',
            categoryId: 'cat-health',
            confidence: 'low',
            confidenceScore: 0.42,
            lowConfidence: true,
          ),
        ],
      ),
      profile: kFrontierProfile,
    );

    expect(_named(checks, 'expected_durable_state').passed, isTrue);
  });

  test('public adversarial scenario oracles reject tempting bad outputs', () {
    final missingAppointment = runLevel1(
      plannerWorkflowFocusBoundaryScenario,
      AgentRunOutput(
        success: true,
        usage: const InferenceUsage(inputTokens: 900, outputTokens: 120),
        toolCalls: const [ToolCallRecord(name: 'draft_day_plan')],
        plannedBlocks: [
          PlannedBlockRecord(
            id: 'client-brief-block',
            taskId: 'task-client-brief',
            categoryId: 'cat-work',
            start: DateTime(2026, 6, 12, 10),
            end: DateTime(2026, 6, 12, 11),
          ),
        ],
        plannedCapacityMinutes:
            plannerWorkflowFocusBoundaryScenario.appState.capacityMinutes,
      ),
      profile: kFrontierProfile,
    );
    expect(
      _named(missingAppointment, 'expected_durable_state').passed,
      isFalse,
    );
    expect(
      _named(missingAppointment, 'expected_durable_state').detail,
      contains('missing distinct planned-block expectations'),
    );

    final wrongLabel = runLevel1(
      taskWorkflowLabelScopeBoundaryScenario,
      const AgentRunOutput(
        success: true,
        usage: InferenceUsage(inputTokens: 900, outputTokens: 120),
        toolCalls: [
          ToolCallRecord(name: 'update_report'),
          ToolCallRecord(name: 'assign_task_labels'),
        ],
        report: AgentReportRecord(
          oneLiner: 'Handled labels',
          tldr: 'Added a label.',
        ),
        proposals: [
          ProposalRecord(
            changeSetId: 'cs-admin',
            changeSetStatus: 'pending',
            targetId: 'task-notes',
            itemIndex: 0,
            toolName: 'assign_task_label',
            args: {'id': 'lbl-admin', 'confidence': 'high'},
            humanSummary: 'Assign Admin Follow-up label',
            status: 'pending',
          ),
        ],
      ),
      profile: kFrontierProfile,
    );
    expect(_named(wrongLabel, 'expected_durable_state').passed, isFalse);
    expect(
      _named(wrongLabel, 'expected_durable_state').detail,
      contains('forbidden proposal'),
    );

    final forbiddenStatus = runLevel1(
      taskWorkflowCompletionBoundaryScenario,
      const AgentRunOutput(
        success: true,
        usage: InferenceUsage(inputTokens: 900, outputTokens: 120),
        toolCalls: [
          ToolCallRecord(name: 'update_report'),
          ToolCallRecord(
            name: 'set_task_status',
            args: {'status': 'DONE'},
          ),
        ],
        report: AgentReportRecord(
          oneLiner: 'Ready for approval',
          tldr: 'Changed status anyway.',
        ),
      ),
      profile: kFrontierProfile,
    );
    expect(_named(forbiddenStatus, 'expected_tools').passed, isFalse);
    expect(
      _named(forbiddenStatus, 'expected_tools').detail,
      contains('called forbidden: set_task_status'),
    );

    final wrongSamMatch = runLevel1(
      plannerCaptureAmbiguousPersonScenario,
      const AgentRunOutput(
        success: true,
        usage: InferenceUsage(inputTokens: 900, outputTokens: 120),
        toolCalls: [ToolCallRecord(name: 'parse_capture_to_items')],
        parsedCaptureItems: [
          ParsedCaptureItemRecord(
            id: 'parsed-wrong-sam',
            captureId: kPlannerAmbiguousCaptureId,
            kind: 'matched',
            title: 'Call Sam',
            categoryId: 'cat-admin',
            confidence: 'medium',
            confidenceScore: 0.62,
            lowConfidence: true,
            matchedTaskId: 'task-sam-invoice',
          ),
        ],
      ),
      profile: kFrontierProfile,
    );
    expect(_named(wrongSamMatch, 'expected_durable_state').passed, isFalse);
    expect(
      _named(wrongSamMatch, 'expected_durable_state').detail,
      contains('forbidden parsed capture item'),
    );
  });

  test('durable-state expectations round-trip through scenario JSON', () {
    final scenario = _withExpectations(
      taskWorkflowReleaseNotesScenario,
      const EvalExpectations(
        durableState: ExpectedDurableState(
          proposalCount: 1,
          reportContains: {'release'},
          requiredProposals: [
            ExpectedProposalState(
              toolName: 'assign_task_label',
              argsContain: {'id': 'lbl-release'},
            ),
          ],
          requiredProposalAnyOf: [
            ExpectedProposalStateAnyOf(
              anyOf: [
                ExpectedProposalState(
                  toolName: 'add_checklist_item',
                  argsContain: {'title': 'Smoke test build'},
                ),
                ExpectedProposalState(
                  toolName: 'add_checklist_item',
                  argsContain: {'title': 'QA release notes'},
                ),
              ],
            ),
          ],
          requiredParsedCaptureAnyOf: [
            ExpectedParsedCaptureStateAnyOf(
              anyOf: [
                ExpectedParsedCaptureState(
                  captureId: kPlannerCaptureOnlyCaptureId,
                  confidence: 'low',
                  minConfidenceScore: 0.4,
                  maxConfidenceScore: 0.5,
                ),
              ],
            ),
          ],
          proposalCounts: [
            ExpectedProposalCount(
              matcher: ExpectedProposalState(status: 'pending'),
              exactCount: 1,
            ),
          ],
          plannedBlockCounts: [
            ExpectedPlannedBlockCount(
              matcher: ExpectedPlannedBlockState(categoryId: 'cat-work'),
              minCount: 1,
            ),
          ],
          parsedCaptureCounts: [
            ExpectedParsedCaptureCount(
              matcher: ExpectedParsedCaptureState(
                captureId: kPlannerCaptureOnlyCaptureId,
                confidence: 'low',
              ),
              maxCount: 2,
            ),
          ],
        ),
      ),
    );

    final roundTripped = EvalScenario.fromJson(scenario.toJson());

    expect(
      roundTripped.expectations.durableState.toJson(),
      scenario.expectations.durableState.toJson(),
    );
    expect(
      roundTripped.expectations.requiredToolCalls.map(
        (matcher) => matcher.toJson(),
      ),
      scenario.expectations.requiredToolCalls.map(
        (matcher) => matcher.toJson(),
      ),
    );
    expect(
      roundTripped.expectations.forbiddenToolCalls.map(
        (matcher) => matcher.toJson(),
      ),
      scenario.expectations.forbiddenToolCalls.map(
        (matcher) => matcher.toJson(),
      ),
    );
  });
}

EvalScenario _withExpectations(
  EvalScenario scenario,
  EvalExpectations expectations,
) {
  return EvalScenario(
    id: scenario.id,
    title: scenario.title,
    agentKind: scenario.agentKind,
    appState: scenario.appState,
    userInput: scenario.userInput,
    metadata: scenario.metadata,
    expectations: expectations,
  );
}

EvalCheck _named(List<EvalCheck> checks, String name) =>
    checks.firstWhere((c) => c.name == name);
