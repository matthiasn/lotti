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
        'changeSetStatus',
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
}
