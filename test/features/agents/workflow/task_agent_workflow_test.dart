import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/workflow/task_agent_strategy.dart';
import 'package:lotti/features/agents/workflow/task_agent_workflow.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../mocks/mocks.dart';

/// Minimal mock of [ConversationRepository] that avoids Riverpod build().
///
/// ConversationRepository is a Riverpod notifier, so we extend it directly and
/// override the methods the workflow calls rather than using `Mock`.
class MockConversationRepository extends ConversationRepository {
  MockConversationRepository(this._mockManager);

  final MockConversationManager _mockManager;
  final List<String> deletedConversationIds = [];

  /// Delegate for sendMessage — set in tests to control behavior.
  Future<void> Function({
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
  Future<void> sendMessage({
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
      await sendMessageDelegate!(
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
  }
}

void main() {
  late MockAgentRepository mockAgentRepository;
  late MockConversationRepository mockConversationRepository;
  late MockAiInputRepository mockAiInputRepository;
  late MockAiConfigRepository mockAiConfigRepository;
  late MockJournalDb mockJournalDb;
  late MockCloudInferenceRepository mockCloudInferenceRepository;
  late MockConversationManager mockConversationManager;
  late TaskAgentWorkflow workflow;

  const agentId = 'agent-001';
  const taskId = 'task-001';
  const runKey = 'run-key-001';
  const threadId = 'thread-001';
  final testDate = DateTime(2024, 6, 15, 10, 30);

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
    providerModelId: 'models/gemini-3.1-pro-preview',
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
    mockConversationManager = MockConversationManager();
    mockConversationRepository =
        MockConversationRepository(mockConversationManager);
    mockAiInputRepository = MockAiInputRepository();
    mockAiConfigRepository = MockAiConfigRepository();
    mockJournalDb = MockJournalDb();
    mockCloudInferenceRepository = MockCloudInferenceRepository();

    registerFallbackValue(
      AgentDomainEntity.unknown(
        id: 'fallback',
        agentId: 'fallback',
        createdAt: DateTime(2024, 3, 15),
      ),
    );
    registerFallbackValue(AiConfigType.inferenceProvider);

    when(() => mockAgentRepository.upsertEntity(any()))
        .thenAnswer((_) async => {});

    workflow = TaskAgentWorkflow(
      agentRepository: mockAgentRepository,
      conversationRepository: mockConversationRepository,
      aiInputRepository: mockAiInputRepository,
      aiConfigRepository: mockAiConfigRepository,
      journalDb: mockJournalDb,
      cloudInferenceRepository: mockCloudInferenceRepository,
    );
  });

  group('TaskAgentWorkflow', () {
    group('execute returns error', () {
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
        expect(result.error, 'No Gemini provider configured');
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

      test('creates conversation, sends message, persists report and state',
          () async {
        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isTrue);

        // Verify report was persisted (at least report + report head + state).
        verify(() => mockAgentRepository.upsertEntity(any()))
            .called(greaterThanOrEqualTo(3));

        // Verify conversation was cleaned up in finally.
        expect(
          mockConversationRepository.deletedConversationIds,
          contains('test-conv-id'),
        );
      });

      test('persists observations when LLM returns structured JSON with them',
          () async {
        // Set up sendMessage to capture the strategy and record a response.
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
          // Simulate the strategy receiving a final response with observations.
          if (strategy is TaskAgentStrategy) {
            strategy.recordFinalResponse(
              '{"report":{"title":"Updated"},'
              '"observations":["Pattern A","Pattern B"]}',
            );
          }
        };

        // Mock manager returning a message so extractFinalAssistantContent
        // finds nothing (the strategy already has the response).
        when(() => mockConversationManager.messages).thenReturn([]);

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isTrue);

        // Should persist: report + report head + 2 observation payloads
        // + 2 observation messages + state update = 7 total.
        verify(() => mockAgentRepository.upsertEntity(any()))
            .called(greaterThanOrEqualTo(7));
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
            verify(() => mockAgentRepository.upsertEntity(captureAny()))
                .captured;

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

    group('WakeResult', () {
      test('success with mutated entries', () {
        const result = WakeResult(
          success: true,
          mutatedEntries: {'entity-1': 'vc-1'},
        );

        expect(result.success, isTrue);
        expect(result.mutatedEntries, {'entity-1': 'vc-1'});
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
  });
}
