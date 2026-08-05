import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/projection/content_digest.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/workflow/task_agent_report_editor.dart';
import 'package:lotti/features/agents/workflow/task_agent_strategy.dart';
import 'package:lotti/features/agents/workflow/task_agent_workflow.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai_consumption/service/ai_interaction_capture.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
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
  late MockCloudInferenceRepository mockCloudInferenceRepository;
  late MockConversationManager mockConversationManager;
  late MockJournalRepository mockJournalRepository;
  late MockChecklistRepository mockChecklistRepository;
  late MockLabelsRepository mockLabelsRepository;
  late MockAgentTemplateService mockTemplateService;
  late TaskAgentWorkflow workflow;

  const agentId = taskAgentTestAgentId;
  const taskId = taskAgentTestTaskId;
  const runKey = taskAgentTestRunKey;
  const threadId = taskAgentTestThreadId;
  final testDate = taskAgentTestDate;
  final testTemplate = taskAgentTestTemplate;
  final testTemplateVersion = taskAgentTestTemplateVersion;
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
    mockCloudInferenceRepository = bench.mockCloudInferenceRepository;
    mockConversationManager = bench.mockConversationManager;
    mockJournalRepository = bench.mockJournalRepository;
    mockChecklistRepository = bench.mockChecklistRepository;
    mockLabelsRepository = bench.mockLabelsRepository;
    mockTemplateService = bench.mockTemplateService;
    workflow = bench.workflow;
  });

  group('TaskAgentWorkflow', () {
    group('execute returns error', () {
      test('when no template assigned', () async {
        stubPreExecuteDefaults(
          mockAgentRepository: mockAgentRepository,
          mockAiInputRepository: mockAiInputRepository,
          testAgentState: testAgentState,
          agentId: agentId,
          taskId: taskId,
        );

        // Override default template stub to return null.
        when(
          () => mockTemplateService.getTemplateForAgent(agentId),
        ).thenAnswer((_) async => null);

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isFalse);
        expect(result.error, 'No template assigned to agent');
      });

      test('when no agent state found', () async {
        when(
          () => mockAgentRepository.getAgentState(agentId),
        ).thenAnswer((_) async => null);

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isFalse);
        expect(result.error, 'No agent state found');
      });

      test('propagates when state reconciliation itself throws', () async {
        // Unlike a null state (graceful WakeResult), a throwing
        // reconciledAgentState has no catch envelope at the call site —
        // the exception escapes execute() to the wake scheduler.
        when(
          () => mockSyncService.reconciledAgentState(agentId),
        ).thenThrow(StateError('reconcile boom'));

        await expectLater(
          workflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('when no active task ID', () async {
        final stateNoTask =
            AgentDomainEntity.agentState(
                  id: 'state-001',
                  agentId: agentId,
                  revision: 1,
                  slots: const AgentSlots(),
                  updatedAt: testDate,
                  vectorClock: null,
                )
                as AgentStateEntity;

        when(
          () => mockAgentRepository.getAgentState(agentId),
        ).thenAnswer((_) async => stateNoTask);

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isFalse);
        expect(result.error, 'No active task ID');
      });

      test('when task not found in journal', () async {
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
        // Template + provider resolution now precedes the task-details load
        // (the compaction summarizer needs the wake's model), so stub it to
        // succeed and let the flow reach the task-not-found branch.
        when(
          () => mockAiConfigRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => [geminiModel]);
        when(
          () => mockAiConfigRepository.getConfigById(
            geminiModel.inferenceProviderId,
          ),
        ).thenAnswer((_) async => geminiProvider);
        when(
          () => mockAiInputRepository.buildTaskDetailsJson(id: taskId),
        ).thenAnswer((_) async => null);
        when(
          () => mockAiInputRepository.buildLinkedTasksJson(taskId),
        ).thenAnswer((_) async => '{}');

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isFalse);
        expect(result.error, 'Task not found');
      });

      test('when no Gemini provider configured', () async {
        stubPreExecuteDefaults(
          mockAgentRepository: mockAgentRepository,
          mockAiInputRepository: mockAiInputRepository,
          testAgentState: testAgentState,
          agentId: agentId,
          taskId: taskId,
        );
        when(
          () => mockAiConfigRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => []);

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isFalse);
        expect(result.error, 'No inference provider configured');
      });

      test(
        'typed disabled setup does not fall back to template model',
        () async {
          stubPreExecuteDefaults(
            mockAgentRepository: mockAgentRepository,
            mockAiInputRepository: mockAiInputRepository,
            testAgentState: testAgentState,
            agentId: agentId,
            taskId: taskId,
          );

          final typedDisabledIdentity = testAgentIdentity.copyWith(
            config: const AgentConfig(
              inferenceSetup: AgentInferenceSetup(
                mode: AgentInferenceSetupMode.disabled,
                origin: AgentInferenceSetupOrigin.user,
              ),
            ),
          );

          final result = await workflow.execute(
            agentIdentity: typedDisabledIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(result.success, isFalse);
          expect(result.error, 'Inference setup is disabled');
        },
      );

      test('when template exists but no active version', () async {
        stubPreExecuteDefaults(
          mockAgentRepository: mockAgentRepository,
          mockAiInputRepository: mockAiInputRepository,
          testAgentState: testAgentState,
          agentId: agentId,
          taskId: taskId,
        );

        // Template exists but active version is null.
        when(
          () => mockTemplateService.getActiveVersion(testTemplate.id),
        ).thenAnswer((_) async => null);

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isFalse);
        expect(result.error, 'No template assigned to agent');
      });
    });

    group('successful execute', () {
      void stubMeliousTaskAgentModel({
        required String providerId,
        required String modelConfigId,
        required String modelName,
        required String providerModelId,
        AgentTemplateVersionEntity? templateVersion,
        InferenceProviderType providerType = InferenceProviderType.melious,
      }) {
        final provider =
            AiConfig.inferenceProvider(
                  id: providerId,
                  baseUrl: 'https://api.melious.ai/v1',
                  apiKey: 'test-key',
                  name: 'Melious',
                  createdAt: DateTime(2024),
                  inferenceProviderType: providerType,
                )
                as AiConfigInferenceProvider;
        final model =
            AiConfig.model(
                  id: modelConfigId,
                  name: modelName,
                  providerModelId: providerModelId,
                  inferenceProviderId: provider.id,
                  createdAt: DateTime(2024),
                  inputModalities: const [Modality.text],
                  outputModalities: const [Modality.text],
                  isReasoningModel: true,
                  supportsFunctionCalling: true,
                )
                as AiConfigModel;
        final template = makeTestTemplate(modelId: providerModelId);
        when(
          () => mockTemplateService.getTemplateForAgent(agentId),
        ).thenAnswer((_) async => template);
        when(
          () => mockTemplateService.getActiveVersion(template.id),
        ).thenAnswer((_) async => templateVersion ?? testTemplateVersion);
        when(
          () => mockAiConfigRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => [model]);
        when(
          () => mockAiConfigRepository.getConfigById(provider.id),
        ).thenAnswer((_) async => provider);
      }

      setUp(() {
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
      });

      test(
        'agent retraction is deferred and commits atomically at end-of-wake, '
        'never mid-conversation',
        () async {
          // An open proposal from a previous wake that the agent will retract
          // during this wake (e.g. after the user acted on a sibling item).
          const openItem = ChangeItem(
            toolName: 'add_checklist_item',
            args: {'title': 'Draft the spec'},
            humanSummary: 'Add: "Draft the spec"',
          );
          final pendingSet = makeTestChangeSet(
            id: 'cs-retract',
            items: const [openItem],
          );
          final fingerprint = ChangeItem.fingerprint(openItem);

          // The retraction service reads/writes through syncService.repository.
          when(
            () => mockSyncService.repository,
          ).thenReturn(mockAgentRepository);
          when(
            () => mockAgentRepository.getPendingChangeSets(
              agentId,
              taskId: any(named: 'taskId'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) async => [pendingSet]);
          when(
            () => mockAgentRepository.getEntity('cs-retract'),
          ).thenAnswer((_) async => pendingSet);

          // Capture every persisted entity, plus a snapshot taken the moment
          // the conversation hands back — before the end-of-wake transaction.
          final upserts = <AgentDomainEntity>[];
          var upsertsAtConversationEnd = <AgentDomainEntity>[];
          when(() => mockSyncService.upsertEntity(any())).thenAnswer((
            inv,
          ) async {
            upserts.add(inv.positionalArguments.single as AgentDomainEntity);
          });

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
                        id: 'retract-call',
                        type: ChatCompletionMessageToolCallType.function,
                        function: ChatCompletionMessageFunctionCall(
                          name: TaskAgentToolNames.retractSuggestions,
                          arguments: jsonEncode({
                            'proposals': [
                              {'fingerprint': fingerprint, 'reason': 'done'},
                            ],
                          }),
                        ),
                      ),
                      const ChatCompletionMessageToolCall(
                        id: 'report-call',
                        type: ChatCompletionMessageToolCallType.function,
                        function: ChatCompletionMessageFunctionCall(
                          name: 'update_report',
                          arguments:
                              '{"oneLiner":"o","tldr":"t","content":"c"}',
                        ),
                      ),
                    ],
                    manager: mockConversationManager,
                  );
                }
                // Snapshot what is persisted by the time the conversation
                // returns — the retraction must NOT be among these yet.
                upsertsAtConversationEnd = List.of(upserts);
                return null;
              };

          final result = await workflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(result.success, isTrue);

          bool isRetractionDecision(AgentDomainEntity e) =>
              e is ChangeDecisionEntity &&
              e.verdict == ChangeDecisionVerdict.retracted &&
              e.actor == DecisionActor.agent;

          // Mid-conversation the retraction is only validated + staged, never
          // persisted — otherwise the suggestion list flashes empty for the
          // seconds until the wake's end-of-wake writes land.
          expect(
            upsertsAtConversationEnd.any(isRetractionDecision),
            isFalse,
            reason: 'retraction must not persist during the conversation',
          );

          // End-of-wake the retraction decision and the flipped change set are
          // both persisted (in the same transaction as the build step).
          final decision = upserts
              .whereType<ChangeDecisionEntity>()
              .singleWhere(isRetractionDecision);
          expect(decision.changeSetId, 'cs-retract');
          expect(decision.retractionReason, 'done');

          final retractedSet = upserts
              .whereType<ChangeSetEntity>()
              .where((s) => s.id == 'cs-retract')
              .last;
          expect(retractedSet.items.single.status, ChangeItemStatus.retracted);
        },
      );

      test(
        'churn guard: retraction of an item the agent re-proposes this wake is '
        'suppressed, leaving the original untouched',
        () async {
          // An open proposal the agent will both re-propose AND retract in the
          // same wake (the weaker-model churn pattern from the field logs).
          const openItem = ChangeItem(
            toolName: 'add_checklist_item',
            args: {'title': 'Draft the spec'},
            humanSummary: 'Add: "Draft the spec"',
          );
          final pendingSet = makeTestChangeSet(
            id: 'cs-churn',
            items: const [openItem],
          );
          final fingerprint = ChangeItem.fingerprint(openItem);

          when(
            () => mockSyncService.repository,
          ).thenReturn(mockAgentRepository);
          when(
            () => mockAgentRepository.getPendingChangeSets(
              agentId,
              taskId: any(named: 'taskId'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) async => [pendingSet]);
          when(
            () => mockAgentRepository.getEntity('cs-churn'),
          ).thenAnswer((_) async => pendingSet);
          // The build step consolidates against the still-open original.
          when(
            () => mockAgentRepository.getProposalLedger(
              agentId,
              taskId: any(named: 'taskId'),
              changeSetFetchLimit: any(named: 'changeSetFetchLimit'),
              resolvedLimit: any(named: 'resolvedLimit'),
            ),
          ).thenAnswer(
            (_) async => ProposalLedger(
              open: const [],
              resolved: const [],
              pendingSets: [pendingSet],
            ),
          );
          // No real checklist titles on the task → the re-proposal is queued in
          // the builder (so its fingerprint lands in proposedFingerprints).
          when(
            () => mockJournalDb.journalEntityById(any()),
          ).thenAnswer((_) async => null);

          final upserts = <AgentDomainEntity>[];
          when(() => mockSyncService.upsertEntity(any())).thenAnswer((
            inv,
          ) async {
            upserts.add(inv.positionalArguments.single as AgentDomainEntity);
          });

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
                        id: 'repropose-call',
                        type: ChatCompletionMessageToolCallType.function,
                        function: ChatCompletionMessageFunctionCall(
                          name: TaskAgentToolNames.addMultipleChecklistItems,
                          arguments: jsonEncode({
                            'items': [
                              {'title': 'Draft the spec'},
                            ],
                          }),
                        ),
                      ),
                      ChatCompletionMessageToolCall(
                        id: 'retract-call',
                        type: ChatCompletionMessageToolCallType.function,
                        function: ChatCompletionMessageFunctionCall(
                          name: TaskAgentToolNames.retractSuggestions,
                          arguments: jsonEncode({
                            'proposals': [
                              {'fingerprint': fingerprint, 'reason': 'dup'},
                            ],
                          }),
                        ),
                      ),
                      const ChatCompletionMessageToolCall(
                        id: 'report-call',
                        type: ChatCompletionMessageToolCallType.function,
                        function: ChatCompletionMessageFunctionCall(
                          name: 'update_report',
                          arguments:
                              '{"oneLiner":"o","tldr":"t","content":"c"}',
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

          // The retraction targeted an item being re-proposed this wake, so it
          // must be suppressed — no agent retraction is persisted, and the
          // original proposal is never flipped to retracted.
          final retractions = upserts.whereType<ChangeDecisionEntity>().where(
            (d) =>
                d.verdict == ChangeDecisionVerdict.retracted &&
                d.actor == DecisionActor.agent,
          );
          expect(retractions, isEmpty);
          final retractedSets = upserts.whereType<ChangeSetEntity>().where(
            (s) => s.items.any((i) => i.status == ChangeItemStatus.retracted),
          );
          expect(retractedSets, isEmpty);
        },
      );

      test('creates conversation, sends message, and persists state', () async {
        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isTrue);

        // System prompt (payload + message) + user message (payload +
        // message) + state update = 5 upsert calls.
        verify(() => mockSyncService.upsertEntity(any())).called(5);

        // A completed wake event-sources lastWakeAt (PR 4, B2).
        expect(capturedMilestones(mockSyncService), [
          AgentMilestone.wakeCompleted,
        ]);

        // Verify conversation was cleaned up in finally.
        expect(
          mockConversationRepository.deletedConversationIds,
          contains('test-conv-id'),
        );

        // No AiInteractionCapture is registered in this suite's default
        // setup, so the consumption gate stays closed: no owner ids are
        // forwarded to sendMessage.
        expect(mockConversationRepository.lastConsumptionAgentId, isNull);
        expect(mockConversationRepository.lastConsumptionTaskId, isNull);
        expect(mockConversationRepository.lastConsumptionCategoryId, isNull);
        expect(mockConversationRepository.lastConsumptionWakeRunKey, isNull);
        expect(mockConversationRepository.lastConsumptionThreadId, isNull);
      });

      test('passes consumption owner ids to sendMessage when an '
          'AiInteractionCapture is registered', () async {
        getIt.registerSingleton<AiInteractionCapture>(
          MockAiInteractionCapture(),
        );
        addTearDown(() {
          if (getIt.isRegistered<AiInteractionCapture>()) {
            getIt.unregister<AiInteractionCapture>();
          }
        });

        // With the gate open the workflow resolves the task's category via
        // journalDb, so the entity lookup must yield a categorised task.
        when(() => mockJournalDb.journalEntityById(taskId)).thenAnswer(
          (_) async => Task(
            data: TaskData(
              status: TaskStatus.open(
                id: 'status_id',
                createdAt: DateTime(2024, 3, 15),
                utcOffset: 60,
              ),
              title: 'Consumption task',
              statusHistory: const [],
              dateTo: DateTime(2024, 3, 15),
              dateFrom: DateTime(2024, 3, 15),
            ),
            meta: Metadata(
              id: taskId,
              createdAt: DateTime(2024, 3, 15),
              dateFrom: DateTime(2024, 3, 15),
              dateTo: DateTime(2024, 3, 15),
              updatedAt: DateTime(2024, 3, 15),
              categoryId: 'cat-consumption-001',
            ),
          ),
        );

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isTrue);
        expect(mockConversationRepository.lastConsumptionAgentId, agentId);
        expect(mockConversationRepository.lastConsumptionTaskId, taskId);
        expect(
          mockConversationRepository.lastConsumptionCategoryId,
          'cat-consumption-001',
        );
        expect(mockConversationRepository.lastConsumptionWakeRunKey, runKey);
        expect(mockConversationRepository.lastConsumptionThreadId, threadId);
      });

      test('persists the system prompt content-addressed and references it '
          'from a system message', () async {
        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {},
          threadId: threadId,
        );
        expect(result.success, isTrue);

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;

        // The payload is content-addressed: its id IS the digest of its
        // content, so re-running with the same template never re-stores it.
        final promptPayload = capturedPayloadEntities(
          captured,
        ).singleWhere((p) => p.content['role'] == 'system');
        expect(promptPayload.id, ContentDigest.of(promptPayload.content));
        expect(promptPayload.content['text'], contains('You are a Task Agent'));

        // The wake references it via a system message so the conversation
        // view can expand and inspect the exact prompt this wake ran with.
        final promptMessage = captured
            .whereType<AgentMessageEntity>()
            .singleWhere(
              (m) =>
                  m.kind == AgentMessageKind.system && m.contentEntryId != null,
            );
        expect(promptMessage.contentEntryId, promptPayload.id);
        expect(promptMessage.threadId, threadId);
      });

      test(
        'does not re-store an already-known system prompt payload',
        () async {
          // The digest already exists (same template ran before, on any agent):
          // only the per-wake reference message is written, not the payload.
          when(
            () => mockAgentRepository.getEntity(
              any(that: startsWith('sha256-v1:')),
            ),
          ).thenAnswer(
            (_) async => AgentDomainEntity.agentMessagePayload(
              id: 'sha256-v1:existing',
              agentId: 'shared-input-content',
              createdAt: DateTime(2024),
              vectorClock: null,
              content: const {'role': 'system', 'text': 'cached'},
            ),
          );

          final result = await workflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {},
            threadId: threadId,
          );
          expect(result.success, isTrue);

          final captured = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;
          expect(
            capturedPayloadEntities(
              captured,
            ).where((p) => p.content['role'] == 'system'),
            isEmpty,
          );
          expect(
            captured.whereType<AgentMessageEntity>().where(
              (m) =>
                  m.kind == AgentMessageKind.system && m.contentEntryId != null,
            ),
            hasLength(1),
          );
        },
      );

      test(
        'propagates the resolved model geminiThinkingMode to the wrapper',
        () async {
          Object? capturedInferenceRepo;
          String? capturedModel;
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
                capturedModel = model;
                capturedInferenceRepo = inferenceRepo;
                return null;
              };

          final result = await workflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(result.success, isTrue);
          expect(capturedModel, 'models/gemini-3-flash-preview');
          expect(capturedInferenceRepo, isA<CloudInferenceWrapper>());

          final wrapper = capturedInferenceRepo! as CloudInferenceWrapper;
          // geminiModel fixture relies on AiConfigModel.geminiThinkingMode's
          // default value (low), which the workflow forwards to the wrapper.
          expect(wrapper.geminiThinkingMode, GeminiThinkingMode.low);
        },
      );

      test(
        'evidence synthesis keeps default temperature for unevaluated models',
        () async {
          String? systemMessage;
          double? capturedTemperature;
          List<ChatCompletionTool>? capturedTools;
          final capturingRepo =
              MockConversationRepository(
                  mockConversationManager,
                  onSystemMessage: (message) => systemMessage = message,
                )
                ..sendMessageDelegate =
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
                      capturedTemperature = temperature;
                      capturedTools = tools;
                      if (strategy is TaskAgentStrategy) {
                        await strategy.processToolCalls(
                          toolCalls: const [
                            ChatCompletionMessageToolCall(
                              id: 'report-call',
                              type: ChatCompletionMessageToolCallType.function,
                              function: ChatCompletionMessageFunctionCall(
                                name: TaskAgentToolNames.updateReport,
                                arguments:
                                    '{"oneLiner":"Next action","tldr":"Critical path","content":"Current state"}',
                              ),
                            ),
                          ],
                          manager: mockConversationManager,
                        );
                      }
                      return null;
                    };
          final optimizedWorkflow = createTestWorkflow(
            agentRepository: mockAgentRepository,
            conversationRepository: capturingRepo,
            aiInputRepository: mockAiInputRepository,
            aiConfigRepository: mockAiConfigRepository,
            journalDb: mockJournalDb,
            cloudInferenceRepository: mockCloudInferenceRepository,
            journalRepository: mockJournalRepository,
            checklistRepository: mockChecklistRepository,
            labelsRepository: mockLabelsRepository,
            syncService: mockSyncService,
            templateService: mockTemplateService,
          );

          final result = await optimizedWorkflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          final reportTool = capturedTools!.singleWhere(
            (tool) => tool.function.name == TaskAgentToolNames.updateReport,
          );
          final properties =
              reportTool.function.parameters!['properties']!
                  as Map<String, dynamic>;
          expect(result.success, isTrue);
          expect(capturedTemperature, 0.3);
          expect(
            systemMessage,
            contains('## Evidence-First Synthesis Protocol'),
          );
          expect(
            reportTool.function.description,
            contains('stale report claims'),
          );
          expect(
            (properties['tldr']! as Map)['description'],
            contains('checked item means only user-marked complete'),
          );
          expect(
            (properties['tldr']! as Map)['description'],
            isNot(contains('include 1-2 relevant emojis')),
          );
        },
      );

      test('Qwen evidence mode uses its tuned direct-executor path without an '
          'editor pass', () async {
        stubMeliousTaskAgentModel(
          providerId: 'melious-provider-qwen',
          modelConfigId: 'qwen-model-config',
          modelName: 'Qwen3.5 122B A10B',
          providerModelId: meliousQwen35122BA10BModelId,
        );

        String? systemMessage;
        double? capturedTemperature;
        final models = <String>[];
        final capturingRepo =
            MockConversationRepository(
                mockConversationManager,
                onSystemMessage: (message) => systemMessage = message,
              )
              ..maxDelegateCalls = 1
              ..sendMessageDelegate =
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
                    models.add(model);
                    capturedTemperature = temperature;
                    await strategy!.processToolCalls(
                      toolCalls: const [
                        ChatCompletionMessageToolCall(
                          id: 'qwen-report-call',
                          type: ChatCompletionMessageToolCallType.function,
                          function: ChatCompletionMessageFunctionCall(
                            name: TaskAgentToolNames.updateReport,
                            arguments:
                                '{"oneLiner":"Review the active risk","tldr":"Approval remains pending.","content":"Marta must approve deployment."}',
                          ),
                        ),
                      ],
                      manager: mockConversationManager,
                    );
                    return const InferenceUsage(
                      inputTokens: 90,
                      outputTokens: 15,
                    );
                  };
        final qwenWorkflow = createTestWorkflow(
          agentRepository: mockAgentRepository,
          conversationRepository: capturingRepo,
          aiInputRepository: mockAiInputRepository,
          aiConfigRepository: mockAiConfigRepository,
          journalDb: mockJournalDb,
          cloudInferenceRepository: mockCloudInferenceRepository,
          journalRepository: mockJournalRepository,
          checklistRepository: mockChecklistRepository,
          labelsRepository: mockLabelsRepository,
          syncService: mockSyncService,
          templateService: mockTemplateService,
        );

        final result = await qwenWorkflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isTrue);
        expect(models, [meliousQwen35122BA10BModelId]);
        expect(capturedTemperature, 0);
        expect(systemMessage, contains('## Scope Erasure'));
        expect(systemMessage, contains('Write free-form Markdown'));
        expect(systemMessage, isNot(contains('Examples of the boundary:')));
        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        final editorAudit = capturedEntitiesOfType<AgentMessageEntity>(captured)
            .singleWhere(
              (message) =>
                  message.metadata.toolName ==
                  '${TaskAgentReportEditor.auditToolPrefix}_direct_qwen',
            );
        expect(editorAudit.metadata.errorMessage, isNull);
      });

      for (final testCase in const [
        (
          modelName: 'Mistral Small 4 119B',
          modelId: meliousMistralSmall4119BInstructModelId,
        ),
        (modelName: 'Qwen3.5 122B A10B', modelId: meliousQwen35122BA10BModelId),
      ]) {
        test('${testCase.modelName} evidence mode records the resolved route '
            'when its provider is not eligible for Qwen editing', () async {
          stubMeliousTaskAgentModel(
            providerId: 'compatible-provider-${testCase.modelId}',
            modelConfigId: 'compatible-model-${testCase.modelId}',
            modelName: testCase.modelName,
            providerModelId: testCase.modelId,
            providerType: InferenceProviderType.openAi,
          );
          final models = <String>[];
          final capturingRepo =
              MockConversationRepository(mockConversationManager)
                ..maxDelegateCalls = 1
                ..sendMessageDelegate =
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
                      models.add(model);
                      await strategy!.processToolCalls(
                        toolCalls: const [
                          ChatCompletionMessageToolCall(
                            id: 'executor-report-call',
                            type: ChatCompletionMessageToolCallType.function,
                            function: ChatCompletionMessageFunctionCall(
                              name: TaskAgentToolNames.updateReport,
                              arguments:
                                  '{"oneLiner":"Review next","tldr":"Review the current task.","content":"Review the current task."}',
                            ),
                          ),
                        ],
                        manager: mockConversationManager,
                      );
                      return const InferenceUsage(
                        inputTokens: 20,
                        outputTokens: 5,
                      );
                    };
          final workflow = createTestWorkflow(
            agentRepository: mockAgentRepository,
            conversationRepository: capturingRepo,
            aiInputRepository: mockAiInputRepository,
            aiConfigRepository: mockAiConfigRepository,
            journalDb: mockJournalDb,
            cloudInferenceRepository: mockCloudInferenceRepository,
            journalRepository: mockJournalRepository,
            checklistRepository: mockChecklistRepository,
            labelsRepository: mockLabelsRepository,
            syncService: mockSyncService,
            templateService: mockTemplateService,
          );

          final result = await workflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(result.success, isTrue);
          expect(models, [testCase.modelId]);
          final captured = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;
          expect(
            capturedEntitiesOfType<AgentMessageEntity>(captured).where(
              (message) =>
                  message.metadata.toolName?.startsWith(
                    TaskAgentReportEditor.auditToolPrefix,
                  ) ??
                  false,
            ),
            isEmpty,
          );
        });
      }

      test('Qwen evidence mode repairs a known direct-report regression and '
          'logs its issue code', () async {
        stubMeliousTaskAgentModel(
          providerId: 'melious-provider-qwen-repair',
          modelConfigId: 'qwen-model-repair',
          modelName: 'Qwen3.5 122B A10B',
          providerModelId: meliousQwen35122BA10BModelId,
        );

        final models = <String>[];
        final messages = <String>[];
        final domainLogger = MockDomainLogger();
        when(
          () => domainLogger.log(
            any(),
            any(),
            subDomain: any(named: 'subDomain'),
          ),
        ).thenReturn(null);
        final capturingRepo =
            MockConversationRepository(mockConversationManager)
              ..maxDelegateCalls = 2
              ..sendMessageDelegate =
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
                    models.add(model);
                    messages.add(message);
                    if (strategy is TaskAgentStrategy) {
                      await strategy.processToolCalls(
                        toolCalls: [
                          const ChatCompletionMessageToolCall(
                            id: 'qwen-action-call',
                            type: ChatCompletionMessageToolCallType.function,
                            function: ChatCompletionMessageFunctionCall(
                              name:
                                  TaskAgentToolNames.addMultipleChecklistItems,
                              arguments:
                                  '{"items":[{"title":"Fix profile seeding"}]}',
                            ),
                          ),
                          ChatCompletionMessageToolCall(
                            id: 'qwen-draft-report-call',
                            type: ChatCompletionMessageToolCallType.function,
                            function: ChatCompletionMessageFunctionCall(
                              name: TaskAgentToolNames.updateReport,
                              arguments: jsonEncode({
                                'oneLiner': 'Fix profile seeding',
                                'tldr':
                                    'Task is ready to begin. No estimate or '
                                    'due date is set.',
                                'content':
                                    'One workflow item was identified: fix '
                                    'profile seeding.',
                              }),
                            ),
                          ),
                        ],
                        manager: mockConversationManager,
                      );
                      return const InferenceUsage(
                        inputTokens: 100,
                        outputTokens: 20,
                      );
                    }
                    await strategy!.processToolCalls(
                      toolCalls: [
                        ChatCompletionMessageToolCall(
                          id: 'qwen-repaired-report-call',
                          type: ChatCompletionMessageToolCallType.function,
                          function: ChatCompletionMessageFunctionCall(
                            name: TaskAgentToolNames.updateReport,
                            arguments: jsonEncode({
                              'oneLiner': 'Fix profile seeding',
                              'tldr': 'Fix profile seeding next.',
                              'content': 'Fix profile seeding.',
                            }),
                          ),
                        ),
                      ],
                      manager: mockConversationManager,
                    );
                    return const InferenceUsage(
                      inputTokens: 30,
                      outputTokens: 8,
                    );
                  };
        final qwenWorkflow = createTestWorkflow(
          agentRepository: mockAgentRepository,
          conversationRepository: capturingRepo,
          aiInputRepository: mockAiInputRepository,
          aiConfigRepository: mockAiConfigRepository,
          journalDb: mockJournalDb,
          cloudInferenceRepository: mockCloudInferenceRepository,
          journalRepository: mockJournalRepository,
          checklistRepository: mockChecklistRepository,
          labelsRepository: mockLabelsRepository,
          syncService: mockSyncService,
          templateService: mockTemplateService,
          domainLogger: domainLogger,
        );

        final result = await qwenWorkflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isTrue);
        expect(models, [
          meliousQwen35122BA10BModelId,
          meliousQwen35122BA10BModelId,
        ]);
        expect(messages.last, contains('requiredCorrections'));
        expect(messages.last, contains('processNarration'));
        verify(
          () => domainLogger.log(
            LogDomain.agentWorkflow,
            'direct Qwen regression detector matched: processNarration',
            subDomain: 'reportEditor',
          ),
        ).called(1);
        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        expect(
          capturedEntitiesOfType<AgentReportEntity>(captured).single.content,
          'Fix profile seeding.',
        );
        final editorAudit = capturedEntitiesOfType<AgentMessageEntity>(captured)
            .singleWhere(
              (message) =>
                  message.metadata.toolName ==
                  '${TaskAgentReportEditor.auditToolPrefix}_direct_qwen_repaired',
            );
        expect(editorAudit.metadata.errorMessage, isNull);
        final usage = capturedTokenUsageEntities(captured);
        expect(usage, hasLength(2));
        expect(
          usage.map((entry) => entry.modelId),
          everyElement(meliousQwen35122BA10BModelId),
        );
      });

      test('Mistral evidence mode accepts a grounded Qwen report revision and '
          'attributes usage to both models', () async {
        stubMeliousTaskAgentModel(
          providerId: 'melious-provider-001',
          modelConfigId: 'mistral-model-config',
          modelName: 'Mistral Small 4 119B',
          providerModelId: meliousMistralSmall4119BInstructModelId,
        );

        final models = <String>[];
        final messages = <String>[];
        final toolNames = <List<String>>[];
        final toolChoices = <ChatCompletionToolChoiceOption?>[];
        final capturingRepo =
            MockConversationRepository(mockConversationManager)
              ..maxDelegateCalls = 2
              ..sendMessageDelegate =
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
                    models.add(model);
                    messages.add(message);
                    toolNames.add(
                      tools?.map((tool) => tool.function.name).toList() ?? [],
                    );
                    toolChoices.add(toolChoice);
                    if (strategy is TaskAgentStrategy) {
                      await strategy.processToolCalls(
                        toolCalls: [
                          const ChatCompletionMessageToolCall(
                            id: 'priority-call',
                            type: ChatCompletionMessageToolCallType.function,
                            function: ChatCompletionMessageFunctionCall(
                              name: TaskAgentToolNames.updateTaskPriority,
                              arguments: '{"priority":"P1"}',
                            ),
                          ),
                          ChatCompletionMessageToolCall(
                            id: 'draft-report-call',
                            type: ChatCompletionMessageToolCallType.function,
                            function: ChatCompletionMessageFunctionCall(
                              name: TaskAgentToolNames.updateReport,
                              arguments: jsonEncode({
                                'oneLiner': 'Task configured',
                                'tldr': 'Priority updated. Ready to begin.',
                                'content': '## Progress\nTask configured.',
                              }),
                            ),
                          ),
                        ],
                        manager: mockConversationManager,
                      );
                      return const InferenceUsage(
                        inputTokens: 100,
                        outputTokens: 20,
                      );
                    }
                    await strategy!.processToolCalls(
                      toolCalls: [
                        ChatCompletionMessageToolCall(
                          id: 'edited-report-call',
                          type: ChatCompletionMessageToolCallType.function,
                          function: ChatCompletionMessageFunctionCall(
                            name: TaskAgentToolNames.updateReport,
                            arguments: jsonEncode({
                              'oneLiner': 'Validate the P1 model candidate',
                              'tldr':
                                  'The P1 validation is ready for its two '
                                  'remaining actions.',
                              'content':
                                  'Run the local evaluation, then compare the '
                                  'candidate with the reference.',
                            }),
                          ),
                        ),
                      ],
                      manager: mockConversationManager,
                    );
                    return const InferenceUsage(
                      inputTokens: 50,
                      outputTokens: 10,
                    );
                  };
        final optimizedWorkflow = createTestWorkflow(
          agentRepository: mockAgentRepository,
          conversationRepository: capturingRepo,
          aiInputRepository: mockAiInputRepository,
          aiConfigRepository: mockAiConfigRepository,
          journalDb: mockJournalDb,
          cloudInferenceRepository: mockCloudInferenceRepository,
          journalRepository: mockJournalRepository,
          checklistRepository: mockChecklistRepository,
          labelsRepository: mockLabelsRepository,
          syncService: mockSyncService,
          templateService: mockTemplateService,
        );

        final result = await optimizedWorkflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isTrue);
        expect(models, [
          meliousMistralSmall4119BInstructModelId,
          meliousQwen35122BA10BModelId,
        ]);
        expect(toolNames.first, contains(TaskAgentToolNames.updateReport));
        expect(toolNames.last, [TaskAgentToolNames.updateReport]);
        expect(toolChoices.first, isNull);
        expect(toolChoices.last, isNotNull);
        expect(messages.last, contains('materialTaskState'));
        expect(messages.last, contains('"priority":"P1"'));
        expect(messages.last, isNot(contains('## Current Task Context')));

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        final editorAudit = capturedEntitiesOfType<AgentMessageEntity>(captured)
            .singleWhere(
              (message) =>
                  message.metadata.toolName ==
                  '${TaskAgentReportEditor.auditToolPrefix}_accepted',
            );
        expect(editorAudit.kind, AgentMessageKind.toolResult);
        expect(editorAudit.metadata.errorMessage, isNull);
        final reports = capturedEntitiesOfType<AgentReportEntity>(captured);
        expect(reports, hasLength(1));
        expect(
          reports.single.content,
          contains('compare the candidate with the reference'),
        );
        final usage = capturedTokenUsageEntities(captured);
        expect(usage, hasLength(2));
        expect(
          usage.map((entry) => entry.modelId),
          containsAll([
            meliousMistralSmall4119BInstructModelId,
            meliousQwen35122BA10BModelId,
          ]),
        );
        expect(
          usage
              .singleWhere(
                (entry) =>
                    entry.modelId == meliousMistralSmall4119BInstructModelId,
              )
              .inputTokens,
          100,
        );
        expect(
          usage
              .singleWhere(
                (entry) => entry.modelId == meliousQwen35122BA10BModelId,
              )
              .inputTokens,
          50,
        );
      });
    });
    group('failed execute', () {
      test('increments consecutiveFailureCount on exception', () async {
        stubPreExecuteDefaults(
          mockAgentRepository: mockAgentRepository,
          mockAiInputRepository: mockAiInputRepository,
          testAgentState: testAgentState,
          agentId: agentId,
          taskId: taskId,
        );
        when(
          () => mockAiConfigRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => [geminiModel]);
        when(
          () => mockAiConfigRepository.getConfigById('gemini-provider-001'),
        ).thenAnswer((_) async => geminiProvider);
        // Make sendMessage throw to trigger the catch branch.
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
              throw Exception('Network error');
            };

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isFalse);
        expect(result.error, contains('Network error'));

        // Verify state was updated with incremented failure count.
        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;

        // Find the state entity that was persisted.
        final stateUpdates = capturedStateEntities(captured);

        expect(stateUpdates, isNotEmpty);
        final updatedState = stateUpdates.last;
        expect(
          updatedState.consecutiveFailureCount,
          testAgentState.consecutiveFailureCount + 1,
        );

        // Conversation should still be cleaned up.
        expect(
          mockConversationRepository.deletedConversationIds,
          contains('test-conv-id'),
        );
      });
    });

    group('_resolveGeminiProvider edge cases', () {
      /// Stubs common to all provider-resolution tests.
      void stubContextToProviderStep() {
        stubPreExecuteDefaults(
          mockAgentRepository: mockAgentRepository,
          mockAiInputRepository: mockAiInputRepository,
          testAgentState: testAgentState,
          agentId: agentId,
          taskId: taskId,
        );
      }

      test('returns error when provider is not an InferenceProvider', () async {
        stubContextToProviderStep();

        when(
          () => mockAiConfigRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => [geminiModel]);
        // Return a model config instead of a provider config.
        when(
          () => mockAiConfigRepository.getConfigById('gemini-provider-001'),
        ).thenAnswer((_) async => geminiModel);

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isFalse);
        expect(result.error, 'No inference provider configured');
      });

      test('returns error when provider has empty API key', () async {
        stubContextToProviderStep();

        final providerNoKey =
            AiConfig.inferenceProvider(
                  id: 'gemini-provider-001',
                  baseUrl: 'https://generativelanguage.googleapis.com',
                  apiKey: '',
                  name: 'Gemini',
                  createdAt: DateTime(2024),
                  inferenceProviderType: InferenceProviderType.gemini,
                )
                as AiConfigInferenceProvider;

        when(
          () => mockAiConfigRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => [geminiModel]);
        when(
          () => mockAiConfigRepository.getConfigById('gemini-provider-001'),
        ).thenAnswer((_) async => providerNoKey);

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isFalse);
        expect(result.error, 'No inference provider configured');
      });
    });

    group('_extractFinalAssistantContent', () {
      setUp(() {
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
      });

      test('picks last assistant message with content', () async {
        when(() => mockConversationManager.messages).thenReturn([
          const ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('hello'),
          ),
          const ChatCompletionMessage.assistant(content: 'First response'),
          const ChatCompletionMessage.assistant(
            content: 'Final analysis complete.',
          ),
        ]);

        await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {},
          threadId: threadId,
        );

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;

        final payloads = capturedPayloadEntities(captured);
        // User message payload + thought payload.
        expect(payloads.length, greaterThanOrEqualTo(2));
        final thoughtPayload = payloads.firstWhere(
          (p) => p.content['text'] == 'Final analysis complete.',
        );
        expect(thoughtPayload.content['text'], 'Final analysis complete.');
      });

      test('no thought persisted when getConversation returns null', () async {
        // Use a new repository mock that returns null for getConversation.
        final nullManagerRepo = NullManagerConversationRepository(
          mockConversationManager,
        );
        final nullWorkflow = createTestWorkflow(
          agentRepository: mockAgentRepository,
          conversationRepository: nullManagerRepo,
          aiInputRepository: mockAiInputRepository,
          aiConfigRepository: mockAiConfigRepository,
          journalDb: mockJournalDb,
          cloudInferenceRepository: mockCloudInferenceRepository,
          journalRepository: mockJournalRepository,
          checklistRepository: mockChecklistRepository,
          labelsRepository: mockLabelsRepository,
          syncService: mockSyncService,
          templateService: mockTemplateService,
        );

        final result = await nullWorkflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {},
          threadId: threadId,
        );

        expect(result.success, isTrue);

        // Only the prompt payloads (system + user) persist — no thought
        // payload since the manager is null.
        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        final payloads = capturedPayloadEntities(captured);
        expect(payloads, hasLength(2));
        // Verify the non-system one is the user message, not a thought.
        final userPayload = payloads.singleWhere(
          (p) => p.content['role'] != 'system',
        );
        final text = userPayload.content['text'] as String?;
        expect(text, contains('Current Task Context'));
      });

      test('no thought persisted when no assistant content', () async {
        when(() => mockConversationManager.messages).thenReturn([
          const ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('hello'),
          ),
        ]);

        await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {},
          threadId: threadId,
        );

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;

        final payloads = capturedPayloadEntities(captured);
        // Only the prompt payloads (system + user), no thought payload.
        expect(payloads, hasLength(2));
        final userPayload = payloads.singleWhere(
          (p) => p.content['role'] != 'system',
        );
        final text = userPayload.content['text'] as String?;
        expect(text, contains('Current Task Context'));
      });

      test('skips assistant messages with empty content', () async {
        when(() => mockConversationManager.messages).thenReturn([
          const ChatCompletionMessage.assistant(content: ''),
          const ChatCompletionMessage.assistant(content: 'Non-empty response'),
        ]);

        await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {},
          threadId: threadId,
        );

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;

        final payloads = capturedPayloadEntities(captured);
        // User message payload + thought payload.
        expect(payloads.length, greaterThanOrEqualTo(2));
        final thoughtPayload = payloads.firstWhere(
          (p) => p.content['text'] == 'Non-empty response',
        );
        expect(thoughtPayload.content['text'], 'Non-empty response');
      });
    });

    group('failure state update error handling', () {
      test('swallows error when updating failure count fails', () async {
        stubPreExecuteDefaults(
          mockAgentRepository: mockAgentRepository,
          mockAiInputRepository: mockAiInputRepository,
          testAgentState: testAgentState,
          agentId: agentId,
          taskId: taskId,
        );
        when(
          () => mockAiConfigRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => [geminiModel]);
        when(
          () => mockAiConfigRepository.getConfigById('gemini-provider-001'),
        ).thenAnswer((_) async => geminiProvider);

        // Make sendMessage throw.
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
              throw Exception('Network failure');
            };

        // Make the state update also throw (the nested try/catch).
        when(
          () => mockSyncService.upsertEntity(any()),
        ).thenThrow(Exception('DB write failed'));

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        // Should still return a failure result, not rethrow.
        expect(result.success, isFalse);
        expect(result.error, contains('Network failure'));
      });
    });

    group('syncService pass-through', () {
      test('routes writes through syncService', () async {
        // Set up stubs for a successful execute path.
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

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isTrue);

        // Writes go through syncService, not the repository directly.
        verify(
          () => mockSyncService.upsertEntity(any()),
        ).called(greaterThanOrEqualTo(1));
      });
    });

    group('null domainLogger fallback', () {
      test(
        '_logError falls back to developer.log when domainLogger is null',
        () async {
          // Create a workflow without domainLogger.
          final nullLoggerWorkflow = createTestWorkflow(
            agentRepository: mockAgentRepository,
            conversationRepository: mockConversationRepository,
            aiInputRepository: mockAiInputRepository,
            aiConfigRepository: mockAiConfigRepository,
            journalDb: mockJournalDb,
            cloudInferenceRepository: mockCloudInferenceRepository,
            journalRepository: mockJournalRepository,
            checklistRepository: mockChecklistRepository,
            labelsRepository: mockLabelsRepository,
            syncService: mockSyncService,
            templateService: mockTemplateService,
          );

          // Set up enough stubs to get into the main try block, then make
          // sendMessage throw to trigger _logError via the outer catch.
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

          // Make sendMessage throw to trigger the outer catch → _logError.
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
                throw Exception('LLM unavailable');
              };

          final result = await nullLoggerWorkflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: 'run-key-1',
            triggerTokens: const {},
            threadId: 'thread-1',
          );

          // Should return error result (not throw), having logged via
          // developer.log fallback.
          expect(result.success, isFalse);
          expect(result.error, contains('LLM unavailable'));
        },
      );
    });
  });
}
