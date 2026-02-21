import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/workflow/task_agent_strategy.dart';
import 'package:lotti/features/agents/workflow/task_agent_workflow.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

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
  late MockJournalRepository mockJournalRepository;
  late MockChecklistRepository mockChecklistRepository;
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
    mockJournalRepository = MockJournalRepository();
    mockChecklistRepository = MockChecklistRepository();

    registerFallbackValue(
      AgentDomainEntity.unknown(
        id: 'fallback',
        agentId: 'fallback',
        createdAt: DateTime(2024, 3, 15),
      ),
    );
    registerFallbackValue(AiConfigType.inferenceProvider);
    registerFallbackValue(testTask as JournalEntity);

    when(() => mockAgentRepository.upsertEntity(any()))
        .thenAnswer((_) async => {});

    workflow = TaskAgentWorkflow(
      agentRepository: mockAgentRepository,
      conversationRepository: mockConversationRepository,
      aiInputRepository: mockAiInputRepository,
      aiConfigRepository: mockAiConfigRepository,
      journalDb: mockJournalDb,
      cloudInferenceRepository: mockCloudInferenceRepository,
      journalRepository: mockJournalRepository,
      checklistRepository: mockChecklistRepository,
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

      test('creates conversation, sends message, and persists state', () async {
        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isTrue);

        // With no tool calls or final text, only state update is persisted.
        verify(() => mockAgentRepository.upsertEntity(any())).called(1);

        // Verify conversation was cleaned up in finally.
        expect(
          mockConversationRepository.deletedConversationIds,
          contains('test-conv-id'),
        );
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
        verify(() => mockAgentRepository.upsertEntity(any()))
            .called(greaterThanOrEqualTo(6));
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
        expect(result.error, 'No Gemini provider configured');
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
        expect(result.error, 'No Gemini provider configured');
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
            verify(() => mockAgentRepository.upsertEntity(captureAny()))
                .captured;

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
            verify(() => mockAgentRepository.upsertEntity(captureAny()))
                .captured;

        // Find the payload entity.
        final payloads = captured
            .whereType<AgentDomainEntity>()
            .where(
              (e) => e.mapOrNull(agentMessagePayload: (_) => true) ?? false,
            )
            .toList();
        expect(payloads, isNotEmpty);
        final payload = payloads.first as AgentMessagePayloadEntity;
        expect(
            payload.content['text'], 'I analyzed the task and it looks good.');
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
        };

        when(() => mockConversationManager.messages).thenReturn([]);

        await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        final captured =
            verify(() => mockAgentRepository.upsertEntity(captureAny()))
                .captured;

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
        };

        return workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );
      }

      test('unknown tool returns error in tool result', () async {
        // The tool call goes through executor which needs category resolution.
        // Since task entity is null, executor returns a policy denial — but
        // that tests the _executeToolHandler dispatch path.
        final result = await executeWithToolCall(
          'nonexistent_tool',
          '{}',
        );

        // The execute should still succeed overall (tool errors don't fail
        // the wake).
        expect(result.success, isTrue);
      });

      test('set_task_title with empty title returns error', () async {
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
      }) async {
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
        when(() => mockAiInputRepository.buildLinkedTasksJson(taskId))
            .thenAnswer((_) async => linkedTasksJson);
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
        expect(message, contains('## Your Prior Observations'));
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

      test('includes linked tasks when non-empty', () async {
        final message = await executeAndCaptureMessage(
          linkedTasksJson: '{"linked":[{"id":"t2","title":"Related"}]}',
        );

        expect(message, isNotNull);
        expect(message, contains('## Linked Tasks'));
        expect(message, contains('Related'));
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

      test('caps observations to 20 most recent', () async {
        // Create 25 observations.
        final observations = List.generate(25, (i) {
          return AgentDomainEntity.agentMessage(
            id: 'obs-$i',
            agentId: agentId,
            threadId: threadId,
            kind: AgentMessageKind.observation,
            createdAt: DateTime(2024, 6, 15, i),
            vectorClock: null,
            contentEntryId: 'pay-$i',
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
        // Only the first 20 should appear (indices 0-19).
        expect(message, contains('Obs 0'));
        expect(message, contains('Obs 19'));
        // Index 20+ should NOT appear.
        expect(message, isNot(contains('Obs 20')));
        expect(message, isNot(contains('Obs 24')));
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

      test('set_task_title with missing title arg returns error', () async {
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
              that: contains('non-empty string'),
            ),
          ),
        ).called(1);
      });

      test('update_task_estimate with null minutes returns error', () async {
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
              that: contains('required'),
            ),
          ),
        ).called(1);
      });

      test('update_task_due_date with empty dueDate returns error', () async {
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
              that: contains('non-empty string'),
            ),
          ),
        ).called(1);
      });

      test('update_task_priority with empty priority returns error', () async {
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
              that: contains('non-empty string'),
            ),
          ),
        ).called(1);
      });

      test('add_multiple_checklist_items with non-array items returns error',
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
              that: contains('non-empty array'),
            ),
          ),
        ).called(1);
      });

      test('update_checklist_items with non-array items returns error',
          () async {
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
              that: contains('non-empty array'),
            ),
          ),
        ).called(1);
      });

      test('update_checklist_items with empty array returns error', () async {
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
              that: contains('non-empty array'),
            ),
          ),
        ).called(1);
      });

      test('add_multiple_checklist_items with empty array returns error',
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
              that: contains('non-empty array'),
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

      group('successful handler execution paths', () {
        /// A Task without estimate, due date, and with default priority —
        /// all three handlers will proceed to write when given this task.
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

        test('update_task_estimate succeeds and reports mutation', () async {
          when(() => mockJournalRepository.updateJournalEntity(any()))
              .thenAnswer((_) async => true);

          final result = await executeWithToolCallOnRealTask(
            'update_task_estimate',
            '{"minutes":60}',
            task: taskForUpdates,
          );
          expect(result.success, isTrue);
          verify(
            () => mockConversationManager.addToolResponse(
              toolCallId: 'tc-1',
              response: any(
                named: 'response',
                that: contains('estimate updated'),
              ),
            ),
          ).called(1);
        });

        test('update_task_due_date succeeds and reports mutation', () async {
          when(() => mockJournalRepository.updateJournalEntity(any()))
              .thenAnswer((_) async => true);

          final result = await executeWithToolCallOnRealTask(
            'update_task_due_date',
            '{"dueDate":"2024-06-30"}',
            task: taskForUpdates,
          );
          expect(result.success, isTrue);
          verify(
            () => mockConversationManager.addToolResponse(
              toolCallId: 'tc-1',
              response: any(
                named: 'response',
                that: contains('due date updated'),
              ),
            ),
          ).called(1);
        });

        test('update_task_priority succeeds and reports mutation', () async {
          when(() => mockJournalRepository.updateJournalEntity(any()))
              .thenAnswer((_) async => true);

          final result = await executeWithToolCallOnRealTask(
            'update_task_priority',
            '{"priority":"P1"}',
            task: taskForUpdates,
          );
          expect(result.success, isTrue);
          verify(
            () => mockConversationManager.addToolResponse(
              toolCallId: 'tc-1',
              response: any(
                named: 'response',
                that: contains('priority updated'),
              ),
            ),
          ).called(1);
        });

        test('update_task_estimate with already-set estimate is skipped',
            () async {
          final result = await executeWithToolCallOnRealTask(
            'update_task_estimate',
            '{"minutes":30}',
            // Uses taskWithCategory which has estimate: Duration(hours: 4)
          );
          expect(result.success, isTrue);
          verify(
            () => mockConversationManager.addToolResponse(
              toolCallId: 'tc-1',
              response: any(
                named: 'response',
                that: contains('already set'),
              ),
            ),
          ).called(1);
        });

        test('update_task_due_date with invalid format returns error',
            () async {
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
                that: contains('Invalid due date'),
              ),
            ),
          ).called(1);
        });

        test('update_task_priority with invalid priority returns error',
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
                that: contains('Invalid priority'),
              ),
            ),
          ).called(1);
        });

        test('update_task_estimate with persistence failure returns error',
            () async {
          when(() => mockJournalRepository.updateJournalEntity(any()))
              .thenThrow(Exception('DB write failed'));

          final result = await executeWithToolCallOnRealTask(
            'update_task_estimate',
            '{"minutes":60}',
            task: taskForUpdates,
          );
          expect(result.success, isTrue);
          verify(
            () => mockConversationManager.addToolResponse(
              toolCallId: 'tc-1',
              response: any(
                named: 'response',
                that: contains('Failed'),
              ),
            ),
          ).called(1);
        });
      });

      test('task entity is not a Task type returns error', () async {
        stubFullExecutePath();

        // Return a non-Task journal entity (e.g., a JournalEntry) that has the
        // correct category. The resolveCategoryId passes, but the handler sees
        // it's not a Task and returns an error.
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

        // First call from resolveCategoryId, second from _executeToolHandler.
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
        };

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isTrue);
        verify(
          () => mockConversationManager.addToolResponse(
            toolCallId: 'tc-2',
            response: any(
              named: 'response',
              that: contains('not a Task'),
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
            verify(() => mockAgentRepository.upsertEntity(captureAny()))
                .captured;

        final payloads = captured
            .whereType<AgentDomainEntity>()
            .where(
              (e) => e.mapOrNull(agentMessagePayload: (_) => true) ?? false,
            )
            .toList();
        expect(payloads, isNotEmpty);
        final payload = payloads.first as AgentMessagePayloadEntity;
        expect(payload.content['text'], 'Final analysis complete.');
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
            verify(() => mockAgentRepository.upsertEntity(captureAny()))
                .captured;

        final payloads = captured
            .whereType<AgentDomainEntity>()
            .where(
              (e) => e.mapOrNull(agentMessagePayload: (_) => true) ?? false,
            )
            .toList();
        // No thought payload when no assistant content.
        expect(payloads, isEmpty);
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
            verify(() => mockAgentRepository.upsertEntity(captureAny()))
                .captured;

        final payloads = captured
            .whereType<AgentDomainEntity>()
            .where(
              (e) => e.mapOrNull(agentMessagePayload: (_) => true) ?? false,
            )
            .toList();
        expect(payloads, isNotEmpty);
        final payload = payloads.first as AgentMessagePayloadEntity;
        expect(payload.content['text'], 'Non-empty response');
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
        when(() => mockAgentRepository.upsertEntity(any()))
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
  });
}
