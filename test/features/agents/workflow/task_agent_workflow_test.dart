import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/workflow/task_agent_strategy.dart';
import 'package:lotti/features/agents/workflow/task_agent_workflow.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

/// Minimal mock of [ConversationRepository] that avoids Riverpod build().
///
/// ConversationRepository is a Riverpod notifier, so we extend it directly and
/// override the methods the workflow calls rather than using `Mock`.
class MockConversationRepository extends ConversationRepository {
  MockConversationRepository(this._mockManager);

  final MockConversationManager _mockManager;
  final List<String> deletedConversationIds = [];

  /// Delegate for sendMessage — set in tests to control behavior.
  Future<InferenceUsage?> Function({
    required String conversationId,
    required String message,
    required String model,
    required AiConfigInferenceProvider provider,
    required InferenceRepositoryInterface inferenceRepo,
    List<ChatCompletionTool>? tools,
    double temperature,
    ConversationStrategy? strategy,
  })? sendMessageDelegate;

  @override
  void build() {
    // No-op for test mock.
  }

  @override
  String createConversation({
    String? systemMessage,
    int maxTurns = 20,
  }) {
    return 'test-conv-id';
  }

  @override
  ConversationManager? getConversation(String conversationId) {
    return _mockManager;
  }

  @override
  void deleteConversation(String conversationId) {
    deletedConversationIds.add(conversationId);
  }

  @override
  Future<InferenceUsage?> sendMessage({
    required String conversationId,
    required String message,
    required String model,
    required AiConfigInferenceProvider provider,
    required InferenceRepositoryInterface inferenceRepo,
    List<ChatCompletionTool>? tools,
    double temperature = 0.7,
    ConversationStrategy? strategy,
  }) async {
    if (sendMessageDelegate != null) {
      return sendMessageDelegate!(
        conversationId: conversationId,
        message: message,
        model: model,
        provider: provider,
        inferenceRepo: inferenceRepo,
        tools: tools,
        temperature: temperature,
        strategy: strategy,
      );
    }
    return null;
  }
}

/// Like [MockConversationRepository] but captures the system message passed
/// to createConversation.
class _CapturingConversationRepository extends MockConversationRepository {
  // ignore: use_super_parameters
  _CapturingConversationRepository(
    MockConversationManager mockManager, {
    required this.onSystemMessage,
  }) : super(mockManager);

  final void Function(String?) onSystemMessage;

  @override
  String createConversation({
    String? systemMessage,
    int maxTurns = 20,
  }) {
    onSystemMessage(systemMessage);
    return 'test-conv-id';
  }
}

/// Like [MockConversationRepository] but returns null from getConversation,
/// simulating a scenario where the conversation was already cleaned up.
class _NullManagerConversationRepository extends MockConversationRepository {
  // ignore: use_super_parameters
  _NullManagerConversationRepository(MockConversationManager mockManager)
      : super(mockManager);

