import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/workflow/task_agent_strategy.dart';
import 'package:lotti/features/agents/workflow/task_agent_workflow.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
import 'package:lotti/features/notifications/repository/notification_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../mocks/mocks.dart';
import '../test_utils.dart';
import 'task_agent_workflow_test_helpers.dart';

void main() {
  late MockAgentRepository mockAgentRepository;
  late MockAgentSyncService mockSyncService;
  late MockConversationRepository mockConversationRepository;
  late MockAiInputRepository mockAiInputRepository;
  late MockAiConfigRepository mockAiConfigRepository;
  late MockJournalDb mockJournalDb;
  late MockConversationManager mockConversationManager;
  late MockJournalRepository mockJournalRepository;
  late MockChecklistRepository mockChecklistRepository;
  late MockLabelsRepository mockLabelsRepository;
  late TaskAgentWorkflow workflow;

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

  setUp(() {
    final bench = createTaskAgentWorkflowTestBench();
    mockAgentRepository = bench.mockAgentRepository;
    mockSyncService = bench.mockSyncService;
    mockConversationRepository = bench.mockConversationRepository;
    mockAiInputRepository = bench.mockAiInputRepository;
    mockAiConfigRepository = bench.mockAiConfigRepository;
    mockJournalDb = bench.mockJournalDb;
    mockConversationManager = bench.mockConversationManager;
    mockJournalRepository = bench.mockJournalRepository;
    mockChecklistRepository = bench.mockChecklistRepository;
    mockLabelsRepository = bench.mockLabelsRepository;
    workflow = bench.workflow;
  });

  group('TaskAgentWorkflow', () {
    group('_executeToolHandler dispatch', () {
      /// Helper that sets up a successful execute path where sendMessage
      /// invokes the strategy's processToolCalls with a specific tool call.
      Future<WakeResult> executeWithToolCall(
        String toolName,
        String arguments,
      ) async {
        stubFullExecutePath(
          mockAgentRepository: mockAgentRepository,
          mockAiInputRepository: mockAiInputRepository,
          mockAiConfigRepository: mockAiConfigRepository,
          mockConversationManager: mockConversationManager,
          testAgentState: testAgentState,
          geminiModel: geminiModel,
          geminiProvider: geminiProvider,
          agentId: agentId,
          taskId: taskId,
        );

        // Stub the task entity lookup used by _executeToolHandler.
        when(
          () => mockJournalDb.journalEntityById(taskId),
        ).thenAnswer((_) async => null);

        mockConversationRepository.sendMessageDelegate =
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
              if (strategy is TaskAgentStrategy) {
                await strategy.processToolCalls(
                  toolCalls: [
                    ChatCompletionMessageToolCall(
                      id: 'tool-call-1',
                      type: ChatCompletionMessageToolCallType.function,
                      function: ChatCompletionMessageFunctionCall(
                        name: toolName,
                        arguments: arguments,
                      ),
                    ),
                  ],
                  manager: mockConversationManager,
                );
              }
              return null;
            };

        return workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );
      }

      test(
        'tool call with missing task entity triggers policy denial',
        () async {
          // journalEntityById returns null, so category resolution yields null
          // and the executor's fail-closed policy denies the call. This verifies
          // the wake doesn't crash on a missing task.
          final result = await executeWithToolCall('nonexistent_tool', '{}');

          // Tool errors don't fail the overall wake.
          expect(result.success, isTrue);
        },
      );

      test(
        'set_task_title with missing task entity is denied gracefully',
        () async {
          // Same as above — task entity is null so executor denies the call.
          final result = await executeWithToolCall(
            'set_task_title',
            '{"title":""}',
          );
          expect(result.success, isTrue);
        },
      );

      test(
        'does not expose disabled related-task drill-down tools to the LLM',
        () async {
          final relatedTaskTool = AgentToolRegistry.taskAgentTools.firstWhere(
            (def) => def.name == TaskAgentToolNames.getRelatedTaskDetails,
          );
          expect(relatedTaskTool.enabled, isFalse);

          when(
            () => mockAgentRepository.getAgentState(agentId),
          ).thenAnswer((_) async => testAgentState);
          when(
            () => mockAgentRepository.getLatestReport(agentId, 'current'),
          ).thenAnswer((_) async => null);
          when(
            () => mockAgentRepository.getMessagesByKind(
              agentId,
              AgentMessageKind.observation,
            ),
          ).thenAnswer((_) async => []);
          when(
            () => mockAiInputRepository.buildTaskDetailsJson(id: taskId),
          ).thenAnswer((_) async => '{"title":"Test Task"}');
          when(
            () => mockAiInputRepository.buildProjectContextJsonForTask(taskId),
          ).thenAnswer((_) async => '{}');
          when(
            () => mockAiInputRepository.buildLinkedFromContext(taskId),
          ).thenAnswer((_) async => <AiLinkedTaskContext>[]);
          when(
            () => mockAiInputRepository.buildLinkedToContext(taskId),
          ).thenAnswer((_) async => <AiLinkedTaskContext>[]);
          when(
            () => mockAiConfigRepository.getConfigsByType(AiConfigType.model),
          ).thenAnswer((_) async => [geminiModel]);
          when(
            () => mockAiConfigRepository.getConfigById('gemini-provider-001'),
          ).thenAnswer((_) async => geminiProvider);
          when(
            () => mockAgentRepository.getReportHead(agentId, 'current'),
          ).thenAnswer((_) async => null);
          when(() => mockConversationManager.messages).thenReturn([]);

          List<ChatCompletionTool>? exposedTools;
          mockConversationRepository.sendMessageDelegate =
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
                exposedTools = tools;
                return null;
              };

          final result = await workflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(result.success, isTrue);
          expect(exposedTools, isNotNull);
          expect(
            exposedTools!.map((tool) => tool.function.name),
            isNot(contains(TaskAgentToolNames.getRelatedTaskDetails)),
          );
        },
      );
    });

    group('tool handler dispatch with real Task', () {
      /// Common stubs for execute path up through sendMessage.
      void stubFullExecutePathLocal() {
        stubFullExecutePath(
          mockAgentRepository: mockAgentRepository,
          mockAiInputRepository: mockAiInputRepository,
          mockAiConfigRepository: mockAiConfigRepository,
          mockConversationManager: mockConversationManager,
          testAgentState: testAgentState,
          geminiModel: geminiModel,
          geminiProvider: geminiProvider,
          agentId: agentId,
          taskId: taskId,
        );
      }

      /// A Task with categoryId matching the agent's allowed set.
      final taskWithCategory = Task(
        data: TaskData(
          status: TaskStatus.open(
            id: 'status_id',
            createdAt: DateTime(2024, 3, 15),
            utcOffset: 60,
          ),
          title: 'Add tests for journal page',
          statusHistory: [],
          dateTo: DateTime(2024, 3, 15),
          dateFrom: DateTime(2024, 3, 15),
          estimate: const Duration(hours: 4),
        ),
        meta: Metadata(
          id: taskId,
          createdAt: DateTime(2024, 3, 15),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          categoryId: 'cat-001',
        ),
      );

      test(
        'reuses task loaded for attention maintenance when rendering prompt',
        () async {
          stubFullExecutePathLocal();
          when(
            () => mockJournalDb.journalEntityById(taskId),
          ).thenAnswer((_) async => taskWithCategory);

          final result = await workflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(result.success, isTrue);
          verify(() => mockJournalDb.journalEntityById(taskId)).called(1);
        },
      );

      /// Sets up sendMessage to dispatch a tool call and capture the result.
      Future<WakeResult> executeWithToolCallOnRealTask(
        String toolName,
        String arguments, {
        Task? task,
      }) async {
        stubFullExecutePathLocal();

        // Return a real Task entity from the DB so tool handler dispatch
        // actually exercises the handler code.
        when(
          () => mockJournalDb.journalEntityById(taskId),
        ).thenAnswer((_) async => task ?? taskWithCategory);

        // Stub addToolResponse on the conversation manager.
        when(
          () => mockConversationManager.addToolResponse(
            toolCallId: any(named: 'toolCallId'),
            response: any(named: 'response'),
          ),
        ).thenReturn(null);

        // Dispatch the tool call on the first sendMessage only. The workflow
        // issues a second, forced-`update_report` retry whenever the strategy
        // finishes without a report — which is every deferred-tool test here
        // because the mock never produces one. Re-dispatching the same tool
        // on retry would double-count `addToolResponse` calls; the retry is
        // fine as a no-op for these tests.
        var dispatched = false;
        mockConversationRepository.sendMessageDelegate =
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
              if (dispatched) return null;
              dispatched = true;
              if (strategy is TaskAgentStrategy) {
                await strategy.processToolCalls(
                  toolCalls: [
                    ChatCompletionMessageToolCall(
                      id: 'tc-1',
                      type: ChatCompletionMessageToolCallType.function,
                      function: ChatCompletionMessageFunctionCall(
                        name: toolName,
                        arguments: arguments,
                      ),
                    ),
                  ],
                  manager: mockConversationManager,
                );
              }
              return null;
            };

        return workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );
      }

      test('set_task_title is deferred when a title already exists', () async {
        // The initial-title auto-apply only fires on an empty title; with a
        // populated title the rename must flow through the confirmable
        // proposal path (no immediate journal write).
        final result = await executeWithToolCallOnRealTask(
          'set_task_title',
          '{"title":"New Title"}',
        );
        expect(result.success, isTrue);
        verifyToolWasDeferred(
          mockConversationManager: mockConversationManager,
          mockJournalRepository: mockJournalRepository,
        );
      });

      test('set_task_title succeeds on empty title', () async {
        // Create a Task with empty title but correct category.
        final taskNoTitle = Task(
          data: TaskData(
            status: TaskStatus.open(
              id: 'status_id',
              createdAt: DateTime(2024, 3, 15),
              utcOffset: 60,
            ),
            title: '',
            statusHistory: [],
            dateTo: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
          ),
          meta: Metadata(
            id: taskId,
            createdAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            categoryId: 'cat-001',
          ),
        );

        when(
          () => mockJournalRepository.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);
        registerFallbackValue(taskNoTitle);

        final result = await executeWithToolCallOnRealTask(
          'set_task_title',
          '{"title":"My New Task"}',
          task: taskNoTitle,
        );
        expect(result.success, isTrue);
        // Empty title takes the initial-title auto-apply shortcut: the
        // handler writes immediately instead of queuing a proposal.
        final written =
            verify(
                  () => mockJournalRepository.updateJournalEntity(captureAny()),
                ).captured.single
                as Task;
        expect(written.data.title, 'My New Task');
      });

      // ── Deferred tool calls ──────────────────────────────────────────
      //
      // All mutating tools are now deferred to a ChangeSetBuilder rather
      // than executed immediately. The strategy responds with "Proposal
      // queued for user review." and the actual validation/execution
      // happens when the user confirms the change set.

      // Deferred-tool invalid/empty-arg cases: validation happens at
      // confirmation time, so the wake itself only records the proposal. Each
      // test asserts the concrete LLM-facing tool response — that the named
      // tool was reported as recorded with the "do not repeat" guidance —
      // rather than only that the wake didn't crash.
      for (final (label, toolName, arguments) in <(String, String, String)>[
        ('set_task_title with missing title arg', 'set_task_title', '{}'),
        (
          'update_task_estimate with null minutes',
          'update_task_estimate',
          '{}',
        ),
        (
          'update_task_due_date with empty dueDate',
          'update_task_due_date',
          '{"dueDate":""}',
        ),
        (
          'update_task_priority with empty priority',
          'update_task_priority',
          '{"priority":""}',
        ),
      ]) {
        test('$label is deferred with a recorded-proposal response', () async {
          final result = await executeWithToolCallOnRealTask(
            toolName,
            arguments,
          );
          expect(result.success, isTrue);

          final response = captureDeferredToolResponse(mockConversationManager);
          expect(response, contains(toolName));
          expect(response, contains('proposal recorded successfully'));
          expect(response, contains('Do NOT call $toolName again'));
        });
      }

      test('assign_task_labels with non-array labels is deferred', () async {
        final result = await executeWithToolCallOnRealTask(
          'assign_task_labels',
          '{"labels":"not-an-array"}',
        );
        expect(result.success, isTrue);
        verifyDeferredToolResponse(mockConversationManager);
      });

      test('assign_task_labels with valid labels is deferred', () async {
        final result = await executeWithToolCallOnRealTask(
          'assign_task_labels',
          '{"labels":[{"id":"label-1","confidence":"high"}]}',
        );

        expect(result.success, isTrue);
        // Labels are NOT executed immediately — they are deferred.
        verifyNever(
          () => mockLabelsRepository.addLabels(
            journalEntityId: any(named: 'journalEntityId'),
            addedLabelIds: any(named: 'addedLabelIds'),
          ),
        );
        verifyDeferredToolResponse(mockConversationManager);
      });

      test(
        'assign_task_labels resolves the label name into the proposal summary',
        () async {
          // The workflow's labelNameResolver looks up the definition and
          // returns its name; the change set builder folds that name into the
          // human-readable summary the user reviews. Stub the lookup and
          // assert the resolved name reaches the persisted change set.
          when(
            () => mockJournalDb.getLabelDefinitionById('label-1'),
          ).thenAnswer(
            (_) async => LabelDefinition(
              id: 'label-1',
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
              name: 'Bug',
              color: '#FF0000',
              vectorClock: null,
            ),
          );

          final result = await executeWithToolCallOnRealTask(
            'assign_task_labels',
            '{"labels":[{"id":"label-1","confidence":"high"}]}',
          );

          expect(result.success, isTrue);
          verify(
            () => mockJournalDb.getLabelDefinitionById('label-1'),
          ).called(1);

          final changeSets = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured.whereType<ChangeSetEntity>().toList();
          final summaries = changeSets
              .expand((s) => s.items)
              .map((i) => i.humanSummary)
              .toList();
          // The resolved name "Bug" (not the raw id) appears in the summary,
          // proving labelNameResolver returned label.name.
          expect(summaries, contains(contains('Bug')));
        },
      );

      test(
        'add_multiple_checklist_items with non-array items is deferred',
        () async {
          final result = await executeWithToolCallOnRealTask(
            'add_multiple_checklist_items',
            '{"items":"not an array"}',
          );
          expect(result.success, isTrue);
          verifyDeferredToolResponse(mockConversationManager);
        },
      );

      test('update_checklist_items with non-array items is deferred', () async {
        final result = await executeWithToolCallOnRealTask(
          'update_checklist_items',
          '{"items":"not an array"}',
        );
        expect(result.success, isTrue);
        verifyDeferredToolResponse(mockConversationManager);
      });

      test('update_checklist_items with empty array is deferred', () async {
        final result = await executeWithToolCallOnRealTask(
          'update_checklist_items',
          '{"items":[]}',
        );
        expect(result.success, isTrue);
        verifyDeferredToolResponse(mockConversationManager);
      });

      test(
        'add_multiple_checklist_items with empty array is deferred',
        () async {
          final result = await executeWithToolCallOnRealTask(
            'add_multiple_checklist_items',
            '{"items":[]}',
          );
          expect(result.success, isTrue);
          verifyDeferredToolResponse(mockConversationManager);
        },
      );

      test(
        'add_multiple_checklist_items with string items reports skipped',
        () async {
          // String items are skipped by the ChangeSetBuilder's batch
          // exploder (they are not Map<String, dynamic>).
          final result = await executeWithToolCallOnRealTask(
            'add_multiple_checklist_items',
            '{"items":["Buy milk","Pay bills"]}',
          );
          expect(result.success, isTrue);
          verify(
            () => mockConversationManager.addToolResponse(
              toolCallId: 'tc-1',
              response: any(named: 'response', that: contains('skipped')),
            ),
          ).called(1);
        },
      );

      test('update_checklist_items with a missing id is rejected', () async {
        // A checklist update without an id cannot be applied, so it is
        // rejected at queue time (not deferred to confirmation) with
        // model-facing feedback — never surfaced as a raw-id suggestion.
        final result = await executeWithToolCallOnRealTask(
          'update_checklist_items',
          '{"items":[{"isChecked":true}]}',
        );
        expect(result.success, isTrue);
        verify(
          () => mockConversationManager.addToolResponse(
            toolCallId: 'tc-1',
            response: any(
              named: 'response',
              that: contains('missing a checklist item "id"'),
            ),
          ),
        ).called(1);
      });

      test('update_time_entry drives the real editable-time-entry resolver '
          'closure and accepts a listed entry', () async {
        // Exercises TaskAgentWorkflow.resolveEditableTimeEntryIds end to end:
        // the running timer for THIS task is excluded, leaving the historical
        // linked entry as the only editable id.
        final timeService = getIt<TimeService>();
        final running = makeLinkedTimeEntry(
          id: 'running-entry',
          dateFrom: DateTime(2024, 6, 14, 10),
          dateTo: DateTime(2024, 6, 14, 10, 5),
          text: 'active',
        );
        final historical = makeLinkedTimeEntry(
          id: 'historical-entry',
          dateFrom: DateTime(2024, 6, 13, 10),
          dateTo: DateTime(2024, 6, 13, 11),
          text: 'past work',
        );
        await timeService.start(running, makeWorkflowTestTask(taskId));
        addTearDown(timeService.stop);
        when(
          () => mockJournalDb.getLinkedEntities(taskId),
        ).thenAnswer((_) async => [running, historical]);

        final result = await executeWithToolCallOnRealTask(
          'update_time_entry',
          '{"entryId":"historical-entry","summary":"Refined"}',
        );

        expect(result.success, isTrue);
        verify(
          () => mockConversationManager.addToolResponse(
            toolCallId: 'tc-1',
            response: any(
              named: 'response',
              that: contains('recorded successfully'),
            ),
          ),
        ).called(1);
      });

      test('update_time_entry rejects an id the real resolver closure does not '
          'list (running timer excluded)', () async {
        final timeService = getIt<TimeService>();
        final running = makeLinkedTimeEntry(
          id: 'running-entry',
          dateFrom: DateTime(2024, 6, 14, 10),
          dateTo: DateTime(2024, 6, 14, 10, 5),
          text: 'active',
        );
        await timeService.start(running, makeWorkflowTestTask(taskId));
        addTearDown(timeService.stop);
        // Only the running entry is linked, and it is excluded from the
        // editable set — so any entryId is rejected as not editable.
        when(
          () => mockJournalDb.getLinkedEntities(taskId),
        ).thenAnswer((_) async => [running]);

        final result = await executeWithToolCallOnRealTask(
          'update_time_entry',
          '{"entryId":"running-entry","summary":"x"}',
        );

        expect(result.success, isTrue);
        verify(
          () => mockConversationManager.addToolResponse(
            toolCallId: 'tc-1',
            response: any(
              named: 'response',
              that: contains('not an editable time entry'),
            ),
          ),
        ).called(1);
      });

      test(
        'update_running_timer drives the real running-timer resolver closure '
        'and accepts the running timer id',
        () async {
          // Exercises TaskAgentWorkflow.resolveRunningTimerId: the timer is for
          // THIS task, so its id is the only accepted timerId.
          final timeService = getIt<TimeService>();
          final running = makeLinkedTimeEntry(
            id: 'running-entry',
            dateFrom: DateTime(2024, 6, 14, 10),
            dateTo: DateTime(2024, 6, 14, 10, 5),
            text: 'active',
          );
          await timeService.start(running, makeWorkflowTestTask(taskId));
          addTearDown(timeService.stop);

          final result = await executeWithToolCallOnRealTask(
            'update_running_timer',
            '{"timerId":"running-entry","summary":"Refactoring"}',
          );

          expect(result.success, isTrue);
          verify(
            () => mockConversationManager.addToolResponse(
              toolCallId: 'tc-1',
              response: any(
                named: 'response',
                that: contains('recorded successfully'),
              ),
            ),
          ).called(1);
        },
      );

      test('update_task_estimate accepts numeric string minutes', () async {
        when(
          () => mockJournalRepository.updateJournalEntity(any()),
        ).thenAnswer((_) async => true);

        final result = await executeWithToolCallOnRealTask(
          'update_task_estimate',
          '{"minutes":"120"}',
        );
        expect(result.success, isTrue);
        // Should NOT receive a validation error — handler's parseMinutes
        // accepts numeric strings.
        verifyNever(
          () => mockConversationManager.addToolResponse(
            toolCallId: 'tc-1',
            response: any(named: 'response', that: contains('required')),
          ),
        );
      });

      test(
        'add_multiple_checklist_items with valid object items passes parsing',
        () async {
          // Valid format: array of objects with "title" field, matching the
          // handler's expected schema.
          final result = await executeWithToolCallOnRealTask(
            'add_multiple_checklist_items',
            '{"items":[{"title":"Buy milk"},{"title":"Walk dog","isChecked":true}]}',
          );
          expect(result.success, isTrue);
          // The tool response should NOT contain the type-validation error.
          // It may report "Created 0 checklist items" because the handler's
          // internal getIt call isn't set up, but that's fine — the point is
          // the args format was accepted.
          verifyNever(
            () => mockConversationManager.addToolResponse(
              toolCallId: 'tc-1',
              response: any(
                named: 'response',
                that: contains('non-empty array'),
              ),
            ),
          );
        },
      );

      test('update_checklist_items with valid items passes parsing', () async {
        // Valid format: array of objects with "id" and "isChecked" fields,
        // using the correct "items" key that the handler expects.
        final result = await executeWithToolCallOnRealTask(
          'update_checklist_items',
          '{"items":[{"id":"item-1","isChecked":true}]}',
        );
        expect(result.success, isTrue);
        // Should NOT contain the type-validation error.
        verifyNever(
          () => mockConversationManager.addToolResponse(
            toolCallId: 'tc-1',
            response: any(named: 'response', that: contains('non-empty array')),
          ),
        );
      });

      test('unknown tool returns error', () async {
        final result = await executeWithToolCallOnRealTask(
          'nonexistent_tool',
          '{}',
        );
        expect(result.success, isTrue);
        verify(
          () => mockConversationManager.addToolResponse(
            toolCallId: 'tc-1',
            response: any(named: 'response', that: contains('Unknown tool')),
          ),
        ).called(1);
      });

      group('deferred handler execution paths', () {
        /// A Task without estimate, due date, and with default priority.
        final taskForUpdates = Task(
          data: TaskData(
            status: TaskStatus.open(
              id: 'status_id',
              createdAt: DateTime(2024, 3, 15),
              utcOffset: 60,
            ),
            title: 'Task without metadata',
            statusHistory: [],
            dateTo: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
          ),
          meta: Metadata(
            id: taskId,
            createdAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            categoryId: 'cat-001',
          ),
        );

        test('update_task_estimate is deferred', () async {
          final result = await executeWithToolCallOnRealTask(
            'update_task_estimate',
            '{"minutes":60}',
            task: taskForUpdates,
          );
          expect(result.success, isTrue);
          // Not executed immediately — deferred to change set.
          verifyToolWasDeferred(
            mockConversationManager: mockConversationManager,
            mockJournalRepository: mockJournalRepository,
          );
        });

        test('update_task_due_date is deferred', () async {
          final result = await executeWithToolCallOnRealTask(
            'update_task_due_date',
            '{"dueDate":"2024-06-30"}',
            task: taskForUpdates,
          );
          expect(result.success, isTrue);
          verifyToolWasDeferred(
            mockConversationManager: mockConversationManager,
            mockJournalRepository: mockJournalRepository,
          );
        });

        test('update_task_priority is deferred', () async {
          final result = await executeWithToolCallOnRealTask(
            'update_task_priority',
            '{"priority":"P1"}',
            task: taskForUpdates,
          );
          expect(result.success, isTrue);
          verifyToolWasDeferred(
            mockConversationManager: mockConversationManager,
            mockJournalRepository: mockJournalRepository,
          );
        });

        test(
          'update_task_estimate with already-set estimate is suppressed',
          () async {
            // When the proposed value matches the current value, the redundancy
            // filter suppresses it and feeds back a skip message to the LLM.
            final result = await executeWithToolCallOnRealTask(
              'update_task_estimate',
              '{"minutes":240}',
            );
            expect(result.success, isTrue);
            verify(
              () => mockConversationManager.addToolResponse(
                toolCallId: 'tc-1',
                response: any(
                  named: 'response',
                  that: contains('Skipped: estimate is already 240 minutes'),
                ),
              ),
            ).called(1);
          },
        );

        test('update_task_due_date with invalid format is deferred', () async {
          // Invalid args are still deferred — validation happens at
          // confirmation time via TaskToolDispatcher.
          final result = await executeWithToolCallOnRealTask(
            'update_task_due_date',
            '{"dueDate":"not-a-date"}',
            task: taskForUpdates,
          );
          expect(result.success, isTrue);
          verifyDeferredToolResponse(mockConversationManager);
        });

        test(
          'update_task_priority with invalid priority is deferred',
          () async {
            final result = await executeWithToolCallOnRealTask(
              'update_task_priority',
              '{"priority":"P9"}',
              task: taskForUpdates,
            );
            expect(result.success, isTrue);
            verifyDeferredToolResponse(mockConversationManager);
          },
        );

        test(
          'update_task_estimate with persistence failure is deferred',
          () async {
            // The tool call is deferred regardless — no DB write happens yet.
            final result = await executeWithToolCallOnRealTask(
              'update_task_estimate',
              '{"minutes":60}',
              task: taskForUpdates,
            );
            expect(result.success, isTrue);
            verifyToolWasDeferred(
              mockConversationManager: mockConversationManager,
              mockJournalRepository: mockJournalRepository,
            );
          },
        );

        test(
          'an incremental flush notifies the UI so suggestions appear mid-wake',
          () async {
            // Writing the change set is not enough: the suggestion providers
            // re-query only when `agentUpdateStreamProvider` emits, and
            // `AgentSyncService` does not notify on upsert. Without a UI
            // notification per flush the proposals stay invisible until
            // `_notifyWakeCompletion` fires after the whole wake returns —
            // i.e. the feature would do nothing at all.
            // `setUpTestGetIt` already registers a MockUpdateNotifications;
            // use that instance so the production lookup and the assertions
            // land on the same object. It lives for the whole file, so drop
            // interactions recorded by earlier tests first.
            final updateNotifications =
                getIt<UpdateNotifications>() as MockUpdateNotifications;
            clearInteractions(updateNotifications);
            when(
              () => updateNotifications.notifyUiOnly(any()),
            ).thenReturn(null);

            final result = await executeWithToolCallOnRealTask(
              'update_task_estimate',
              '{"minutes":60}',
              task: taskForUpdates,
            );

            expect(result.success, isTrue);
            final notified = verify(
              () => updateNotifications.notifyUiOnly(captureAny()),
            ).captured.cast<Set<String>>();
            expect(
              notified,
              isNotEmpty,
              reason: 'the flush must announce itself to the UI',
            );
            expect(
              notified.expand((ids) => ids),
              containsAll(<String>[agentId, taskId]),
              reason: 'the task page watches both ids',
            );
            // notifyUiOnly, not notify: `notify` also feeds
            // `localUpdateStream`, which drives wake orchestration and would
            // let a wake re-trigger itself.
            verifyNever(
              () => updateNotifications.notify(
                any(),
                fromSync: any(named: 'fromSync'),
              ),
            );
          },
        );

        test('deferred change set fires a task-suggestion notification when '
            'NotificationRepository is registered', () async {
          // End-to-end through the wake: ChangeSetBuilder.build runs
          // inside syncService.runInTransaction at step 10b and must fire
          // the inbox row for the accumulated pending item. The builder-
          // level path is covered in change_set_builder_test; this pins
          // the workflow-level integration.
          final notificationRepository = MockNotificationRepository();
          getIt.registerSingleton<NotificationRepository>(
            notificationRepository,
          );
          addTearDown(() => getIt.unregister<NotificationRepository>());
          when(
            () => notificationRepository.createTaskSuggestion(
              linkedTaskId: any(named: 'linkedTaskId'),
              suggestionCount: any(named: 'suggestionCount'),
              title: any(named: 'title'),
              body: any(named: 'body'),
              scheduledFor: any(named: 'scheduledFor'),
              category: any(named: 'category'),
              idSeed: any(named: 'idSeed'),
            ),
          ).thenAnswer((_) async => null);

          final result = await executeWithToolCallOnRealTask(
            'update_task_estimate',
            '{"minutes":60}',
            task: taskForUpdates,
          );

          expect(result.success, isTrue);
          verify(
            () => notificationRepository.createTaskSuggestion(
              linkedTaskId: taskId,
              suggestionCount: 1,
              title: any(named: 'title'),
              body: any(named: 'body'),
              category: any(named: 'category'),
              idSeed: any(named: 'idSeed'),
            ),
          ).called(1);
        });
      });

      group('deferred checklist handler paths', () {
        test(
          'add_multiple_checklist_items is deferred, not executed immediately',
          () async {
            final result = await executeWithToolCallOnRealTask(
              'add_multiple_checklist_items',
              '{"items":[{"title":"Buy milk"}]}',
            );

            expect(result.success, isTrue);
            // Checklist items are NOT created immediately — they are deferred.
            verifyNever(
              () => mockChecklistRepository.addItemToChecklist(
                checklistId: any(named: 'checklistId'),
                title: any(named: 'title'),
                isChecked: any(named: 'isChecked'),
                categoryId: any(named: 'categoryId'),
                checkedBy: any(named: 'checkedBy'),
              ),
            );
            verifyDeferredToolResponse(mockConversationManager);
          },
        );

        test('update_checklist_items is deferred', () async {
          final result = await executeWithToolCallOnRealTask(
            'update_checklist_items',
            '{"items":[{"id":"item-1","isChecked":true}]}',
          );

          expect(result.success, isTrue);
          verifyDeferredToolResponse(mockConversationManager);
        });

        test('add_multiple_checklist_items resolves existing titles and '
            'suppresses a duplicate against them', () async {
          // The workflow's existingChecklistTitlesResolver lower-cases and
          // trims each existing item title into a dedup set. Stub the task
          // to report one existing checklist item; the matching new
          // proposal must then be filtered out as redundant.
          final existingItem =
              JournalEntity.checklistItem(
                    meta: Metadata(
                      id: 'cl-existing',
                      createdAt: DateTime(2024, 3, 15),
                      dateFrom: DateTime(2024, 3, 15),
                      dateTo: DateTime(2024, 3, 15),
                      updatedAt: DateTime(2024, 3, 15),
                    ),
                    data: const ChecklistItemData(
                      title: '  Buy Milk  ',
                      isChecked: false,
                      linkedChecklists: [],
                    ),
                  )
                  as ChecklistItem;

          when(
            () => mockChecklistRepository.getChecklistItemsForTask(
              task: taskWithCategory,
            ),
          ).thenAnswer((_) async => [existingItem]);

          final result = await executeWithToolCallOnRealTask(
            'add_multiple_checklist_items',
            '{"items":[{"title":"buy milk"}]}',
          );

          expect(result.success, isTrue);
          // The resolver was consulted with the real task entity.
          verify(
            () => mockChecklistRepository.getChecklistItemsForTask(
              task: taskWithCategory,
            ),
          ).called(1);
          // Capture every tool response sent back to the LLM. The
          // case-insensitive dedup against the trimmed existing title must
          // have reported the proposal as redundant.
          final responses = verify(
            () => mockConversationManager.addToolResponse(
              toolCallId: any(named: 'toolCallId'),
              response: captureAny(named: 'response'),
            ),
          ).captured.cast<String>();
          expect(responses, contains(contains('already exists on the task')));
        });

        test(
          'update_checklist_items resolves title from DB for ID-only items',
          () async {
            // Stub journalEntityById to return a ChecklistItem for the
            // referenced item ID so the resolver closure is exercised.
            final checklistItem = JournalEntity.checklistItem(
              meta: Metadata(
                id: 'cl-item-1',
                createdAt: DateTime(2024, 3, 15),
                dateFrom: DateTime(2024, 3, 15),
                dateTo: DateTime(2024, 3, 15),
                updatedAt: DateTime(2024, 3, 15),
              ),
              data: const ChecklistItemData(
                title: 'Buy groceries',
                isChecked: false,
                linkedChecklists: [],
              ),
            );

            when(
              () => mockJournalDb.journalEntityById('cl-item-1'),
            ).thenAnswer((_) async => checklistItem);

            final result = await executeWithToolCallOnRealTask(
              'update_checklist_items',
              '{"items":[{"id":"cl-item-1","isChecked":true}]}',
            );

            expect(result.success, isTrue);

            // Verify the resolver looked up the checklist item.
            verify(
              () => mockJournalDb.journalEntityById('cl-item-1'),
            ).called(1);
          },
        );

        test('update_checklist_items duplicate visible proposal is filtered by '
            'the ledger at build time', () async {
          const summary = 'Check off: "Address CodeRabbit review comments"';
          const existingItem = ChangeItem(
            toolName: TaskAgentToolNames.updateChecklistItem,
            args: {'id': 'cl-existing', 'isChecked': true},
            humanSummary: summary,
          );
          final pendingSet = makeTestChangeSet(
            id: 'cs-existing-visible-duplicate',
            items: const [existingItem],
          );
          final newChecklistItem = JournalEntity.checklistItem(
            meta: Metadata(
              id: 'cl-new',
              createdAt: DateTime(2024, 3, 15),
              dateFrom: DateTime(2024, 3, 15),
              dateTo: DateTime(2024, 3, 15),
              updatedAt: DateTime(2024, 3, 15),
            ),
            data: const ChecklistItemData(
              title: 'Address CodeRabbit review comments',
              isChecked: false,
              linkedChecklists: [],
            ),
          );
          final upserts = <AgentDomainEntity>[];

          when(
            () => mockSyncService.repository,
          ).thenReturn(mockAgentRepository);
          when(
            () => mockAgentRepository.getEntity(pendingSet.id),
          ).thenAnswer((_) async => pendingSet);
          when(
            () => mockAgentRepository.getProposalLedger(
              agentId,
              taskId: any(named: 'taskId'),
              changeSetFetchLimit: any(named: 'changeSetFetchLimit'),
              resolvedLimit: any(named: 'resolvedLimit'),
            ),
          ).thenAnswer(
            (_) async => ProposalLedger(
              open: [
                LedgerEntry(
                  changeSetId: pendingSet.id,
                  itemIndex: 0,
                  toolName: existingItem.toolName,
                  args: existingItem.args,
                  humanSummary: existingItem.humanSummary,
                  fingerprint: ChangeItem.fingerprint(existingItem),
                  status: ChangeItemStatus.pending,
                  createdAt: pendingSet.createdAt,
                ),
              ],
              resolved: const [],
              pendingSets: [pendingSet],
            ),
          );
          when(
            () => mockJournalDb.journalEntityById('cl-new'),
          ).thenAnswer((_) async => newChecklistItem);
          when(() => mockSyncService.upsertEntity(any())).thenAnswer((
            invocation,
          ) async {
            upserts.add(
              invocation.positionalArguments.single as AgentDomainEntity,
            );
          });

          final result = await executeWithToolCallOnRealTask(
            TaskAgentToolNames.updateChecklistItems,
            '{"items":[{"id":"cl-new","isChecked":true}]}',
          );

          expect(result.success, isTrue);
          expect(
            upserts.whereType<ChangeSetEntity>(),
            isEmpty,
            reason:
                'the duplicate visible proposal must not create or merge a '
                'change set',
          );
          verify(() => mockJournalDb.journalEntityById('cl-new')).called(1);
        });
      });

      group('link_task through the workflow-wired resolvers', () {
        /// A live task on the other end of the proposed relationship.
        final linkTargetTask = Task(
          data: TaskData(
            status: TaskStatus.open(
              id: 'status_id',
              createdAt: DateTime(2024, 3, 15),
              utcOffset: 60,
            ),
            title: 'Ship the migration',
            statusHistory: [],
            dateTo: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
          ),
          meta: Metadata(
            id: 'link-target-1',
            createdAt: DateTime(2024, 3, 15),
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            categoryId: 'cat-001',
          ),
        );

        EntryLink storedLink({
          required String fromId,
          required String toId,
          EntryLinkType type = EntryLinkType.blocks,
          DateTime? deletedAt,
        }) => type.buildLink(
          id: 'link-$fromId-$toId-${type.name}',
          fromId: fromId,
          toId: toId,
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          vectorClock: null,
          deletedAt: deletedAt,
        );

        List<String> capturedToolResponses() => verify(
          () => mockConversationManager.addToolResponse(
            toolCallId: any(named: 'toolCallId'),
            response: captureAny(named: 'response'),
          ),
        ).captured.cast<String>();

        test(
          'queues a proposal with the title resolved from the journal',
          () async {
            when(
              () => mockJournalDb.journalEntityById('link-target-1'),
            ).thenAnswer((_) async => linkTargetTask);
            when(
              () => mockJournalDb.linksForEntryIdsBidirectional({taskId}),
            ).thenAnswer((_) async => []);

            final result = await executeWithToolCallOnRealTask(
              'link_task',
              '{"relation":"is_blocked_by","targetTaskId":"link-target-1"}',
            );

            expect(result.success, isTrue);
            // The workflow-wired resolver looked the target up in the DB and
            // fed its title into the queued proposal's response.
            verify(
              () => mockJournalDb.journalEntityById('link-target-1'),
            ).called(1);
            expect(
              capturedToolResponses(),
              contains(contains('link_task proposal recorded')),
            );
          },
        );

        test(
          'rejects a hallucinated target id via the journal lookup',
          () async {
            when(
              () => mockJournalDb.journalEntityById('ghost-task'),
            ).thenAnswer((_) async => null);

            final result = await executeWithToolCallOnRealTask(
              'link_task',
              '{"relation":"blocks","targetTaskId":"ghost-task"}',
            );

            // The wake itself succeeds; the proposal was rejected fail-closed
            // with model-facing feedback instead of being queued.
            expect(result.success, isTrue);
            expect(
              capturedToolResponses(),
              contains(contains('does not exist')),
            );
          },
        );

        test(
          'a tombstoned target task is rejected like a missing one',
          () async {
            final deletedTarget = linkTargetTask.copyWith(
              meta: linkTargetTask.meta.copyWith(
                deletedAt: DateTime(2024, 3, 16),
              ),
            );
            when(
              () => mockJournalDb.journalEntityById('link-target-1'),
            ).thenAnswer((_) async => deletedTarget);

            final result = await executeWithToolCallOnRealTask(
              'link_task',
              '{"relation":"blocks","targetTaskId":"link-target-1"}',
            );

            expect(result.success, isTrue);
            expect(
              capturedToolResponses(),
              contains(contains('does not exist')),
            );
          },
        );

        test(
          'suppresses an existing relationship read from the links table',
          () async {
            when(
              () => mockJournalDb.journalEntityById('link-target-1'),
            ).thenAnswer((_) async => linkTargetTask);
            when(
              () => mockJournalDb.linksForEntryIdsBidirectional({taskId}),
            ).thenAnswer(
              (_) async => [
                // The exact edge being proposed, already stored and live.
                storedLink(fromId: taskId, toId: 'link-target-1'),
                // A tombstoned edge that must be filtered out, not matched.
                storedLink(
                  fromId: 'link-target-1',
                  toId: taskId,
                  type: EntryLinkType.supersedes,
                  deletedAt: DateTime(2024, 3, 16),
                ),
              ],
            );

            final result = await executeWithToolCallOnRealTask(
              'link_task',
              '{"relation":"blocks","targetTaskId":"link-target-1"}',
            );

            expect(result.success, isTrue);
            expect(
              capturedToolResponses(),
              contains(contains('the relationship exists')),
            );
          },
        );
      });

      test(
        'task entity is not a Task type — set_task_title is still deferred',
        () async {
          stubFullExecutePathLocal();

          // Return a non-Task journal entity. The strategy defers the tool
          // call regardless — type validation happens at confirmation time.
          final nonTaskEntity = JournalEntry(
            meta: Metadata(
              id: taskId,
              createdAt: DateTime(2024, 3, 15),
              dateFrom: DateTime(2024, 3, 15),
              dateTo: DateTime(2024, 3, 15),
              updatedAt: DateTime(2024, 3, 15),
              categoryId: 'cat-001',
            ),
            entryText: const EntryText(plainText: 'Not a task'),
          );

          when(
            () => mockJournalDb.journalEntityById(taskId),
          ).thenAnswer((_) async => nonTaskEntity);
          when(
            () => mockConversationManager.addToolResponse(
              toolCallId: any(named: 'toolCallId'),
              response: any(named: 'response'),
            ),
          ).thenReturn(null);

          mockConversationRepository.sendMessageDelegate =
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
                if (strategy is TaskAgentStrategy) {
                  await strategy.processToolCalls(
                    toolCalls: [
                      const ChatCompletionMessageToolCall(
                        id: 'tc-2',
                        type: ChatCompletionMessageToolCallType.function,
                        function: ChatCompletionMessageFunctionCall(
                          name: 'set_task_title',
                          arguments: '{"title":"Test"}',
                        ),
                      ),
                    ],
                    manager: mockConversationManager,
                  );
                }
                return null;
              };

          final result = await workflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(result.success, isTrue);
          // Tool call is deferred — not validated against entity type.
          verifyDeferredToolResponse(
            mockConversationManager,
            toolCallId: 'tc-2',
          );
        },
      );
    });
  });
}
