import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/projection/content_digest.dart';
import 'package:lotti/features/agents/projection/input_capture.dart';
import 'package:lotti/features/agents/sync/agent_input_capture_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/workflow/task_agent_strategy.dart';
import 'package:lotti/features/agents/workflow/task_agent_workflow.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../categories/test_utils.dart';
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

  const agentId = 'agent-001';
  const taskId = 'task-001';
  const runKey = 'run-key-001';
  const threadId = 'thread-001';
  final testDate = DateTime(2024, 6, 15, 10, 30);

  final testTemplate = makeTestTemplate();
  final testTemplateVersion = makeTestTemplateVersion(
    directives: 'You are a diligent task agent named Laura.',
  );

  final testAgentIdentity =
      AgentDomainEntity.agent(
            id: agentId,
            agentId: agentId,
            kind: 'task_agent',
            displayName: 'Test Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: {'cat-001'},
            currentStateId: 'state-001',
            config: const AgentConfig(),
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024, 6),
            vectorClock: null,
          )
          as AgentIdentityEntity;

  final testAgentState =
      AgentDomainEntity.agentState(
            id: 'state-001',
            agentId: agentId,
            revision: 3,
            slots: const AgentSlots(activeTaskId: taskId),
            updatedAt: testDate,
            vectorClock: null,
          )
          as AgentStateEntity;

  final geminiProvider =
      AiConfig.inferenceProvider(
            id: 'gemini-provider-001',
            baseUrl: 'https://generativelanguage.googleapis.com',
            apiKey: 'test-api-key',
            name: 'Gemini',
            createdAt: DateTime(2024),
            inferenceProviderType: InferenceProviderType.gemini,
          )
          as AiConfigInferenceProvider;

  final geminiModel =
      AiConfig.model(
            id: 'model-gemini-3-1-pro',
            name: 'Gemini 3.1 Pro Preview',
            providerModelId: 'models/gemini-3-flash-preview',
            inferenceProviderId: 'gemini-provider-001',
            createdAt: DateTime(2024),
            inputModalities: const [Modality.text],
            outputModalities: const [Modality.text],
            isReasoningModel: true,
            supportsFunctionCalling: true,
            description: 'Test model',
          )
          as AiConfigModel;

  setUp(() async {
    mockAgentRepository = MockAgentRepository();
    mockSyncService = MockAgentSyncService();
    mockConversationManager = MockConversationManager();
    mockConversationRepository = MockConversationRepository(
      mockConversationManager,
    );
    mockAiInputRepository = MockAiInputRepository();
    mockAiConfigRepository = MockAiConfigRepository();
    mockJournalDb = MockJournalDb();
    mockCloudInferenceRepository = MockCloudInferenceRepository();
    mockJournalRepository = MockJournalRepository();
    mockChecklistRepository = MockChecklistRepository();
    mockLabelsRepository = MockLabelsRepository();
    mockTemplateService = MockAgentTemplateService();

    registerAllFallbackValues();

    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
          ..registerSingleton<TimeService>(TimeService());
      },
    );

    when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async => {});
    stubAppendMilestone(mockSyncService);
    stubReconciledAgentState(mockSyncService, mockAgentRepository);

    // System-prompt persistence checks payload existence by content digest;
    // default to "not present" so the content-addressed write path runs
    // (individual tests re-stub specific ids).
    when(
      () => mockAgentRepository.getEntity(any()),
    ).thenAnswer((_) async => null);

    // The workflow's `_collectObservationPayloads` switched from a per-id
    // `Future.wait(getEntity)` fan-out to the bulk
    // `AgentRepository.getEntitiesByIds(...)` call (see the 2026-05-12
    // slow-log analysis). Existing tests stub payloads via
    // `getEntity('payload-X')`; route the bulk stub through those by
    // delegating to the same per-id stubs, so a test only needs to
    // teach the mock about each id once.
    when(
      () => mockAgentRepository.getEntitiesByIds(any()),
    ).thenAnswer((invocation) async {
      final ids = invocation.positionalArguments.first as Iterable<String>;
      final result = <String, AgentDomainEntity>{};
      for (final id in ids) {
        final entity = await mockAgentRepository.getEntity(id);
        if (entity != null) {
          result[id] = entity;
        }
      }
      return result;
    });

    // `_buildLinkedTasksContextJson` switched from per-task
    // `Future.wait(_resolveLatestTaskAgentReport)` to bulk
    // `getLinksToMultiple` + `getLatestReportsByAgentIds`. Forward the
    // bulk calls through the existing per-id `getLinksTo` /
    // `getLatestReport` stubs so the same test fixtures keep driving
    // the workflow without per-test rewrites.
    when(
      () => mockAgentRepository.getLinksToMultiple(
        any(),
        type: any(named: 'type'),
      ),
    ).thenAnswer((invocation) async {
      final ids = invocation.positionalArguments.first as List<String>;
      final type = invocation.namedArguments[const Symbol('type')] as String?;
      final result = <String, List<AgentLink>>{};
      for (final id in ids) {
        final links = await mockAgentRepository.getLinksTo(id, type: type);
        if (links.isNotEmpty) {
          result[id] = links;
        }
      }
      return result;
    });

    when(
      () => mockAgentRepository.getLatestReportsByAgentIds(any(), any()),
    ).thenAnswer((invocation) async {
      final ids = invocation.positionalArguments.first as List<String>;
      final scope = invocation.positionalArguments[1] as String;
      final result = <String, AgentReportEntity>{};
      for (final id in ids) {
        final report = await mockAgentRepository.getLatestReport(id, scope);
        if (report != null) {
          result[id] = report;
        }
      }
      return result;
    });

    when(
      () => mockAgentRepository.updateWakeRunTemplate(
        any(),
        any(),
        any(),
        resolvedModelId: any(named: 'resolvedModelId'),
        soulId: any(named: 'soulId'),
        soulVersionId: any(named: 'soulVersionId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockAgentRepository.getLinksTo(any(), type: 'agent_task'),
    ).thenAnswer((_) async => <AgentLink>[]);
    when(
      () => mockAgentRepository.getRecentDecisions(
        any(),
        taskId: any(named: 'taskId'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => <ChangeDecisionEntity>[]);
    when(
      () => mockAgentRepository.getPendingChangeSets(
        any(),
        taskId: any(named: 'taskId'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => <ChangeSetEntity>[]);
    when(
      () => mockAgentRepository.getProposalLedger(
        any(),
        taskId: any(named: 'taskId'),
        changeSetFetchLimit: any(named: 'changeSetFetchLimit'),
        resolvedLimit: any(named: 'resolvedLimit'),
      ),
    ).thenAnswer((_) async => const ProposalLedger.empty());
    when(
      () => mockAiInputRepository.buildLinkedFromContext(any()),
    ).thenAnswer((_) async => <AiLinkedTaskContext>[]);
    when(
      () => mockAiInputRepository.buildLinkedToContext(any()),
    ).thenAnswer((_) async => <AiLinkedTaskContext>[]);
    when(
      () => mockAiInputRepository.buildProjectContextJsonForTask(any()),
    ).thenAnswer((_) async => '{}');
    when(
      () => mockAiInputRepository.buildRelatedProjectTasksJson(
        taskId: any(named: 'taskId'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => '{}');
    when(
      () => mockJournalDb.getLinkedEntities(any()),
    ).thenAnswer((_) async => <JournalEntity>[]);

    // Default template stubs — tests that need different behavior override.
    when(
      () => mockTemplateService.getTemplateForAgent(agentId),
    ).thenAnswer((_) async => testTemplate);
    when(
      () => mockTemplateService.getActiveVersion(testTemplate.id),
    ).thenAnswer((_) async => testTemplateVersion);

    workflow = TaskAgentWorkflow(
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
      domainLogger: DomainLogger(loggingService: LoggingService())
        ..enabledDomains.add(LogDomain.agentWorkflow),
    );
  });

  tearDownAll(tearDownTestGetIt);

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
            (s) => s.items.any(
              (i) => i.status == ChangeItemStatus.retracted,
            ),
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
        final promptPayload = capturedPayloadEntities(captured).singleWhere(
          (p) => p.content['role'] == 'system',
        );
        expect(promptPayload.id, ContentDigest.of(promptPayload.content));
        expect(
          promptPayload.content['text'],
          contains('You are a Task Agent'),
        );

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

      test('queries proposal ledger for deduplication context', () async {
        // Override with a non-empty ledger (pendingSets populated) to
        // exercise the expand/where lambda in the dedup path.
        final pendingChangeSet =
            AgentDomainEntity.changeSet(
                  id: 'cs-existing',
                  agentId: agentId,
                  taskId: taskId,
                  threadId: 'old-thread',
                  runKey: 'old-run',
                  status: ChangeSetStatus.pending,
                  items: const [
                    ChangeItem(
                      toolName: 'set_task_title',
                      args: {'title': 'Existing proposal'},
                      humanSummary: 'Set title',
                    ),
                  ],
                  createdAt: DateTime(2024, 3, 15),
                  vectorClock: null,
                )
                as ChangeSetEntity;

        when(
          () => mockAgentRepository.getProposalLedger(
            any(),
            taskId: any(named: 'taskId'),
            changeSetFetchLimit: any(named: 'changeSetFetchLimit'),
            resolvedLimit: any(named: 'resolvedLimit'),
          ),
        ).thenAnswer(
          (_) async => ProposalLedger(
            open: const [],
            resolved: const [],
            pendingSets: [pendingChangeSet],
          ),
        );

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isTrue);

        verify(
          () => mockAgentRepository.getProposalLedger(
            agentId,
            taskId: taskId,
            resolvedLimit: TaskAgentWorkflow.resolvedDecisionWindow,
          ),
        ).called(1);
      });

      test('system prompt contains scaffold and template directives', () async {
        String? capturedSystemMessage;
        // Override createConversation to capture the system message.
        final capturingRepo = CapturingConversationRepository(
          mockConversationManager,
          onSystemMessage: (msg) => capturedSystemMessage = msg,
        );
        final capturingWorkflow = createTestWorkflow(
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

        await capturingWorkflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(capturedSystemMessage, isNotNull);
        // Scaffold content.
        expect(capturedSystemMessage, contains('You are a Task Agent'));
        expect(capturedSystemMessage, contains('update_report'));
        expect(capturedSystemMessage, contains('oneLiner'));
        // Parent project context scaffold section.
        expect(
          capturedSystemMessage,
          contains('## Parent Project Context'),
        );
        // Related-tasks scaffold is disabled to reduce context pollution.
        expect(
          capturedSystemMessage,
          isNot(contains('## Related Tasks In This Project')),
        );
        // Template directives appended.
        expect(
          capturedSystemMessage,
          contains('Your Personality & Directives'),
        );
        expect(
          capturedSystemMessage,
          contains('You are a diligent task agent named Laura.'),
        );
      });

      test(
        'system prompt uses split directives when generalDirective is set',
        () async {
          final splitVersion = makeTestTemplateVersion(
            generalDirective: 'Be thorough and precise.',
          );
          when(
            () => mockTemplateService.getActiveVersion(testTemplate.id),
          ).thenAnswer((_) async => splitVersion);

          String? capturedSystemMessage;
          final capturingRepo = CapturingConversationRepository(
            mockConversationManager,
            onSystemMessage: (msg) => capturedSystemMessage = msg,
          );
          final capturingWorkflow = createTestWorkflow(
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

          await capturingWorkflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(capturedSystemMessage, isNotNull);
          // Core scaffold present.
          expect(capturedSystemMessage, contains('You are a Task Agent'));
          // Parent project context scaffold section.
          expect(
            capturedSystemMessage,
            contains('## Parent Project Context'),
          );
          // Related-tasks scaffold is disabled to reduce context pollution.
          expect(
            capturedSystemMessage,
            isNot(contains('## Related Tasks In This Project')),
          );
          // General directive injected.
          expect(
            capturedSystemMessage,
            contains('Be thorough and precise.'),
          );
          expect(
            capturedSystemMessage,
            contains('Your Personality & Directives'),
          );
          // Default report scaffold used when reportDirective is empty.
          expect(capturedSystemMessage, contains('## Report'));
          expect(capturedSystemMessage, isNot(contains('## Report Directive')));
        },
      );

      test(
        'system prompt uses custom report directive when reportDirective is set',
        () async {
          final splitVersion = makeTestTemplateVersion(
            generalDirective: 'Be concise.',
            reportDirective: 'Write reports in bullet points only.',
          );
          when(
            () => mockTemplateService.getActiveVersion(testTemplate.id),
          ).thenAnswer((_) async => splitVersion);

          String? capturedSystemMessage;
          final capturingRepo = CapturingConversationRepository(
            mockConversationManager,
            onSystemMessage: (msg) => capturedSystemMessage = msg,
          );
          final capturingWorkflow = createTestWorkflow(
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

          await capturingWorkflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(capturedSystemMessage, isNotNull);
          // Custom report directive replaces the default report section.
          expect(
            capturedSystemMessage,
            contains('## Report Directive'),
          );
          expect(
            capturedSystemMessage,
            contains('Write reports in bullet points only.'),
          );
          // Parent project context scaffold section.
          expect(
            capturedSystemMessage,
            contains('## Parent Project Context'),
          );
          // Related-tasks scaffold is disabled to reduce context pollution.
          expect(
            capturedSystemMessage,
            isNot(contains('## Related Tasks In This Project')),
          );
          // General directive present.
          expect(capturedSystemMessage, contains('Be concise.'));
          // Tool usage guidelines (trailing scaffold) still present.
          expect(capturedSystemMessage, contains('## Tool Usage Guidelines'));
        },
      );

      test(
        'system prompt separates personality from skills when soul is assigned',
        () async {
          final splitVersion = makeTestTemplateVersion(
            generalDirective: 'Focus on task completion and accuracy.',
          );
          when(
            () => mockTemplateService.getActiveVersion(testTemplate.id),
          ).thenAnswer((_) async => splitVersion);

          final mockSoulService = MockSoulDocumentService();
          final soulVersion = makeTestSoulDocumentVersion(
            voiceDirective: 'Speak warmly and with clarity.',
            toneBounds: 'Never be sarcastic.',
            coachingStyle: 'Celebrate small wins.',
            antiSycophancyPolicy: 'Push back when tasks seem misguided.',
          );
          when(
            () => mockSoulService.resolveActiveSoulForTemplate(
              testTemplate.id,
            ),
          ).thenAnswer((_) async => soulVersion);

          String? capturedSystemMessage;
          final capturingRepo = CapturingConversationRepository(
            mockConversationManager,
            onSystemMessage: (msg) => capturedSystemMessage = msg,
          );
          final capturingWorkflow = createTestWorkflow(
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
            soulDocumentService: mockSoulService,
          );

          await capturingWorkflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(capturedSystemMessage, isNotNull);
          // Soul personality fields injected under separate heading.
          expect(capturedSystemMessage, contains('## Your Personality'));
          expect(
            capturedSystemMessage,
            contains('Speak warmly and with clarity.'),
          );
          expect(capturedSystemMessage, contains('Never be sarcastic.'));
          expect(capturedSystemMessage, contains('Celebrate small wins.'));
          expect(
            capturedSystemMessage,
            contains('Push back when tasks seem misguided.'),
          );
          // Operational directives under separate heading.
          expect(
            capturedSystemMessage,
            contains('## Your Operational Directives'),
          );
          expect(
            capturedSystemMessage,
            contains('Focus on task completion and accuracy.'),
          );
          // Combined heading must NOT appear when soul is present.
          expect(
            capturedSystemMessage,
            isNot(contains('## Your Personality & Directives')),
          );
        },
      );

      test(
        'system prompt uses legacy heading when no soul is assigned',
        () async {
          final splitVersion = makeTestTemplateVersion(
            generalDirective: 'Skills only directive.',
          );
          when(
            () => mockTemplateService.getActiveVersion(testTemplate.id),
          ).thenAnswer((_) async => splitVersion);

          final mockSoulService = MockSoulDocumentService();
          when(
            () => mockSoulService.resolveActiveSoulForTemplate(
              testTemplate.id,
            ),
          ).thenAnswer((_) async => null);

          String? capturedSystemMessage;
          final capturingRepo = CapturingConversationRepository(
            mockConversationManager,
            onSystemMessage: (msg) => capturedSystemMessage = msg,
          );
          final capturingWorkflow = createTestWorkflow(
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
            soulDocumentService: mockSoulService,
          );

          await capturingWorkflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(capturedSystemMessage, isNotNull);
          // Legacy combined heading.
          expect(
            capturedSystemMessage,
            contains('## Your Personality & Directives'),
          );
          expect(
            capturedSystemMessage,
            contains('Skills only directive.'),
          );
          // Separate headings must NOT appear.
          expect(
            capturedSystemMessage,
            isNot(contains('## Your Personality\n')),
          );
          expect(
            capturedSystemMessage,
            isNot(contains('## Your Operational Directives')),
          );
        },
      );

      test(
        'soul resolution failure propagates as exception',
        () async {
          final splitVersion = makeTestTemplateVersion(
            generalDirective: 'Skills directive.',
          );
          when(
            () => mockTemplateService.getActiveVersion(testTemplate.id),
          ).thenAnswer((_) async => splitVersion);

          final mockSoulService = MockSoulDocumentService();
          when(
            () => mockSoulService.resolveActiveSoulForTemplate(
              testTemplate.id,
            ),
          ).thenThrow(Exception('Soul DB error'));

          final soulWorkflow = createTestWorkflow(
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
            soulDocumentService: mockSoulService,
          );

          await expectLater(
            soulWorkflow.execute(
              agentIdentity: testAgentIdentity,
              runKey: runKey,
              triggerTokens: {'entity-a'},
              threadId: threadId,
            ),
            throwsA(
              isA<Exception>().having(
                (e) => e.toString(),
                'message',
                contains('Soul DB error'),
              ),
            ),
          );
        },
      );

      test(
        'token usage records soul provenance when soul is assigned',
        () async {
          final splitVersion = makeTestTemplateVersion(
            generalDirective: 'Be precise.',
          );
          when(
            () => mockTemplateService.getActiveVersion(testTemplate.id),
          ).thenAnswer((_) async => splitVersion);

          final mockSoulService = MockSoulDocumentService();
          final soulVersion = makeTestSoulDocumentVersion(
            id: 'sv-001',
            agentId: 'soul-doc-001',
            voiceDirective: 'Warm voice.',
          );
          when(
            () => mockSoulService.resolveActiveSoulForTemplate(
              testTemplate.id,
            ),
          ).thenAnswer((_) async => soulVersion);

          // Use a conversation repo that returns actual token usage.
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
              }) async =>
                  const InferenceUsage(inputTokens: 50, outputTokens: 25);

          final soulWorkflow = TaskAgentWorkflow(
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
            soulDocumentService: mockSoulService,
          );

          await soulWorkflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          // Verify soul provenance in wake run.
          verify(
            () => mockAgentRepository.updateWakeRunTemplate(
              runKey,
              testTemplate.id,
              splitVersion.id,
              resolvedModelId: any(named: 'resolvedModelId'),
              soulId: 'soul-doc-001',
              soulVersionId: 'sv-001',
            ),
          ).called(1);

          // Verify soul provenance in token usage entity.
          final captured = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;
          final tokenUsages = capturedTokenUsageEntities(captured);
          expect(tokenUsages, isNotEmpty);
          final tokenUsage = tokenUsages.first;
          expect(tokenUsage.soulDocumentId, 'soul-doc-001');
          expect(tokenUsage.soulDocumentVersionId, 'sv-001');
        },
      );

      test('records template provenance on wake run', () async {
        await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        verify(
          () => mockAgentRepository.updateWakeRunTemplate(
            runKey,
            testTemplate.id,
            testTemplateVersion.id,
            resolvedModelId: any(named: 'resolvedModelId'),
            soulId: any(named: 'soulId'),
            soulVersionId: any(named: 'soulVersionId'),
          ),
        ).called(1);
      });

      test('continues when template provenance recording fails', () async {
        when(
          () => mockAgentRepository.updateWakeRunTemplate(
            any(),
            any(),
            any(),
            resolvedModelId: any(named: 'resolvedModelId'),
            soulId: any(named: 'soulId'),
            soulVersionId: any(named: 'soulVersionId'),
          ),
        ).thenThrow(Exception('DB error'));

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        // Wake should still succeed despite provenance failure.
        expect(result.success, isTrue);
      });

      test(
        'persists observations from record_observations tool calls',
        () async {
          // Set up sendMessage to simulate the strategy accumulating
          // observations via the record_observations tool during conversation.
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
                // Simulate the LLM calling record_observations by directly
                // invoking processToolCalls with a record_observations call.
                if (strategy is TaskAgentStrategy) {
                  await strategy.processToolCalls(
                    toolCalls: [
                      const ChatCompletionMessageToolCall(
                        id: 'obs-call',
                        type: ChatCompletionMessageToolCallType.function,
                        function: ChatCompletionMessageFunctionCall(
                          name: 'record_observations',
                          arguments:
                              '{"observations":["Pattern A","Pattern B"]}',
                        ),
                      ),
                    ],
                    manager: mockConversationManager,
                  );
                }
                return null;
              };

          when(() => mockConversationManager.messages).thenReturn([]);

          final result = await workflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(result.success, isTrue);

          // Should persist: assistant message (from processToolCalls)
          // + 2 observation payloads + 2 observation messages
          // + state update = 6 total.
          verify(
            () => mockSyncService.upsertEntity(any()),
          ).called(greaterThanOrEqualTo(6));
        },
      );

      test(
        'persists observation payloads with priority and category fields',
        () async {
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
                        id: 'obs-structured',
                        type: ChatCompletionMessageToolCallType.function,
                        function: ChatCompletionMessageFunctionCall(
                          name: 'record_observations',
                          arguments:
                              '{"observations":[{"text":"User is frustrated",'
                              ' "priority":"critical","category":"grievance"}]}',
                        ),
                      ),
                    ],
                    manager: mockConversationManager,
                  );
                }
                return null;
              };

          when(() => mockConversationManager.messages).thenReturn([]);

          final result = await workflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(result.success, isTrue);

          final captured = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;

          // Find the persisted observation payload entity (has priority key).
          final payloads = capturedPayloadEntities(
            captured,
          ).where((p) => p.content.containsKey('priority')).toList();

          expect(payloads, hasLength(1));
          final payload = payloads.first;
          expect(payload.content['text'], 'User is frustrated');
          expect(payload.content['priority'], 'critical');
          expect(payload.content['category'], 'grievance');
        },
      );

      test(
        'persists wakeTokenUsage entity when usage data is returned',
        () async {
          // Return non-null usage from sendMessage.
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
                return const InferenceUsage(
                  inputTokens: 150,
                  outputTokens: 75,
                  thoughtsTokens: 30,
                  cachedInputTokens: 20,
                );
              };

          final result = await workflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(result.success, isTrue);

          // Verify a wakeTokenUsage entity was persisted.
          final captured = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;

          final tokenUsageEntities = capturedTokenUsageEntities(captured);

          expect(tokenUsageEntities, hasLength(1));
          final entity = tokenUsageEntities.first;
          expect(entity.agentId, agentId);
          expect(entity.runKey, runKey);
          expect(entity.threadId, threadId);
          expect(entity.inputTokens, 150);
          expect(entity.outputTokens, 75);
          expect(entity.thoughtsTokens, 30);
          expect(entity.cachedInputTokens, 20);
        },
      );

      test('does not persist wakeTokenUsage when usage is null', () async {
        // Default delegate returns null.
        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isTrue);

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;

        final tokenUsageEntities = capturedTokenUsageEntities(captured);

        expect(tokenUsageEntities, isEmpty);
      });

      test('does not persist wakeTokenUsage when usage has no data', () async {
        // Return an empty usage (hasData == false).
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
              return InferenceUsage.empty;
            };

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isTrue);

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;

        final tokenUsageEntities = capturedTokenUsageEntities(captured);

        expect(tokenUsageEntities, isEmpty);
      });

      test('handles _persistTokenUsage failure gracefully', () async {
        // Return usage data, but make the sync service throw on wakeTokenUsage.
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
              return const InferenceUsage(
                inputTokens: 100,
                outputTokens: 50,
              );
            };

        // Make upsertEntity throw only for wakeTokenUsage entities.
        var callCount = 0;
        when(() => mockSyncService.upsertEntity(any())).thenAnswer((inv) async {
          final entity = inv.positionalArguments[0] as AgentDomainEntity;
          final isTokenUsage =
              entity.mapOrNull(wakeTokenUsage: (_) => true) ?? false;
          if (isTokenUsage) {
            throw Exception('Sync failed');
          }
          callCount++;
        });

        // Should NOT fail the overall wake despite persistence error.
        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isTrue);
        // Other entities (user message, state update, etc.) were still persisted.
        expect(callCount, greaterThan(0));
      });

      test('cleans up conversation in finally block even on success', () async {
        await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(
          mockConversationRepository.deletedConversationIds,
          contains('test-conv-id'),
        );
      });
    });

    group('forced update_report retry', () {
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
        'issues a second sendMessage with toolChoice forced to update_report '
        'when the strategy ended without a report',
        () async {
          final calls =
              <
                ({
                  String message,
                  ChatCompletionToolChoiceOption? toolChoice,
                })
              >[];

          // Allow the delegate to run for both the primary call and the retry
          // so the test can observe both invocations.
          mockConversationRepository
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
                  calls.add((message: message, toolChoice: toolChoice));
                  return null;
                };

          final result = await workflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(result.success, isTrue);
          expect(calls, hasLength(2));

          // First call: normal wake, no forced tool choice.
          expect(calls[0].toolChoice, isNull);

          // Second call: forced update_report.
          final retryToolChoice = calls[1].toolChoice;
          expect(retryToolChoice, isNotNull);
          retryToolChoice!.map(
            mode: (_) => fail('Expected named tool choice, got mode.'),
            tool: (named) {
              expect(
                named.value.function.name,
                TaskAgentStrategy.reportToolName,
              );
            },
          );
          expect(
            calls[1].message,
            contains('You did not call `update_report`'),
          );
        },
      );

      test(
        'swallows retry failures so the main-pass observations and metadata '
        'still reach the transaction',
        () async {
          mockConversationRepository
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
                  // First call: record an observation via the real strategy
                  // so the wake has something meaningful to persist.
                  if (toolChoice == null) {
                    if (strategy is TaskAgentStrategy) {
                      await strategy.processToolCalls(
                        toolCalls: const [
                          ChatCompletionMessageToolCall(
                            id: 'obs-1',
                            type: ChatCompletionMessageToolCallType.function,
                            function: ChatCompletionMessageFunctionCall(
                              name: 'record_observations',
                              arguments:
                                  '{"observations":["important finding"]}',
                            ),
                          ),
                        ],
                        manager: mockConversationManager,
                      );
                    }
                    return null;
                  }
                  // Second call (retry): blow up. The workflow must catch
                  // this and still persist the observation recorded above.
                  throw Exception('simulated retry failure');
                };

          when(() => mockConversationManager.messages).thenReturn([]);

          final result = await workflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          // The wake must NOT fail because of the retry exception.
          expect(result.success, isTrue);

          // The observation recorded before the retry threw must be persisted.
          final captured = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;
          final observationPayloads = capturedPayloadEntities(
            captured,
          ).where((p) => p.content['text'] == 'important finding').toList();
          expect(observationPayloads, hasLength(1));
        },
      );

      test(
        'accumulates token usage across the main call and the forced retry',
        () async {
          mockConversationRepository
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
                  // First call returns usage; retry (forced tool choice)
                  // returns more usage. Both must be merged and persisted.
                  if (toolChoice == null) {
                    return const InferenceUsage(
                      inputTokens: 100,
                      outputTokens: 40,
                    );
                  }
                  return const InferenceUsage(
                    inputTokens: 25,
                    outputTokens: 15,
                  );
                };

          final result = await workflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(result.success, isTrue);

          final captured = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;
          final tokenUsageEntities = capturedTokenUsageEntities(captured);

          expect(tokenUsageEntities, hasLength(1));
          final entity = tokenUsageEntities.first;
          expect(entity.inputTokens, 125);
          expect(entity.outputTokens, 55);
        },
      );

      test(
        'does NOT issue a retry when the strategy already published a report',
        () async {
          var callCount = 0;
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
                callCount++;
                if (strategy is TaskAgentStrategy) {
                  await strategy.processToolCalls(
                    toolCalls: const [
                      ChatCompletionMessageToolCall(
                        id: 'report-call',
                        type: ChatCompletionMessageToolCallType.function,
                        function: ChatCompletionMessageFunctionCall(
                          name: 'update_report',
                          arguments:
                              '{"oneLiner":"one","tldr":"tldr","content":"body"}',
                        ),
                      ),
                    ],
                    manager: mockConversationManager,
                  );
                }
                return null;
              };

          when(() => mockConversationManager.messages).thenReturn([]);

          final result = await workflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(result.success, isTrue);
          expect(callCount, 1);
        },
      );
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

    group('report and thought persistence', () {
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
        'persists report and report head when strategy produces report',
        () async {
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
                        id: 'rpt-call',
                        type: ChatCompletionMessageToolCallType.function,
                        function: ChatCompletionMessageFunctionCall(
                          name: 'update_report',
                          arguments:
                              r'{"content":"# Report\nAll good.","oneLiner":"Implementation done, release next","tldr":"Implementation is done and release is next."}',
                        ),
                      ),
                    ],
                    manager: mockConversationManager,
                  );
                }
                return null;
              };

          when(() => mockConversationManager.messages).thenReturn([]);

          final result = await workflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(result.success, isTrue);

          // Report + report head + state update + assistant message = 4+
          final captured = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;

          final reports = captured
              .whereType<AgentDomainEntity>()
              .where(
                (e) => e.mapOrNull(agentReport: (_) => true) ?? false,
              )
              .toList();
          expect(reports, hasLength(1));
          final report = reports.first as AgentReportEntity;
          expect(report.content, '# Report\nAll good.');

          final heads = captured
              .whereType<AgentDomainEntity>()
              .where(
                (e) => e.mapOrNull(agentReportHead: (_) => true) ?? false,
              )
              .toList();
          expect(heads, hasLength(1));
        },
      );

      test('persists report with tldr and oneLiner when provided', () async {
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
                      id: 'rpt-call',
                      type: ChatCompletionMessageToolCallType.function,
                      function: ChatCompletionMessageFunctionCall(
                        name: 'update_report',
                        arguments: jsonEncode({
                          'content': '# Detailed Report\nFull analysis.',
                          'oneLiner': 'Implementation done, release next',
                          'tldr': 'Brief summary.',
                        }),
                      ),
                    ),
                  ],
                  manager: mockConversationManager,
                );
              }
              return null;
            };

        when(() => mockConversationManager.messages).thenReturn([]);

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isTrue);

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;

        final reports = captured
            .whereType<AgentDomainEntity>()
            .where(
              (e) => e.mapOrNull(agentReport: (_) => true) ?? false,
            )
            .toList();
        expect(reports, hasLength(1));
        final report = reports.first as AgentReportEntity;
        expect(report.content, '# Detailed Report\nFull analysis.');
        expect(report.tldr, 'Brief summary.');
        expect(report.oneLiner, 'Implementation done, release next');
      });

      test('persists thought message when LLM produces final text', () async {
        when(() => mockConversationManager.messages).thenReturn([
          const ChatCompletionMessage.assistant(
            content: 'I analyzed the task and it looks good.',
          ),
        ]);

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isTrue);

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;

        // Find the thought payload entity (the one with the LLM response,
        // not the user message payload).
        final payloads = capturedPayloadEntities(captured);
        // At least 2 payloads: user message + thought.
        expect(payloads.length, greaterThanOrEqualTo(2));
        final thoughtPayload = payloads.firstWhere(
          (p) => p.content['text'] == 'I analyzed the task and it looks good.',
        );
        expect(
          thoughtPayload.content['text'],
          'I analyzed the task and it looks good.',
        );
      });

      test('uses existing report head ID when one exists', () async {
        final existingHead =
            AgentDomainEntity.agentReportHead(
                  id: 'existing-head-id',
                  agentId: agentId,
                  scope: 'current',
                  reportId: 'old-report',
                  updatedAt: testDate,
                  vectorClock: null,
                )
                as AgentReportHeadEntity;

        when(
          () => mockAgentRepository.getReportHead(agentId, 'current'),
        ).thenAnswer((_) async => existingHead);

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
                      id: 'rpt-call',
                      type: ChatCompletionMessageToolCallType.function,
                      function: ChatCompletionMessageFunctionCall(
                        name: 'update_report',
                        arguments:
                            '{"content":"# Updated","oneLiner":"Implementation done, release next","tldr":"Implementation is done and release is next."}',
                      ),
                    ),
                  ],
                  manager: mockConversationManager,
                );
              }
              return null;
            };

        when(() => mockConversationManager.messages).thenReturn([]);

        await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;

        final heads = captured
            .whereType<AgentDomainEntity>()
            .where(
              (e) => e.mapOrNull(agentReportHead: (_) => true) ?? false,
            )
            .toList();
        expect(heads, hasLength(1));
        final head = heads.first as AgentReportHeadEntity;
        expect(head.id, 'existing-head-id');
      });

      test(
        'embeds a new report and deletes the previous report embedding',
        () async {
          final existingHead =
              AgentDomainEntity.agentReportHead(
                    id: 'existing-head-id',
                    agentId: agentId,
                    scope: 'current',
                    reportId: 'old-report',
                    updatedAt: testDate,
                    vectorClock: null,
                  )
                  as AgentReportHeadEntity;
          final mockEmbeddingStore = MockEmbeddingStore();
          final mockEmbeddingRepository = MockOllamaEmbeddingRepository();
          final workflowWithEmbeddings = TaskAgentWorkflow(
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
            domainLogger: DomainLogger(loggingService: LoggingService())
              ..enabledDomains.add(LogDomain.agentWorkflow),
            embeddingStore: mockEmbeddingStore,
            embeddingRepository: mockEmbeddingRepository,
          );

          when(
            () => mockAgentRepository.getReportHead(agentId, 'current'),
          ).thenAnswer((_) async => existingHead);
          when(
            () => mockAiConfigRepository.resolveOllamaBaseUrl(),
          ).thenAnswer((_) async => 'http://localhost:11434');
          when(() => mockEmbeddingStore.getContentHash(any())).thenReturn(null);
          when(
            () => mockEmbeddingRepository.embed(
              input: any(named: 'input'),
              baseUrl: any(named: 'baseUrl'),
            ),
          ).thenAnswer(
            (_) async => Float32List.fromList(
              List<double>.filled(kEmbeddingDimensions, 0.25),
            ),
          );
          when(
            () => mockJournalDb.journalEntityById(taskId),
          ).thenAnswer(
            (_) async => Task(
              data: TaskData(
                status: TaskStatus.open(
                  id: 'status_id',
                  createdAt: DateTime(2024, 3, 15),
                  utcOffset: 60,
                ),
                title: 'Add tests for embedding cleanup',
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
            ),
          );
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
                        id: 'rpt-call',
                        type: ChatCompletionMessageToolCallType.function,
                        function: ChatCompletionMessageFunctionCall(
                          name: 'update_report',
                          arguments:
                              r'{"content":"# Report\nThis report has enough content to embed.","oneLiner":"Implementation done, release next","tldr":"Implementation is done and release is next."}',
                        ),
                      ),
                    ],
                    manager: mockConversationManager,
                  );
                }
                return null;
              };
          when(() => mockConversationManager.messages).thenReturn([]);

          final result = await workflowWithEmbeddings.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(result.success, isTrue);
          await pumpEventQueue();

          verify(
            () => mockEmbeddingRepository.embed(
              input: any(named: 'input'),
              baseUrl: 'http://localhost:11434',
            ),
          ).called(1);
          verify(
            () => mockEmbeddingStore.deleteEntityEmbeddings('old-report'),
          ).called(1);
        },
      );

      test(
        'swallows errors thrown while embedding the report',
        () async {
          // _embedAgentReport runs fire-and-forget after the transaction
          // commits. If the category lookup throws, the failure must be
          // caught (logged) and never surface as a wake failure, and no
          // embedding/deletion side effects should run.
          final mockEmbeddingStore = MockEmbeddingStore();
          final mockEmbeddingRepository = MockOllamaEmbeddingRepository();
          final workflowWithEmbeddings = TaskAgentWorkflow(
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
            domainLogger: DomainLogger(loggingService: LoggingService())
              ..enabledDomains.add(LogDomain.agentWorkflow),
            embeddingStore: mockEmbeddingStore,
            embeddingRepository: mockEmbeddingRepository,
          );

          when(
            () => mockAgentRepository.getReportHead(agentId, 'current'),
          ).thenAnswer((_) async => null);
          when(
            () => mockAiConfigRepository.resolveOllamaBaseUrl(),
          ).thenAnswer((_) async => 'http://localhost:11434');
          // The category lookup inside _embedAgentReport throws — this is the
          // branch we want to exercise (the catch on line 885).
          when(
            () => mockJournalDb.journalEntityById(taskId),
          ).thenThrow(Exception('db unavailable'));

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
                        id: 'rpt-call',
                        type: ChatCompletionMessageToolCallType.function,
                        function: ChatCompletionMessageFunctionCall(
                          name: 'update_report',
                          arguments:
                              r'{"content":"# Report\nThis report has enough content to embed.","oneLiner":"done","tldr":"done."}',
                        ),
                      ),
                    ],
                    manager: mockConversationManager,
                  );
                }
                return null;
              };
          when(() => mockConversationManager.messages).thenReturn([]);

          final result = await workflowWithEmbeddings.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          // The wake itself still succeeds — embedding is best-effort.
          expect(result.success, isTrue);
          await pumpEventQueue();

          // The throwing lookup short-circuits before any embed/delete call.
          verifyNever(
            () => mockEmbeddingRepository.embed(
              input: any(named: 'input'),
              baseUrl: any(named: 'baseUrl'),
            ),
          );
          verifyNever(
            () => mockEmbeddingStore.deleteEntityEmbeddings(any()),
          );
        },
      );
    });

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
          final result = await executeWithToolCall(
            'nonexistent_tool',
            '{}',
          );

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

    group('_buildUserMessage context', () {
      /// Helper that sets up the common stubs for a successful execute, and
      /// captures the user message string sent to the conversation.
      Future<String?> executeAndCaptureMessage({
        AgentReportEntity? lastReport,
        List<AgentMessageEntity> observations = const [],
        String projectContextJson = '{}',
        String linkedTasksJson = '{}',
        Set<String> triggerTokens = const {},
        bool throwOnLinkedContextBuild = false,
      }) async {
        List<AiLinkedTaskContext> parseLinkedTasks(dynamic rawRows) {
          if (rawRows is! List) return const <AiLinkedTaskContext>[];
          return rawRows.whereType<Map<String, dynamic>>().map((row) {
            final id = (row['id'] as String?) ?? 'linked-task';
            return AiLinkedTaskContext(
              id: id,
              title: (row['title'] as String?) ?? id,
              status: (row['status'] as String?) ?? 'OPEN',
              statusSince: DateTime(2024),
              priority: (row['priority'] as String?) ?? 'M',
              estimate: (row['estimate'] as String?) ?? '00:00',
              timeSpent: (row['timeSpent'] as String?) ?? '00:00',
              createdAt: DateTime(2024),
              labels: const <Map<String, String>>[],
              languageCode: row['languageCode'] as String?,
              latestSummary: row['latestSummary'] as String?,
            );
          }).toList();
        }

        final parsed = jsonDecode(linkedTasksJson);
        final linkedMap = parsed is Map<String, dynamic>
            ? parsed
            : <String, dynamic>{};
        final linkedFrom = parseLinkedTasks(linkedMap['linked_from']);
        final linkedTo = [
          ...parseLinkedTasks(linkedMap['linked_to']),
          ...parseLinkedTasks(linkedMap['linked']),
        ];

        when(
          () => mockAgentRepository.getAgentState(agentId),
        ).thenAnswer((_) async => testAgentState);
        when(
          () => mockAgentRepository.getLatestReport(agentId, 'current'),
        ).thenAnswer((_) async => lastReport);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.observation,
          ),
        ).thenAnswer((_) async => observations);
        when(
          () => mockAiInputRepository.buildTaskDetailsJson(id: taskId),
        ).thenAnswer((_) async => '{"title":"Test Task"}');
        when(
          () => mockAiInputRepository.buildProjectContextJsonForTask(taskId),
        ).thenAnswer((_) async => projectContextJson);
        if (throwOnLinkedContextBuild) {
          when(
            () => mockAiInputRepository.buildLinkedFromContext(taskId),
          ).thenThrow(Exception('linked context failed'));
        } else {
          when(
            () => mockAiInputRepository.buildLinkedFromContext(taskId),
          ).thenAnswer((_) async => linkedFrom);
        }
        when(
          () => mockAiInputRepository.buildLinkedToContext(taskId),
        ).thenAnswer((_) async => linkedTo);
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

        String? capturedMessage;
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
              capturedMessage = message;
              return null;
            };

        await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: triggerTokens,
          threadId: threadId,
        );

        return capturedMessage;
      }

      test(
        'injects label and correction-example context when available',
        () async {
          when(() => mockJournalDb.journalEntityById(taskId)).thenAnswer(
            (_) async => Task(
              data: TaskData(
                status: TaskStatus.open(
                  id: 'status_id',
                  createdAt: DateTime(2024, 3, 15),
                  utcOffset: 60,
                ),
                title: 'Labelled task',
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
                categoryId: 'cat-001',
              ),
            ),
          );
          when(() => mockJournalDb.getAllLabelDefinitions()).thenAnswer(
            (_) async => [
              LabelDefinition(
                id: 'lbl-bug',
                createdAt: DateTime(2024),
                updatedAt: DateTime(2024),
                name: 'Bug',
                color: '#FF0000',
                vectorClock: null,
                applicableCategoryIds: const ['cat-001'],
              ),
            ],
          );
          when(() => mockJournalDb.getCategoryById('cat-001')).thenAnswer(
            (_) async => CategoryTestUtils.createTestCategory(
              id: 'cat-001',
              correctionExamples: [
                ChecklistCorrectionExample(
                  before: 'mac OS',
                  after: 'macOS',
                  capturedAt: DateTime(2024, 5, 2),
                ),
              ],
            ),
          );

          final message = await executeAndCaptureMessage();

          expect(message, isNotNull);
          // Label-context branch: available labels injected.
          expect(message, contains('## Available Labels'));
          expect(message, contains('Bug'));
          // Correction-example branch: category examples injected.
          expect(message, contains('## Correction Examples'));
          expect(message, contains('macOS'));
        },
      );

      test(
        'never injects the prior report prose into the user message',
        () async {
          // The report is a projection of the log, not agent memory: re-reading
          // its own stale conclusions creates a feedback loop (a wrong
          // "learning" re-published verbatim every wake). With a report present,
          // neither the prose nor the first-wake bootstrap section appears.
          final report =
              AgentDomainEntity.agentReport(
                    id: 'rpt-1',
                    agentId: agentId,
                    scope: 'current',
                    createdAt: testDate,
                    vectorClock: null,
                    content: '# My Report\nAll good.',
                  )
                  as AgentReportEntity;

          final message = await executeAndCaptureMessage(lastReport: report);

          expect(message, isNotNull);
          expect(message, isNot(contains('## Current Report')));
          expect(message, isNot(contains('# My Report')));
          expect(message, isNot(contains('## First Wake')));
          // The closing instruction states the conditional-report contract.
          expect(message, contains('If the report would materially change'));
        },
      );

      test(
        'includes parent project context with project report tldr and full content',
        () async {
          final message = await executeAndCaptureMessage(
            projectContextJson: jsonEncode({
              'project': {
                'id': 'project-1',
                'title': 'Parent Project',
                'status': 'ACTIVE',
              },
              'latestProjectAgentReport': {
                'tldr': 'Project TLDR',
                'content': '## Project Report\nFull project report body.',
              },
            }),
          );

          expect(message, isNotNull);
          expect(message, contains('## Parent Project Context'));
          expect(message, contains('Parent Project'));
          expect(message, contains('Project TLDR'));
          expect(message, contains('Full project report body.'));
        },
      );

      test(
        'does not include a related-task directory section in the wake context',
        () async {
          final message = await executeAndCaptureMessage();

          expect(message, isNotNull);
          expect(
            message,
            isNot(contains('## Related Tasks In This Project')),
          );
        },
      );

      test('includes first wake message when no report exists', () async {
        final message = await executeAndCaptureMessage();

        expect(message, isNotNull);
        expect(message, contains('First Wake'));
        expect(message, contains('No prior report exists'));
      });

      test('includes observation text in user message', () async {
        final obs =
            AgentDomainEntity.agentMessage(
                  id: 'obs-1',
                  agentId: agentId,
                  threadId: threadId,
                  kind: AgentMessageKind.observation,
                  createdAt: DateTime(2024, 6, 15, 9),
                  vectorClock: null,
                  contentEntryId: 'payload-obs-1',
                  metadata: const AgentMessageMetadata(runKey: runKey),
                )
                as AgentMessageEntity;

        final payload = AgentDomainEntity.agentMessagePayload(
          id: 'payload-obs-1',
          agentId: agentId,
          createdAt: DateTime(2024, 6, 15, 9),
          vectorClock: null,
          content: <String, Object?>{'text': 'Task needs refactoring'},
        );

        when(
          () => mockAgentRepository.getEntity('payload-obs-1'),
        ).thenAnswer((_) async => payload);

        final message = await executeAndCaptureMessage(observations: [obs]);

        expect(message, isNotNull);
        expect(message, contains('## Agent Journal'));
        expect(message, contains('Task needs refactoring'));
      });

      test(
        'shows "(no content)" for observation with missing payload',
        () async {
          final obs =
              AgentDomainEntity.agentMessage(
                    id: 'obs-2',
                    agentId: agentId,
                    threadId: threadId,
                    kind: AgentMessageKind.observation,
                    createdAt: DateTime(2024, 6, 15, 9),
                    vectorClock: null,
                    contentEntryId: 'missing-payload',
                    metadata: const AgentMessageMetadata(runKey: runKey),
                  )
                  as AgentMessageEntity;

          when(
            () => mockAgentRepository.getEntity('missing-payload'),
          ).thenAnswer((_) async => null);

          final message = await executeAndCaptureMessage(observations: [obs]);

          expect(message, isNotNull);
          expect(message, contains('(no content)'));
        },
      );

      test(
        'shows "(no content)" for observation with null contentEntryId',
        () async {
          final obs =
              AgentDomainEntity.agentMessage(
                    id: 'obs-3',
                    agentId: agentId,
                    threadId: threadId,
                    kind: AgentMessageKind.observation,
                    createdAt: DateTime(2024, 6, 15, 9),
                    vectorClock: null,
                    metadata: const AgentMessageMetadata(runKey: runKey),
                  )
                  as AgentMessageEntity;

          final message = await executeAndCaptureMessage(observations: [obs]);

          expect(message, isNotNull);
          expect(message, contains('(no content)'));
        },
      );

      test(
        'includes linked tasks and uses linked task-agent report instead of summary',
        () async {
          final linkedReport =
              AgentDomainEntity.agentReport(
                    id: 'linked-report-1',
                    agentId: 'linked-agent-1',
                    scope: 'current',
                    createdAt: DateTime(2024, 6, 14, 8),
                    vectorClock: null,
                    oneLiner: 'Linked task is on track.',
                    tldr: 'Linked task TLDR: integration nearly done.',
                    content: '## Linked Agent Report\nFrom task agent.',
                  )
                  as AgentReportEntity;
          final link = AgentLink.agentTask(
            id: 'link-1',
            fromId: 'linked-agent-1',
            toId: 't2',
            createdAt: DateTime(2024, 6, 14),
            updatedAt: DateTime(2024, 6, 14),
            vectorClock: null,
          );
          when(
            () => mockAgentRepository.getLinksTo('t2', type: 'agent_task'),
          ).thenAnswer((_) async => [link]);
          when(
            () => mockAgentRepository.getLatestReport(
              'linked-agent-1',
              'current',
            ),
          ).thenAnswer((_) async => linkedReport);

          final message = await executeAndCaptureMessage(
            linkedTasksJson:
                '{"linked":[{"id":"t2","title":"Related",'
                '"latestSummary":"Legacy summary"}]}',
          );

          expect(message, isNotNull);
          expect(message, contains('## Linked Tasks'));
          expect(message, contains('Related'));
          expect(message, contains('latestTaskAgentReportTldr'));
          // Compact summary is embedded…
          expect(
            message,
            contains('Linked task TLDR: integration nearly done.'),
          );
          expect(message, contains('Linked task is on track.'));
          // …but the full report body is trimmed out to save prefill.
          expect(message, isNot(contains('From task agent.')));
          expect(message, isNot(contains('latestSummary')));
        },
      );

      test(
        'uses link id as deterministic tie-breaker for equal createdAt',
        () async {
          final now = DateTime(2024, 6, 14, 8);
          final linkB = AgentLink.agentTask(
            id: 'link-b',
            fromId: 'linked-agent-b',
            toId: 't2',
            createdAt: now,
            updatedAt: now,
            vectorClock: null,
          );
          final linkA = AgentLink.agentTask(
            id: 'link-a',
            fromId: 'linked-agent-a',
            toId: 't2',
            createdAt: now,
            updatedAt: now,
            vectorClock: null,
          );
          when(
            () => mockAgentRepository.getLinksTo('t2', type: 'agent_task'),
          ).thenAnswer((_) async => [linkB, linkA]);

          // With descending tie-breaking on ID, 'link-b' sorts before
          // 'link-a' in `orderedPrimaryFirst`, so the workflow picks
          // 'linked-agent-b's report when both exist with non-empty
          // content. Stub both reports; the assertion below verifies
          // that the workflow's deterministic tie-break still picks B.
          final reportB =
              AgentDomainEntity.agentReport(
                    id: 'linked-report-b',
                    agentId: 'linked-agent-b',
                    scope: 'current',
                    createdAt: now,
                    vectorClock: null,
                    tldr: 'Report B summary',
                    content: 'report-b',
                  )
                  as AgentReportEntity;
          final reportA =
              AgentDomainEntity.agentReport(
                    id: 'linked-report-a',
                    agentId: 'linked-agent-a',
                    scope: 'current',
                    createdAt: now,
                    vectorClock: null,
                    tldr: 'Report A summary',
                    content: 'report-a',
                  )
                  as AgentReportEntity;
          when(
            () => mockAgentRepository.getLatestReport(
              'linked-agent-b',
              'current',
            ),
          ).thenAnswer((_) async => reportB);
          when(
            () => mockAgentRepository.getLatestReport(
              'linked-agent-a',
              'current',
            ),
          ).thenAnswer((_) async => reportA);

          final message = await executeAndCaptureMessage(
            linkedTasksJson: '{"linked":[{"id":"t2","title":"Related"}]}',
          );

          // The 2026-05-12 N+1 rewrite moved from a per-link
          // `Future.wait(getLatestReport)` (which short-circuited on
          // the first non-empty report) to a bulk
          // `getLatestReportsByAgentIds` fetch followed by an
          // in-memory walk of the sorted links. Correctness contract
          // is the same — the first link in `orderedPrimaryFirst`
          // order whose report has non-empty content wins. Reports are
          // now embedded as their compact tldr (not the full body), so
          // the tie-break is asserted via the rendered summary:
          // report B's tldr must show up, report A's must NOT.
          expect(message, isNotNull);
          expect(message, contains('Report B summary'));
          expect(message, isNot(contains('Report A summary')));
        },
      );

      test(
        'falls back to empty linked-task context when build throws',
        () async {
          final message = await executeAndCaptureMessage(
            linkedTasksJson:
                '{"linked":[{"id":"t2","title":"Related",'
                '"latestSummary":"Legacy summary"}]}',
            throwOnLinkedContextBuild: true,
          );

          expect(message, isNotNull);
          expect(message, isNot(contains('## Linked Tasks')));
        },
      );

      test(
        'tolerates a failing batch agent_task link lookup',
        () async {
          // getLinksToMultiple throwing must be caught: the linked-task
          // section still renders (the rows themselves came from the JSON),
          // but no per-task agent report is injected.
          when(
            () => mockAgentRepository.getLinksToMultiple(
              any(),
              type: any(named: 'type'),
            ),
          ).thenThrow(Exception('link batch failed'));

          final message = await executeAndCaptureMessage(
            linkedTasksJson: '{"linked":[{"id":"t2","title":"Related"}]}',
          );

          expect(message, isNotNull);
          // The section renders from the linked rows themselves.
          expect(message, contains('## Linked Tasks'));
          expect(message, contains('Related'));
          // No report enrichment happened because the lookup failed.
          expect(message, isNot(contains('latestTaskAgentReportTldr')));
        },
      );

      test(
        'tolerates a failing batch agent report lookup',
        () async {
          // Links resolve, so linkedAgentIds is non-empty and the report
          // batch fetch runs — but getLatestReportsByAgentIds throws. The
          // catch must swallow it: the section renders without a report.
          final link = AgentLink.agentTask(
            id: 'link-1',
            fromId: 'linked-agent-1',
            toId: 't2',
            createdAt: DateTime(2024, 6, 14),
            updatedAt: DateTime(2024, 6, 14),
            vectorClock: null,
          );
          when(
            () => mockAgentRepository.getLinksToMultiple(
              any(),
              type: any(named: 'type'),
            ),
          ).thenAnswer(
            (_) async => {
              't2': [link],
            },
          );
          when(
            () => mockAgentRepository.getLatestReportsByAgentIds(
              any(),
              any(),
            ),
          ).thenThrow(Exception('report batch failed'));

          final message = await executeAndCaptureMessage(
            linkedTasksJson: '{"linked":[{"id":"t2","title":"Related"}]}',
          );

          expect(message, isNotNull);
          expect(message, contains('## Linked Tasks'));
          expect(message, contains('Related'));
          // The report lookup failed, so no tldr is injected.
          expect(message, isNot(contains('latestTaskAgentReportTldr')));
        },
      );

      test('omits linked tasks section when empty', () async {
        final message = await executeAndCaptureMessage();

        expect(message, isNotNull);
        expect(message, isNot(contains('## Linked Tasks')));
      });

      test('omits parent project context section when empty', () async {
        final message = await executeAndCaptureMessage();

        expect(message, isNotNull);
        expect(message, isNot(contains('## Parent Project Context')));
      });

      test('omits related tasks section when empty', () async {
        final message = await executeAndCaptureMessage();

        expect(message, isNotNull);
        expect(message, isNot(contains('## Related Tasks In This Project')));
      });

      test('includes trigger tokens when non-empty', () async {
        final message = await executeAndCaptureMessage(
          triggerTokens: {'entity-x', 'entity-y'},
        );

        expect(message, isNotNull);
        expect(message, contains('## Changed Since Last Wake'));
        expect(message, contains('entity-x'));
        expect(message, contains('entity-y'));
      });

      test(
        'omits Active Running Timer section when no timer is active',
        () async {
          final message = await executeAndCaptureMessage();

          expect(message, isNotNull);
          expect(message, isNot(contains('## Active Running Timer')));
        },
      );

      test(
        'omits Editable Time Entries section when no entries exist',
        () async {
          final message = await executeAndCaptureMessage();

          expect(message, isNotNull);
          expect(message, isNot(contains('## Editable Time Entries')));
        },
      );

      test(
        'includes linked JournalEntry rows in Editable Time Entries newest '
        'first',
        () async {
          final older = _makeLinkedTimeEntry(
            id: 'entry-older',
            dateFrom: DateTime(2024, 6, 14, 9),
            dateTo: DateTime(2024, 6, 14, 10),
            text: 'Older workshop notes',
          );
          final newer = _makeLinkedTimeEntry(
            id: 'entry-newer',
            dateFrom: DateTime(2024, 6, 15, 13),
            dateTo: DateTime(2024, 6, 15, 14, 30),
            text: 'Newer planning notes',
          );
          when(
            () => mockJournalDb.getLinkedEntities(taskId),
          ).thenAnswer((_) async => [older, _makeTask('linked-task'), newer]);

          final message = await executeAndCaptureMessage();

          expect(message, isNotNull);
          expect(message, contains('## Editable Time Entries'));
          expect(message, contains('Only pass an `entryId` listed here'));
          expect(message, contains('id: entry-newer'));
          expect(message, contains('dateFrom: 2024-06-15T13:00:00.000'));
          expect(message, contains('"Newer planning notes"'));
          expect(message, contains('id: entry-older'));
          expect(
            message!.indexOf('id: entry-newer'),
            lessThan(message.indexOf('id: entry-older')),
          );
          expect(message, isNot(contains('id: linked-task')));
        },
      );

      test(
        'lists every linked JournalEntry in Editable Time Entries',
        () async {
          final entries = List.generate(21, (index) {
            final id = index.toString().padLeft(2, '0');
            return _makeLinkedTimeEntry(
              id: 'entry-$id',
              dateFrom: DateTime(2024, 6, 15, index),
              dateTo: DateTime(2024, 6, 15, index, 30),
              text: 'Entry $id notes',
            );
          });
          when(
            () => mockJournalDb.getLinkedEntities(taskId),
          ).thenAnswer((_) async => entries);

          final message = await executeAndCaptureMessage();

          expect(message, isNotNull);
          expect('- id:'.allMatches(message!).length, 21);
          expect(message, contains('id: entry-20'));
          expect(message, contains('id: entry-00'));
          expect(
            message.indexOf('id: entry-20'),
            lessThan(message.indexOf('id: entry-00')),
          );
        },
      );

      test('includes full editable time entry text', () async {
        final longText = 'x' * 205;
        when(
          () => mockJournalDb.getLinkedEntities(taskId),
        ).thenAnswer(
          (_) async => [
            _makeLinkedTimeEntry(
              id: 'entry-long',
              dateFrom: DateTime(2024, 6, 14, 9),
              dateTo: DateTime(2024, 6, 14, 10),
              text: longText,
            ),
          ],
        );

        final message = await executeAndCaptureMessage();

        expect(message, isNotNull);
        expect(message, contains('id: entry-long'));
        expect(message, contains(jsonEncode(longText)));
      });

      test(
        'omits Editable Time Entries section when linked entry lookup fails',
        () async {
          when(
            () => mockJournalDb.getLinkedEntities(taskId),
          ).thenThrow(Exception('linked entries failed'));

          final message = await executeAndCaptureMessage();

          expect(message, isNotNull);
          expect(message, isNot(contains('## Editable Time Entries')));
        },
      );

      test(
        'includes full Active Running Timer details when timer is for THIS '
        'task',
        () async {
          final timeService = getIt<TimeService>();
          final task = Task(
            meta: Metadata(
              id: taskId,
              dateFrom: DateTime(2024, 6),
              dateTo: DateTime(2024, 6),
              createdAt: DateTime(2024, 6),
              updatedAt: DateTime(2024, 6),
            ),
            data: TaskData(
              status: TaskStatus.open(
                id: taskId,
                createdAt: DateTime(2024, 6),
                utcOffset: 0,
              ),
              dateFrom: DateTime(2024, 6),
              dateTo: DateTime(2024, 6),
              statusHistory: [],
              title: 'Active task',
            ),
          );
          final timerEntry = JournalEntry(
            meta: Metadata(
              id: 'timer-entry-007',
              dateFrom: DateTime(2024, 6, 14, 10),
              dateTo: DateTime(2024, 6, 14, 10, 5),
              createdAt: DateTime(2024, 6, 14, 10),
              updatedAt: DateTime(2024, 6, 14, 10),
            ),
            entryText: const EntryText(plainText: 'wip notes'),
          );
          await timeService.start(timerEntry, task);
          addTearDown(timeService.stop);

          final message = await executeAndCaptureMessage();

          expect(message, isNotNull);
          expect(message, contains('## Active Running Timer'));
          expect(message, contains('running for THIS task'));
          expect(message, contains('timerId: timer-entry-007'));
          expect(message, contains('current text: "wip notes"'));
          expect(message, contains('update_running_timer'));
          // The end of the tracked range must be a live "now" timestamp, not
          // the stale `dateTo` carried on the in-memory entity (which
          // [TimeService] only updates on its broadcast stream, not on the
          // entity returned by [getCurrent]). The fixture's stale dateTo
          // (10:05 on a 2024 date) must not leak into the prompt.
          expect(message, isNot(contains('2024-06-14T10:05')));
        },
      );

      test('excludes the active timer from Editable Time Entries', () async {
        final timeService = getIt<TimeService>();
        final task = _makeTask(taskId);
        final running = _makeLinkedTimeEntry(
          id: 'running-entry',
          dateFrom: DateTime(2024, 6, 14, 10),
          dateTo: DateTime(2024, 6, 14, 10, 5),
          text: 'active timer text',
        );
        final historical = _makeLinkedTimeEntry(
          id: 'historical-entry',
          dateFrom: DateTime(2024, 6, 13, 10),
          dateTo: DateTime(2024, 6, 13, 11),
          text: 'past work',
        );
        await timeService.start(running, task);
        addTearDown(timeService.stop);
        when(
          () => mockJournalDb.getLinkedEntities(taskId),
        ).thenAnswer((_) async => [running, historical]);

        final message = await executeAndCaptureMessage();

        expect(message, isNotNull);
        expect(message, contains('## Editable Time Entries'));
        expect(message, contains('id: historical-entry'));
        expect('- id:'.allMatches(message!).length, 1);
      });

      test(
        'exposes only tracked range when timer belongs to a DIFFERENT task',
        () async {
          final timeService = getIt<TimeService>();
          final otherTask = Task(
            meta: Metadata(
              id: 'other-task-id',
              dateFrom: DateTime(2024, 6),
              dateTo: DateTime(2024, 6),
              createdAt: DateTime(2024, 6),
              updatedAt: DateTime(2024, 6),
            ),
            data: TaskData(
              status: TaskStatus.open(
                id: 'other-task-id',
                createdAt: DateTime(2024, 6),
                utcOffset: 0,
              ),
              dateFrom: DateTime(2024, 6),
              dateTo: DateTime(2024, 6),
              statusHistory: [],
              title: 'Other task',
            ),
          );
          final timerEntry = JournalEntry(
            meta: Metadata(
              id: 'other-timer-id',
              dateFrom: DateTime(2024, 6, 14, 9),
              dateTo: DateTime(2024, 6, 14, 9, 30),
              createdAt: DateTime(2024, 6, 14, 9),
              updatedAt: DateTime(2024, 6, 14, 9),
            ),
            entryText: const EntryText(plainText: 'secret notes'),
          );
          await timeService.start(timerEntry, otherTask);
          addTearDown(timeService.stop);

          final message = await executeAndCaptureMessage();

          expect(message, isNotNull);
          expect(message, contains('## Active Running Timer'));
          expect(message, contains('DIFFERENT task'));
          expect(message, contains('tracked elsewhere:'));
          // Detail leakage guards: no other-task identity, no timer id, no
          // entry text, and update_running_timer is unavailable for this
          // wake.
          expect(message, isNot(contains('other-task-id')));
          expect(message, isNot(contains('other-timer-id')));
          expect(message, isNot(contains('secret notes')));
          expect(message, contains('update_running_timer` is NOT available'));
          // The cross-task overlap guard relies on a live tracked-end
          // timestamp; the stale fixture `dateTo` (09:30 on a 2024 date)
          // must not appear in the prompt or the agent could under-report
          // the interval already being tracked elsewhere.
          expect(message, isNot(contains('2024-06-14T09:30')));
        },
      );

      test('omits trigger section when empty', () async {
        final message = await executeAndCaptureMessage();

        expect(message, isNotNull);
        expect(message, isNot(contains('## Changed Since Last Wake')));
      });

      test(
        'shows "(no content)" for observation with empty string text payload',
        () async {
          final obs =
              AgentDomainEntity.agentMessage(
                    id: 'obs-empty',
                    agentId: agentId,
                    threadId: threadId,
                    kind: AgentMessageKind.observation,
                    createdAt: DateTime(2024, 6, 15, 9),
                    vectorClock: null,
                    contentEntryId: 'payload-empty-text',
                    metadata: const AgentMessageMetadata(runKey: runKey),
                  )
                  as AgentMessageEntity;

          final payload = AgentDomainEntity.agentMessagePayload(
            id: 'payload-empty-text',
            agentId: agentId,
            createdAt: DateTime(2024, 6, 15, 9),
            vectorClock: null,
            content: <String, Object?>{'text': ''},
          );

          when(
            () => mockAgentRepository.getEntity('payload-empty-text'),
          ).thenAnswer((_) async => payload);

          final message = await executeAndCaptureMessage(observations: [obs]);

          expect(message, isNotNull);
          expect(message, contains('(no content)'));
        },
      );

      test(
        'shows "(no content)" for observation with non-string text payload',
        () async {
          final obs =
              AgentDomainEntity.agentMessage(
                    id: 'obs-wrong-type',
                    agentId: agentId,
                    threadId: threadId,
                    kind: AgentMessageKind.observation,
                    createdAt: DateTime(2024, 6, 15, 9),
                    vectorClock: null,
                    contentEntryId: 'payload-wrong-type',
                    metadata: const AgentMessageMetadata(runKey: runKey),
                  )
                  as AgentMessageEntity;

          final payload = AgentDomainEntity.agentMessagePayload(
            id: 'payload-wrong-type',
            agentId: agentId,
            createdAt: DateTime(2024, 6, 15, 9),
            vectorClock: null,
            content: <String, Object?>{'text': 42},
          );

          when(
            () => mockAgentRepository.getEntity('payload-wrong-type'),
          ).thenAnswer((_) async => payload);

          final message = await executeAndCaptureMessage(observations: [obs]);

          expect(message, isNotNull);
          expect(message, contains('(no content)'));
        },
      );

      group('proposal ledger', () {
        LedgerEntry openEntry({
          required String toolName,
          required Map<String, dynamic> args,
          required String humanSummary,
          DateTime? createdAt,
        }) {
          return LedgerEntry(
            changeSetId: 'cs-${toolName.hashCode}',
            itemIndex: 0,
            toolName: toolName,
            args: args,
            humanSummary: humanSummary,
            fingerprint: ChangeItem.fingerprintFromParts(toolName, args),
            status: ChangeItemStatus.pending,
            createdAt: createdAt ?? DateTime(2024, 6, 15, 10),
          );
        }

        LedgerEntry resolvedEntry({
          required String toolName,
          required Map<String, dynamic> args,
          required String humanSummary,
          required ChangeItemStatus status,
          required ChangeDecisionVerdict verdict,
          DecisionActor? resolvedBy = DecisionActor.user,
          String? reason,
        }) {
          return LedgerEntry(
            changeSetId: 'cs-${toolName.hashCode}',
            itemIndex: 0,
            toolName: toolName,
            args: args,
            humanSummary: humanSummary,
            fingerprint: ChangeItem.fingerprintFromParts(toolName, args),
            status: status,
            createdAt: DateTime(2024, 6, 15, 10),
            resolvedAt: DateTime(2024, 6, 15, 11),
            resolvedBy: resolvedBy,
            verdict: verdict,
            reason: reason,
          );
        }

        void stubLedger(ProposalLedger ledger) {
          when(
            () => mockAgentRepository.getProposalLedger(
              any(),
              taskId: any(named: 'taskId'),
              changeSetFetchLimit: any(named: 'changeSetFetchLimit'),
              resolvedLimit: any(named: 'resolvedLimit'),
            ),
          ).thenAnswer((_) async => ledger);
        }

        test(
          'renders a single ## Proposal Ledger section with fingerprints',
          () async {
            stubLedger(
              ProposalLedger(
                open: [
                  openEntry(
                    toolName: 'set_task_title',
                    args: const {'title': 'New Title'},
                    humanSummary: 'Rename task to "New Title"',
                  ),
                ],
                resolved: const [],
              ),
            );

            final message = await executeAndCaptureMessage();

            expect(message, isNotNull);
            expect(message, contains('## Proposal Ledger'));
            // The unified section replaces the legacy split.
            expect(message, isNot(contains('## Recent User Decisions')));
            expect(message, isNot(contains('## Pending Proposals')));
            // Open items carry a fingerprint so the agent can retract them.
            final expectedFingerprint = ChangeItem.fingerprintFromParts(
              'set_task_title',
              const {'title': 'New Title'},
            );
            expect(message, contains('[fp=$expectedFingerprint]'));
            expect(
              message,
              contains('`set_task_title`: Rename task to "New Title"'),
            );
            expect(message, contains('### Open (1)'));
          },
        );

        test(
          'omits the Proposal Ledger section when the ledger is empty',
          () async {
            // Default stub is an empty ledger; do not override.
            final message = await executeAndCaptureMessage();

            expect(message, isNotNull);
            expect(message, isNot(contains('## Proposal Ledger')));
          },
        );

        test(
          'renders resolved entries with verdict icon, actor, and reason',
          () async {
            stubLedger(
              ProposalLedger(
                open: const [],
                resolved: [
                  resolvedEntry(
                    toolName: 'set_task_title',
                    args: const {'title': 'Done'},
                    humanSummary: 'Rename task to "Done"',
                    status: ChangeItemStatus.confirmed,
                    verdict: ChangeDecisionVerdict.confirmed,
                  ),
                  resolvedEntry(
                    toolName: 'update_task_estimate',
                    args: const {'estimate': '2h'},
                    humanSummary: 'Set estimate to 2 hours',
                    status: ChangeItemStatus.rejected,
                    verdict: ChangeDecisionVerdict.rejected,
                    reason: 'Too high',
                  ),
                  resolvedEntry(
                    toolName: 'update_task_priority',
                    args: const {'priority': 'P1'},
                    humanSummary: 'Set priority to P1',
                    status: ChangeItemStatus.retracted,
                    verdict: ChangeDecisionVerdict.retracted,
                    resolvedBy: DecisionActor.agent,
                    reason: 'Already P1',
                  ),
                ],
              ),
            );

            final message = await executeAndCaptureMessage();

            expect(message, isNotNull);
            expect(message, contains('### Resolved (3, most recent)'));
            // Confirmed by user
            expect(message, contains('\u2713 `set_task_title`'));
            expect(message, contains('by user'));
            // Rejected with reason
            expect(message, contains('\u2717 `update_task_estimate`'));
            expect(message, contains('(reason: "Too high")'));
            // Retracted by agent with its own reason
            expect(message, contains('\u21ba `update_task_priority`'));
            expect(message, contains('by agent'));
            expect(message, contains('(reason: "Already P1")'));
          },
        );

        test(
          'renders resolved entry with null verdict/actor using status '
          'fallback and circle icon',
          () async {
            // A resolved entry with no verdict and no actor: the formatter
            // must fall back to the status name for the label, the ○ circle
            // icon for the missing verdict, and an empty actor suffix (no
            // " by user"/" by agent").
            stubLedger(
              ProposalLedger(
                open: const [],
                resolved: [
                  LedgerEntry(
                    changeSetId: 'cs-stale',
                    itemIndex: 0,
                    toolName: 'set_task_title',
                    args: const {'title': 'Stale'},
                    humanSummary: 'Rename task to "Stale"',
                    fingerprint: ChangeItem.fingerprintFromParts(
                      'set_task_title',
                      const {'title': 'Stale'},
                    ),
                    status: ChangeItemStatus.deferred,
                    createdAt: DateTime(2024, 6, 15, 10),
                    resolvedAt: DateTime(2024, 6, 15, 11),
                    // verdict and resolvedBy intentionally left null.
                  ),
                ],
              ),
            );

            final message = await executeAndCaptureMessage();

            expect(message, isNotNull);
            expect(message, contains('### Resolved (1, most recent)'));
            // Circle icon for the null verdict branch.
            expect(message, contains('○ `set_task_title`'));
            // Verdict label falls back to the status name.
            expect(message, contains('— deferred'));
            // No actor suffix is appended for a null resolvedBy.
            expect(message, isNot(contains('deferred by user')));
            expect(message, isNot(contains('deferred by agent')));
          },
        );

        test(
          'renders both open and resolved groups side by side',
          () async {
            stubLedger(
              ProposalLedger(
                open: [
                  openEntry(
                    toolName: 'add_checklist_item',
                    args: const {'text': 'Still waiting'},
                    humanSummary: 'Add checklist item: "Still waiting"',
                  ),
                ],
                resolved: [
                  resolvedEntry(
                    toolName: 'set_task_title',
                    args: const {'title': 'Already Done'},
                    humanSummary: 'Rename task to "Already Done"',
                    status: ChangeItemStatus.confirmed,
                    verdict: ChangeDecisionVerdict.confirmed,
                  ),
                ],
              ),
            );

            final message = await executeAndCaptureMessage();

            expect(message, isNotNull);
            expect(message, contains('### Open (1)'));
            expect(message, contains('Add checklist item: "Still waiting"'));
            expect(message, contains('### Resolved (1, most recent)'));
            expect(message, contains('Rename task to "Already Done"'));
          },
        );

        test(
          'Open group shows "(none)" when there are no open entries',
          () async {
            stubLedger(
              ProposalLedger(
                open: const [],
                resolved: [
                  resolvedEntry(
                    toolName: 'set_task_title',
                    args: const {'title': 'x'},
                    humanSummary: 'Rename task',
                    status: ChangeItemStatus.confirmed,
                    verdict: ChangeDecisionVerdict.confirmed,
                  ),
                ],
              ),
            );

            final message = await executeAndCaptureMessage();

            expect(message, isNotNull);
            expect(message, contains('### Open (0)'));
            expect(message, contains('- (none)'));
          },
        );
      });

      test('caps observations to 20 most recent', () async {
        // Create 25 observations ordered newest-first (as the DB returns).
        final observations = List.generate(25, (i) {
          // Index 0 = newest (hour 24), index 24 = oldest (hour 0).
          final hour = 24 - i;
          return AgentDomainEntity.agentMessage(
                id: 'obs-$hour',
                agentId: agentId,
                threadId: threadId,
                kind: AgentMessageKind.observation,
                createdAt: DateTime(2024, 6, 15, hour),
                vectorClock: null,
                contentEntryId: 'pay-$hour',
                metadata: const AgentMessageMetadata(runKey: runKey),
              )
              as AgentMessageEntity;
        });

        // Stub all payloads.
        for (var i = 0; i < 25; i++) {
          when(() => mockAgentRepository.getEntity('pay-$i')).thenAnswer((
            _,
          ) async {
            return AgentDomainEntity.agentMessagePayload(
              id: 'pay-$i',
              agentId: agentId,
              createdAt: DateTime(2024, 6, 15, i),
              vectorClock: null,
              content: <String, Object?>{'text': 'Obs $i'},
            );
          });
        }

        final message = await executeAndCaptureMessage(
          observations: observations,
        );

        expect(message, isNotNull);
        // The 20 most recent (hours 5-24) should appear; oldest 5 dropped.
        expect(message, contains('Obs 5'));
        expect(message, contains('Obs 24'));
        // Oldest observations (hours 0-4) should NOT appear.
        expect(message, isNot(contains('Obs 0')));
        expect(message, isNot(contains('Obs 4')));
      });

      test('includes prior critical observations section '
          'with grievances and excellence', () async {
        final grievanceObs =
            AgentDomainEntity.agentMessage(
                  id: 'obs-grievance',
                  agentId: agentId,
                  threadId: threadId,
                  kind: AgentMessageKind.observation,
                  createdAt: DateTime(2024, 6, 14, 8),
                  vectorClock: null,
                  contentEntryId: 'pay-grievance',
                  metadata: const AgentMessageMetadata(runKey: runKey),
                )
                as AgentMessageEntity;

        final excellenceObs =
            AgentDomainEntity.agentMessage(
                  id: 'obs-excellence',
                  agentId: agentId,
                  threadId: threadId,
                  kind: AgentMessageKind.observation,
                  createdAt: DateTime(2024, 6, 14, 9),
                  vectorClock: null,
                  contentEntryId: 'pay-excellence',
                  metadata: const AgentMessageMetadata(runKey: runKey),
                )
                as AgentMessageEntity;

        final routineObs =
            AgentDomainEntity.agentMessage(
                  id: 'obs-routine',
                  agentId: agentId,
                  threadId: threadId,
                  kind: AgentMessageKind.observation,
                  createdAt: DateTime(2024, 6, 14, 10),
                  vectorClock: null,
                  contentEntryId: 'pay-routine',
                  metadata: const AgentMessageMetadata(runKey: runKey),
                )
                as AgentMessageEntity;

        when(() => mockAgentRepository.getEntity('pay-grievance')).thenAnswer((
          _,
        ) async {
          return AgentDomainEntity.agentMessagePayload(
            id: 'pay-grievance',
            agentId: agentId,
            createdAt: DateTime(2024, 6, 14, 8),
            vectorClock: null,
            content: <String, Object?>{
              'text': 'User frustrated with wrong priority',
              'priority': 'critical',
              'category': 'grievance',
            },
          );
        });

        when(() => mockAgentRepository.getEntity('pay-excellence')).thenAnswer((
          _,
        ) async {
          return AgentDomainEntity.agentMessagePayload(
            id: 'pay-excellence',
            agentId: agentId,
            createdAt: DateTime(2024, 6, 14, 9),
            vectorClock: null,
            content: <String, Object?>{
              'text': 'User praised report quality',
              'priority': 'critical',
              'category': 'excellence',
            },
          );
        });

        when(() => mockAgentRepository.getEntity('pay-routine')).thenAnswer((
          _,
        ) async {
          return AgentDomainEntity.agentMessagePayload(
            id: 'pay-routine',
            agentId: agentId,
            createdAt: DateTime(2024, 6, 14, 10),
            vectorClock: null,
            content: <String, Object?>{
              'text': 'Routine observation note',
              'priority': 'routine',
              'category': 'operational',
            },
          );
        });

        final message = await executeAndCaptureMessage(
          observations: [grievanceObs, excellenceObs, routineObs],
        );

        expect(message, isNotNull);
        // Critical section should appear.
        expect(
          message,
          contains('## Prior Critical Observations (Self-Review)'),
        );
        expect(message, contains('### Grievances'));
        expect(
          message,
          contains('User frustrated with wrong priority'),
        );
        expect(message, contains('### Excellence (keep doing this)'));
        expect(message, contains('User praised report quality'));
        // Routine observation should NOT appear in critical section.
        final criticalSection = message!.substring(
          message.indexOf('## Prior Critical Observations'),
          message.indexOf('## Agent Journal'),
        );
        expect(
          criticalSection,
          isNot(contains('Routine observation note')),
        );
        // But routine observation should appear in the journal.
        expect(message, contains('## Agent Journal'));
        expect(message, contains('Routine observation note'));
      });

      test(
        'omits critical section when no critical observations exist',
        () async {
          final routineObs =
              AgentDomainEntity.agentMessage(
                    id: 'obs-routine',
                    agentId: agentId,
                    threadId: threadId,
                    kind: AgentMessageKind.observation,
                    createdAt: DateTime(2024, 6, 14, 10),
                    vectorClock: null,
                    contentEntryId: 'pay-routine',
                    metadata: const AgentMessageMetadata(runKey: runKey),
                  )
                  as AgentMessageEntity;

          when(() => mockAgentRepository.getEntity('pay-routine')).thenAnswer((
            _,
          ) async {
            return AgentDomainEntity.agentMessagePayload(
              id: 'pay-routine',
              agentId: agentId,
              createdAt: DateTime(2024, 6, 14, 10),
              vectorClock: null,
              content: <String, Object?>{
                'text': 'Just a routine note',
                'priority': 'routine',
                'category': 'operational',
              },
            );
          });

          final message = await executeAndCaptureMessage(
            observations: [routineObs],
          );

          expect(message, isNotNull);
          expect(
            message,
            isNot(contains('Prior Critical Observations')),
          );
          expect(message, contains('## Agent Journal'));
          expect(message, contains('Just a routine note'));
        },
      );

      test('critical section appears before Agent Journal '
          'in message order', () async {
        final critObs =
            AgentDomainEntity.agentMessage(
                  id: 'obs-crit',
                  agentId: agentId,
                  threadId: threadId,
                  kind: AgentMessageKind.observation,
                  createdAt: DateTime(2024, 6, 14, 8),
                  vectorClock: null,
                  contentEntryId: 'pay-crit',
                  metadata: const AgentMessageMetadata(runKey: runKey),
                )
                as AgentMessageEntity;

        when(() => mockAgentRepository.getEntity('pay-crit')).thenAnswer((
          _,
        ) async {
          return AgentDomainEntity.agentMessagePayload(
            id: 'pay-crit',
            agentId: agentId,
            createdAt: DateTime(2024, 6, 14, 8),
            vectorClock: null,
            content: <String, Object?>{
              'text': 'Critical grievance item',
              'priority': 'critical',
              'category': 'grievance',
            },
          );
        });

        final message = await executeAndCaptureMessage(
          observations: [critObs],
        );

        expect(message, isNotNull);
        final criticalIdx = message!.indexOf('Prior Critical Observations');
        final journalIdx = message.indexOf('## Agent Journal');
        expect(criticalIdx, lessThan(journalIdx));
      });

      test('handles payload resolution errors gracefully '
          'in critical observation filtering', () async {
        final obs =
            AgentDomainEntity.agentMessage(
                  id: 'obs-err',
                  agentId: agentId,
                  threadId: threadId,
                  kind: AgentMessageKind.observation,
                  createdAt: DateTime(2024, 6, 14, 8),
                  vectorClock: null,
                  contentEntryId: 'pay-err',
                  metadata: const AgentMessageMetadata(runKey: runKey),
                )
                as AgentMessageEntity;

        when(
          () => mockAgentRepository.getEntity('pay-err'),
        ).thenThrow(Exception('DB error'));

        final message = await executeAndCaptureMessage(
          observations: [obs],
        );

        expect(message, isNotNull);
        // Should not crash; observation renders with fallback text.
        expect(message, contains('## Agent Journal'));
        expect(message, contains('(no content)'));
        // No critical section since payload resolution failed.
        expect(
          message,
          isNot(contains('Prior Critical Observations')),
        );
      });

      test(
        'treats template_improvement as grievance in critical section',
        () async {
          final obs =
              AgentDomainEntity.agentMessage(
                    id: 'obs-tmpl',
                    agentId: agentId,
                    threadId: threadId,
                    kind: AgentMessageKind.observation,
                    createdAt: DateTime(2024, 6, 14, 8),
                    vectorClock: null,
                    contentEntryId: 'pay-tmpl',
                    metadata: const AgentMessageMetadata(runKey: runKey),
                  )
                  as AgentMessageEntity;

          when(() => mockAgentRepository.getEntity('pay-tmpl')).thenAnswer((
            _,
          ) async {
            return AgentDomainEntity.agentMessagePayload(
              id: 'pay-tmpl',
              agentId: agentId,
              createdAt: DateTime(2024, 6, 14, 8),
              vectorClock: null,
              content: <String, Object?>{
                'text': 'User wants different behavior',
                'priority': 'critical',
                'category': 'template_improvement',
              },
            );
          });

          final message = await executeAndCaptureMessage(
            observations: [obs],
          );

          expect(message, isNotNull);
          expect(message, contains('### Grievances'));
          expect(
            message,
            contains('User wants different behavior'),
          );
          // Should not appear in excellence.
          expect(
            message,
            isNot(contains('### Excellence')),
          );
        },
      );

      test('skips critical observations with empty text', () async {
        final obs =
            AgentDomainEntity.agentMessage(
                  id: 'obs-empty',
                  agentId: agentId,
                  threadId: threadId,
                  kind: AgentMessageKind.observation,
                  createdAt: DateTime(2024, 6, 14, 8),
                  vectorClock: null,
                  contentEntryId: 'pay-empty',
                  metadata: const AgentMessageMetadata(runKey: runKey),
                )
                as AgentMessageEntity;

        when(() => mockAgentRepository.getEntity('pay-empty')).thenAnswer((
          _,
        ) async {
          return AgentDomainEntity.agentMessagePayload(
            id: 'pay-empty',
            agentId: agentId,
            createdAt: DateTime(2024, 6, 14, 8),
            vectorClock: null,
            content: <String, Object?>{
              'text': '',
              'priority': 'critical',
              'category': 'grievance',
            },
          );
        });

        final message = await executeAndCaptureMessage(
          observations: [obs],
        );

        expect(message, isNotNull);
        // Empty text should be skipped from critical section.
        expect(
          message,
          isNot(contains('Prior Critical Observations')),
        );
      });

      test('includes all observations when count is exactly 20', () async {
        // Create exactly 20 observations ordered newest-first.
        final observations = List.generate(20, (i) {
          final hour =
              19 - i; // Index 0 = newest (hour 19), index 19 = oldest (hour 0).
          return AgentDomainEntity.agentMessage(
                id: 'obs-exact-$hour',
                agentId: agentId,
                threadId: threadId,
                kind: AgentMessageKind.observation,
                createdAt: DateTime(2024, 6, 15, hour),
                vectorClock: null,
                contentEntryId: 'pay-exact-$hour',
                metadata: const AgentMessageMetadata(runKey: runKey),
              )
              as AgentMessageEntity;
        });

        // Stub all 20 payloads.
        for (var i = 0; i < 20; i++) {
          when(() => mockAgentRepository.getEntity('pay-exact-$i')).thenAnswer((
            _,
          ) async {
            return AgentDomainEntity.agentMessagePayload(
              id: 'pay-exact-$i',
              agentId: agentId,
              createdAt: DateTime(2024, 6, 15, i),
              vectorClock: null,
              content: <String, Object?>{'text': 'ExactObs $i'},
            );
          });
        }

        final message = await executeAndCaptureMessage(
          observations: observations,
        );

        expect(message, isNotNull);
        // All 20 observations should appear — none truncated.
        expect(message, contains('ExactObs 0'));
        expect(message, contains('ExactObs 19'));
        expect(message, contains('## Agent Journal'));
      });

      test('truncates observations to 20 when count is 21', () async {
        // Create 21 observations ordered newest-first.
        final observations = List.generate(21, (i) {
          final hour =
              20 - i; // Index 0 = newest (hour 20), index 20 = oldest (hour 0).
          return AgentDomainEntity.agentMessage(
                id: 'obs-boundary-$hour',
                agentId: agentId,
                threadId: threadId,
                kind: AgentMessageKind.observation,
                createdAt: DateTime(2024, 6, 15, hour),
                vectorClock: null,
                contentEntryId: 'pay-boundary-$hour',
                metadata: const AgentMessageMetadata(runKey: runKey),
              )
              as AgentMessageEntity;
        });

        // Stub all 21 payloads.
        for (var i = 0; i <= 20; i++) {
          when(
            () => mockAgentRepository.getEntity('pay-boundary-$i'),
          ).thenAnswer((_) async {
            return AgentDomainEntity.agentMessagePayload(
              id: 'pay-boundary-$i',
              agentId: agentId,
              createdAt: DateTime(2024, 6, 15, i),
              vectorClock: null,
              content: <String, Object?>{'text': 'BoundaryObs $i'},
            );
          });
        }

        final message = await executeAndCaptureMessage(
          observations: observations,
        );

        expect(message, isNotNull);
        // The 20 most recent (hours 1-20) should appear.
        expect(message, contains('BoundaryObs 1'));
        expect(message, contains('BoundaryObs 20'));
        // The single oldest observation (hour 0) should be truncated.
        expect(message, isNot(contains('BoundaryObs 0')));
      });

      test('filters linked tasks with null or empty IDs gracefully', () async {
        // Provide linked tasks JSON where some entries have no 'id' or an
        // empty string 'id'. The production code (lines 1333-1337) filters
        // these out via whereType<String>().where(id.isNotEmpty).
        final linkedJson = jsonEncode({
          'linked_from': [
            {'id': '', 'title': 'Empty ID Task', 'status': 'OPEN'},
            {'title': 'Null ID Task', 'status': 'OPEN'},
            {'id': 'valid-1', 'title': 'Valid Task', 'status': 'OPEN'},
          ],
          'linked_to': <Map<String, dynamic>>[],
        });
        final message = await executeAndCaptureMessage(
          linkedTasksJson: linkedJson,
        );

        expect(message, isNotNull);
        // The section should still appear because there is one valid linked task.
        expect(message, contains('## Linked Tasks'));
        expect(message, contains('Valid Task'));
        // Entries with missing/empty IDs should not cause errors — the message
        // should still include the rows (they're serialized), but no report
        // enrichment happens for them.
        expect(message, contains('Empty ID Task'));
        expect(message, contains('Null ID Task'));
        // No taskAgentId should have been injected for entries without valid IDs.
        // Valid ID entry also won't have a report since getLinksTo returns [].
        verifyNever(
          () => mockAgentRepository.getLinksTo('', type: 'agent_task'),
        );
      });
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

      test('set_task_title delegates to handler when title exists', () async {
        // Handler receives the call — the workflow no longer hard-guards
        // against existing titles (the prompt instructs the agent).
        final result = await executeWithToolCallOnRealTask(
          'set_task_title',
          '{"title":"New Title"}',
        );
        expect(result.success, isTrue);
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
      });

      // ── Deferred tool calls ──────────────────────────────────────────
      //
      // All mutating tools are now deferred to a ChangeSetBuilder rather
      // than executed immediately. The strategy responds with "Proposal
      // queued for user review." and the actual validation/execution
      // happens when the user confirms the change set.

      test('set_task_title with missing title arg is deferred', () async {
        final result = await executeWithToolCallOnRealTask(
          'set_task_title',
          '{}',
        );
        expect(result.success, isTrue);
        verifyDeferredToolResponse(mockConversationManager);
      });

      test('update_task_estimate with null minutes is deferred', () async {
        final result = await executeWithToolCallOnRealTask(
          'update_task_estimate',
          '{}',
        );
        expect(result.success, isTrue);
        verifyDeferredToolResponse(mockConversationManager);
      });

      test('update_task_due_date with empty dueDate is deferred', () async {
        final result = await executeWithToolCallOnRealTask(
          'update_task_due_date',
          '{"dueDate":""}',
        );
        expect(result.success, isTrue);
        verifyDeferredToolResponse(mockConversationManager);
      });

      test('update_task_priority with empty priority is deferred', () async {
        final result = await executeWithToolCallOnRealTask(
          'update_task_priority',
          '{"priority":""}',
        );
        expect(result.success, isTrue);
        verifyDeferredToolResponse(mockConversationManager);
      });

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
              response: any(
                named: 'response',
                that: contains('skipped'),
              ),
            ),
          ).called(1);
        },
      );

      test('update_checklist_items with missing id is deferred', () async {
        // Items with missing id are still valid Maps and get deferred.
        // Validation happens at confirmation time.
        final result = await executeWithToolCallOnRealTask(
          'update_checklist_items',
          '{"items":[{"isChecked":true}]}',
        );
        expect(result.success, isTrue);
        verifyDeferredToolResponse(mockConversationManager);
      });

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
            response: any(
              named: 'response',
              that: contains('required'),
            ),
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
            response: any(
              named: 'response',
              that: contains('non-empty array'),
            ),
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
            response: any(
              named: 'response',
              that: contains('Unknown tool'),
            ),
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

        test(
          'add_multiple_checklist_items resolves existing titles and '
          'suppresses a duplicate against them',
          () async {
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
            expect(
              responses,
              contains(contains('already exists on the task')),
            );
          },
        );

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
          const ChatCompletionMessage.assistant(
            content: 'First response',
          ),
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
          const ChatCompletionMessage.assistant(
            content: 'Non-empty response',
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

    group('WakeResult', () {
      test('success with mutated entries', () {
        const result = WakeResult(
          success: true,
          mutatedEntries: {
            'entity-1': VectorClock({'host-a': 1}),
          },
        );

        expect(result.success, isTrue);
        expect(
          result.mutatedEntries,
          {
            'entity-1': const VectorClock({'host-a': 1}),
          },
        );
        expect(result.error, isNull);
      });

      test('failure with error message', () {
        const result = WakeResult(
          success: false,
          error: 'Something went wrong',
        );

        expect(result.success, isFalse);
        expect(result.mutatedEntries, isEmpty);
        expect(result.error, 'Something went wrong');
      });

      test('defaults mutatedEntries to empty map', () {
        const result = WakeResult(success: true);

        expect(result.mutatedEntries, isEmpty);
        expect(result.error, isNull);
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

    group('input capture (ADR 0020)', () {
      test(
        'captures the rendered task sources when a capture service is wired',
        () async {
          final capture = _RecordingCaptureService();
          final linkedEntry = _makeLinkedTimeEntry(
            id: 'linked-1',
            dateFrom: DateTime(2024, 6),
            dateTo: DateTime(2024, 6),
            text: 'a captured note',
          );
          when(
            () => mockJournalDb.getLinkedEntities(taskId),
          ).thenAnswer((_) async => [linkedEntry]);

          final workflow = createTestWorkflow(
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
            inputCaptureService: capture,
          );
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
            triggerTokens: {},
            threadId: threadId,
          );

          expect(result.success, isTrue);
          expect(capture.callCount, 1);
          expect(capture.agentId, agentId);
          expect(capture.threadId, threadId);
          expect(capture.runKey, runKey);
          // The workflow rendered the linked journal entry into a source.
          expect(capture.sources.map((s) => s.contentEntryId), ['linked-1']);
          expect(capture.sources.single.content['text'], 'a captured note');
        },
      );

      test(
        'a capture failure is non-fatal — the wake still succeeds',
        () async {
          when(
            () => mockJournalDb.getLinkedEntities(taskId),
          ).thenAnswer((_) async => const []);
          final workflow = createTestWorkflow(
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
            inputCaptureService: _ThrowingCaptureService(),
          );
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
            triggerTokens: {},
            threadId: threadId,
          );

          expect(result.success, isTrue);
        },
      );
    });

    group('compaction read-flip (ADR 0017/0020)', () {
      test(
        'assembles the task log from the captured frontier and drops the '
        'inline journal log',
        () async {
          // The captured frontier holds one source; with no summary yet it is
          // the verbatim tail.
          const tailContent = {
            'entryType': 'text',
            'text': 'captured tail content',
          };
          final tailDigest = ContentDigest.of(tailContent);

          when(
            () => mockSyncService.repository,
          ).thenReturn(mockAgentRepository);
          when(
            () => mockAgentRepository.getMessagesByKind(
              agentId,
              AgentMessageKind.system,
            ),
          ).thenAnswer((_) async => []);
          when(
            () => mockAgentRepository.getMessagesByKind(
              agentId,
              AgentMessageKind.summary,
            ),
          ).thenAnswer((_) async => []);
          when(() => mockAgentRepository.getLinksFrom(agentId)).thenAnswer(
            (_) async => [
              AgentLink.messagePayload(
                id: 'pl-1',
                fromId: agentId,
                toId: tailDigest,
                createdAt: DateTime(2024, 6, 2),
                updatedAt: DateTime(2024, 6, 2),
                vectorClock: null,
                contentEntryId: 'e1',
                sourceCreatedAt: DateTime(2024, 6),
              ),
            ],
          );
          when(() => mockAgentRepository.getEntity(tailDigest)).thenAnswer(
            (_) async => AgentDomainEntity.agentMessagePayload(
              id: tailDigest,
              agentId: agentId,
              createdAt: DateTime(2024, 6, 2),
              vectorClock: null,
              content: tailContent,
            ),
          );
          when(
            () => mockAiInputRepository.buildTaskStateMarkdown(taskId),
          ).thenAnswer((_) async => '- Title: Slim header');
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

          final workflow = createTestWorkflow(
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
            // A succeeding capture service so the read-flip trusts the frontier.
            inputCaptureService: _RecordingCaptureService(),
            logSummarizer: stubLogSummarizer(),
          );

          final sentMessages = <String>[];
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
                sentMessages.add(message);
                return null;
              };

          final result = await workflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {},
            threadId: threadId,
          );

          expect(result.success, isTrue);
          verify(
            () => mockAiInputRepository.buildTaskStateMarkdown(taskId),
          ).called(1);

          // The SENT prompt carries the slim header + the assembled task log
          // (the captured tail) — proving the read-flip.
          final userText = sentMessages.first;
          expect(userText, contains('Slim header'));
          expect(userText, contains('## Task Log'));
          expect(userText, contains('captured tail content'));
          // Prefix-cache layout: the append-only task log must precede the
          // task-state JSON, whose timeSpent ticks on every working wake — a
          // single mutated byte upstream voids the cache for the whole log.
          expect(
            userText.indexOf('## Task Log'),
            lessThan(userText.indexOf('## Current Task Context')),
          );

          // The PERSISTED prompt is a v2 record: only the non-derivable
          // halves are stored — the log block itself is reconstructed from
          // the synced event log via the marker (ADR 0020).
          final captured = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;
          final record = capturedPayloadEntities(
            captured,
          ).map((p) => p.content).firstWhere((c) => c['promptFormat'] == 'v2');
          expect(record['head'], endsWith('## Task Log\n'));
          expect(
            record['tail']! as String,
            contains('## Current Task Context'),
          );
          expect(record['head'], isNot(contains('captured tail content')));
          expect(record['tail'], isNot(contains('captured tail content')));
          final marker = record['log']! as Map<String, Object?>;
          expect(marker['until'], isNotNull);
        },
      );

      test('falls back to the inline log when nothing is captured yet', () async {
        // Compaction on, but the captured frontier is empty (capture unwired or
        // failed) — the wake must keep the full journal log, not a blank header.
        when(
          () => mockSyncService.repository,
        ).thenReturn(mockAgentRepository);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.system,
          ),
        ).thenAnswer((_) async => []);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.summary,
          ),
        ).thenAnswer((_) async => []);
        when(
          () => mockAgentRepository.getLinksFrom(agentId),
        ).thenAnswer((_) async => []);
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

        final workflow = createTestWorkflow(
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
          logSummarizer: stubLogSummarizer(),
        );

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {},
          threadId: threadId,
        );

        expect(result.success, isTrue);
        // Full inline log requested; the markdown task-state variant is NOT
        // used when there's nothing to replace the inline log with.
        verify(
          () => mockAiInputRepository.buildTaskDetailsJson(id: taskId),
        ).called(1);
        verifyNever(
          () => mockAiInputRepository.buildTaskStateMarkdown(taskId),
        );
        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        final userText = capturedPayloadEntities(captured)
            .map((p) => p.content['text'] as String? ?? '')
            .firstWhere((t) => t.contains('Current Task Context'));
        expect(userText, isNot(contains('## Task Log')));
      });

      test('a capture failure falls back to the inline log even if a stale '
          'frontier exists', () async {
        // A non-empty captured frontier exists from a prior wake, but THIS
        // wake's capture throws — so the frontier may be stale and must not be
        // used; the wake keeps the full inline log.
        const tailContent = {
          'entryType': 'text',
          'text': 'stale captured content',
        };
        final tailDigest = ContentDigest.of(tailContent);
        when(
          () => mockSyncService.repository,
        ).thenReturn(mockAgentRepository);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.system,
          ),
        ).thenAnswer((_) async => []);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.summary,
          ),
        ).thenAnswer((_) async => []);
        when(() => mockAgentRepository.getLinksFrom(agentId)).thenAnswer(
          (_) async => [
            AgentLink.messagePayload(
              id: 'pl-1',
              fromId: agentId,
              toId: tailDigest,
              createdAt: DateTime(2024, 6, 2),
              updatedAt: DateTime(2024, 6, 2),
              vectorClock: null,
              contentEntryId: 'e1',
              sourceCreatedAt: DateTime(2024, 6),
            ),
          ],
        );
        when(() => mockAgentRepository.getEntity(tailDigest)).thenAnswer(
          (_) async => AgentDomainEntity.agentMessagePayload(
            id: tailDigest,
            agentId: 'shared-input-content',
            createdAt: DateTime(2024, 6, 2),
            vectorClock: null,
            content: tailContent,
          ),
        );
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

        final workflow = createTestWorkflow(
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
          inputCaptureService: _ThrowingCaptureService(),
          logSummarizer: stubLogSummarizer(),
        );

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {},
          threadId: threadId,
        );

        expect(result.success, isTrue);
        verify(
          () => mockAiInputRepository.buildTaskDetailsJson(id: taskId),
        ).called(1);
        verifyNever(
          () => mockAiInputRepository.buildTaskStateMarkdown(taskId),
        );
        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        final userText = capturedPayloadEntities(captured)
            .map((p) => p.content['text'] as String? ?? '')
            .firstWhere((t) => t.contains('Current Task Context'));
        expect(userText, isNot(contains('stale captured content')));
        expect(userText, isNot(contains('## Task Log')));
      });

      test('a failing summarizer is non-fatal: the wake still read-flips to the '
          'uncovered tail', () async {
        // budget 0 + two captured sources ⇒ compaction tries to fold the oldest
        // and calls the summarizer, which throws. Emission must be swallowed and
        // the wake must still assemble the captured (un-summarized) tail.
        const olderContent = {'entryType': 'text', 'text': 'older entry'};
        const newerContent = {'entryType': 'text', 'text': 'newer entry'};
        final olderDigest = ContentDigest.of(olderContent);
        final newerDigest = ContentDigest.of(newerContent);

        when(
          () => mockSyncService.repository,
        ).thenReturn(mockAgentRepository);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.system,
          ),
        ).thenAnswer((_) async => []);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.summary,
          ),
        ).thenAnswer((_) async => []);
        when(() => mockAgentRepository.getLinksFrom(agentId)).thenAnswer(
          (_) async => [
            AgentLink.messagePayload(
              id: 'pl-1',
              fromId: agentId,
              toId: olderDigest,
              createdAt: DateTime(2024, 6, 2),
              updatedAt: DateTime(2024, 6, 2),
              vectorClock: null,
              contentEntryId: 'e1',
              sourceCreatedAt: DateTime(2024, 6),
            ),
            AgentLink.messagePayload(
              id: 'pl-2',
              fromId: agentId,
              toId: newerDigest,
              createdAt: DateTime(2024, 6, 2),
              updatedAt: DateTime(2024, 6, 2),
              vectorClock: null,
              contentEntryId: 'e2',
              sourceCreatedAt: DateTime(2024, 6, 2),
            ),
          ],
        );
        when(() => mockAgentRepository.getEntity(olderDigest)).thenAnswer(
          (_) async => AgentDomainEntity.agentMessagePayload(
            id: olderDigest,
            agentId: 'shared-input-content',
            createdAt: DateTime(2024, 6, 2),
            vectorClock: null,
            content: olderContent,
          ),
        );
        when(() => mockAgentRepository.getEntity(newerDigest)).thenAnswer(
          (_) async => AgentDomainEntity.agentMessagePayload(
            id: newerDigest,
            agentId: 'shared-input-content',
            createdAt: DateTime(2024, 6, 2),
            vectorClock: null,
            content: newerContent,
          ),
        );
        when(
          () => mockAiInputRepository.buildTaskStateMarkdown(taskId),
        ).thenAnswer((_) async => '- Title: Slim header');
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

        final boomSummarizer = stubLogSummarizer(
          error: StateError('summarizer boom'),
        );
        final workflow = createTestWorkflow(
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
          inputCaptureService: _RecordingCaptureService(),
          compactionTailBudgetTokens: 0,
          logSummarizer: boomSummarizer,
        );

        final sentMessages = <String>[];
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
              sentMessages.add(message);
              return null;
            };

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {},
          threadId: threadId,
        );

        // The wake completes despite the summarizer throwing, and no summary was
        // persisted — so the assembled tail still carries both sources verbatim.
        expect(result.success, isTrue);
        // The summarizer was invoked with the wake's resolved provider — the
        // agent distills its own memory with the model it thinks with.
        verify(
          () => boomSummarizer.summarize(
            sources: any(named: 'sources'),
            priorSummary: any(named: 'priorSummary'),
            model: any(named: 'model'),
            provider: geminiProvider,
          ),
        ).called(1);
        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        expect(
          captured.whereType<AgentMessageEntity>().where(
            (m) => m.kind == AgentMessageKind.summary,
          ),
          isEmpty,
        );
        expect(sentMessages.first, contains('older entry'));
        expect(sentMessages.first, contains('newer entry'));
        expect(
          sentMessages.first,
          isNot(contains('Summary of earlier activity')),
        );
      });

      test('resolved verdicts render as decision events in the task log; '
          'the ledger section keeps only open proposals', () async {
        const tailContent = {'entryType': 'text', 'text': 'captured note'};
        final tailDigest = ContentDigest.of(tailContent);
        when(
          () => mockSyncService.repository,
        ).thenReturn(mockAgentRepository);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.system,
          ),
        ).thenAnswer((_) async => []);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.summary,
          ),
        ).thenAnswer((_) async => []);
        when(() => mockAgentRepository.getLinksFrom(agentId)).thenAnswer(
          (_) async => [
            AgentLink.messagePayload(
              id: 'pl-1',
              fromId: agentId,
              toId: tailDigest,
              createdAt: DateTime(2024, 6, 2),
              updatedAt: DateTime(2024, 6, 2),
              vectorClock: null,
              contentEntryId: 'e1',
              sourceCreatedAt: DateTime(2024, 6),
            ),
          ],
        );
        when(() => mockAgentRepository.getEntity(tailDigest)).thenAnswer(
          (_) async => AgentDomainEntity.agentMessagePayload(
            id: tailDigest,
            agentId: agentId,
            createdAt: DateTime(2024, 6, 2),
            vectorClock: null,
            content: tailContent,
          ),
        );
        when(
          () => mockAiInputRepository.buildTaskStateMarkdown(taskId),
        ).thenAnswer((_) async => '- Title: Slim header');
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
        // One open proposal (state — must stay in the ledger section) and one
        // resolved verdict (event — must move into the task log).
        when(
          () => mockAgentRepository.getProposalLedger(
            any(),
            taskId: any(named: 'taskId'),
            changeSetFetchLimit: any(named: 'changeSetFetchLimit'),
            resolvedLimit: any(named: 'resolvedLimit'),
          ),
        ).thenAnswer(
          (_) async => ProposalLedger(
            open: [
              LedgerEntry(
                changeSetId: 'cs-2',
                itemIndex: 0,
                toolName: 'update_task_estimate',
                args: const {},
                humanSummary: 'Estimate 2h',
                fingerprint: 'update_task_estimate:7',
                status: ChangeItemStatus.pending,
                createdAt: DateTime(2024, 6, 3),
              ),
            ],
            resolved: [
              LedgerEntry(
                changeSetId: 'cs-1',
                itemIndex: 0,
                toolName: 'set_task_title',
                args: const {},
                humanSummary: 'Set title to "X"',
                fingerprint: 'set_task_title:42',
                status: ChangeItemStatus.confirmed,
                createdAt: DateTime(2024, 6),
                resolvedAt: DateTime(2024, 6, 1, 12),
                resolvedBy: DecisionActor.user,
                verdict: ChangeDecisionVerdict.confirmed,
              ),
            ],
          ),
        );

        final workflow = createTestWorkflow(
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
          inputCaptureService: _RecordingCaptureService(),
          logSummarizer: stubLogSummarizer(),
        );

        final sentMessages = <String>[];
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
              sentMessages.add(message);
              return null;
            };

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {},
          threadId: threadId,
        );
        expect(result.success, isTrue);

        final userText = sentMessages.first;

        // The verdict is an event in the task log…
        expect(userText, contains('## Task Log'));
        expect(
          userText,
          contains(
            '(id: cs-1:0, decision) [fp=set_task_title:42] '
            '✓ `set_task_title`: '
            'Set title to "X" — confirmed by user',
          ),
        );
        // …interleaved chronologically: verdict (June 1) before note (June 2).
        expect(
          userText.indexOf('(id: cs-1:0, decision)'),
          lessThan(userText.indexOf('captured note')),
        );
        // The ledger section keeps only the open (actionable) state.
        expect(userText, contains('### Open (1)'));
        expect(userText, contains('[fp=update_task_estimate:7]'));
        expect(userText, isNot(contains('### Resolved')));
      });

      test('a throwing assembleContext degrades to the legacy inline log '
          'instead of killing the wake', () async {
        when(
          () => mockSyncService.repository,
        ).thenReturn(mockAgentRepository);
        // The compactor's projection read throws (both maybeCompact and
        // assembleContext hit this; each is independently caught).
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.system,
          ),
        ).thenAnswer(
          (_) => Future<List<AgentMessageEntity>>.error(
            Exception('projection read failed'),
          ),
        );
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

        final workflow = createTestWorkflow(
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
          inputCaptureService: _RecordingCaptureService(),
          logSummarizer: stubLogSummarizer(),
        );

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {},
          threadId: threadId,
        );

        expect(result.success, isTrue);
        verify(
          () => mockAiInputRepository.buildTaskDetailsJson(id: taskId),
        ).called(1);
        verifyNever(
          () => mockAiInputRepository.buildTaskStateMarkdown(taskId),
        );
      });

      test('a saturated resolved-decision window logs loudly and the wake '
          'still renders the full legacy ledger', () async {
        final saturated = ProposalLedger(
          open: const [],
          resolved: List.generate(
            TaskAgentWorkflow.resolvedDecisionWindow,
            (i) => LedgerEntry(
              changeSetId: 'cs-$i',
              itemIndex: 0,
              toolName: 'set_task_title',
              args: const {},
              humanSummary: 'Proposal $i',
              fingerprint: 'set_task_title:$i',
              status: ChangeItemStatus.confirmed,
              createdAt: DateTime(2024, 6),
              resolvedAt: DateTime(2024, 6, 1, 12),
              resolvedBy: DecisionActor.user,
              verdict: ChangeDecisionVerdict.confirmed,
            ),
          ),
        );
        when(
          () => mockAgentRepository.getProposalLedger(
            any(),
            taskId: any(named: 'taskId'),
            changeSetFetchLimit: any(named: 'changeSetFetchLimit'),
            resolvedLimit: any(named: 'resolvedLimit'),
          ),
        ).thenAnswer((_) async => saturated);
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
          triggerTokens: {},
          threadId: threadId,
        );

        expect(result.success, isTrue);
        // Legacy mode renders the full resolved listing — proving the
        // saturated ledger flowed through unharmed.
        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        final userText = capturedPayloadEntities(captured)
            .map((p) => p.content['text'] as String? ?? '')
            .firstWhere((t) => t.contains('Current Task Context'));
        expect(
          userText,
          contains(
            '### Resolved (${TaskAgentWorkflow.resolvedDecisionWindow}, '
            'most recent)',
          ),
        );
      });

      test('the full prompt is append-only across wakes: identical bytes '
          'before the task log, appends inside it', () async {
        // The provider prefix-cache invariant at the PROMPT level: when a new
        // event lands between two wakes, everything upstream of the task log
        // is byte-identical and the log block itself only grows at the end.
        // The volatile tail (task state, timer, ledger…) follows the log.
        const firstContent = {'entryType': 'text', 'text': 'first note'};
        const secondContent = {'entryType': 'text', 'text': 'second note'};
        final firstDigest = ContentDigest.of(firstContent);
        final secondDigest = ContentDigest.of(secondContent);

        when(
          () => mockSyncService.repository,
        ).thenReturn(mockAgentRepository);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.system,
          ),
        ).thenAnswer((_) async => []);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.summary,
          ),
        ).thenAnswer((_) async => []);
        final links = <AgentLink>[
          AgentLink.messagePayload(
            id: 'pl-1',
            fromId: agentId,
            toId: firstDigest,
            createdAt: DateTime(2024, 6, 2),
            updatedAt: DateTime(2024, 6, 2),
            vectorClock: null,
            contentEntryId: 'e1',
            sourceCreatedAt: DateTime(2024, 6),
          ),
        ];
        when(
          () => mockAgentRepository.getLinksFrom(agentId),
        ).thenAnswer((_) async => List.of(links));
        when(() => mockAgentRepository.getEntity(firstDigest)).thenAnswer(
          (_) async => AgentDomainEntity.agentMessagePayload(
            id: firstDigest,
            agentId: agentId,
            createdAt: DateTime(2024, 6, 2),
            vectorClock: null,
            content: firstContent,
          ),
        );
        when(() => mockAgentRepository.getEntity(secondDigest)).thenAnswer(
          (_) async => AgentDomainEntity.agentMessagePayload(
            id: secondDigest,
            agentId: agentId,
            createdAt: DateTime(2024, 6, 3),
            vectorClock: null,
            content: secondContent,
          ),
        );
        when(
          () => mockAiInputRepository.buildTaskStateMarkdown(taskId),
        ).thenAnswer((_) async => '- Title: Slim header');
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

        final workflow = createTestWorkflow(
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
          inputCaptureService: _RecordingCaptureService(),
          logSummarizer: stubLogSummarizer(),
        );

        final sentMessages = <String>[];
        // Each wake sends the prompt plus a forced-report retry.
        mockConversationRepository
          ..maxDelegateCalls = 4
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
                sentMessages.add(message);
                return null;
              };

        final firstResult = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {},
          threadId: threadId,
        );
        expect(firstResult.success, isTrue);
        // Filter out forced-report retry messages — only wake prompts.
        String lastPrompt() =>
            sentMessages.lastWhere((m) => m.contains('## Task Log'));
        final firstPrompt = lastPrompt();

        // A new event lands between the wakes.
        links.add(
          AgentLink.messagePayload(
            id: 'pl-2',
            fromId: agentId,
            toId: secondDigest,
            createdAt: DateTime(2024, 6, 3),
            updatedAt: DateTime(2024, 6, 3),
            vectorClock: null,
            contentEntryId: 'e2',
            sourceCreatedAt: DateTime(2024, 6, 3),
          ),
        );

        final secondResult = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: 'run-key-2',
          triggerTokens: {},
          threadId: threadId,
        );
        expect(secondResult.success, isTrue);
        final secondPrompt = lastPrompt();

        // Everything before the task log is byte-identical across the wakes…
        String head(String s) => s.substring(0, s.indexOf('## Task Log'));
        expect(head(secondPrompt), head(firstPrompt));
        // …and the log block itself only appends (modulo the trailing section
        // separator).
        String logBlock(String s) => s
            .substring(
              s.indexOf('## Task Log'),
              s.indexOf('## Current Task Context'),
            )
            .trimRight();
        expect(logBlock(secondPrompt), startsWith(logBlock(firstPrompt)));
        expect(logBlock(secondPrompt), contains('second note'));
      });
    });
  });
}