  @override
  ConversationManager? getConversation(String conversationId) => null;
}

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

  final testAgentIdentity = AgentDomainEntity.agent(
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
  ) as AgentIdentityEntity;

  final testAgentState = AgentDomainEntity.agentState(
    id: 'state-001',
    agentId: agentId,
    revision: 3,
    slots: const AgentSlots(activeTaskId: taskId),
    updatedAt: testDate,
    vectorClock: null,
  ) as AgentStateEntity;

  final geminiProvider = AiConfig.inferenceProvider(
    id: 'gemini-provider-001',
    baseUrl: 'https://generativelanguage.googleapis.com',
    apiKey: 'test-api-key',
    name: 'Gemini',
    createdAt: DateTime(2024),
    inferenceProviderType: InferenceProviderType.gemini,
  ) as AiConfigInferenceProvider;

  final geminiModel = AiConfig.model(
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
  ) as AiConfigModel;

  setUp(() {
    mockAgentRepository = MockAgentRepository();
    mockSyncService = MockAgentSyncService();
    mockConversationManager = MockConversationManager();
    mockConversationRepository =
        MockConversationRepository(mockConversationManager);
    mockAiInputRepository = MockAiInputRepository();
    mockAiConfigRepository = MockAiConfigRepository();
    mockJournalDb = MockJournalDb();
    mockCloudInferenceRepository = MockCloudInferenceRepository();
    mockJournalRepository = MockJournalRepository();
    mockChecklistRepository = MockChecklistRepository();
    mockLabelsRepository = MockLabelsRepository();
    mockTemplateService = MockAgentTemplateService();

    registerAllFallbackValues();

    when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async => {});
    when(
      () => mockAgentRepository.updateWakeRunTemplate(any(), any(), any()),
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
    when(() => mockAiInputRepository.buildLinkedFromContext(any()))
        .thenAnswer((_) async => <AiLinkedTaskContext>[]);
    when(() => mockAiInputRepository.buildLinkedToContext(any()))
        .thenAnswer((_) async => <AiLinkedTaskContext>[]);

    // Default template stubs — tests that need different behavior override.
    when(() => mockTemplateService.getTemplateForAgent(agentId))
        .thenAnswer((_) async => testTemplate);
    when(() => mockTemplateService.getActiveVersion(testTemplate.id))
        .thenAnswer((_) async => testTemplateVersion);

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
        ..enabledDomains.add(LogDomains.agentWorkflow),
    );
  });

  group('TaskAgentWorkflow', () {
    group('execute returns error', () {
      test('when no template assigned', () async {
        when(() => mockAgentRepository.getAgentState(agentId))
            .thenAnswer((_) async => testAgentState);
        when(() => mockAgentRepository.getLatestReport(agentId, 'current'))
            .thenAnswer((_) async => null);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.observation,
          ),
        ).thenAnswer((_) async => []);
        when(() => mockAiInputRepository.buildTaskDetailsJson(id: taskId))
            .thenAnswer((_) async => '{"title":"Test Task"}');
        when(() => mockAiInputRepository.buildLinkedTasksJson(taskId))
            .thenAnswer((_) async => '{}');

        // Override default template stub to return null.
        when(() => mockTemplateService.getTemplateForAgent(agentId))
            .thenAnswer((_) async => null);

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
        when(() => mockAgentRepository.getAgentState(agentId))
            .thenAnswer((_) async => null);

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
        final stateNoTask = AgentDomainEntity.agentState(
          id: 'state-001',
          agentId: agentId,
          revision: 1,
          slots: const AgentSlots(),
          updatedAt: testDate,
          vectorClock: null,
        ) as AgentStateEntity;

        when(() => mockAgentRepository.getAgentState(agentId))
            .thenAnswer((_) async => stateNoTask);

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
        when(() => mockAgentRepository.getAgentState(agentId))
            .thenAnswer((_) async => testAgentState);
        when(() => mockAgentRepository.getLatestReport(agentId, 'current'))
            .thenAnswer((_) async => null);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.observation,
          ),
        ).thenAnswer((_) async => []);
        when(() => mockAiInputRepository.buildTaskDetailsJson(id: taskId))
            .thenAnswer((_) async => null);
        when(() => mockAiInputRepository.buildLinkedTasksJson(taskId))
            .thenAnswer((_) async => '{}');

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
        when(() => mockAgentRepository.getAgentState(agentId))
            .thenAnswer((_) async => testAgentState);
        when(() => mockAgentRepository.getLatestReport(agentId, 'current'))
            .thenAnswer((_) async => null);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.observation,
          ),
        ).thenAnswer((_) async => []);
        when(() => mockAiInputRepository.buildTaskDetailsJson(id: taskId))
            .thenAnswer((_) async => '{"title":"Test Task"}');
        when(() => mockAiInputRepository.buildLinkedTasksJson(taskId))
            .thenAnswer((_) async => '{}');
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
        when(() => mockAgentRepository.getAgentState(agentId))
            .thenAnswer((_) async => testAgentState);
        when(() => mockAgentRepository.getLatestReport(agentId, 'current'))
            .thenAnswer((_) async => null);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.observation,
          ),
        ).thenAnswer((_) async => []);
        when(() => mockAiInputRepository.buildTaskDetailsJson(id: taskId))
            .thenAnswer((_) async => '{"title":"Test Task"}');
        when(() => mockAiInputRepository.buildLinkedTasksJson(taskId))
            .thenAnswer((_) async => '{}');

        // Template exists but active version is null.
        when(() => mockTemplateService.getActiveVersion(testTemplate.id))
            .thenAnswer((_) async => null);

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
        // Common stubs for a successful execute path.
        when(() => mockAgentRepository.getAgentState(agentId))
            .thenAnswer((_) async => testAgentState);
        when(() => mockAgentRepository.getLatestReport(agentId, 'current'))
            .thenAnswer((_) async => null);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.observation,
          ),
        ).thenAnswer((_) async => []);
        when(() => mockAiInputRepository.buildTaskDetailsJson(id: taskId))
            .thenAnswer((_) async => '{"title":"Test Task"}');
        when(() => mockAiInputRepository.buildLinkedTasksJson(taskId))
            .thenAnswer((_) async => '{}');
        when(
          () => mockAiConfigRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => [geminiModel]);
        when(
          () => mockAiConfigRepository.getConfigById('gemini-provider-001'),
        ).thenAnswer((_) async => geminiProvider);
        when(() => mockAgentRepository.getReportHead(agentId, 'current'))
            .thenAnswer((_) async => null);

        // Mock manager messages (empty list for final content extraction).
        when(() => mockConversationManager.messages).thenReturn([]);
      });

      test('creates conversation, sends message, and persists state', () async {
        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isTrue);

        // User message (payload + message) + state update = 3 upsert calls.
        verify(() => mockSyncService.upsertEntity(any())).called(3);

        // Verify conversation was cleaned up in finally.
        expect(
          mockConversationRepository.deletedConversationIds,
          contains('test-conv-id'),
        );
      });

      test('system prompt contains scaffold and template directives', () async {
        String? capturedSystemMessage;
        // Override createConversation to capture the system message.
        final capturingRepo = _CapturingConversationRepository(
          mockConversationManager,
          onSystemMessage: (msg) => capturedSystemMessage = msg,
        );
        final capturingWorkflow = TaskAgentWorkflow(
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
        // Template directives appended.
        expect(
            capturedSystemMessage, contains('Your Personality & Directives'));
        expect(
          capturedSystemMessage,
          contains('You are a diligent task agent named Laura.'),
        );
      });

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
          ),
        ).called(1);
      });

      test('continues when template provenance recording fails', () async {
        when(
          () => mockAgentRepository.updateWakeRunTemplate(
            any(),
            any(),
            any(),
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

      test('persists observations from record_observations tool calls',
          () async {
        // Set up sendMessage to simulate the strategy accumulating
        // observations via the record_observations tool during conversation.
        mockConversationRepository.sendMessageDelegate = ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
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
                    arguments: '{"observations":["Pattern A","Pattern B"]}',
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
        verify(() => mockSyncService.upsertEntity(any()))
            .called(greaterThanOrEqualTo(6));
      });

      test('persists wakeTokenUsage entity when usage data is returned',
          () async {
        // Return non-null usage from sendMessage.
        mockConversationRepository.sendMessageDelegate = ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
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
        final captured =
            verify(() => mockSyncService.upsertEntity(captureAny())).captured;

        final tokenUsageEntities = captured
            .whereType<AgentDomainEntity>()
            .where(
              (e) => e.mapOrNull(wakeTokenUsage: (_) => true) ?? false,
            )
            .toList();

        expect(tokenUsageEntities, hasLength(1));
        final entity = tokenUsageEntities.first as WakeTokenUsageEntity;
        expect(entity.agentId, agentId);
        expect(entity.runKey, runKey);
        expect(entity.threadId, threadId);
        expect(entity.inputTokens, 150);
        expect(entity.outputTokens, 75);
        expect(entity.thoughtsTokens, 30);
        expect(entity.cachedInputTokens, 20);
      });

      test('does not persist wakeTokenUsage when usage is null', () async {
        // Default delegate returns null.
        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isTrue);

        final captured =
            verify(() => mockSyncService.upsertEntity(captureAny())).captured;

        final tokenUsageEntities = captured
            .whereType<AgentDomainEntity>()
            .where(
              (e) => e.mapOrNull(wakeTokenUsage: (_) => true) ?? false,
            )
            .toList();

        expect(tokenUsageEntities, isEmpty);
      });

      test('does not persist wakeTokenUsage when usage has no data', () async {
        // Return an empty usage (hasData == false).
        mockConversationRepository.sendMessageDelegate = ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
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

        final captured =
            verify(() => mockSyncService.upsertEntity(captureAny())).captured;

        final tokenUsageEntities = captured
            .whereType<AgentDomainEntity>()
            .where(
              (e) => e.mapOrNull(wakeTokenUsage: (_) => true) ?? false,
            )
            .toList();

        expect(tokenUsageEntities, isEmpty);
      });

      test('handles _persistTokenUsage failure gracefully', () async {
        // Return usage data, but make the sync service throw on wakeTokenUsage.
        mockConversationRepository.sendMessageDelegate = ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
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

    group('failed execute', () {
      test('increments consecutiveFailureCount on exception', () async {
        when(() => mockAgentRepository.getAgentState(agentId))
            .thenAnswer((_) async => testAgentState);
        when(() => mockAgentRepository.getLatestReport(agentId, 'current'))
            .thenAnswer((_) async => null);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.observation,
          ),
        ).thenAnswer((_) async => []);
        when(() => mockAiInputRepository.buildTaskDetailsJson(id: taskId))
            .thenAnswer((_) async => '{"title":"Test Task"}');
        when(() => mockAiInputRepository.buildLinkedTasksJson(taskId))
            .thenAnswer((_) async => '{}');
        when(
          () => mockAiConfigRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => [geminiModel]);
        when(
          () => mockAiConfigRepository.getConfigById('gemini-provider-001'),
        ).thenAnswer((_) async => geminiProvider);
        // Make sendMessage throw to trigger the catch branch.
        mockConversationRepository.sendMessageDelegate = ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
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
        final captured =
            verify(() => mockSyncService.upsertEntity(captureAny())).captured;

        // Find the state entity that was persisted.
        final stateUpdates = captured
            .whereType<AgentDomainEntity>()
            .where(
              (e) => e.map(
                agent: (_) => false,
                agentState: (_) => true,
                agentMessage: (_) => false,
                agentMessagePayload: (_) => false,
                agentReport: (_) => false,
                agentReportHead: (_) => false,
                agentTemplate: (_) => false,
                agentTemplateVersion: (_) => false,
                agentTemplateHead: (_) => false,
                evolutionSession: (_) => false,
                evolutionNote: (_) => false,
                changeSet: (_) => false,
                changeDecision: (_) => false,
                wakeTokenUsage: (_) => false,
                unknown: (_) => false,
              ),
            )
            .toList();

        expect(stateUpdates, isNotEmpty);
        final updatedState = stateUpdates.last as AgentStateEntity;
        expect(
          updatedState.consecutiveFailureCount,
          testAgentState.consecutiveFailureCount + 1,
        );
        expect(updatedState.revision, testAgentState.revision + 1);

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
        when(() => mockAgentRepository.getAgentState(agentId))
            .thenAnswer((_) async => testAgentState);
        when(() => mockAgentRepository.getLatestReport(agentId, 'current'))
            .thenAnswer((_) async => null);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.observation,
          ),
        ).thenAnswer((_) async => []);
        when(() => mockAiInputRepository.buildTaskDetailsJson(id: taskId))
            .thenAnswer((_) async => '{"title":"Test Task"}');
        when(() => mockAiInputRepository.buildLinkedTasksJson(taskId))
            .thenAnswer((_) async => '{}');
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

        final providerNoKey = AiConfig.inferenceProvider(
          id: 'gemini-provider-001',
          baseUrl: 'https://generativelanguage.googleapis.com',
          apiKey: '',
          name: 'Gemini',
          createdAt: DateTime(2024),
          inferenceProviderType: InferenceProviderType.gemini,
        ) as AiConfigInferenceProvider;

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
        when(() => mockAgentRepository.getAgentState(agentId))
            .thenAnswer((_) async => testAgentState);
        when(() => mockAgentRepository.getLatestReport(agentId, 'current'))
            .thenAnswer((_) async => null);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.observation,
          ),
        ).thenAnswer((_) async => []);
        when(() => mockAiInputRepository.buildTaskDetailsJson(id: taskId))
            .thenAnswer((_) async => '{"title":"Test Task"}');
        when(() => mockAiInputRepository.buildLinkedTasksJson(taskId))
            .thenAnswer((_) async => '{}');
        when(
          () => mockAiConfigRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => [geminiModel]);
        when(
          () => mockAiConfigRepository.getConfigById('gemini-provider-001'),
        ).thenAnswer((_) async => geminiProvider);
        when(() => mockAgentRepository.getReportHead(agentId, 'current'))
            .thenAnswer((_) async => null);
      });

      test('persists report and report head when strategy produces report',
          () async {
        mockConversationRepository.sendMessageDelegate = ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
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
                    arguments: r'{"markdown":"# Report\nAll good."}',
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
        final captured =
            verify(() => mockSyncService.upsertEntity(captureAny())).captured;

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

        final captured =
            verify(() => mockSyncService.upsertEntity(captureAny())).captured;

        // Find the thought payload entity (the one with the LLM response,
        // not the user message payload).
        final payloads = captured
            .whereType<AgentDomainEntity>()
            .where(
              (e) => e.mapOrNull(agentMessagePayload: (_) => true) ?? false,
            )
            .cast<AgentMessagePayloadEntity>()
            .toList();
        // At least 2 payloads: user message + thought.
        expect(payloads.length, greaterThanOrEqualTo(2));
        final thoughtPayload = payloads.firstWhere(
          (p) => p.content['text'] == 'I analyzed the task and it looks good.',
        );
        expect(thoughtPayload.content['text'],
            'I analyzed the task and it looks good.');
      });

      test('uses existing report head ID when one exists', () async {
        final existingHead = AgentDomainEntity.agentReportHead(
          id: 'existing-head-id',
          agentId: agentId,
          scope: 'current',
          reportId: 'old-report',
          updatedAt: testDate,
          vectorClock: null,
        ) as AgentReportHeadEntity;

        when(() => mockAgentRepository.getReportHead(agentId, 'current'))
            .thenAnswer((_) async => existingHead);

        mockConversationRepository.sendMessageDelegate = ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
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
                    arguments: '{"markdown":"# Updated"}',
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

        final captured =
            verify(() => mockSyncService.upsertEntity(captureAny())).captured;

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
    });

    group('_executeToolHandler dispatch', () {
      /// Helper that sets up a successful execute path where sendMessage
      /// invokes the strategy's processToolCalls with a specific tool call.
      Future<WakeResult> executeWithToolCall(
        String toolName,
        String arguments,
      ) async {
        when(() => mockAgentRepository.getAgentState(agentId))
            .thenAnswer((_) async => testAgentState);
        when(() => mockAgentRepository.getLatestReport(agentId, 'current'))
            .thenAnswer((_) async => null);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.observation,
          ),
        ).thenAnswer((_) async => []);
        when(() => mockAiInputRepository.buildTaskDetailsJson(id: taskId))
            .thenAnswer((_) async => '{"title":"Test Task"}');
        when(() => mockAiInputRepository.buildLinkedTasksJson(taskId))
            .thenAnswer((_) async => '{}');
        when(
          () => mockAiConfigRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => [geminiModel]);
        when(
          () => mockAiConfigRepository.getConfigById('gemini-provider-001'),
        ).thenAnswer((_) async => geminiProvider);
        when(() => mockAgentRepository.getReportHead(agentId, 'current'))
            .thenAnswer((_) async => null);
        when(() => mockConversationManager.messages).thenReturn([]);

        // Stub the task entity lookup used by _executeToolHandler.
        when(() => mockJournalDb.journalEntityById(taskId))
            .thenAnswer((_) async => null);

        mockConversationRepository.sendMessageDelegate = ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
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

      test('tool call with missing task entity triggers policy denial',
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
      });

      test('set_task_title with missing task entity is denied gracefully',
          () async {
        // Same as above — task entity is null so executor denies the call.
        final result = await executeWithToolCall(
          'set_task_title',
          '{"title":""}',
        );
        expect(result.success, isTrue);
      });
    });

    group('_buildUserMessage context', () {
      /// Helper that sets up the common stubs for a successful execute, and
      /// captures the user message string sent to the conversation.
      Future<String?> executeAndCaptureMessage({
        AgentReportEntity? lastReport,
        List<AgentMessageEntity> observations = const [],
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
        final linkedMap =
            parsed is Map<String, dynamic> ? parsed : <String, dynamic>{};
        final linkedFrom = parseLinkedTasks(linkedMap['linked_from']);
        final linkedTo = [
          ...parseLinkedTasks(linkedMap['linked_to']),
          ...parseLinkedTasks(linkedMap['linked']),
        ];

        when(() => mockAgentRepository.getAgentState(agentId))
            .thenAnswer((_) async => testAgentState);
        when(() => mockAgentRepository.getLatestReport(agentId, 'current'))
            .thenAnswer((_) async => lastReport);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.observation,
          ),
        ).thenAnswer((_) async => observations);
        when(() => mockAiInputRepository.buildTaskDetailsJson(id: taskId))
            .thenAnswer((_) async => '{"title":"Test Task"}');
        if (throwOnLinkedContextBuild) {
          when(() => mockAiInputRepository.buildLinkedFromContext(taskId))
              .thenThrow(Exception('linked context failed'));
        } else {
          when(() => mockAiInputRepository.buildLinkedFromContext(taskId))
              .thenAnswer((_) async => linkedFrom);
        }
        when(() => mockAiInputRepository.buildLinkedToContext(taskId))
            .thenAnswer((_) async => linkedTo);
        when(
          () => mockAiConfigRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => [geminiModel]);
        when(
          () => mockAiConfigRepository.getConfigById('gemini-provider-001'),
        ).thenAnswer((_) async => geminiProvider);
        when(() => mockAgentRepository.getReportHead(agentId, 'current'))
            .thenAnswer((_) async => null);
        when(() => mockConversationManager.messages).thenReturn([]);

        String? capturedMessage;
        mockConversationRepository.sendMessageDelegate = ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
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

      test('includes existing report in user message', () async {
        final report = AgentDomainEntity.agentReport(
          id: 'rpt-1',
          agentId: agentId,
          scope: 'current',
          createdAt: testDate,
          vectorClock: null,
          content: '# My Report\nAll good.',
        ) as AgentReportEntity;

        final message = await executeAndCaptureMessage(lastReport: report);

        expect(message, isNotNull);
        expect(message, contains('## Current Report'));
        expect(message, contains('# My Report'));
        expect(message, contains('All good.'));
      });

      test('includes first wake message when no report exists', () async {
        final message = await executeAndCaptureMessage();

        expect(message, isNotNull);
        expect(message, contains('First Wake'));
        expect(message, contains('No prior report exists'));
      });

      test('includes observation text in user message', () async {
        final obs = AgentDomainEntity.agentMessage(
          id: 'obs-1',
          agentId: agentId,
          threadId: threadId,
          kind: AgentMessageKind.observation,
          createdAt: DateTime(2024, 6, 15, 9),
          vectorClock: null,
          contentEntryId: 'payload-obs-1',
          metadata: const AgentMessageMetadata(runKey: runKey),
        ) as AgentMessageEntity;

        final payload = AgentDomainEntity.agentMessagePayload(
          id: 'payload-obs-1',
          agentId: agentId,
          createdAt: DateTime(2024, 6, 15, 9),
          vectorClock: null,
          content: <String, Object?>{'text': 'Task needs refactoring'},
        );

        when(() => mockAgentRepository.getEntity('payload-obs-1'))
            .thenAnswer((_) async => payload);

        final message = await executeAndCaptureMessage(observations: [obs]);

        expect(message, isNotNull);
        expect(message, contains('## Agent Journal'));
        expect(message, contains('Task needs refactoring'));
      });

      test('shows "(no content)" for observation with missing payload',
          () async {
        final obs = AgentDomainEntity.agentMessage(
          id: 'obs-2',
          agentId: agentId,
          threadId: threadId,
          kind: AgentMessageKind.observation,
          createdAt: DateTime(2024, 6, 15, 9),
          vectorClock: null,
          contentEntryId: 'missing-payload',
          metadata: const AgentMessageMetadata(runKey: runKey),
        ) as AgentMessageEntity;

        when(() => mockAgentRepository.getEntity('missing-payload'))
            .thenAnswer((_) async => null);

        final message = await executeAndCaptureMessage(observations: [obs]);

        expect(message, isNotNull);
        expect(message, contains('(no content)'));
      });

      test('shows "(no content)" for observation with null contentEntryId',
          () async {
        final obs = AgentDomainEntity.agentMessage(
          id: 'obs-3',
          agentId: agentId,
          threadId: threadId,
          kind: AgentMessageKind.observation,
          createdAt: DateTime(2024, 6, 15, 9),
          vectorClock: null,
          metadata: const AgentMessageMetadata(runKey: runKey),
        ) as AgentMessageEntity;

        final message = await executeAndCaptureMessage(observations: [obs]);

        expect(message, isNotNull);
        expect(message, contains('(no content)'));
      });

      test(
          'includes linked tasks and uses linked task-agent report instead of summary',
          () async {
        final linkedReport = AgentDomainEntity.agentReport(
          id: 'linked-report-1',
          agentId: 'linked-agent-1',
          scope: 'current',
          createdAt: DateTime(2024, 6, 14, 8),
          vectorClock: null,
          content: '## Linked Agent Report\nFrom task agent.',
        ) as AgentReportEntity;
        final link = AgentLink.agentTask(
          id: 'link-1',
          fromId: 'linked-agent-1',
          toId: 't2',
          createdAt: DateTime(2024, 6, 14),
          updatedAt: DateTime(2024, 6, 14),
          vectorClock: null,
        );
        when(() => mockAgentRepository.getLinksTo('t2', type: 'agent_task'))
            .thenAnswer((_) async => [link]);
        when(() => mockAgentRepository.getLatestReport(
            'linked-agent-1', 'current')).thenAnswer((_) async => linkedReport);

        final message = await executeAndCaptureMessage(
          linkedTasksJson: '{"linked":[{"id":"t2","title":"Related",'
              '"latestSummary":"Legacy summary"}]}',
        );

        expect(message, isNotNull);
        expect(message, contains('## Linked Tasks'));
        expect(message, contains('Related'));
        expect(message, contains('latestTaskAgentReport'));
        expect(message, contains('From task agent.'));
        expect(message, isNot(contains('latestSummary')));
      });

      test('uses link id as deterministic tie-breaker for equal createdAt',
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
        when(() => mockAgentRepository.getLinksTo('t2', type: 'agent_task'))
            .thenAnswer((_) async => [linkB, linkA]);

        // With descending tie-breaking on ID, 'link-b' sorts before 'link-a',
        // so the workflow resolves the report for 'linked-agent-b' first.
        final reportB = AgentDomainEntity.agentReport(
          id: 'linked-report-b',
          agentId: 'linked-agent-b',
          scope: 'current',
          createdAt: now,
          vectorClock: null,
          content: 'report-b',
        ) as AgentReportEntity;
        when(() => mockAgentRepository.getLatestReport(
            'linked-agent-b', 'current')).thenAnswer((_) async => reportB);

        final message = await executeAndCaptureMessage(
          linkedTasksJson: '{"linked":[{"id":"t2","title":"Related"}]}',
        );

        verify(
          () =>
              mockAgentRepository.getLatestReport('linked-agent-b', 'current'),
        ).called(1);
        verifyNever(
          () =>
              mockAgentRepository.getLatestReport('linked-agent-a', 'current'),
        );
        expect(message, isNotNull);
        expect(message, contains('report-b'));
      });

      test('falls back to empty linked-task context when build throws',
          () async {
        final message = await executeAndCaptureMessage(
          linkedTasksJson: '{"linked":[{"id":"t2","title":"Related",'
              '"latestSummary":"Legacy summary"}]}',
          throwOnLinkedContextBuild: true,
        );

        expect(message, isNotNull);
        expect(message, isNot(contains('## Linked Tasks')));
      });

      test('omits linked tasks section when empty', () async {
        final message = await executeAndCaptureMessage();

        expect(message, isNotNull);
        expect(message, isNot(contains('## Linked Tasks')));
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

      test('omits trigger section when empty', () async {
        final message = await executeAndCaptureMessage();

        expect(message, isNotNull);
        expect(message, isNot(contains('## Changed Since Last Wake')));
      });

      test(
          'shows "(no content)" for observation with empty string text payload',
          () async {
        final obs = AgentDomainEntity.agentMessage(
          id: 'obs-empty',
          agentId: agentId,
          threadId: threadId,
          kind: AgentMessageKind.observation,
          createdAt: DateTime(2024, 6, 15, 9),
          vectorClock: null,
          contentEntryId: 'payload-empty-text',
          metadata: const AgentMessageMetadata(runKey: runKey),
        ) as AgentMessageEntity;

        final payload = AgentDomainEntity.agentMessagePayload(
          id: 'payload-empty-text',
          agentId: agentId,
          createdAt: DateTime(2024, 6, 15, 9),
          vectorClock: null,
          content: <String, Object?>{'text': ''},
        );

        when(() => mockAgentRepository.getEntity('payload-empty-text'))
            .thenAnswer((_) async => payload);

        final message = await executeAndCaptureMessage(observations: [obs]);

        expect(message, isNotNull);
        expect(message, contains('(no content)'));
      });

      test('shows "(no content)" for observation with non-string text payload',
          () async {
        final obs = AgentDomainEntity.agentMessage(
          id: 'obs-wrong-type',
          agentId: agentId,
          threadId: threadId,
          kind: AgentMessageKind.observation,
          createdAt: DateTime(2024, 6, 15, 9),
          vectorClock: null,
          contentEntryId: 'payload-wrong-type',
          metadata: const AgentMessageMetadata(runKey: runKey),
        ) as AgentMessageEntity;

        final payload = AgentDomainEntity.agentMessagePayload(
          id: 'payload-wrong-type',
          agentId: agentId,
          createdAt: DateTime(2024, 6, 15, 9),
          vectorClock: null,
          content: <String, Object?>{'text': 42},
        );

        when(() => mockAgentRepository.getEntity('payload-wrong-type'))
            .thenAnswer((_) async => payload);

        final message = await executeAndCaptureMessage(observations: [obs]);

        expect(message, isNotNull);
        expect(message, contains('(no content)'));
      });

      group('decision history', () {
        ChangeDecisionEntity makeDecision({
          required String toolName,
          required ChangeDecisionVerdict verdict,
          String? rejectionReason,
        }) {
          return AgentDomainEntity.changeDecision(
            id: 'dec-${toolName.hashCode}',
            agentId: agentId,
            changeSetId: 'cs-1',
            itemIndex: 0,
            toolName: toolName,
            verdict: verdict,
            createdAt: DateTime(2024, 6, 15),
            vectorClock: null,
            taskId: taskId,
            rejectionReason: rejectionReason,
          ) as ChangeDecisionEntity;
        }

        test('includes decision history when decisions exist', () async {
          when(
            () => mockAgentRepository.getRecentDecisions(
              any(),
              taskId: any(named: 'taskId'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) async => [
                makeDecision(
                  toolName: 'set_task_title',
                  verdict: ChangeDecisionVerdict.confirmed,
                ),
              ]);

          final message = await executeAndCaptureMessage();

          expect(message, isNotNull);
          expect(message, contains('## Recent User Decisions'));
          expect(message, contains('set_task_title'));
          expect(message, contains('confirmed'));
        });

        test('omits decision history when no decisions exist', () async {
          // Default stub returns empty list.
          final message = await executeAndCaptureMessage();

          expect(message, isNotNull);
          expect(message, isNot(contains('## Recent User Decisions')));
        });

        test('displays rejection reason when present', () async {
          when(
            () => mockAgentRepository.getRecentDecisions(
              any(),
              taskId: any(named: 'taskId'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) async => [
                makeDecision(
                  toolName: 'update_task_estimate',
                  verdict: ChangeDecisionVerdict.rejected,
                  rejectionReason: 'I know better',
                ),
              ]);

          final message = await executeAndCaptureMessage();

          expect(message, isNotNull);
          expect(message, contains('I know better'));
          expect(message, contains('rejected'));
          expect(message, contains('\u2717')); // ✗
        });

        test('formats mixed verdicts correctly', () async {
          when(
            () => mockAgentRepository.getRecentDecisions(
              any(),
              taskId: any(named: 'taskId'),
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) async => [
                makeDecision(
                  toolName: 'set_task_title',
                  verdict: ChangeDecisionVerdict.confirmed,
                ),
                makeDecision(
                  toolName: 'update_task_estimate',
                  verdict: ChangeDecisionVerdict.rejected,
                  rejectionReason: 'Too high',
                ),
                makeDecision(
                  toolName: 'assign_task_labels',
                  verdict: ChangeDecisionVerdict.deferred,
                ),
              ]);

          final message = await executeAndCaptureMessage();

          expect(message, isNotNull);
          // Confirmed
          expect(message, contains('\u2713 set_task_title'));
          // Rejected with reason
          expect(message, contains('\u2717 update_task_estimate'));
          expect(message, contains('Too high'));
          // Deferred
          expect(message, contains('\u23f8 assign_task_labels'));
          expect(message, contains('deferred'));
        });

        test('error in getRecentDecisions does not crash the wake', () async {
          when(
            () => mockAgentRepository.getRecentDecisions(
              any(),
              taskId: any(named: 'taskId'),
              limit: any(named: 'limit'),
            ),
          ).thenThrow(Exception('DB error'));

          final message = await executeAndCaptureMessage();

          // Should still get a valid message, just without decision history.
          expect(message, isNotNull);
          expect(message, isNot(contains('## Recent User Decisions')));
          expect(message, contains('Current Task Context'));
        });
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
          ) as AgentMessageEntity;
        });

        // Stub all payloads.
        for (var i = 0; i < 25; i++) {
          when(() => mockAgentRepository.getEntity('pay-$i'))
              .thenAnswer((_) async {
            return AgentDomainEntity.agentMessagePayload(
              id: 'pay-$i',
              agentId: agentId,
              createdAt: DateTime(2024, 6, 15, i),
              vectorClock: null,
              content: <String, Object?>{'text': 'Obs $i'},
            );
          });
        }

        final message =
            await executeAndCaptureMessage(observations: observations);

        expect(message, isNotNull);
        // The 20 most recent (hours 5-24) should appear; oldest 5 dropped.
        expect(message, contains('Obs 5'));
        expect(message, contains('Obs 24'));
        // Oldest observations (hours 0-4) should NOT appear.
        expect(message, isNot(contains('Obs 0')));
        expect(message, isNot(contains('Obs 4')));
      });
    });

    group('tool handler dispatch with real Task', () {
      /// Common stubs for execute path up through sendMessage.
      void stubFullExecutePath() {
        when(() => mockAgentRepository.getAgentState(agentId))
            .thenAnswer((_) async => testAgentState);
        when(() => mockAgentRepository.getLatestReport(agentId, 'current'))
            .thenAnswer((_) async => null);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.observation,
          ),
        ).thenAnswer((_) async => []);
        when(() => mockAiInputRepository.buildTaskDetailsJson(id: taskId))
            .thenAnswer((_) async => '{"title":"Test Task"}');
        when(() => mockAiInputRepository.buildLinkedTasksJson(taskId))
            .thenAnswer((_) async => '{}');
        when(
          () => mockAiConfigRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => [geminiModel]);
        when(
          () => mockAiConfigRepository.getConfigById('gemini-provider-001'),
        ).thenAnswer((_) async => geminiProvider);
        when(() => mockAgentRepository.getReportHead(agentId, 'current'))
            .thenAnswer((_) async => null);
        when(() => mockConversationManager.messages).thenReturn([]);
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
        stubFullExecutePath();

        // Return a real Task entity from the DB so tool handler dispatch
        // actually exercises the handler code.
        when(() => mockJournalDb.journalEntityById(taskId))
            .thenAnswer((_) async => task ?? taskWithCategory);

        // Stub addToolResponse on the conversation manager.
        when(
          () => mockConversationManager.addToolResponse(
            toolCallId: any(named: 'toolCallId'),
            response: any(named: 'response'),
          ),
        ).thenReturn(null);

        mockConversationRepository.sendMessageDelegate = ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
          temperature = 0.7,
          strategy,
        }) async {
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

        when(() => mockJournalRepository.updateJournalEntity(any()))
            .thenAnswer((_) async => true);
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
        verify(
          () => mockConversationManager.addToolResponse(
            toolCallId: 'tc-1',
            response: any(
              named: 'response',
              that: contains('Proposal queued for user review'),
            ),
          ),
        ).called(1);
      });

      test('update_task_estimate with null minutes is deferred', () async {
        final result = await executeWithToolCallOnRealTask(
          'update_task_estimate',
          '{}',
        );
        expect(result.success, isTrue);
        verify(
          () => mockConversationManager.addToolResponse(
            toolCallId: 'tc-1',
            response: any(
              named: 'response',
              that: contains('Proposal queued for user review'),
            ),
          ),
        ).called(1);
      });

      test('update_task_due_date with empty dueDate is deferred', () async {
        final result = await executeWithToolCallOnRealTask(
          'update_task_due_date',
          '{"dueDate":""}',
        );
        expect(result.success, isTrue);
        verify(
          () => mockConversationManager.addToolResponse(
            toolCallId: 'tc-1',
            response: any(
              named: 'response',
              that: contains('Proposal queued for user review'),
            ),
          ),
        ).called(1);
      });

      test('update_task_priority with empty priority is deferred', () async {
        final result = await executeWithToolCallOnRealTask(
          'update_task_priority',
          '{"priority":""}',
        );
        expect(result.success, isTrue);
        verify(
          () => mockConversationManager.addToolResponse(
            toolCallId: 'tc-1',
            response: any(
              named: 'response',
              that: contains('Proposal queued for user review'),
            ),
          ),
        ).called(1);
      });

      test('assign_task_labels with non-array labels is deferred', () async {
        final result = await executeWithToolCallOnRealTask(
          'assign_task_labels',
          '{"labels":"not-an-array"}',
        );
        expect(result.success, isTrue);
        verify(
          () => mockConversationManager.addToolResponse(
            toolCallId: 'tc-1',
            response: any(
              named: 'response',
              that: contains('Proposal queued for user review'),
            ),
          ),
        ).called(1);
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
        verify(
          () => mockConversationManager.addToolResponse(
            toolCallId: 'tc-1',
            response: any(
              named: 'response',
              that: contains('Proposal queued for user review'),
            ),
          ),
        ).called(1);
      });

      test('add_multiple_checklist_items with non-array items is deferred',
          () async {
        final result = await executeWithToolCallOnRealTask(
          'add_multiple_checklist_items',
          '{"items":"not an array"}',
        );
        expect(result.success, isTrue);
        verify(
          () => mockConversationManager.addToolResponse(
            toolCallId: 'tc-1',
            response: any(
              named: 'response',
              that: contains('Proposal queued for user review'),
            ),
          ),
        ).called(1);
      });

      test('update_checklist_items with non-array items is deferred', () async {
        final result = await executeWithToolCallOnRealTask(
          'update_checklist_items',
          '{"items":"not an array"}',
        );
        expect(result.success, isTrue);
        verify(
          () => mockConversationManager.addToolResponse(
            toolCallId: 'tc-1',
            response: any(
              named: 'response',
              that: contains('Proposal queued for user review'),
            ),
          ),
        ).called(1);
      });

      test('update_checklist_items with empty array is deferred', () async {
        final result = await executeWithToolCallOnRealTask(
          'update_checklist_items',
          '{"items":[]}',
        );
        expect(result.success, isTrue);
        verify(
          () => mockConversationManager.addToolResponse(
            toolCallId: 'tc-1',
            response: any(
              named: 'response',
              that: contains('Proposal queued for user review'),
            ),
          ),
        ).called(1);
      });

      test('add_multiple_checklist_items with empty array is deferred',
          () async {
        final result = await executeWithToolCallOnRealTask(
          'add_multiple_checklist_items',
          '{"items":[]}',
        );
        expect(result.success, isTrue);
        verify(
          () => mockConversationManager.addToolResponse(
            toolCallId: 'tc-1',
            response: any(
              named: 'response',
              that: contains('Proposal queued for user review'),
            ),
          ),
        ).called(1);
      });

      test('add_multiple_checklist_items with string items reports skipped',
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
      });

      test('update_checklist_items with missing id is deferred', () async {
        // Items with missing id are still valid Maps and get deferred.
        // Validation happens at confirmation time.
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
              that: contains('Proposal queued for user review'),
            ),
          ),
        ).called(1);
      });

      test('update_task_estimate accepts numeric string minutes', () async {
        when(() => mockJournalRepository.updateJournalEntity(any()))
            .thenAnswer((_) async => true);

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
      });

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
          verifyNever(
            () => mockJournalRepository.updateJournalEntity(any()),
          );
          verify(
            () => mockConversationManager.addToolResponse(
              toolCallId: 'tc-1',
              response: any(
                named: 'response',
                that: contains('Proposal queued for user review'),
              ),
            ),
          ).called(1);
        });

        test('update_task_due_date is deferred', () async {
          final result = await executeWithToolCallOnRealTask(
            'update_task_due_date',
            '{"dueDate":"2024-06-30"}',
            task: taskForUpdates,
          );
          expect(result.success, isTrue);
          verifyNever(
            () => mockJournalRepository.updateJournalEntity(any()),
          );
          verify(
            () => mockConversationManager.addToolResponse(
              toolCallId: 'tc-1',
              response: any(
                named: 'response',
                that: contains('Proposal queued for user review'),
              ),
            ),
          ).called(1);
        });

        test('update_task_priority is deferred', () async {
          final result = await executeWithToolCallOnRealTask(
            'update_task_priority',
            '{"priority":"P1"}',
            task: taskForUpdates,
          );
          expect(result.success, isTrue);
          verifyNever(
            () => mockJournalRepository.updateJournalEntity(any()),
          );
          verify(
            () => mockConversationManager.addToolResponse(
              toolCallId: 'tc-1',
              response: any(
                named: 'response',
                that: contains('Proposal queued for user review'),
              ),
            ),
          ).called(1);
        });

        test('update_task_estimate with already-set estimate is deferred',
            () async {
          // Even when the value matches, it is still deferred — validation
          // happens at confirmation time.
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
                that: contains('Proposal queued for user review'),
              ),
            ),
          ).called(1);
        });

        test('update_task_due_date with invalid format is deferred', () async {
          // Invalid args are still deferred — validation happens at
          // confirmation time via TaskToolDispatcher.
          final result = await executeWithToolCallOnRealTask(
            'update_task_due_date',
            '{"dueDate":"not-a-date"}',
            task: taskForUpdates,
          );
          expect(result.success, isTrue);
          verify(
            () => mockConversationManager.addToolResponse(
              toolCallId: 'tc-1',
              response: any(
                named: 'response',
                that: contains('Proposal queued for user review'),
              ),
            ),
          ).called(1);
        });

        test('update_task_priority with invalid priority is deferred',
            () async {
          final result = await executeWithToolCallOnRealTask(
            'update_task_priority',
            '{"priority":"P9"}',
            task: taskForUpdates,
          );
          expect(result.success, isTrue);
          verify(
            () => mockConversationManager.addToolResponse(
              toolCallId: 'tc-1',
              response: any(
                named: 'response',
                that: contains('Proposal queued for user review'),
              ),
            ),
          ).called(1);
        });

        test('update_task_estimate with persistence failure is deferred',
            () async {
          // The tool call is deferred regardless — no DB write happens yet.
          final result = await executeWithToolCallOnRealTask(
            'update_task_estimate',
            '{"minutes":60}',
            task: taskForUpdates,
          );
          expect(result.success, isTrue);
          verifyNever(
            () => mockJournalRepository.updateJournalEntity(any()),
          );
          verify(
            () => mockConversationManager.addToolResponse(
              toolCallId: 'tc-1',
              response: any(
                named: 'response',
                that: contains('Proposal queued for user review'),
              ),
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
          verify(
            () => mockConversationManager.addToolResponse(
              toolCallId: 'tc-1',
              response: any(
                named: 'response',
                that: contains('Proposal queued for user review'),
              ),
            ),
          ).called(1);
        });

        test('update_checklist_items is deferred', () async {
          final result = await executeWithToolCallOnRealTask(
            'update_checklist_items',
            '{"items":[{"id":"item-1","isChecked":true}]}',
          );

          expect(result.success, isTrue);
          verify(
            () => mockConversationManager.addToolResponse(
              toolCallId: 'tc-1',
              response: any(
                named: 'response',
                that: contains('Proposal queued for user review'),
              ),
            ),
          ).called(1);
        });

        test('update_checklist_items resolves title from DB for ID-only items',
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

          when(() => mockJournalDb.journalEntityById('cl-item-1'))
              .thenAnswer((_) async => checklistItem);

          final result = await executeWithToolCallOnRealTask(
            'update_checklist_items',
            '{"items":[{"id":"cl-item-1","isChecked":true}]}',
          );

          expect(result.success, isTrue);

          // Verify the resolver looked up the checklist item.
          verify(() => mockJournalDb.journalEntityById('cl-item-1')).called(1);
        });
      });

      test('task entity is not a Task type — set_task_title is still deferred',
          () async {
        stubFullExecutePath();

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

        when(() => mockJournalDb.journalEntityById(taskId))
            .thenAnswer((_) async => nonTaskEntity);
        when(
          () => mockConversationManager.addToolResponse(
            toolCallId: any(named: 'toolCallId'),
            response: any(named: 'response'),
          ),
        ).thenReturn(null);

        mockConversationRepository.sendMessageDelegate = ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
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
        verify(
          () => mockConversationManager.addToolResponse(
            toolCallId: 'tc-2',
            response: any(
              named: 'response',
              that: contains('Proposal queued for user review'),
            ),
          ),
        ).called(1);
      });
    });

    group('_extractFinalAssistantContent', () {
      setUp(() {
        when(() => mockAgentRepository.getAgentState(agentId))
            .thenAnswer((_) async => testAgentState);
        when(() => mockAgentRepository.getLatestReport(agentId, 'current'))
            .thenAnswer((_) async => null);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.observation,
          ),
        ).thenAnswer((_) async => []);
        when(() => mockAiInputRepository.buildTaskDetailsJson(id: taskId))
            .thenAnswer((_) async => '{"title":"Test Task"}');
        when(() => mockAiInputRepository.buildLinkedTasksJson(taskId))
            .thenAnswer((_) async => '{}');
        when(
          () => mockAiConfigRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => [geminiModel]);
        when(
          () => mockAiConfigRepository.getConfigById('gemini-provider-001'),
        ).thenAnswer((_) async => geminiProvider);
        when(() => mockAgentRepository.getReportHead(agentId, 'current'))
            .thenAnswer((_) async => null);
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

        final captured =
            verify(() => mockSyncService.upsertEntity(captureAny())).captured;

        final payloads = captured
            .whereType<AgentDomainEntity>()
            .where(
              (e) => e.mapOrNull(agentMessagePayload: (_) => true) ?? false,
            )
            .cast<AgentMessagePayloadEntity>()
            .toList();
        // User message payload + thought payload.
        expect(payloads.length, greaterThanOrEqualTo(2));
        final thoughtPayload = payloads.firstWhere(
          (p) => p.content['text'] == 'Final analysis complete.',
        );
        expect(thoughtPayload.content['text'], 'Final analysis complete.');
      });

      test('no thought persisted when getConversation returns null', () async {
        // Use a new repository mock that returns null for getConversation.
        final nullManagerRepo =
            _NullManagerConversationRepository(mockConversationManager);
        final nullWorkflow = TaskAgentWorkflow(
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

        // Only user message payload (no thought payload since manager null).
        final captured =
            verify(() => mockSyncService.upsertEntity(captureAny())).captured;
        final payloads = captured
            .whereType<AgentDomainEntity>()
            .where(
              (e) => e.mapOrNull(agentMessagePayload: (_) => true) ?? false,
            )
            .cast<AgentMessagePayloadEntity>()
            .toList();
        // User message payload exists, but no thought payload.
        expect(payloads, hasLength(1));
        // Verify it's the user message, not a thought.
        final text = payloads.first.content['text'] as String?;
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

        final captured =
            verify(() => mockSyncService.upsertEntity(captureAny())).captured;

        final payloads = captured
            .whereType<AgentDomainEntity>()
            .where(
              (e) => e.mapOrNull(agentMessagePayload: (_) => true) ?? false,
            )
            .cast<AgentMessagePayloadEntity>()
            .toList();
        // Only user message payload, no thought payload.
        expect(payloads, hasLength(1));
        final text = payloads.first.content['text'] as String?;
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

        final captured =
            verify(() => mockSyncService.upsertEntity(captureAny())).captured;

        final payloads = captured
            .whereType<AgentDomainEntity>()
            .where(
              (e) => e.mapOrNull(agentMessagePayload: (_) => true) ?? false,
            )
            .cast<AgentMessagePayloadEntity>()
            .toList();
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
        when(() => mockAgentRepository.getAgentState(agentId))
            .thenAnswer((_) async => testAgentState);
        when(() => mockAgentRepository.getLatestReport(agentId, 'current'))
            .thenAnswer((_) async => null);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.observation,
          ),
        ).thenAnswer((_) async => []);
        when(() => mockAiInputRepository.buildTaskDetailsJson(id: taskId))
            .thenAnswer((_) async => '{"title":"Test Task"}');
        when(() => mockAiInputRepository.buildLinkedTasksJson(taskId))
            .thenAnswer((_) async => '{}');
        when(
          () => mockAiConfigRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => [geminiModel]);
        when(
          () => mockAiConfigRepository.getConfigById('gemini-provider-001'),
        ).thenAnswer((_) async => geminiProvider);

        // Make sendMessage throw.
        mockConversationRepository.sendMessageDelegate = ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
          temperature = 0.7,
          strategy,
        }) async {
          throw Exception('Network failure');
        };

        // Make the state update also throw (the nested try/catch).
        when(() => mockSyncService.upsertEntity(any()))
            .thenThrow(Exception('DB write failed'));

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
        when(() => mockAgentRepository.getAgentState(agentId))
            .thenAnswer((_) async => testAgentState);
        when(() => mockAgentRepository.getLatestReport(agentId, 'current'))
            .thenAnswer((_) async => null);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.observation,
          ),
        ).thenAnswer((_) async => []);
        when(() => mockAiInputRepository.buildTaskDetailsJson(id: taskId))
            .thenAnswer((_) async => '{"title":"Test Task"}');
        when(() => mockAiInputRepository.buildLinkedTasksJson(taskId))
            .thenAnswer((_) async => '{}');
        when(
          () => mockAiConfigRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => [geminiModel]);
        when(
          () => mockAiConfigRepository.getConfigById('gemini-provider-001'),
        ).thenAnswer((_) async => geminiProvider);
        when(() => mockAgentRepository.getReportHead(agentId, 'current'))
            .thenAnswer((_) async => null);
        when(() => mockConversationManager.messages).thenReturn([]);

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isTrue);

        // Writes go through syncService, not the repository directly.
        verify(() => mockSyncService.upsertEntity(any()))
            .called(greaterThanOrEqualTo(1));
      });
    });

    group('WakeResult', () {
      test('success with mutated entries', () {
        const result = WakeResult(
          success: true,
          mutatedEntries: {
            'entity-1': VectorClock({'host-a': 1})
          },
        );

        expect(result.success, isTrue);
        expect(
          result.mutatedEntries,
          {
            'entity-1': const VectorClock({'host-a': 1})
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
      test('_logError falls back to developer.log when domainLogger is null',
          () async {
        // Create a workflow without domainLogger.
        final nullLoggerWorkflow = TaskAgentWorkflow(
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
        when(() => mockAgentRepository.getAgentState(agentId))
            .thenAnswer((_) async => testAgentState);
        when(() => mockAgentRepository.getLatestReport(agentId, 'current'))
            .thenAnswer((_) async => null);
        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.observation,
          ),
        ).thenAnswer((_) async => []);
        when(() => mockAiInputRepository.buildTaskDetailsJson(id: taskId))
            .thenAnswer((_) async => '{"title":"Test Task"}');
        when(() => mockAiInputRepository.buildLinkedTasksJson(taskId))
            .thenAnswer((_) async => '{}');
        when(
          () => mockAiConfigRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => [geminiModel]);
        when(
          () => mockAiConfigRepository.getConfigById('gemini-provider-001'),
        ).thenAnswer((_) async => geminiProvider);
        when(() => mockAgentRepository.getReportHead(agentId, 'current'))
            .thenAnswer((_) async => null);
        when(() => mockConversationManager.messages).thenReturn([]);

        // Make sendMessage throw to trigger the outer catch → _logError.
        mockConversationRepository.sendMessageDelegate = ({
          required conversationId,
          required message,
          required model,
          required provider,
          required inferenceRepo,
          tools,
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
      });
    });
  });
}
