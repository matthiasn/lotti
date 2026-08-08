import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/attention_negotiation.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/workflow/task_agent_strategy.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import 'task_agent_workflow_test_helpers.dart';

/// Covers the agenda-gated tool surface of a wake: which tools
/// `TaskAgentWorkflow` advertises for the facts it resolves about the task, and
/// how that list widens after the opening turn.
///
/// The gating itself is unit-tested in
/// `test/features/agents/tools/task_agent_tool_gate_test.dart`; these tests
/// prove the workflow resolves the *facts* from the real task, timer and
/// ledger, which is the part that can silently withhold a tool a wake needs.
void main() {
  const agentId = taskAgentTestAgentId;
  const taskId = taskAgentTestTaskId;
  const runKey = taskAgentTestRunKey;
  const threadId = taskAgentTestThreadId;
  final testAgentIdentity = taskAgentTestAgentIdentity;
  final testAgentState = taskAgentTestAgentState;
  final geminiProvider = taskAgentTestGeminiProvider;
  final geminiModel = taskAgentTestGeminiModel;

  setUpAll(setUpTaskAgentWorkflowTestGetIt);
  tearDownAll(tearDownTaskAgentWorkflowTestGetIt);

  /// A task with no checklist items — the bare case every gate applies to.
  Task bareTask({List<String>? checklistIds}) => Task(
    meta: Metadata(
      id: taskId,
      createdAt: DateTime(2024, 3, 15),
      dateFrom: DateTime(2024, 3, 15),
      dateTo: DateTime(2024, 3, 15),
      updatedAt: DateTime(2024, 3, 15),
      categoryId: 'cat-001',
    ),
    data: TaskData(
      status: TaskStatus.open(
        id: 'status_id',
        createdAt: DateTime(2024, 3, 15),
        utcOffset: 60,
      ),
      title: 'Wire up the gated tool surface',
      statusHistory: [],
      dateFrom: DateTime(2024, 3, 15),
      dateTo: DateTime(2024, 3, 15),
      checklistIds: checklistIds,
    ),
  );

  /// Runs one wake and returns, per `sendMessage` in call order, the tool names
  /// the workflow handed over (`handedOver`) and the ones the turn really saw
  /// after the strategy narrowed them (`forTurn`).
  ///
  /// Both are needed: the wake facts decide `handedOver`, the staged exposure
  /// decides `forTurn`, and only comparing the two shows which of the two
  /// mechanisms dropped a tool.
  Future<List<({List<String> handedOver, List<String> forTurn})>>
  exposedToolNamesPerTurn(
    TaskAgentWorkflowTestBench bench, {
    Task? task,
  }) async {
    stubFullExecutePath(
      mockAgentRepository: bench.mockAgentRepository,
      mockAiInputRepository: bench.mockAiInputRepository,
      mockAiConfigRepository: bench.mockAiConfigRepository,
      mockConversationManager: bench.mockConversationManager,
      testAgentState: testAgentState,
      geminiModel: geminiModel,
      geminiProvider: geminiProvider,
      agentId: agentId,
      taskId: taskId,
    );
    when(
      () => bench.mockJournalDb.journalEntityById(taskId),
    ).thenAnswer((_) async => task ?? bareTask());

    // Two turns: the forced-`update_report` retry is the second call, which is
    // exactly the turn the staged exposure widens on.
    bench.mockConversationRepository.maxDelegateCalls = 2;

    final perTurn = <({List<String> handedOver, List<String> forTurn})>[];
    bench.mockConversationRepository.sendMessageDelegate =
        ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
          toolChoice,
          temperature = 0.7,
          strategy,
        }) async {
          final turnIndex = perTurn.length;
          final handedOver = tools ?? const <ChatCompletionTool>[];
          // Mirrors `ConversationRepository.sendMessage`: the strategy gets to
          // narrow the list the workflow handed over, per turn.
          final forTurn =
              (strategy as TaskAgentStrategy?)?.toolsForTurn(
                turnIndex: turnIndex,
                manager: bench.mockConversationManager,
              ) ??
              handedOver;
          perTurn.add((
            handedOver: handedOver.map((tool) => tool.function.name).toList(),
            forTurn: forTurn.map((tool) => tool.function.name).toList(),
          ));
          return null;
        };

    final result = await bench.workflow.execute(
      agentIdentity: testAgentIdentity,
      runKey: runKey,
      triggerTokens: {'entity-a'},
      threadId: threadId,
    );

    expect(result.success, isTrue);
    expect(perTurn, isNotEmpty, reason: 'the wake never reached the LLM');
    return perTurn;
  }

  /// Every gated tool name, so an assertion states the whole set rather than
  /// the one name a test happens to care about.
  const gatedToolNames = <String>[
    TaskAgentToolNames.updateChecklistItems,
    TaskAgentToolNames.updateRunningTimer,
    TaskAgentToolNames.updateTimeEntry,
    TaskAgentToolNames.assignTaskLabels,
    TaskAgentToolNames.retractSuggestions,
    TaskAgentToolNames.resolveAttentionRequest,
  ];

  group('TaskAgentWorkflow tool exposure', () {
    test('advertises every gated tool when narrowToolSurface is off', () async {
      // The shipped wake: nothing about the task is true — no checklist, no
      // timer, no labels, no proposals, no claims — and it still gets the
      // whole registry, including `update_report` on the opening turn.
      final bench = createTaskAgentWorkflowTestBench();

      final perTurn = await exposedToolNamesPerTurn(bench);

      expect(perTurn.first.handedOver, containsAll(gatedToolNames));
      expect(
        perTurn.first.handedOver,
        contains(TaskAgentToolNames.updateReport),
      );
      // Nothing is staged, so the strategy hands the list straight through
      // rather than narrowing the opening turn.
      expect(perTurn.first.forTurn, perTurn.first.handedOver);
    });

    test(
      'withholds every unusable tool, and update_report until turn two',
      () async {
        final bench = createTaskAgentWorkflowTestBench(narrowToolSurface: true);

        final perTurn = await exposedToolNamesPerTurn(bench);

        for (final name in gatedToolNames) {
          expect(
            perTurn.first.handedOver,
            isNot(contains(name)),
            reason: '$name has no precondition met on this task',
          );
        }
        // `bareTask()` carries a null `checklistIds`, which is how a task that
        // never had a checklist is stored. The gate has to read that as
        // "nothing to update" rather than "unknown, so offer it" — otherwise
        // `update_checklist_items` is never withheld from a real task.
        expect(
          perTurn.first.handedOver,
          isNot(contains(TaskAgentToolNames.updateChecklistItems)),
        );
        // `update_report` is the staged one: the workflow still hands it over,
        // and the strategy withholds it from the opening turn so the wake does
        // the work before it reports on it.
        expect(
          perTurn.first.handedOver,
          contains(TaskAgentToolNames.updateReport),
        );
        expect(
          perTurn.first.forTurn,
          isNot(contains(TaskAgentToolNames.updateReport)),
        );
        // Unconditional tools stay on the opening turn — the narrowing must not
        // strip the tools that make a wake useful.
        expect(
          perTurn.first.forTurn,
          containsAll(<String>[
            TaskAgentToolNames.setTaskStatus,
            TaskAgentToolNames.setTaskTitle,
            TaskAgentToolNames.updateTaskDueDate,
            TaskAgentToolNames.recordObservations,
          ]),
        );
      },
    );

    test(
      'offers each gated tool once the task supplies its precondition',
      () async {
        final bench = createTaskAgentWorkflowTestBench(narrowToolSurface: true);

        final running = makeLinkedTimeEntry(
          id: 'running-entry',
          dateFrom: DateTime(2024, 6, 14, 10),
          dateTo: DateTime(2024, 6, 14, 10, 5),
          text: 'active',
        );
        final completed = makeLinkedTimeEntry(
          id: 'completed-entry',
          dateFrom: DateTime(2024, 6, 13, 10),
          dateTo: DateTime(2024, 6, 13, 11),
          text: 'past work',
        );
        final task = bareTask(checklistIds: ['checklist-1']);

        final timeService = getIt<TimeService>();
        await timeService.start(running, task);
        addTearDown(timeService.stop);

        when(
          () => bench.mockJournalDb.getLinkedEntities(taskId),
        ).thenAnswer((_) async => <JournalEntity>[running, completed]);
        when(bench.mockJournalDb.getAllLabelDefinitions).thenAnswer(
          (_) async => [
            LabelDefinition(
              id: 'label-1',
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
              name: 'Bug',
              color: '#FF0000',
              vectorClock: null,
            ),
          ],
        );
        when(
          () => bench.mockAgentRepository.getProposalLedger(
            any(),
            taskId: any(named: 'taskId'),
            changeSetFetchLimit: any(named: 'changeSetFetchLimit'),
            resolvedLimit: any(named: 'resolvedLimit'),
          ),
        ).thenAnswer(
          (_) async => ProposalLedger(
            open: [
              LedgerEntry(
                changeSetId: 'cs-1',
                itemIndex: 0,
                toolName: TaskAgentToolNames.setTaskStatus,
                args: const {'status': 'inProgress'},
                humanSummary: 'Move to in progress',
                fingerprint: 'fp-1',
                status: ChangeItemStatus.pending,
                createdAt: DateTime(2024, 6, 14),
              ),
            ],
            resolved: const [],
          ),
        );
        when(
          () => bench.mockAgentRepository.getAttentionClaimsForTarget(
            targetKind: any(named: 'targetKind'),
            targetId: any(named: 'targetId'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => [
            AgentDomainEntity.attentionRequest(
                  id: 'attn-1',
                  agentId: agentId,
                  kind: AttentionRequestKind.task,
                  title: 'Finish the gated tool surface',
                  categoryId: 'cat-001',
                  requestedMinutes: 90,
                  impact: 5,
                  urgency: 4,
                  energyFit: AttentionEnergyFit.high,
                  evidenceRefs: const [
                    AttentionEvidenceRef(
                      kind: AttentionEvidenceKind.task,
                      id: taskId,
                      label: 'Gated tool surface',
                    ),
                  ],
                  targetId: taskId,
                  targetKind: 'task',
                  createdAt: DateTime(2024, 6, 14),
                  vectorClock: null,
                )
                as AttentionRequestEntity,
          ],
        );

        final perTurn = await exposedToolNamesPerTurn(bench, task: task);

        expect(perTurn.first.handedOver, containsAll(gatedToolNames));
      },
    );

    test(
      'withholds update_running_timer for a timer owned by another task',
      () async {
        // A timer running on a different task reaches the prompt only as an
        // opaque range, so there is no id for the agent to update — offering the
        // tool would only invite it to invent one. The completed entry still
        // earns `update_time_entry`, which is what separates the two gates.
        final bench = createTaskAgentWorkflowTestBench(narrowToolSurface: true);

        final running = makeLinkedTimeEntry(
          id: 'running-entry',
          dateFrom: DateTime(2024, 6, 14, 10),
          dateTo: DateTime(2024, 6, 14, 10, 5),
          text: 'active elsewhere',
        );
        final completed = makeLinkedTimeEntry(
          id: 'completed-entry',
          dateFrom: DateTime(2024, 6, 13, 10),
          dateTo: DateTime(2024, 6, 13, 11),
          text: 'past work',
        );

        final timeService = getIt<TimeService>();
        await timeService.start(running, makeWorkflowTestTask('other-task'));
        addTearDown(timeService.stop);

        when(
          () => bench.mockJournalDb.getLinkedEntities(taskId),
        ).thenAnswer((_) async => <JournalEntity>[completed]);

        final perTurn = await exposedToolNamesPerTurn(bench);

        expect(
          perTurn.first.handedOver,
          isNot(contains(TaskAgentToolNames.updateRunningTimer)),
        );
        expect(
          perTurn.first.handedOver,
          contains(TaskAgentToolNames.updateTimeEntry),
        );
      },
    );

    test(
      'withholds update_time_entry when the only linked entry is running',
      () async {
        // The running entry is excluded from the editable set — it is
        // `update_running_timer`'s target, not `update_time_entry`'s — so a task
        // whose only time record is the live one has nothing to edit.
        final bench = createTaskAgentWorkflowTestBench(narrowToolSurface: true);

        final running = makeLinkedTimeEntry(
          id: 'running-entry',
          dateFrom: DateTime(2024, 6, 14, 10),
          dateTo: DateTime(2024, 6, 14, 10, 5),
          text: 'active',
        );
        final task = bareTask();

        final timeService = getIt<TimeService>();
        await timeService.start(running, task);
        addTearDown(timeService.stop);

        when(
          () => bench.mockJournalDb.getLinkedEntities(taskId),
        ).thenAnswer((_) async => <JournalEntity>[running]);

        final perTurn = await exposedToolNamesPerTurn(bench, task: task);

        expect(
          perTurn.first.handedOver,
          contains(TaskAgentToolNames.updateRunningTimer),
        );
        expect(
          perTurn.first.handedOver,
          isNot(contains(TaskAgentToolNames.updateTimeEntry)),
        );
      },
    );
  });
}
