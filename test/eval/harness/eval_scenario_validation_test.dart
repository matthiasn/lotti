import 'package:flutter_test/flutter_test.dart';

import '../scenarios/eval_scenarios.dart';
import 'eval_harness.dart';

void main() {
  test('committed eval catalog has valid scenario references', () {
    final issues = validateEvalScenarioCatalog(allEvalScenarios);

    expect(issues, isEmpty);
  });

  test('reports broken fixture and durable-state references', () {
    final scenario = EvalScenario(
      id: 'broken_refs',
      title: 'Broken references',
      agentKind: AgentKind.planningAgent,
      appState: MockedAppState(
        now: DateTime(2026, 6, 10, 7),
        categoryIds: const ['cat-work'],
        tasks: const [
          MockTask(
            id: 'task-known',
            title: 'Known task',
            status: 'OPEN',
            categoryId: 'cat-missing',
            labelIds: ['label-missing'],
          ),
        ],
        captures: const [
          MockCapture(
            id: 'capture-known',
            transcript: 'Take a walk.',
            parsedItems: [
              MockParsedCaptureItem(
                id: 'parsed-known',
                title: 'Take a walk',
                categoryId: 'cat-missing',
                matchedTaskId: 'task-missing',
                confidence: 'certain',
                confidenceScore: 1.2,
              ),
            ],
          ),
        ],
        taskLogEntries: const [
          MockTaskLogEntry(
            id: 'task-log-known',
            taskId: 'task-missing',
            transcript: '',
            durationMinutes: -1,
            entryType: 'video',
          ),
        ],
        existingBlocks: [
          MockDayBlock(
            id: 'block-broken',
            categoryId: 'cat-missing',
            start: DateTime(2026, 6, 10, 10),
            end: DateTime(2026, 6, 10, 9),
            taskId: 'task-missing',
          ),
        ],
      ),
      userInput: const UserInput(
        transcript: 'Broken wake.',
        triggerTokens: {
          'decided_task:task-missing',
          'capture_submitted:capture-missing',
          'decided_capture_item:parsed-missing',
        },
      ),
      metadata: const EvalScenarioMetadata(
        capabilityIds: ['planner.broken.refs'],
      ),
      expectations: const EvalExpectations(
        durableState: ExpectedDurableState(
          proposalCount: -1,
          requiredProposalAnyOf: [
            ExpectedProposalStateAnyOf(anyOf: []),
          ],
          requiredProposals: [
            ExpectedProposalState(targetId: 'task-missing'),
          ],
          proposalCounts: [
            ExpectedProposalCount(
              matcher: ExpectedProposalState(toolName: 'assign_task_label'),
              minCount: 1,
              exactCount: 1,
            ),
          ],
          requiredPlannedBlocks: [
            ExpectedPlannedBlockState(
              taskId: 'task-missing',
              categoryId: 'cat-missing',
              minDurationMinutes: 90,
              maxDurationMinutes: 30,
            ),
          ],
          plannedBlockCounts: [
            ExpectedPlannedBlockCount(
              matcher: ExpectedPlannedBlockState(categoryId: 'cat-missing'),
              minCount: 3,
              maxCount: 1,
            ),
          ],
          requiredParsedCaptureItems: [
            ExpectedParsedCaptureState(
              captureId: 'capture-missing',
              categoryId: 'cat-missing',
              matchedTaskId: 'task-missing',
              confidence: 'certain',
              minConfidenceScore: 0.8,
              maxConfidenceScore: 0.2,
            ),
          ],
          parsedCaptureCounts: [
            ExpectedParsedCaptureCount(
              matcher: ExpectedParsedCaptureState(confidence: 'certain'),
              exactCount: -1,
            ),
          ],
        ),
      ),
    );

    final messages = validateEvalScenario(
      scenario,
    ).map((issue) => issue.message).toSet();

    expect(
      messages,
      contains(
        'task task-known references unknown category '
        'cat-missing',
      ),
    );
    expect(
      messages,
      contains(
        'task task-known references unknown label '
        'label-missing',
      ),
    );
    expect(
      messages,
      contains(
        'existing block block-broken has non-positive '
        'duration',
      ),
    );
    expect(
      messages,
      contains('task log entry task-log-known has an empty transcript'),
    );
    expect(
      messages,
      contains('task log entry task-log-known has negative durationMinutes'),
    );
    expect(
      messages,
      contains(
        'task log entry task-log-known has unsupported entryType video',
      ),
    );
    expect(
      messages,
      contains(
        'task log entry task-log-known references unknown task task-missing',
      ),
    );
    expect(
      messages,
      contains(
        'parsed item parsed-known has confidenceScore '
        'outside 0..1',
      ),
    );
    expect(
      messages,
      contains(
        'trigger token references unknown parsed capture '
        'item parsed-missing',
      ),
    );
    expect(messages, contains('durableState.proposalCount is negative'));
    expect(
      messages,
      contains('durableState.requiredProposalAnyOf has an empty anyOf group'),
    );
    expect(
      messages,
      contains(
        'durableState.requiredProposals references unknown target '
        'task-missing',
      ),
    );
    expect(
      messages,
      contains(
        'durableState.proposalCounts cannot combine exactCount with minCount '
        'or maxCount',
      ),
    );
    expect(
      messages,
      contains(
        'durableState.proposalCounts matcher must specify status or '
        'changeSetStatus or changeSetId',
      ),
    );
    expect(
      messages,
      contains(
        'durableState.requiredPlannedBlocks has minDurationMinutes > '
        'maxDurationMinutes',
      ),
    );
    expect(
      messages,
      contains('durableState.plannedBlockCounts has minCount > maxCount'),
    );
    expect(
      messages,
      contains(
        'durableState.requiredParsedCaptureItems has '
        'minConfidenceScore > maxConfidenceScore',
      ),
    );
    expect(
      messages,
      contains('durableState.parsedCaptureCounts has negative exactCount'),
    );
  });

  test('validates recoverable tool-result failure expectations', () {
    EvalScenario withExpectations(EvalExpectations expectations) =>
        EvalScenario(
          id: 'broken_tool_recovery',
          title: 'Broken tool recovery metadata',
          agentKind: AgentKind.taskAgent,
          appState: MockedAppState(
            now: DateTime(2026, 6, 10, 7),
            categoryIds: const ['cat-work'],
            tasks: const [
              MockTask(
                id: 'task-known',
                title: 'Known task',
                status: 'OPEN',
                categoryId: 'cat-work',
              ),
            ],
          ),
          userInput: const UserInput(
            transcript: 'Recover from a failed tool call.',
            triggerTokens: {'decided_task:task-known'},
          ),
          metadata: const EvalScenarioMetadata(
            capabilityIds: ['task.reporting.toolrecovery'],
          ),
          expectations: expectations,
        );

    expect(
      validateEvalScenario(
        withExpectations(
          const EvalExpectations(maxAllowedToolResultFailures: -1),
        ),
      ).map((issue) => issue.message),
      contains('maxAllowedToolResultFailures is negative'),
    );
    expect(
      validateEvalScenario(
        withExpectations(
          const EvalExpectations(maxAllowedToolResultFailures: 1),
        ),
      ).map((issue) => issue.message),
      contains('maxAllowedToolResultFailures requires allowedFailedToolNames'),
    );
    expect(
      validateEvalScenario(
        withExpectations(
          const EvalExpectations(allowedFailedToolNames: {'update_report'}),
        ),
      ).map((issue) => issue.message),
      contains(
        'allowedFailedToolNames requires maxAllowedToolResultFailures > 0',
      ),
    );
    expect(
      validateEvalScenario(
        withExpectations(
          const EvalExpectations(
            allowedFailedToolNames: {''},
            maxAllowedToolResultFailures: 1,
          ),
        ),
      ).map((issue) => issue.message),
      contains('allowedFailedToolNames contains an empty tool name'),
    );
  });

  test('validates tool-specific task proposal oracle schemas', () {
    final scenario = _taskScenarioWithDurableState(
      const ExpectedDurableState(
        requiredProposals: [
          ExpectedProposalState(
            toolName: 'update_task_due_date',
            argsContain: {'due': '2026-06-11'},
          ),
          ExpectedProposalState(
            toolName: 'add_multiple_checklist_items',
            argsContain: {'title': 'Review notes'},
          ),
          ExpectedProposalState(toolName: ' '),
          ExpectedProposalState(changeSetId: ' '),
        ],
        requiredProposalAnyOf: [
          ExpectedProposalStateAnyOf(
            anyOf: [
              ExpectedProposalState(
                toolName: 'assign_task_label',
                argsContain: {'labelId': 'lbl-release'},
              ),
            ],
          ),
        ],
        proposalCounts: [
          ExpectedProposalCount(
            matcher: ExpectedProposalState(
              toolName: 'rewrite_history',
              status: 'pending',
            ),
            exactCount: 1,
          ),
        ],
        forbiddenProposals: [
          ExpectedProposalState(
            argsContain: {'id': 'ci-1', 'dueDate': '2026-06-11'},
          ),
          ExpectedProposalState(
            toolName: 'add_checklist_item',
            argsContain: {'name': 'Review notes'},
          ),
        ],
      ),
    );

    final messages = validateEvalScenario(
      scenario,
    ).map((issue) => issue.message).toList();

    expect(
      messages,
      _containsMessage(
        'durableState.requiredProposals argsContain key due is not valid '
        'for proposal toolName update_task_due_date',
      ),
    );
    expect(
      messages,
      _containsMessage(
        'durableState.requiredProposals has unknown proposal toolName '
        'add_multiple_checklist_items for taskAgent',
      ),
    );
    expect(
      messages,
      contains('durableState.requiredProposals has an empty toolName'),
    );
    expect(
      messages,
      contains('durableState.requiredProposals has an empty changeSetId'),
    );
    expect(
      messages,
      _containsMessage(
        'durableState.requiredProposalAnyOf argsContain key labelId is not '
        'valid for proposal toolName assign_task_label',
      ),
    );
    expect(
      messages,
      _containsMessage(
        'durableState.proposalCounts.matcher has unknown proposal toolName '
        'rewrite_history for taskAgent',
      ),
    );
    expect(
      messages,
      _containsMessage(
        'durableState.forbiddenProposals argsContain keys dueDate, id do not '
        'match any known proposal tool for taskAgent',
      ),
    );
    expect(
      messages,
      _containsMessage(
        'durableState.forbiddenProposals argsContain key name is not valid '
        'for proposal toolName add_checklist_item',
      ),
    );
  });

  test('validates proposal change-set id oracle references', () {
    final validScenario = _taskScenarioWithExpectations(
      const EvalExpectations(
        durableState: ExpectedDurableState(
          proposalCounts: [
            ExpectedProposalCount(
              matcher: ExpectedProposalState(
                changeSetId: 'open-review-changelog',
              ),
              exactCount: 1,
            ),
          ],
        ),
      ),
      proposalSets: const [
        MockProposalSet(
          id: 'open-review-changelog',
          items: [
            MockProposalItem(
              toolName: 'add_checklist_item',
              args: {'title': 'Review changelog'},
              humanSummary: 'Add: "Review changelog"',
            ),
          ],
        ),
      ],
    );

    expect(validateEvalScenario(validScenario), isEmpty);

    final invalidScenario = _taskScenarioWithExpectations(
      const EvalExpectations(
        durableState: ExpectedDurableState(
          requiredProposals: [
            ExpectedProposalState(changeSetId: 'fresh-duplicate'),
          ],
          requiredProposalAnyOf: [
            ExpectedProposalStateAnyOf(
              anyOf: [
                ExpectedProposalState(changeSetId: 'fresh-duplicate'),
              ],
            ),
          ],
          proposalCounts: [
            ExpectedProposalCount(
              matcher: ExpectedProposalState(
                changeSetId: 'fresh-duplicate',
              ),
              exactCount: 1,
            ),
          ],
          forbiddenProposals: [
            ExpectedProposalState(changeSetId: 'fresh-duplicate'),
          ],
        ),
      ),
      proposalSets: const [
        MockProposalSet(
          id: 'open-review-changelog',
          items: [
            MockProposalItem(
              toolName: 'add_checklist_item',
              args: {'title': 'Review changelog'},
              humanSummary: 'Add: "Review changelog"',
            ),
          ],
        ),
      ],
    );

    final messages = validateEvalScenario(
      invalidScenario,
    ).map((issue) => issue.message).toList();

    for (final field in const [
      'requiredProposals',
      'requiredProposalAnyOf',
      'proposalCounts.matcher',
      'forbiddenProposals',
    ]) {
      expect(
        messages,
        contains(
          'durableState.$field references unknown seeded proposal set '
          'fresh-duplicate',
        ),
      );
    }
    expect(
      messages,
      isNot(
        contains(
          'durableState.proposalCounts matcher must specify status or '
          'changeSetStatus or changeSetId',
        ),
      ),
    );
  });

  test('validates raw task tool-call oracle schemas', () {
    final validScenario = _taskScenarioWithExpectations(
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
          ExpectedToolCallState(
            toolName: 'add_multiple_checklist_items',
            argsContain: {
              'items': [
                {'title': 'Review notes'},
              ],
            },
          ),
        ],
      ),
    );

    expect(validateEvalScenario(validScenario), isEmpty);

    final invalidScenario = _taskScenarioWithExpectations(
      const EvalExpectations(
        requiredToolCalls: [
          ExpectedToolCallState(toolName: ' '),
          ExpectedToolCallState(
            toolName: 'add_checklist_item',
            argsContain: {'title': 'Review notes'},
          ),
          ExpectedToolCallState(
            toolName: 'assign_task_labels',
            argsContain: {'id': 'lbl-release'},
          ),
          ExpectedToolCallState(
            toolName: 'assign_task_labels',
            argsContain: {
              'labels': [
                {'labelId': 'lbl-release'},
              ],
            },
          ),
          ExpectedToolCallState(
            toolName: 'add_multiple_checklist_items',
            argsContain: {'items': <Map<String, dynamic>>[]},
          ),
        ],
        forbiddenToolCalls: [
          ExpectedToolCallState(
            toolName: 'rewrite_history',
            argsContain: {'anything': true},
          ),
        ],
      ),
    );

    final messages = validateEvalScenario(
      invalidScenario,
    ).map((issue) => issue.message).toList();

    expect(messages, contains('requiredToolCalls has an empty toolName'));
    expect(
      messages,
      _containsMessage(
        'requiredToolCalls has unknown raw toolName add_checklist_item',
      ),
    );
    expect(
      messages,
      _containsMessage(
        'requiredToolCalls argsContain key id is not valid for raw toolName '
        'assign_task_labels',
      ),
    );
    expect(
      messages,
      _containsMessage(
        'requiredToolCalls argsContain item key labelId is not valid for '
        'assign_task_labels.labels[]',
      ),
    );
    expect(
      messages,
      contains(
        'requiredToolCalls argsContain add_multiple_checklist_items.items '
        'must not be an empty list',
      ),
    );
    expect(
      messages,
      _containsMessage(
        'forbiddenToolCalls has unknown raw toolName rewrite_history',
      ),
    );
  });

  test('validates cascade wake oracle schemas', () {
    final valid = _taskScenarioWithExpectations(
      const EvalExpectations(
        cascadeWakes: [
          ExpectedCascadeWakeState(
            wakeIndex: 0,
            requiredToolCalls: [
              ExpectedToolCallState(
                toolName: 'update_checklist_items',
                argsContain: {
                  'items': [
                    {'id': 'ci-1', 'isChecked': true},
                  ],
                },
              ),
            ],
            durableState: ExpectedDurableState(
              reportContains: {'pull request'},
              requiredProposals: [
                ExpectedProposalState(
                  toolName: 'update_checklist_item',
                  targetId: 'task-known',
                  status: 'pending',
                  argsContain: {'id': 'ci-1', 'isChecked': true},
                ),
              ],
            ),
          ),
        ],
      ),
    );

    expect(validateEvalScenario(valid), isEmpty);

    final invalid = _taskScenarioWithExpectations(
      const EvalExpectations(
        cascadeWakes: [
          ExpectedCascadeWakeState(wakeIndex: -1),
          ExpectedCascadeWakeState(
            wakeIndex: 0,
            requiredToolCalls: [
              ExpectedToolCallState(
                toolName: 'add_checklist_item',
                argsContain: {'title': 'Wrong raw tool'},
              ),
            ],
          ),
          ExpectedCascadeWakeState(
            wakeIndex: 0,
            durableState: ExpectedDurableState(
              requiredProposals: [
                ExpectedProposalState(targetId: 'task-missing'),
              ],
            ),
          ),
          ExpectedCascadeWakeState(
            wakeIndex: 2,
            durableState: ExpectedDurableState(reportContains: {'later'}),
          ),
        ],
      ),
    );

    final messages = validateEvalScenario(
      invalid,
    ).map((issue) => issue.message).toList();

    expect(messages, contains('cascadeWakes has duplicate wakeIndex 0'));
    expect(messages, contains('cascadeWakes[0].wakeIndex is negative'));
    expect(messages, contains('cascadeWakes[0] has no oracle fields'));
    expect(
      messages,
      _containsMessage(
        'cascadeWakes[1].requiredToolCalls has unknown raw toolName '
        'add_checklist_item',
      ),
    );
    expect(
      messages,
      contains(
        'cascadeWakes[2].durableState.requiredProposals references unknown '
        'target task-missing',
      ),
    );
    expect(
      messages,
      contains(
        'cascadeWakes[3].wakeIndex 2 has no matching taskLogEntries wake',
      ),
    );
  });

  test('accepts persisted singular proposal schemas and broad matchers', () {
    final scenario = _taskScenarioWithDurableState(
      const ExpectedDurableState(
        requiredProposals: [
          ExpectedProposalState(
            toolName: 'assign_task_label',
            argsContain: {'id': 'lbl-release', 'confidence': 'high'},
          ),
          ExpectedProposalState(
            toolName: 'add_checklist_item',
            argsContain: {'title': 'Review notes', 'isChecked': false},
          ),
          ExpectedProposalState(
            toolName: 'update_checklist_item',
            argsContain: {
              'id': 'ci-1',
              'title': 'Updated note',
              'isArchived': true,
            },
          ),
          ExpectedProposalState(
            toolName: 'migrate_checklist_item',
            argsContain: {
              'id': 'ci-2',
              'title': 'Move to follow-up',
              'targetTaskId': 'follow-up-placeholder',
            },
          ),
          ExpectedProposalState(
            toolName: 'create_follow_up_task',
            argsContain: {
              'title': 'Follow up with Sam',
              '_placeholderTaskId': 'follow-up-placeholder',
            },
          ),
        ],
        forbiddenProposals: [
          ExpectedProposalState(argsContain: {'id': 'ci-1'}),
        ],
      ),
    );

    expect(validateEvalScenario(scenario), isEmpty);
  });

  test('validates planner diff proposal oracle schemas', () {
    final valid = _plannerScenarioWithDurableState(
      const ExpectedDurableState(
        requiredProposals: [
          ExpectedProposalState(
            toolName: 'add_block',
            argsContain: {
              'action': 'added',
              'toStart': '2026-06-10T10:00:00',
              'title': 'Review notes',
            },
          ),
        ],
      ),
    );

    expect(validateEvalScenario(valid), isEmpty);

    final invalid = _plannerScenarioWithDurableState(
      const ExpectedDurableState(
        requiredProposals: [
          ExpectedProposalState(toolName: 'assign_task_label'),
          ExpectedProposalState(
            toolName: 'add_block',
            argsContain: {'start': '2026-06-10T10:00:00'},
          ),
        ],
      ),
    );
    final messages = validateEvalScenario(
      invalid,
    ).map((issue) => issue.message).toList();

    expect(
      messages,
      _containsMessage(
        'durableState.requiredProposals has unknown proposal toolName '
        'assign_task_label for planningAgent',
      ),
    );
    expect(
      messages,
      _containsMessage(
        'durableState.requiredProposals argsContain key start is not valid '
        'for proposal toolName add_block',
      ),
    );
  });

  test('validates seeded proposal fixture tool names and argument keys', () {
    final scenario = EvalScenario(
      id: 'seeded_proposal_schema',
      title: 'Seeded proposal schema',
      agentKind: AgentKind.taskAgent,
      appState: MockedAppState(
        now: DateTime(2026, 6, 10, 7),
        categoryIds: const ['cat-work'],
        tasks: const [
          MockTask(
            id: 'task-known',
            title: 'Known task',
            status: 'OPEN',
            categoryId: 'cat-work',
          ),
        ],
        proposalSets: const [
          MockProposalSet(
            id: 'bad-fixture',
            targetId: 'task-known',
            items: [
              MockProposalItem(
                toolName: 'add_multiple_checklist_items',
                args: {'items': <Object?>[]},
                humanSummary: 'Raw batch should not be persisted',
              ),
              MockProposalItem(
                toolName: 'add_checklist_item',
                args: {'name': 'Review notes'},
                humanSummary: 'Wrong argument key',
              ),
            ],
          ),
        ],
      ),
      userInput: const UserInput(
        transcript: 'Validate seeded proposal rows.',
        triggerTokens: {'decided_task:task-known'},
      ),
      metadata: const EvalScenarioMetadata(
        capabilityIds: ['task.seeded.proposal.schema'],
      ),
    );

    final messages = validateEvalScenario(
      scenario,
    ).map((issue) => issue.message).toList();

    expect(
      messages,
      _containsMessage(
        'proposal set bad-fixture item 0 has unknown proposal toolName '
        'add_multiple_checklist_items for taskAgent',
      ),
    );
    expect(
      messages,
      _containsMessage(
        'proposal set bad-fixture item 1 argsContain key name is not valid '
        'for proposal toolName add_checklist_item',
      ),
    );
  });

  test('validates scenario review metadata without requiring it globally', () {
    final base = EvalScenario(
      id: 'reviewed_fixture',
      title: 'Reviewed fixture',
      agentKind: AgentKind.taskAgent,
      appState: MockedAppState(
        now: DateTime(2026, 6, 10, 7),
        categoryIds: const ['cat-work'],
        tasks: const [
          MockTask(
            id: 'task-known',
            title: 'Known task',
            status: 'OPEN',
            categoryId: 'cat-work',
          ),
        ],
      ),
      userInput: const UserInput(
        transcript: 'Validate review metadata.',
        triggerTokens: {'decided_task:task-known'},
      ),
      metadata: const EvalScenarioMetadata(
        capabilityIds: ['task.review.validation'],
      ),
    );

    EvalScenario withReview(EvalScenarioReview review) {
      final json = base.toJson();
      json['metadata'] = <String, dynamic>{
        ...(json['metadata'] as Map<String, dynamic>),
        'review': review.toJson(),
      };
      return EvalScenario.fromJson(json);
    }

    final validNeedsReview = withReview(
      EvalScenarioReview(
        status: EvalScenarioReviewStatus.needsReview,
        reviewer: 'human-reviewer',
        reviewedAt: '2026-06-10T12:00:00.000Z',
        subjectDigest: EvalProvenance.scenarioReviewSubjectDigest(base),
        rationale: 'Structurally valid but not tuning-ready yet.',
      ),
    );

    expect(validateEvalScenario(validNeedsReview), isEmpty);

    final malformed = withReview(
      const EvalScenarioReview(
        status: EvalScenarioReviewStatus.reviewed,
        reviewer: ' ',
        reviewedAt: 'not-a-date',
        subjectDigest: 'sha256:not-real',
        rationale: '',
        sourceDigest: 'sha256:not-real-either',
      ),
    );
    final malformedMessages = validateEvalScenario(
      malformed,
    ).map((issue) => issue.message).toSet();

    expect(
      malformedMessages,
      containsAll({
        'scenario review reviewer is empty',
        'scenario review rationale is empty',
        'scenario review reviewedAt is invalid',
        'scenario review subjectDigest is not a sha256 digest',
        'scenario review sourceDigest is not a sha256 digest',
      }),
    );

    final stale = withReview(
      EvalScenarioReview(
        status: EvalScenarioReviewStatus.reviewed,
        reviewer: 'human-reviewer',
        reviewedAt: '2026-06-10T12:00:00.000Z',
        subjectDigest: EvalProvenance.digestText('old scenario'),
        rationale: 'This digest no longer matches.',
      ),
    );

    expect(
      validateEvalScenario(stale).map((issue) => issue.message),
      contains(
        'scenario review subjectDigest is '
        '${EvalProvenance.digestText('old scenario')}, expected '
        '${EvalProvenance.scenarioReviewSubjectDigest(base)}',
      ),
    );
  });

  test('adversarial scenarios must use canonical stress tags', () {
    final scenario = EvalScenario(
      id: 'typoed_stress_tag',
      title: 'Typoed stress tag',
      agentKind: AgentKind.taskAgent,
      appState: MockedAppState(
        now: DateTime(2026, 6, 10, 7),
        categoryIds: const ['cat-work'],
        tasks: const [
          MockTask(
            id: 'task-known',
            title: 'Known task',
            status: 'OPEN',
            categoryId: 'cat-work',
          ),
        ],
      ),
      userInput: const UserInput(
        transcript: 'Recover from stale state.',
        triggerTokens: {'decided_task:task-known'},
      ),
      metadata: const EvalScenarioMetadata(
        capabilityIds: ['task.reporting.toolrecovery'],
        source: EvalScenarioSource.adversarial,
        isAdversarial: true,
        tags: {'adversarial', 'stale_state'},
      ),
    );

    final messages = validateEvalScenario(
      scenario,
    ).map((issue) => issue.message).toSet();

    expect(
      messages,
      contains(
        'adversarial scenario lacks a default stress tag: '
        '${kDefaultAdversarialStressTags.join(', ')}',
      ),
    );
  });

  test('adversarial scenarios require canonical source and tag', () {
    EvalScenario scenario({
      required EvalScenarioSource source,
      required Set<String> tags,
    }) {
      return EvalScenario(
        id: 'partial_adversarial_metadata',
        title: 'Partial adversarial metadata',
        agentKind: AgentKind.taskAgent,
        appState: MockedAppState(
          now: DateTime(2026, 6, 10, 7),
          categoryIds: const ['cat-work'],
          tasks: const [
            MockTask(
              id: 'task-known',
              title: 'Known task',
              status: 'OPEN',
              categoryId: 'cat-work',
            ),
          ],
        ),
        userInput: const UserInput(
          transcript: 'Recover from stale state.',
          triggerTokens: {'decided_task:task-known'},
        ),
        metadata: EvalScenarioMetadata(
          capabilityIds: const ['task.reporting.toolrecovery'],
          source: source,
          isAdversarial: true,
          tags: tags,
        ),
      );
    }

    final missingSourceMessages = validateEvalScenario(
      scenario(
        source: EvalScenarioSource.handAuthored,
        tags: const {'adversarial', 'stale-state'},
      ),
    ).map((issue) => issue.message).toSet();
    final missingTagMessages = validateEvalScenario(
      scenario(
        source: EvalScenarioSource.adversarial,
        tags: const {'stale-state'},
      ),
    ).map((issue) => issue.message).toSet();

    expect(
      missingSourceMessages,
      contains('adversarial scenario must use adversarial source'),
    );
    expect(
      missingSourceMessages,
      isNot(contains('adversarial scenario must use adversarial tag')),
    );
    expect(
      missingTagMessages,
      contains('adversarial scenario must use adversarial tag'),
    );
    expect(
      missingTagMessages,
      isNot(contains('adversarial scenario must use adversarial source')),
    );
  });

  test('adversarial scenarios require digest-bound source provenance', () {
    final base = EvalScenario(
      id: 'adversarial_source_provenance',
      title: 'Adversarial source provenance',
      agentKind: AgentKind.taskAgent,
      appState: MockedAppState(
        now: DateTime(2026, 6, 10, 7),
        categoryIds: const ['cat-work'],
        tasks: const [
          MockTask(
            id: 'task-known',
            title: 'Known task',
            status: 'OPEN',
            categoryId: 'cat-work',
          ),
        ],
      ),
      userInput: const UserInput(
        transcript: 'Recover from stale state.',
        triggerTokens: {'decided_task:task-known'},
      ),
      metadata: const EvalScenarioMetadata(
        capabilityIds: ['task.reporting.toolrecovery'],
        source: EvalScenarioSource.adversarial,
        isAdversarial: true,
        tags: {'adversarial', 'stale-state'},
      ),
    );

    EvalScenario withReview(EvalScenarioReview review) {
      final json = base.toJson();
      json['metadata'] = <String, dynamic>{
        ...(json['metadata'] as Map<String, dynamic>),
        'review': review.toJson(),
      };
      return EvalScenario.fromJson(json);
    }

    EvalScenarioReview review({
      EvalScenarioReviewStatus status = EvalScenarioReviewStatus.reviewed,
      bool includeSourceDigest = true,
      String? sourceDigest,
      String? sourceLabel = 'public-adversarial-catalog',
      String? generator = 'human-authored-adversarial-case',
    }) {
      return EvalScenarioReview(
        status: status,
        reviewer: 'human-reviewer',
        reviewedAt: '2026-06-10T12:00:00.000Z',
        subjectDigest: EvalProvenance.scenarioReviewSubjectDigest(base),
        rationale: 'Reviewed adversarial source provenance.',
        sourceDigest: includeSourceDigest
            ? sourceDigest ?? EvalProvenance.digestText('source')
            : null,
        sourceLabel: sourceLabel,
        generator: generator,
      );
    }

    expect(validateEvalScenario(withReview(review())), isEmpty);

    final missingReviewMessages = validateEvalScenario(
      base,
    ).map((issue) => issue.message).toSet();
    final needsReviewMessages = validateEvalScenario(
      withReview(review(status: EvalScenarioReviewStatus.needsReview)),
    ).map((issue) => issue.message).toSet();
    final missingDigestMessages = validateEvalScenario(
      withReview(review(includeSourceDigest: false)),
    ).map((issue) => issue.message).toSet();
    final invalidDigestMessages = validateEvalScenario(
      withReview(review(sourceDigest: 'sha256:not-real')),
    ).map((issue) => issue.message).toSet();
    final missingOriginMessages = validateEvalScenario(
      withReview(review(sourceLabel: ' ', generator: null)),
    ).map((issue) => issue.message).toSet();

    expect(
      missingReviewMessages,
      contains('adversarial scenario requires review provenance'),
    );
    expect(
      needsReviewMessages,
      contains('adversarial scenario review must be reviewed or adjudicated'),
    );
    expect(
      missingDigestMessages,
      contains('adversarial scenario review sourceDigest is required'),
    );
    expect(
      invalidDigestMessages,
      contains('scenario review sourceDigest is not a sha256 digest'),
    );
    expect(
      missingOriginMessages,
      contains(
        'adversarial scenario review sourceLabel or generator is required',
      ),
    );
  });

  test('validates capability selectors and governed agent prefixes', () {
    final scenario = EvalScenario(
      id: 'bad_capability_ids',
      title: 'Bad capability ids',
      agentKind: AgentKind.taskAgent,
      appState: MockedAppState(
        now: DateTime(2026, 6, 10, 7),
        categoryIds: const ['cat-work'],
        tasks: const [
          MockTask(
            id: 'task-known',
            title: 'Known task',
            status: 'OPEN',
            categoryId: 'cat-work',
          ),
        ],
      ),
      userInput: const UserInput(
        transcript: 'Check bad capability ids.',
        triggerTokens: {'decided_task:task-known'},
      ),
      metadata: const EvalScenarioMetadata(
        capabilityIds: [
          'planner.cross.agent',
          'task.duplicate',
          'task.duplicate',
          'unsafe value',
        ],
      ),
    );

    final messages = validateEvalScenario(
      scenario,
    ).map((issue) => issue.message).toSet();

    expect(
      messages,
      contains(
        'scenario capability id planner.cross.agent does not match taskAgent',
      ),
    );
    expect(
      messages,
      contains('scenario has duplicate capability id task.duplicate'),
    );
    expect(
      messages,
      contains('scenario capability id unsafe value is not a safe selector'),
    );
  });
}