/// Records [AgentInputCaptureService.captureWakeInputs] calls so the wiring test
/// can assert what the workflow captured, without a real log.
class _RecordingCaptureService implements AgentInputCaptureService {
  int callCount = 0;
  String? agentId;
  List<RenderedSource> sources = const [];
  DateTime? at;
  String? threadId;
  String? runKey;

  @override
  Future<CaptureDelta> captureWakeInputs({
    required String agentId,
    required List<RenderedSource> sources,
    required DateTime at,
    String? threadId,
    String? runKey,
    List<AgentMessageEntity>? systemMessages,
    List<AgentLink>? links,
  }) async {
    callCount++;
    this.agentId = agentId;
    this.sources = sources;
    this.at = at;
    this.threadId = threadId;
    this.runKey = runKey;
    return const CaptureDelta(
      newPayloads: [],
      newReferences: [],
      retractedEntryIds: [],
    );
  }
}

/// A capture service that always throws, to prove the workflow treats capture
/// as non-fatal (the wake completes anyway).
class _ThrowingCaptureService implements AgentInputCaptureService {
  @override
  Future<CaptureDelta> captureWakeInputs({
    required String agentId,
    required List<RenderedSource> sources,
    required DateTime at,
    String? threadId,
    String? runKey,
    List<AgentMessageEntity>? systemMessages,
    List<AgentLink>? links,
  }) async {
    throw StateError('capture boom');
  }
}

Task _makeTask(String id) {
  return Task(
    meta: Metadata(
      id: id,
      dateFrom: DateTime(2024, 6),
      dateTo: DateTime(2024, 6),
      createdAt: DateTime(2024, 6),
      updatedAt: DateTime(2024, 6),
    ),
    data: TaskData(
      status: TaskStatus.open(
        id: id,
        createdAt: DateTime(2024, 6),
        utcOffset: 0,
      ),
      dateFrom: DateTime(2024, 6),
      dateTo: DateTime(2024, 6),
      statusHistory: [],
      title: 'Linked task',
    ),
  );
}

JournalEntry _makeLinkedTimeEntry({
  required String id,
  required DateTime dateFrom,
  required DateTime dateTo,
  required String text,
}) {
  return JournalEntry(
    meta: Metadata(
      id: id,
      dateFrom: dateFrom,
      dateTo: dateTo,
      createdAt: dateFrom,
      updatedAt: dateFrom,
    ),
    entryText: EntryText(plainText: text),
  );
}
