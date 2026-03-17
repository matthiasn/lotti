import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
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

    when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async => {});
    when(
      () => mockAgentRepository.updateWakeRunTemplate(
        any(),
        any(),
        any(),
        resolvedModelId: any(named: 'resolvedModelId'),
      ),
    ).thenAnswer((_) async {});
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
    });
  });
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