EvalScenario _taskScenarioWithDurableState(ExpectedDurableState durableState) =>
    _taskScenarioWithExpectations(
      EvalExpectations(durableState: durableState),
    );

EvalScenario _taskScenarioWithExpectations(
  EvalExpectations expectations, {
  List<MockProposalSet> proposalSets = const [],
}) => EvalScenario(
  id: 'task_proposal_oracle_schema',
  title: 'Task proposal oracle schema',
  agentKind: AgentKind.taskAgent,
  appState: MockedAppState(
    now: DateTime(2026, 6, 10, 7),
    categoryIds: const ['cat-work'],
    labels: const [
      MockLabelDefinition(
        id: 'lbl-release',
        name: 'Release',
        color: '#00AA00',
      ),
    ],
    tasks: const [
      MockTask(
        id: 'task-known',
        title: 'Known task',
        status: 'OPEN',
        categoryId: 'cat-work',
        checklist: [
          MockChecklistItem(id: 'ci-1', title: 'Old note'),
          MockChecklistItem(id: 'ci-2', title: 'Move to follow-up'),
        ],
      ),
    ],
    taskLogEntries: const [
      MockTaskLogEntry(
        id: 'task-log-known',
        taskId: 'task-known',
        transcript: 'I created the pull request.',
      ),
    ],
    proposalSets: proposalSets,
  ),
  userInput: const UserInput(
    transcript: 'Validate expected proposals.',
    triggerTokens: {'decided_task:task-known'},
  ),
  metadata: const EvalScenarioMetadata(
    capabilityIds: ['task.proposal.schema'],
  ),
  expectations: expectations,
);

EvalScenario _plannerScenarioWithDurableState(
  ExpectedDurableState durableState,
) => EvalScenario(
  id: 'planner_proposal_oracle_schema',
  title: 'Planner proposal oracle schema',
  agentKind: AgentKind.planningAgent,
  appState: MockedAppState(
    now: DateTime(2026, 6, 10, 7),
    categoryIds: const ['cat-work'],
    tasks: const [
      MockTask(
        id: 'task-known',
        title: 'Known task',
        status: 'OPEN',
        categoryId: 'cat-work',
      ),
    ],
  ),
  userInput: const UserInput(
    transcript: 'Validate expected planner proposals.',
    triggerTokens: {'drafting:2026-06-10'},
  ),
  metadata: const EvalScenarioMetadata(
    capabilityIds: ['planner.proposal.schema'],
  ),
  expectations: EvalExpectations(durableState: durableState),
);

Matcher _containsMessage(String fragment) => contains(
  predicate<String>(
    (message) => message.contains(fragment),
    'message containing "$fragment"',
  ),
);
