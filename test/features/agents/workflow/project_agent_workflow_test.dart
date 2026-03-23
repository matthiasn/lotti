import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/tools/project_tool_definitions.dart';
import 'package:lotti/features/agents/workflow/project_agent_workflow.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../test_utils.dart';

/// Minimal mock of [ConversationRepository] for workflow tests.
class _MockConversationRepository extends ConversationRepository {
  _MockConversationRepository(this._mockManager);

  final MockConversationManager _mockManager;
  final List<String> deletedConversationIds = [];

  Future<InferenceUsage?> Function({
    required String conversationId,
    required String message,
    required String model,
    required AiConfigInferenceProvider provider,
    required InferenceRepositoryInterface inferenceRepo,
    List<ChatCompletionTool>? tools,
    double temperature,
    ConversationStrategy? strategy,
  })?
  sendMessageDelegate;

  @override
  void build() {}

  @override
  String createConversation({String? systemMessage, int maxTurns = 20}) {
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

void main() {
  late MockAgentRepository mockAgentRepository;
  late MockAgentSyncService mockSyncService;
  late _MockConversationRepository mockConversationRepository;
  late MockAiConfigRepository mockAiConfigRepository;
  late MockCloudInferenceRepository mockCloudInferenceRepository;
  late MockConversationManager mockConversationManager;
  late MockJournalRepository mockJournalRepository;
  late MockAgentTemplateService mockTemplateService;
  late ProjectAgentWorkflow workflow;

  const agentId = 'agent-001';
  const projectId = 'project-001';
  const runKey = 'run-key-001';
  const threadId = 'thread-001';

  final testAgentIdentity = makeTestIdentity(
    kind: 'project_agent',
    config: const AgentConfig(profileId: 'profile-001'),
  );

  final testAgentState = makeTestState(
    slots: const AgentSlots(activeProjectId: projectId),
  );

  final testAgentStateNoProject = makeTestState();

  final testTemplate = makeTestTemplate();
  final testTemplateVersion = makeTestTemplateVersion(
    directives: 'You are a project oversight agent.',
  );

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

  final testProfile =
      AiConfig.inferenceProfile(
            id: 'profile-001',
            name: 'Test Profile',
            createdAt: DateTime(2024),
            thinkingModelId: 'models/test-model-v1',
          )
          as AiConfigInferenceProfile;

  final testModel =
      AiConfig.model(
            id: 'model-001',
            name: 'Test Model',
            providerModelId: 'models/test-model-v1',
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
    mockConversationRepository = _MockConversationRepository(
      mockConversationManager,
    );
    mockAiConfigRepository = MockAiConfigRepository();
    mockCloudInferenceRepository = MockCloudInferenceRepository();
    mockJournalRepository = MockJournalRepository();
    mockTemplateService = MockAgentTemplateService();

    registerAllFallbackValues();

    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<PersistenceLogic>(MockPersistenceLogic());
      },
    );

    when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
    when(
      () => mockAgentRepository.updateWakeRunTemplate(
        any(),
        any(),
        any(),
        resolvedModelId: any(named: 'resolvedModelId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockAgentRepository.getLatestReport(any(), any()),
    ).thenAnswer((_) async => null);
    when(
      () => mockAgentRepository.getLinksToMultiple(
        any(),
        type: any(named: 'type'),
      ),
    ).thenAnswer((_) async => {});
    when(
      () => mockAgentRepository.getLatestReportsByAgentIds(any(), any()),
    ).thenAnswer((_) async => {});
    when(() => mockConversationManager.messages).thenReturn([]);

    workflow = ProjectAgentWorkflow(
      agentRepository: mockAgentRepository,
      conversationRepository: mockConversationRepository,
      aiConfigRepository: mockAiConfigRepository,
      cloudInferenceRepository: mockCloudInferenceRepository,
      journalRepository: mockJournalRepository,
      syncService: mockSyncService,
      templateService: mockTemplateService,
    );
  });

  tearDown(tearDownTestGetIt);

  group('ProjectAgentWorkflow', () {
    group('early abort conditions', () {
      test('returns failure when agent state is null', () async {
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
        expect(result.error, contains('No agent state'));
      });

      test('returns failure when no active project ID in slots', () async {
        when(
          () => mockAgentRepository.getAgentState(agentId),
        ).thenAnswer((_) async => testAgentStateNoProject);

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isFalse);
        expect(result.error, contains('No active project ID'));
      });

      test('returns failure when project entity not found', () async {
        when(
          () => mockAgentRepository.getAgentState(agentId),
        ).thenAnswer((_) async => testAgentState);
        when(
          () => mockJournalRepository.getJournalEntityById(projectId),
        ).thenAnswer((_) async => null);

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isFalse);
        expect(result.error, contains('Project not found'));
      });

      test('returns failure when no template resolved', () async {
        when(
          () => mockAgentRepository.getAgentState(agentId),
        ).thenAnswer((_) async => testAgentState);
        when(
          () => mockJournalRepository.getJournalEntityById(projectId),
        ).thenAnswer((_) async => _fakeProjectEntity());
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
          () => mockTemplateService.getTemplateForAgent(agentId),
        ).thenAnswer((_) async => null);

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isFalse);
        expect(result.error, contains('No inference provider'));
      });

      test('returns failure when profile resolution fails', () async {
        when(
          () => mockAgentRepository.getAgentState(agentId),
        ).thenAnswer((_) async => testAgentState);
        when(
          () => mockJournalRepository.getJournalEntityById(projectId),
        ).thenAnswer((_) async => _fakeProjectEntity());
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
          () => mockTemplateService.getTemplateForAgent(agentId),
        ).thenAnswer((_) async => testTemplate);
        when(
          () => mockTemplateService.getActiveVersion(testTemplate.id),
        ).thenAnswer((_) async => testTemplateVersion);
        // Profile found but provider resolution fails (no API key).
        when(
          () => mockAiConfigRepository.getConfigById('profile-001'),
        ).thenAnswer((_) async => testProfile);
        when(
          () => mockAiConfigRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => [testModel]);
        when(
          () => mockAiConfigRepository.getConfigById('gemini-provider-001'),
        ).thenAnswer((_) async => null);

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isFalse);
        expect(result.error, contains('No inference provider'));
      });
    });

    group('successful execution', () {
      setUp(() {
        when(
          () => mockAgentRepository.getAgentState(agentId),
        ).thenAnswer((_) async => testAgentState);
        when(
          () => mockJournalRepository.getJournalEntityById(projectId),
        ).thenAnswer((_) async => _fakeProjectEntity());
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
          () => mockTemplateService.getTemplateForAgent(agentId),
        ).thenAnswer((_) async => testTemplate);
        when(
          () => mockTemplateService.getActiveVersion(testTemplate.id),
        ).thenAnswer((_) async => testTemplateVersion);
        when(
          () => mockAiConfigRepository.getConfigById('profile-001'),
        ).thenAnswer((_) async => testProfile);
        when(
          () => mockAiConfigRepository.getConfigById('model-001'),
        ).thenAnswer((_) async => testModel);
        when(
          () => mockAiConfigRepository.getConfigById('gemini-provider-001'),
        ).thenAnswer((_) async => geminiProvider);
        when(
          () => mockAiConfigRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => [testModel]);
        when(
          () => mockAgentRepository.getReportHead(agentId, 'current'),
        ).thenAnswer((_) async => null);
        when(
          () => mockJournalRepository.getLinkedEntities(
            linkedTo: projectId,
          ),
        ).thenAnswer((_) async => []);
      });

      test('completes successfully and persists state', () async {
        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isTrue);

        // Verify conversation was cleaned up.
        expect(
          mockConversationRepository.deletedConversationIds,
          contains('test-conv-id'),
        );
      });

      test('persists user message and state update', () async {
        await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        // User message payload + user message + state update inside
        // transaction = at least 3 upsertEntity calls.
        verify(() => mockSyncService.upsertEntity(any())).called(
          greaterThanOrEqualTo(3),
        );
      });

      test(
        'skips due scheduled wake when no pending project activity exists',
        () async {
          final testDate = DateTime(2026, 3, 20, 6, 30);
          final dueState = makeTestState(
            slots: const AgentSlots(activeProjectId: projectId),
            scheduledWakeAt: DateTime(2026, 3, 20, 6),
          );
          when(
            () => mockAgentRepository.getAgentState(agentId),
          ).thenAnswer((_) async => dueState);
          when(
            () => mockAgentRepository.getLatestReport(agentId, 'current'),
          ).thenAnswer((_) async => makeTestReport());

          await withClock(Clock.fixed(testDate), () async {
            await workflow.execute(
              agentIdentity: testAgentIdentity,
              runKey: runKey,
              triggerTokens: const {},
              threadId: threadId,
            );
          });

          final captured = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;
          final updatedState = captured.single as AgentStateEntity;
          expect(updatedState.scheduledWakeAt, DateTime(2026, 3, 21, 6));
          expect(updatedState.slots.lastDailyWakeAt, isNull);
          expect(mockConversationRepository.deletedConversationIds, isEmpty);
          verifyNever(
            () => mockAgentRepository.updateWakeRunTemplate(
              any(),
              any(),
              any(),
              resolvedModelId: any(named: 'resolvedModelId'),
            ),
          );
        },
      );

      test(
        'rolls forward the daily digest schedule when the scheduled wake is due',
        () async {
          final testDate = DateTime(2026, 3, 20, 6, 30);
          final dueState = makeTestState(
            slots: AgentSlots(
              activeProjectId: projectId,
              pendingProjectActivityAt: DateTime(2026, 3, 20, 5),
            ),
            scheduledWakeAt: DateTime(2026, 3, 20, 6),
          );
          when(
            () => mockAgentRepository.getAgentState(agentId),
          ).thenAnswer((_) async => dueState);
          when(
            () => mockAgentRepository.getLatestReport(agentId, 'current'),
          ).thenAnswer((_) async => makeTestReport());

          await withClock(Clock.fixed(testDate), () async {
            await workflow.execute(
              agentIdentity: testAgentIdentity,
              runKey: runKey,
              triggerTokens: const {},
              threadId: threadId,
            );
          });

          final captured = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;
          final updatedState = captured.whereType<AgentStateEntity>().last;
          expect(updatedState.scheduledWakeAt, DateTime(2026, 3, 21, 6));
          expect(updatedState.slots.lastDailyWakeAt, testDate);
          expect(updatedState.slots.pendingProjectActivityAt, isNull);
        },
      );

      test(
        'keeps the future digest schedule and clears pending activity on non-due wakes',
        () async {
          final testDate = DateTime(2026, 3, 20, 9);
          final futureSchedule = DateTime(2026, 3, 21, 6);
          final scheduledState = makeTestState(
            slots: AgentSlots(
              activeProjectId: projectId,
              pendingProjectActivityAt: DateTime(2026, 3, 20, 8),
            ),
            scheduledWakeAt: futureSchedule,
          );
          when(
            () => mockAgentRepository.getAgentState(agentId),
          ).thenAnswer((_) async => scheduledState);
          when(
            () => mockAgentRepository.getLatestReport(agentId, 'current'),
          ).thenAnswer((_) async => makeTestReport());

          await withClock(Clock.fixed(testDate), () async {
            await workflow.execute(
              agentIdentity: testAgentIdentity,
              runKey: runKey,
              triggerTokens: {'entity-a'},
              threadId: threadId,
            );
          });

          final captured = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;
          final updatedState = captured.whereType<AgentStateEntity>().last;
          expect(updatedState.scheduledWakeAt, futureSchedule);
          expect(updatedState.slots.lastDailyWakeAt, isNull);
          expect(updatedState.slots.pendingProjectActivityAt, isNull);
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
            resolvedModelId: 'models/test-model-v1',
          ),
        ).called(1);
      });

      test('cleans up conversation even on failure', () async {
        mockConversationRepository.sendMessageDelegate =
            ({
              required conversationId,
              required message,
              required model,
              required provider,
              required inferenceRepo,
              tools,
              temperature = 0.7,
              strategy,
            }) async {
              throw Exception('LLM error');
            };

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isFalse);
        expect(
          mockConversationRepository.deletedConversationIds,
          contains('test-conv-id'),
        );
      });

      test('increments failure count on error', () async {
        mockConversationRepository.sendMessageDelegate =
            ({
              required conversationId,
              required message,
              required model,
              required provider,
              required inferenceRepo,
              tools,
              temperature = 0.7,
              strategy,
            }) async {
              throw Exception('LLM error');
            };

        await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        // Verify state was updated with incremented failure count.
        // The state update outside the transaction (for failure) is the 3rd
        // upsertEntity call (after user message payload + user message).
        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;

        final stateUpdates = captured.whereType<AgentStateEntity>().where(
          (s) => s.consecutiveFailureCount > 0,
        );
        expect(stateUpdates, isNotEmpty);
      });
      test('includes linked task context in user message', () async {
        final linkedTask = _fakeTaskEntity(
          title: 'Implement API',
          status: TaskStatus.inProgress(
            id: 'status-t1',
            createdAt: DateTime(2024, 6, 20),
            utcOffset: 0,
          ),
        );

        when(
          () => mockJournalRepository.getLinkedEntities(
            linkedTo: projectId,
          ),
        ).thenAnswer((_) async => [linkedTask]);

        when(
          () => mockAgentRepository.getLinksToMultiple(
            ['task-001'],
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer((_) async => {});

        String? capturedMessage;
        mockConversationRepository.sendMessageDelegate =
            ({
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
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(capturedMessage, isNotNull);
        expect(capturedMessage, contains('Linked Tasks'));
        expect(capturedMessage, contains('Implement API'));
        expect(capturedMessage, contains('in_progress'));
      });

      test('includes task-agent report in linked task context', () async {
        final linkedTask = _fakeTaskEntity(
          id: 'task-002',
          title: 'Write Tests',
        );

        when(
          () => mockJournalRepository.getLinkedEntities(
            linkedTo: projectId,
          ),
        ).thenAnswer((_) async => [linkedTask]);

        final agentLink = AgentLink.agentTask(
          id: 'link-ta-1',
          fromId: 'task-agent-1',
          toId: 'task-002',
          createdAt: kAgentTestDate,
          updatedAt: kAgentTestDate,
          vectorClock: null,
        );

        when(
          () => mockAgentRepository.getLinksToMultiple(
            ['task-002'],
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer(
          (_) async => {
            'task-002': [agentLink],
          },
        );

        final taskReport = makeTestReport(
          agentId: 'task-agent-1',
          createdAt: DateTime(2024, 6, 21, 9, 30),
          content: 'Task is 80% complete with 3 tests passing.',
        );

        when(
          () => mockAgentRepository.getLatestReportsByAgentIds(
            ['task-agent-1'],
            'current',
          ),
        ).thenAnswer(
          (_) async => {'task-agent-1': taskReport},
        );

        String? capturedMessage;
        mockConversationRepository.sendMessageDelegate =
            ({
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
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(capturedMessage, contains('80% complete'));
        expect(capturedMessage, contains('task-agent-1'));
        expect(
          capturedMessage,
          contains(DateTime(2024, 6, 21, 9, 30).toIso8601String()),
        );
      });

      test('resolves observation payloads into user message', () async {
        final observation = makeTestMessage(
          id: 'obs-msg-1',
          kind: AgentMessageKind.observation,
          contentEntryId: 'obs-payload-1',
        );

        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.observation,
          ),
        ).thenAnswer((_) async => [observation]);

        final payload = makeTestMessagePayload(
          id: 'obs-payload-1',
          content: <String, Object?>{'text': 'Sprint velocity is declining'},
        );

        when(
          () => mockAgentRepository.getEntity('obs-payload-1'),
        ).thenAnswer((_) async => payload);

        String? capturedMessage;
        mockConversationRepository.sendMessageDelegate =
            ({
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
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(capturedMessage, contains('Sprint velocity is declining'));
      });

      test('renders placeholder for missing observation payload', () async {
        final observation = makeTestMessage(
          id: 'obs-msg-2',
          kind: AgentMessageKind.observation,
          contentEntryId: 'missing-payload',
        );

        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.observation,
          ),
        ).thenAnswer((_) async => [observation]);

        when(
          () => mockAgentRepository.getEntity('missing-payload'),
        ).thenAnswer((_) async => null);

        String? capturedMessage;
        mockConversationRepository.sendMessageDelegate =
            ({
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
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(capturedMessage, contains('(no content)'));
      });

      test('persists deferred items as change set', () async {
        mockConversationRepository.sendMessageDelegate =
            ({
              required conversationId,
              required message,
              required model,
              required provider,
              required inferenceRepo,
              tools,
              temperature = 0.7,
              strategy,
            }) async {
              if (strategy != null) {
                final toolCalls = [
                  ChatCompletionMessageToolCall(
                    id: 'call-def-1',
                    type: ChatCompletionMessageToolCallType.function,
                    function: ChatCompletionMessageFunctionCall(
                      name: ProjectAgentToolNames.createTask,
                      arguments: jsonEncode({
                        'title': 'Add monitoring',
                        'description': 'Set up alerts',
                        'priority': 'HIGH',
                      }),
                    ),
                  ),
                  ChatCompletionMessageToolCall(
                    id: 'call-def-2',
                    type: ChatCompletionMessageToolCallType.function,
                    function: ChatCompletionMessageFunctionCall(
                      name: ProjectAgentToolNames.updateProjectStatus,
                      arguments: jsonEncode({
                        'status': 'at_risk',
                        'reason': 'Dependency delayed',
                      }),
                    ),
                  ),
                ];

                final manager = mockConversationRepository.getConversation(
                  conversationId,
                )!;
                when(
                  () => manager.addToolResponse(
                    toolCallId: any(named: 'toolCallId'),
                    response: any(named: 'response'),
                  ),
                ).thenReturn(null);

                await strategy.processToolCalls(
                  toolCalls: toolCalls,
                  manager: manager,
                );
              }
              return null;
            };

        await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;

        final changeSets = captured.whereType<ChangeSetEntity>().toList();
        expect(changeSets, hasLength(1));

        final changeSet = changeSets.first;
        expect(changeSet.agentId, agentId);
        expect(changeSet.taskId, projectId);
        expect(changeSet.threadId, threadId);
        expect(changeSet.runKey, runKey);
        expect(changeSet.status, ChangeSetStatus.pending);
        expect(changeSet.items, hasLength(2));
        expect(
          changeSet.items[0].toolName,
          ProjectAgentToolNames.createTask,
        );
        expect(changeSet.items[0].humanSummary, contains('Add monitoring'));
        expect(
          changeSet.items[1].toolName,
          ProjectAgentToolNames.updateProjectStatus,
        );
        expect(changeSet.items[1].humanSummary, contains('at_risk'));
      });

      test('does not create change set when no deferred items', () async {
        await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;

        final changeSets = captured.whereType<ChangeSetEntity>().toList();
        expect(changeSets, isEmpty);
      });

      test('includes previous report in user message', () async {
        final previousReport = makeTestReport(
          content: '# Previous Project Report\nAll systems operational.',
          tldr: 'All good.',
        );

        when(
          () => mockAgentRepository.getLatestReport(agentId, 'current'),
        ).thenAnswer((_) async => previousReport);

        String? capturedMessage;
        mockConversationRepository.sendMessageDelegate =
            ({
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
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(capturedMessage, contains('Previous Report'));
        expect(capturedMessage, contains('All systems operational'));
      });

      test('handles linked tasks context error gracefully', () async {
        when(
          () => mockJournalRepository.getLinkedEntities(
            linkedTo: projectId,
          ),
        ).thenThrow(Exception('DB connection lost'));

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isTrue);
      });

      test('handles observation payload resolution error gracefully', () async {
        final observation = makeTestMessage(
          id: 'obs-err',
          kind: AgentMessageKind.observation,
          contentEntryId: 'payload-err',
        );

        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.observation,
          ),
        ).thenAnswer((_) async => [observation]);

        when(
          () => mockAgentRepository.getEntity('payload-err'),
        ).thenThrow(Exception('Storage error'));

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isTrue);
      });

      test(
        'writes project context with target date and on-hold reason',
        () async {
          final onHoldProject = JournalEntity.project(
            meta: Metadata(
              id: projectId,
              createdAt: DateTime(2024, 6, 15),
              updatedAt: DateTime(2024, 6, 15),
              dateFrom: DateTime(2024, 6, 15),
              dateTo: DateTime(2024, 6, 15),
            ),
            data: ProjectData(
              title: 'On Hold Project',
              status: ProjectStatus.onHold(
                id: 'status-oh',
                createdAt: DateTime(2024, 7),
                utcOffset: 0,
                reason: 'Waiting for vendor delivery',
              ),
              dateFrom: DateTime(2024, 6, 15),
              dateTo: DateTime(2024, 12, 31),
              targetDate: DateTime(2025, 3),
            ),
          );

          when(
            () => mockJournalRepository.getJournalEntityById(projectId),
          ).thenAnswer((_) async => onHoldProject);

          String? capturedMessage;
          mockConversationRepository.sendMessageDelegate =
              ({
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
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(capturedMessage, contains('On Hold Project'));
          expect(capturedMessage, contains('Target date'));
          expect(capturedMessage, contains('2025-03-01'));
          expect(capturedMessage, contains('On-hold reason'));
          expect(capturedMessage, contains('Waiting for vendor delivery'));
        },
      );

      test(
        'persists recommend_next_steps with correct human summary',
        () async {
          mockConversationRepository.sendMessageDelegate =
              ({
                required conversationId,
                required message,
                required model,
                required provider,
                required inferenceRepo,
                tools,
                temperature = 0.7,
                strategy,
              }) async {
                if (strategy != null) {
                  final toolCalls = [
                    ChatCompletionMessageToolCall(
                      id: 'call-rec-1',
                      type: ChatCompletionMessageToolCallType.function,
                      function: ChatCompletionMessageFunctionCall(
                        name: ProjectAgentToolNames.recommendNextSteps,
                        arguments: jsonEncode({
                          'steps': [
                            {
                              'title': 'Prioritize API',
                              'rationale': 'Scaling issues',
                              'priority': 'high',
                            },
                            {
                              'title': 'Write tests',
                              'rationale': 'Coverage low',
                              'priority': 'medium',
                            },
                          ],
                        }),
                      ),
                    ),
                  ];

                  final manager = mockConversationRepository.getConversation(
                    conversationId,
                  )!;
                  when(
                    () => manager.addToolResponse(
                      toolCallId: any(named: 'toolCallId'),
                      response: any(named: 'response'),
                    ),
                  ).thenReturn(null);

                  await strategy.processToolCalls(
                    toolCalls: toolCalls,
                    manager: manager,
                  );
                }
                return null;
              };

          await workflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          final captured = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;

          final changeSets = captured.whereType<ChangeSetEntity>().toList();
          expect(changeSets, hasLength(1));
          expect(changeSets.first.items.first.humanSummary, contains('2'));
          expect(
            changeSets.first.items.first.humanSummary,
            contains('next step'),
          );
        },
      );

      test('persists token usage when returned by sendMessage', () async {
        mockConversationRepository.sendMessageDelegate =
            ({
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

        await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;

        final tokenUsages = captured.whereType<WakeTokenUsageEntity>().toList();
        expect(tokenUsages, hasLength(1));
        expect(tokenUsages.first.inputTokens, 100);
        expect(tokenUsages.first.outputTokens, 50);
        expect(tokenUsages.first.modelId, 'models/test-model-v1');
      });

      test('persists report and updates report head', () async {
        mockConversationRepository.sendMessageDelegate =
            ({
              required conversationId,
              required message,
              required model,
              required provider,
              required inferenceRepo,
              tools,
              temperature = 0.7,
              strategy,
            }) async {
              if (strategy != null) {
                final toolCalls = [
                  ChatCompletionMessageToolCall(
                    id: 'call-rpt',
                    type: ChatCompletionMessageToolCallType.function,
                    function: ChatCompletionMessageFunctionCall(
                      name: ProjectAgentToolNames.updateProjectReport,
                      arguments: jsonEncode({
                        'markdown': '# Status Report\nAll good.',
                        'tldr': 'On track.',
                      }),
                    ),
                  ),
                ];

                final manager = mockConversationRepository.getConversation(
                  conversationId,
                )!;
                when(
                  () => manager.addToolResponse(
                    toolCallId: any(named: 'toolCallId'),
                    response: any(named: 'response'),
                  ),
                ).thenReturn(null);

                await strategy.processToolCalls(
                  toolCalls: toolCalls,
                  manager: manager,
                );
              }
              return null;
            };

        await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;

        final reports = captured.whereType<AgentReportEntity>().toList();
        expect(reports, hasLength(1));
        expect(reports.first.content, '# Status Report\nAll good.');
        expect(reports.first.tldr, 'On track.');

        final heads = captured.whereType<AgentReportHeadEntity>().toList();
        expect(heads, hasLength(1));
      });

      test('persists observations with payloads', () async {
        mockConversationRepository.sendMessageDelegate =
            ({
              required conversationId,
              required message,
              required model,
              required provider,
              required inferenceRepo,
              tools,
              temperature = 0.7,
              strategy,
            }) async {
              if (strategy != null) {
                final toolCalls = [
                  ChatCompletionMessageToolCall(
                    id: 'call-obs',
                    type: ChatCompletionMessageToolCallType.function,
                    function: ChatCompletionMessageFunctionCall(
                      name: ProjectAgentToolNames.recordObservations,
                      arguments: jsonEncode({
                        'observations': ['Team morale is high'],
                      }),
                    ),
                  ),
                ];

                final manager = mockConversationRepository.getConversation(
                  conversationId,
                )!;
                when(
                  () => manager.addToolResponse(
                    toolCallId: any(named: 'toolCallId'),
                    response: any(named: 'response'),
                  ),
                ).thenReturn(null);

                await strategy.processToolCalls(
                  toolCalls: toolCalls,
                  manager: manager,
                );
              }
              return null;
            };

        await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;

        final payloads = captured
            .whereType<AgentMessagePayloadEntity>()
            .toList();
        // User message payload + observation payload = 2.
        expect(payloads.length, greaterThanOrEqualTo(2));

        final obsPayload = payloads.firstWhere(
          (p) => p.content['text'] == 'Team morale is high',
        );
        expect(obsPayload.content['priority'], 'routine');
        expect(obsPayload.content['category'], 'operational');
      });

      test('persists final assistant response as thought', () async {
        when(() => mockConversationManager.messages).thenReturn([
          const ChatCompletionMessage.assistant(
            content: 'Here is my analysis of the project.',
          ),
        ]);

        await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;

        final thoughtPayloads = captured
            .whereType<AgentMessagePayloadEntity>()
            .where(
              (p) => p.content['text'] == 'Here is my analysis of the project.',
            )
            .toList();
        expect(thoughtPayloads, hasLength(1));

        final thoughtMessages = captured
            .whereType<AgentMessageEntity>()
            .where((m) => m.kind == AgentMessageKind.thought)
            .toList();
        expect(thoughtMessages, hasLength(1));
      });

      test('linked task with multiple statuses maps correctly', () async {
        final tasks = [
          _fakeTaskEntity(
            id: 'task-done',
            title: 'Done Task',
            status: TaskStatus.done(
              id: 's1',
              createdAt: DateTime(2024, 7),
              utcOffset: 0,
            ),
          ),
          _fakeTaskEntity(
            id: 'task-blocked',
            title: 'Blocked Task',
            status: TaskStatus.blocked(
              id: 's2',
              createdAt: DateTime(2024, 7),
              utcOffset: 0,
              reason: 'Waiting on API',
            ),
          ),
          _fakeTaskEntity(
            id: 'task-groomed',
            title: 'Groomed Task',
            status: TaskStatus.groomed(
              id: 's3',
              createdAt: DateTime(2024, 7),
              utcOffset: 0,
            ),
          ),
          _fakeTaskEntity(
            id: 'task-onhold',
            title: 'On Hold Task',
            status: TaskStatus.onHold(
              id: 's4',
              createdAt: DateTime(2024, 7),
              utcOffset: 0,
              reason: 'Deprioritized',
            ),
          ),
          _fakeTaskEntity(
            id: 'task-rejected',
            title: 'Rejected Task',
            status: TaskStatus.rejected(
              id: 's5',
              createdAt: DateTime(2024, 7),
              utcOffset: 0,
            ),
          ),
        ];

        when(
          () => mockJournalRepository.getLinkedEntities(
            linkedTo: projectId,
          ),
        ).thenAnswer((_) async => tasks);

        when(
          () => mockAgentRepository.getLinksToMultiple(
            tasks.map((t) => t.meta.id).toList(),
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer((_) async => {});

        String? capturedMessage;
        mockConversationRepository.sendMessageDelegate =
            ({
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
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(capturedMessage, contains('"done"'));
        expect(capturedMessage, contains('"blocked"'));
        expect(capturedMessage, contains('"groomed"'));
        expect(capturedMessage, contains('"on_hold"'));
        expect(capturedMessage, contains('"rejected"'));
      });

      test('uses generalDirective from template version', () async {
        when(
          () => mockTemplateService.getActiveVersion(testTemplate.id),
        ).thenAnswer(
          (_) async => makeTestTemplateVersion(
            directives: 'fallback directives',
            generalDirective: 'You are a senior PM agent.',
          ),
        );

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isTrue);
      });

      test('uses existing report head ID when updating', () async {
        final existingHead =
            AgentDomainEntity.agentReportHead(
                  id: 'existing-head-id',
                  agentId: agentId,
                  scope: AgentReportScopes.current,
                  reportId: 'old-report-id',
                  updatedAt: DateTime(2024, 5),
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
              temperature = 0.7,
              strategy,
            }) async {
              if (strategy != null) {
                final toolCalls = [
                  ChatCompletionMessageToolCall(
                    id: 'call-rpt2',
                    type: ChatCompletionMessageToolCallType.function,
                    function: ChatCompletionMessageFunctionCall(
                      name: ProjectAgentToolNames.updateProjectReport,
                      arguments: jsonEncode({'markdown': 'Updated report.'}),
                    ),
                  ),
                ];
                final manager = mockConversationRepository.getConversation(
                  conversationId,
                )!;
                when(
                  () => manager.addToolResponse(
                    toolCallId: any(named: 'toolCallId'),
                    response: any(named: 'response'),
                  ),
                ).thenReturn(null);
                await strategy.processToolCalls(
                  toolCalls: toolCalls,
                  manager: manager,
                );
              }
              return null;
            };

        await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;

        final heads = captured.whereType<AgentReportHeadEntity>().toList();
        expect(heads, hasLength(1));
        expect(heads.first.id, 'existing-head-id');
      });

      test('includes project description in user message', () async {
        final projectWithDesc = JournalEntity.project(
          meta: Metadata(
            id: projectId,
            createdAt: DateTime(2024, 6, 15),
            updatedAt: DateTime(2024, 6, 15),
            dateFrom: DateTime(2024, 6, 15),
            dateTo: DateTime(2024, 6, 15),
          ),
          data: ProjectData(
            title: 'Described Project',
            status: ProjectStatus.active(
              id: 'status-d',
              createdAt: DateTime(2024, 6, 15),
              utcOffset: 0,
            ),
            dateFrom: DateTime(2024, 6, 15),
            dateTo: DateTime(2024, 12, 31),
          ),
          entryText: const EntryText(
            plainText: 'A project to build a widget system.',
          ),
        );

        when(
          () => mockJournalRepository.getJournalEntityById(projectId),
        ).thenAnswer((_) async => projectWithDesc);

        String? capturedMessage;
        mockConversationRepository.sendMessageDelegate =
            ({
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
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(capturedMessage, contains('Description'));
        expect(
          capturedMessage,
          contains('A project to build a widget system.'),
        );
      });

      test('handles observation without contentEntryId', () async {
        final observation = makeTestMessage(
          id: 'obs-no-content',
          kind: AgentMessageKind.observation,
        );

        when(
          () => mockAgentRepository.getMessagesByKind(
            agentId,
            AgentMessageKind.observation,
          ),
        ).thenAnswer((_) async => [observation]);

        String? capturedMessage;
        mockConversationRepository.sendMessageDelegate =
            ({
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
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(capturedMessage, contains('(no content)'));
      });

      test('handles task-agent report resolution error gracefully', () async {
        final linkedTask = _fakeTaskEntity(
          id: 'task-err',
          title: 'Error Task',
        );

        when(
          () => mockJournalRepository.getLinkedEntities(
            linkedTo: projectId,
          ),
        ).thenAnswer((_) async => [linkedTask]);

        when(
          () => mockAgentRepository.getLinksToMultiple(
            ['task-err'],
            type: AgentLinkTypes.agentTask,
          ),
        ).thenThrow(Exception('Link lookup failed'));

        String? capturedMessage;
        mockConversationRepository.sendMessageDelegate =
            ({
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

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        // Should still succeed — error is caught inside
        // _resolveLatestTaskAgentReport.
        expect(result.success, isTrue);
        // Task still appears but without a task-agent report.
        expect(capturedMessage, contains('Error Task'));
        expect(capturedMessage, isNot(contains('taskAgentId')));
      });

      test('skips task-agent with empty report content', () async {
        final linkedTask = _fakeTaskEntity(
          id: 'task-empty-rpt',
          title: 'Empty Report Task',
        );

        when(
          () => mockJournalRepository.getLinkedEntities(
            linkedTo: projectId,
          ),
        ).thenAnswer((_) async => [linkedTask]);

        final agentLink = AgentLink.agentTask(
          id: 'link-ta-2',
          fromId: 'task-agent-2',
          toId: 'task-empty-rpt',
          createdAt: kAgentTestDate,
          updatedAt: kAgentTestDate,
          vectorClock: null,
        );

        when(
          () => mockAgentRepository.getLinksToMultiple(
            ['task-empty-rpt'],
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer(
          (_) async => {
            'task-empty-rpt': [agentLink],
          },
        );

        final emptyReport = makeTestReport(
          agentId: 'task-agent-2',
          content: '   ',
        );

        when(
          () => mockAgentRepository.getLatestReportsByAgentIds(
            ['task-agent-2'],
            'current',
          ),
        ).thenAnswer(
          (_) async => {'task-agent-2': emptyReport},
        );

        String? capturedMessage;
        mockConversationRepository.sendMessageDelegate =
            ({
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
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        // Should not include task-agent-2 since the report content was empty.
        expect(capturedMessage, isNot(contains('task-agent-2')));
      });

      test('handles batch report lookup failure gracefully', () async {
        final linkedTask = _fakeTaskEntity(
          id: 'task-report-err',
          title: 'Batch Report Failure Task',
        );

        when(
          () => mockJournalRepository.getLinkedEntities(
            linkedTo: projectId,
          ),
        ).thenAnswer((_) async => [linkedTask]);

        final agentLink = AgentLink.agentTask(
          id: 'link-batch-rpt',
          fromId: 'task-agent-batch',
          toId: 'task-report-err',
          createdAt: kAgentTestDate,
          updatedAt: kAgentTestDate,
          vectorClock: null,
        );

        when(
          () => mockAgentRepository.getLinksToMultiple(
            ['task-report-err'],
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer(
          (_) async => {
            'task-report-err': [agentLink],
          },
        );

        when(
          () => mockAgentRepository.getLatestReportsByAgentIds(
            ['task-agent-batch'],
            'current',
          ),
        ).thenThrow(Exception('Batch report lookup failed'));

        String? capturedMessage;
        mockConversationRepository.sendMessageDelegate =
            ({
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

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(result.success, isTrue);
        expect(capturedMessage, contains('Batch Report Failure Task'));
        expect(capturedMessage, isNot(contains('task-agent-batch')));
      });

      test('handles state update failure after main error', () async {
        mockConversationRepository.sendMessageDelegate =
            ({
              required conversationId,
              required message,
              required model,
              required provider,
              required inferenceRepo,
              tools,
              temperature = 0.7,
              strategy,
            }) async {
              throw Exception('LLM catastrophic failure');
            };

        // Make state update also fail.
        var callCount = 0;
        when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {
          callCount++;
          // Let the first 2 calls succeed (user message payload + user message)
          // then fail for the state update in the catch block.
          if (callCount > 2) {
            throw Exception('DB write failed');
          }
        });

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        // Should still return a failure result (not crash).
        expect(result.success, isFalse);
      });

      test('handles user message persistence failure gracefully', () async {
        var callCount = 0;
        when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {
          callCount++;
          // Fail on first call (user message payload).
          if (callCount == 1) {
            throw Exception('Persistence failed');
          }
        });

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        // Should still succeed — user message persistence is non-fatal.
        expect(result.success, isTrue);
      });

      test('handles token usage persistence failure gracefully', () async {
        mockConversationRepository.sendMessageDelegate =
            ({
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

        var entityCallCount = 0;
        when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {
          entityCallCount++;
          // Fail on 3rd call (token usage — after user payload and user msg).
          if (entityCallCount == 3) {
            throw Exception('Token usage persist failed');
          }
        });

        final result = await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        // Should still succeed — token usage persistence is non-fatal.
        expect(result.success, isTrue);
      });

      test('builds default human summary for unknown deferred tool', () async {
        mockConversationRepository.sendMessageDelegate =
            ({
              required conversationId,
              required message,
              required model,
              required provider,
              required inferenceRepo,
              tools,
              temperature = 0.7,
              strategy,
            }) async {
              if (strategy != null) {
                final toolCalls = [
                  ChatCompletionMessageToolCall(
                    id: 'call-status',
                    type: ChatCompletionMessageToolCallType.function,
                    function: ChatCompletionMessageFunctionCall(
                      name: ProjectAgentToolNames.updateProjectStatus,
                      arguments: jsonEncode({
                        'status': 'on_track',
                        'reason': 'All tasks progressing',
                      }),
                    ),
                  ),
                ];

                final manager = mockConversationRepository.getConversation(
                  conversationId,
                )!;
                when(
                  () => manager.addToolResponse(
                    toolCallId: any(named: 'toolCallId'),
                    response: any(named: 'response'),
                  ),
                ).thenReturn(null);

                await strategy.processToolCalls(
                  toolCalls: toolCalls,
                  manager: manager,
                );
              }
              return null;
            };

        await workflow.execute(
          agentIdentity: testAgentIdentity,
          runKey: runKey,
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;

        final changeSets = captured.whereType<ChangeSetEntity>().toList();
        expect(changeSets, hasLength(1));
        expect(
          changeSets.first.items.first.humanSummary,
          contains('on_track'),
        );
      });

      test(
        'uses scaffold-only system prompt when directive is empty',
        () async {
          when(
            () => mockTemplateService.getActiveVersion(testTemplate.id),
          ).thenAnswer(
            (_) async => makeTestTemplateVersion(
              directives: '   ',
            ),
          );

          final result = await workflow.execute(
            agentIdentity: testAgentIdentity,
            runKey: runKey,
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(result.success, isTrue);
        },
      );

      test('selects most recent task-agent link when multiple exist', () async {
        final linkedTask = _fakeTaskEntity(
          id: 'task-multi-link',
          title: 'Multi-Link Task',
        );

        when(
          () => mockJournalRepository.getLinkedEntities(
            linkedTo: projectId,
          ),
        ).thenAnswer((_) async => [linkedTask]);

        final olderLink = AgentLink.agentTask(
          id: 'link-old',
          fromId: 'old-agent',
          toId: 'task-multi-link',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: null,
        );

        final newerLink = AgentLink.agentTask(
          id: 'link-new',
          fromId: 'new-agent',
          toId: 'task-multi-link',
          createdAt: DateTime(2024, 6),
          updatedAt: DateTime(2024, 6),
          vectorClock: null,
        );

        when(
          () => mockAgentRepository.getLinksToMultiple(
            ['task-multi-link'],
            type: AgentLinkTypes.agentTask,
          ),
        ).thenAnswer(
          (_) async => {
            'task-multi-link': [olderLink, newerLink],
          },
        );

        final newerReport = makeTestReport(
          agentId: 'new-agent',
          content: 'Newer agent report.',
        );

        when(
          () => mockAgentRepository.getLatestReportsByAgentIds(
            any(),
            'current',
          ),
        ).thenAnswer(
          (_) async => {'new-agent': newerReport},
        );

        String? capturedMessage;
        mockConversationRepository.sendMessageDelegate =
            ({
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
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        // Should use the newer link's agent report.
        expect(capturedMessage, contains('Newer agent report'));
        expect(capturedMessage, contains('new-agent'));
      });

      test(
        'falls back to an older task-agent report when the newest link has none',
        () async {
          final linkedTask = _fakeTaskEntity(
            id: 'task-fallback-link',
            title: 'Fallback Task',
          );

          when(
            () => mockJournalRepository.getLinkedEntities(
              linkedTo: projectId,
            ),
          ).thenAnswer((_) async => [linkedTask]);

          final olderLink = AgentLink.agentTask(
            id: 'link-older',
            fromId: 'older-agent',
            toId: 'task-fallback-link',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
            vectorClock: null,
          );
          final newerLink = AgentLink.agentTask(
            id: 'link-newer',
            fromId: 'newer-agent',
            toId: 'task-fallback-link',
            createdAt: DateTime(2024, 6),
            updatedAt: DateTime(2024, 6),
            vectorClock: null,
          );

          when(
            () => mockAgentRepository.getLinksToMultiple(
              ['task-fallback-link'],
              type: AgentLinkTypes.agentTask,
            ),
          ).thenAnswer(
            (_) async => {
              'task-fallback-link': [olderLink, newerLink],
            },
          );

          final olderReport = makeTestReport(
            agentId: 'older-agent',
            content: 'Older agent still has the useful report.',
          );
          when(
            () => mockAgentRepository.getLatestReportsByAgentIds(
              any(),
              'current',
            ),
          ).thenAnswer((_) async => {'older-agent': olderReport});

          String? capturedMessage;
          mockConversationRepository.sendMessageDelegate =
              ({
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
            triggerTokens: {'entity-a'},
            threadId: threadId,
          );

          expect(
            capturedMessage,
            contains('Older agent still has the useful report.'),
          );
          expect(capturedMessage, contains('older-agent'));
          expect(capturedMessage, isNot(contains('newer-agent')));
        },
      );

      test('skips linked tasks section when no tasks are linked', () async {
        String? capturedMessage;
        mockConversationRepository.sendMessageDelegate =
            ({
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
          triggerTokens: {'entity-a'},
          threadId: threadId,
        );

        expect(capturedMessage, isNot(contains('Linked Tasks')));
      });
    });
  });
}

/// Creates a minimal fake task entity for testing.
JournalEntity _fakeTaskEntity({
  String id = 'task-001',
  String title = 'Test Task',
  TaskStatus? status,
}) {
  return JournalEntity.task(
    meta: Metadata(
      id: id,
      createdAt: DateTime(2024, 6, 15),
      updatedAt: DateTime(2024, 6, 15),
      dateFrom: DateTime(2024, 6, 15),
      dateTo: DateTime(2024, 6, 15),
    ),
    data: TaskData(
      title: title,
      dateFrom: DateTime(2024, 6, 15),
      dateTo: DateTime(2024, 6, 15),
      status:
          status ??
          TaskStatus.open(
            id: 'status-t1',
            createdAt: DateTime(2024, 6, 15),
            utcOffset: 0,
          ),
      statusHistory: [],
    ),
  );
}

/// Creates a minimal fake project entity for testing.
JournalEntity _fakeProjectEntity() {
  return JournalEntity.project(
    meta: Metadata(
      id: 'project-001',
      createdAt: DateTime(2024, 6, 15),
      updatedAt: DateTime(2024, 6, 15),
      dateFrom: DateTime(2024, 6, 15),
      dateTo: DateTime(2024, 6, 15),
    ),
    data: ProjectData(
      title: 'Test Project',
      status: ProjectStatus.active(
        id: 'status-001',
        createdAt: DateTime(2024, 6, 15),
        utcOffset: 0,
      ),
      dateFrom: DateTime(2024, 6, 15),
      dateTo: DateTime(2024, 12, 31),
    ),
  );
}
