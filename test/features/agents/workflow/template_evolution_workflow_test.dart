import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/workflow/evolution_strategy.dart';
import 'package:lotti/features/agents/workflow/template_evolution_workflow.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../mocks/mocks.dart';
import '../test_utils.dart';

/// Test mock for ConversationRepository that controls the conversation flow.
class _TestConversationRepository extends ConversationRepository {
  _TestConversationRepository({this.assistantResponse});

  final String? assistantResponse;
  final List<String> deletedIds = [];

  /// Optional delegate to control sendMessage behavior (e.g., throwing).
  Future<void> Function()? sendMessageDelegate;

  @override
  void build() {}

  @override
  String createConversation({
    String? systemMessage,
    int maxTurns = 20,
  }) {
    return 'test-conv-id';
  }

  @override
  ConversationManager? getConversation(String conversationId) {
    if (assistantResponse == null) return null;

    final manager = ConversationManager(
      conversationId: conversationId,
      maxTurns: 1,
    )
      ..initialize()
      ..addAssistantMessage(content: assistantResponse);

    return manager;
  }

  @override
  void deleteConversation(String conversationId) {
    deletedIds.add(conversationId);
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
      await sendMessageDelegate!();
    }
    // Otherwise no-op: the assistant response is pre-loaded in getConversation.
  }
}

void main() {
  late MockAiConfigRepository mockAiConfig;
  late MockCloudInferenceRepository mockCloudInference;

  setUpAll(() {
    registerFallbackValue(AiConfigType.model);
    registerFallbackValue(
      AgentDomainEntity.unknown(
        id: 'fallback',
        agentId: 'fallback',
        createdAt: DateTime(2024),
      ),
    );
  });

  setUp(() {
    mockAiConfig = MockAiConfigRepository();
    mockCloudInference = MockCloudInferenceRepository();
  });

  void stubProviderResolution({String apiKey = 'test-key'}) {
    when(() => mockAiConfig.getConfigsByType(AiConfigType.model))
        .thenAnswer((_) async => [testAiModel()]);
    when(() => mockAiConfig.getConfigById('provider-1'))
        .thenAnswer((_) async => testInferenceProvider(apiKey: apiKey));
  }

  group('EvolutionFeedback', () {
    test('isEmpty returns true when all fields are blank', () {
      const feedback = EvolutionFeedback();
      expect(feedback.isEmpty, isTrue);
    });

    test('isEmpty returns false when any field has content', () {
      const feedback = EvolutionFeedback(enjoyed: 'great reports');
      expect(feedback.isEmpty, isFalse);
    });

    test('isEmpty trims whitespace', () {
      const feedback = EvolutionFeedback(enjoyed: '   ');
      expect(feedback.isEmpty, isTrue);
    });
  });

  group('proposeEvolution', () {
    test('returns proposal when provider resolves and LLM responds', () async {
      final convRepo = _TestConversationRepository(
        assistantResponse: 'You are an improved agent.',
      );
      stubProviderResolution();

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: convRepo,
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
      );

      final version = makeTestTemplateVersion();
      final proposal = await workflow.proposeEvolution(
        template: makeTestTemplate(),
        currentVersion: version,
        metrics: makeTestMetrics(),
        feedback: const EvolutionFeedback(
          enjoyed: 'Clear reports',
          didntWork: 'Too verbose',
          specificChanges: 'Be more concise',
        ),
      );

      expect(proposal, isNotNull);
      expect(proposal!.proposedDirectives, 'You are an improved agent.');
      expect(proposal.originalDirectives, version.directives);
      expect(convRepo.deletedIds, contains('test-conv-id'));
    });

    test('strips markdown fences from LLM response', () async {
      final convRepo = _TestConversationRepository(
        assistantResponse: '```\nYou are a better agent.\n```',
      );
      stubProviderResolution();

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: convRepo,
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
      );

      final proposal = await workflow.proposeEvolution(
        template: makeTestTemplate(),
        currentVersion: makeTestTemplateVersion(),
        metrics: makeTestMetrics(),
        feedback: const EvolutionFeedback(enjoyed: 'good'),
      );

      expect(proposal, isNotNull);
      expect(proposal!.proposedDirectives, 'You are a better agent.');
    });

    test('returns null when model is not configured', () async {
      final convRepo = _TestConversationRepository();

      when(() => mockAiConfig.getConfigsByType(AiConfigType.model))
          .thenAnswer((_) async => []);

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: convRepo,
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
      );

      final proposal = await workflow.proposeEvolution(
        template: makeTestTemplate(),
        currentVersion: makeTestTemplateVersion(),
        metrics: makeTestMetrics(),
        feedback: const EvolutionFeedback(enjoyed: 'good'),
      );

      expect(proposal, isNull);
    });

    test('returns null when provider has no API key', () async {
      final convRepo = _TestConversationRepository();
      stubProviderResolution(apiKey: '');

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: convRepo,
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
      );

      final proposal = await workflow.proposeEvolution(
        template: makeTestTemplate(),
        currentVersion: makeTestTemplateVersion(),
        metrics: makeTestMetrics(),
        feedback: const EvolutionFeedback(enjoyed: 'good'),
      );

      expect(proposal, isNull);
    });

    test('cleans up conversation even when response is null', () async {
      final convRepo = _TestConversationRepository();
      stubProviderResolution();

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: convRepo,
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
      );

      final proposal = await workflow.proposeEvolution(
        template: makeTestTemplate(),
        currentVersion: makeTestTemplateVersion(),
        metrics: makeTestMetrics(),
        feedback: const EvolutionFeedback(enjoyed: 'good'),
      );

      expect(proposal, isNull);
      expect(convRepo.deletedIds, contains('test-conv-id'));
    });

    test('returns null when provider is not an inference provider type',
        () async {
      final convRepo = _TestConversationRepository();

      when(() => mockAiConfig.getConfigsByType(AiConfigType.model))
          .thenAnswer((_) async => [testAiModel()]);
      // Return a model config instead of an inference provider.
      when(() => mockAiConfig.getConfigById('provider-1'))
          .thenAnswer((_) async => testAiModel());

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: convRepo,
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
      );

      final proposal = await workflow.proposeEvolution(
        template: makeTestTemplate(),
        currentVersion: makeTestTemplateVersion(),
        metrics: makeTestMetrics(),
        feedback: const EvolutionFeedback(enjoyed: 'good'),
      );

      expect(proposal, isNull);
    });

    test('returns null when sendMessage throws', () async {
      final convRepo = _TestConversationRepository()
        ..sendMessageDelegate = () async {
          throw Exception('LLM failure');
        };
      stubProviderResolution();

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: convRepo,
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
      );

      final proposal = await workflow.proposeEvolution(
        template: makeTestTemplate(),
        currentVersion: makeTestTemplateVersion(),
        metrics: makeTestMetrics(),
        feedback: const EvolutionFeedback(enjoyed: 'good'),
      );

      expect(proposal, isNull);
      // Conversation should still be cleaned up in finally block.
      expect(convRepo.deletedIds, contains('test-conv-id'));
    });

    test('returns null when LLM returns empty string', () async {
      final convRepo = _TestConversationRepository(assistantResponse: '');
      stubProviderResolution();

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: convRepo,
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
      );

      final proposal = await workflow.proposeEvolution(
        template: makeTestTemplate(),
        currentVersion: makeTestTemplateVersion(),
        metrics: makeTestMetrics(),
        feedback: const EvolutionFeedback(enjoyed: 'good'),
      );

      expect(proposal, isNull);
    });

    test('builds user message with partial feedback fields', () async {
      final convRepo = _TestConversationRepository(
        assistantResponse: 'Improved directives.',
      );
      stubProviderResolution();

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: convRepo,
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
      );

      // Only didntWork is populated.
      final proposal = await workflow.proposeEvolution(
        template: makeTestTemplate(),
        currentVersion: makeTestTemplateVersion(),
        metrics: makeTestMetrics(),
        feedback: const EvolutionFeedback(didntWork: 'Too slow'),
      );

      expect(proposal, isNotNull);
      expect(proposal!.proposedDirectives, 'Improved directives.');
    });
  });

  group('stripMarkdownFences', () {
    test('strips triple backtick fences', () {
      expect(
        TemplateEvolutionWorkflow.stripMarkdownFences('```\nHello\n```'),
        'Hello',
      );
    });

    test('strips fences with language tag', () {
      expect(
        TemplateEvolutionWorkflow.stripMarkdownFences(
          '```text\nHello world\n```',
        ),
        'Hello world',
      );
    });

    test('leaves unfenced text unchanged', () {
      expect(
        TemplateEvolutionWorkflow.stripMarkdownFences('Just plain text'),
        'Just plain text',
      );
    });
  });

  // ── Multi-turn session tests ──────────────────────────────────────────────

  group('startSession', () {
    late MockAgentTemplateService mockTemplateService;
    late MockAgentSyncService mockSyncService;
    late MockAgentRepository mockRepository;

    setUp(() {
      mockTemplateService = MockAgentTemplateService();
      mockSyncService = MockAgentSyncService();
      mockRepository = MockAgentRepository();
      when(() => mockTemplateService.repository).thenReturn(mockRepository);
    });

    TemplateEvolutionWorkflow buildSessionWorkflow({
      _TestConversationRepository? convRepo,
    }) {
      return TemplateEvolutionWorkflow(
        conversationRepository: convRepo ??
            _TestConversationRepository(
              assistantResponse: 'I see some patterns in the data.',
            ),
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
      );
    }

    void stubFullContext() {
      stubProviderResolution();
      when(() => mockTemplateService.getTemplate(any()))
          .thenAnswer((_) async => makeTestTemplate());
      when(() => mockTemplateService.getActiveVersion(any()))
          .thenAnswer((_) async => makeTestTemplateVersion());
      when(() => mockTemplateService.computeMetrics(any()))
          .thenAnswer((_) async => makeTestMetrics());
      when(() => mockTemplateService.getVersionHistory(any(),
              limit: any(named: 'limit')))
          .thenAnswer((_) async => [makeTestTemplateVersion()]);
      when(() => mockTemplateService.getRecentInstanceReports(any()))
          .thenAnswer((_) async => []);
      when(() => mockTemplateService.getRecentInstanceObservations(any()))
          .thenAnswer((_) async => []);
      when(
        () => mockTemplateService.getRecentEvolutionNotes(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => []);
      when(() => mockTemplateService.getEvolutionSessions(any()))
          .thenAnswer((_) async => []);
      when(() => mockTemplateService.countChangesSince(any(), any()))
          .thenAnswer((_) async => 0);
      when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
    }

    test('creates session and returns assistant response', () async {
      stubFullContext();
      final workflow = buildSessionWorkflow();

      final response = await workflow.startSession(
        templateId: kTestTemplateId,
      );

      expect(response, 'I see some patterns in the data.');
      expect(workflow.activeSessions, hasLength(1));

      final session = workflow.activeSessions.values.first;
      expect(session.templateId, kTestTemplateId);

      // Verify session entity was persisted.
      final captured =
          verify(() => mockSyncService.upsertEntity(captureAny())).captured;
      final sessionEntity = captured.firstWhere(
        (e) => e is EvolutionSessionEntity,
      ) as EvolutionSessionEntity;
      expect(sessionEntity.templateId, kTestTemplateId);
      expect(sessionEntity.status, EvolutionSessionStatus.active);
      expect(sessionEntity.sessionNumber, 1);
    });

    test('computes session number from existing sessions', () async {
      stubFullContext();
      when(() => mockTemplateService.getEvolutionSessions(any()))
          .thenAnswer((_) async => [
                makeTestEvolutionSession(sessionNumber: 3),
                makeTestEvolutionSession(
                  id: 'evo-session-002',
                  sessionNumber: 2,
                ),
              ]);
      final workflow = buildSessionWorkflow();

      await workflow.startSession(templateId: kTestTemplateId);

      final captured =
          verify(() => mockSyncService.upsertEntity(captureAny())).captured;
      final sessionEntity = captured.firstWhere(
        (e) => e is EvolutionSessionEntity,
      ) as EvolutionSessionEntity;
      expect(sessionEntity.sessionNumber, 4);
    });

    test('returns null when templateService is not set', () async {
      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(),
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
      );

      final response = await workflow.startSession(
        templateId: kTestTemplateId,
      );

      expect(response, isNull);
    });

    test('returns null when template not found', () async {
      stubFullContext();
      when(() => mockTemplateService.getTemplate(any()))
          .thenAnswer((_) async => null);
      final workflow = buildSessionWorkflow();

      final response = await workflow.startSession(
        templateId: kTestTemplateId,
      );

      expect(response, isNull);
    });

    test('returns null when no active version', () async {
      stubFullContext();
      when(() => mockTemplateService.getActiveVersion(any()))
          .thenAnswer((_) async => null);
      final workflow = buildSessionWorkflow();

      final response = await workflow.startSession(
        templateId: kTestTemplateId,
      );

      expect(response, isNull);
    });

    test('returns null when provider cannot be resolved', () async {
      stubFullContext();
      when(() => mockAiConfig.getConfigsByType(AiConfigType.model))
          .thenAnswer((_) async => []);
      final workflow = buildSessionWorkflow();

      final response = await workflow.startSession(
        templateId: kTestTemplateId,
      );

      expect(response, isNull);
    });

    test('abandons session on sendMessage failure', () async {
      stubFullContext();
      final convRepo = _TestConversationRepository(
        assistantResponse: 'response',
      )..sendMessageDelegate = () async {
          throw Exception('LLM error');
        };

      // Stub getEntity for session lookup during abandon.
      when(() => mockRepository.getEntity(any())).thenAnswer((_) async => null);

      final workflow = buildSessionWorkflow(convRepo: convRepo);

      final response = await workflow.startSession(
        templateId: kTestTemplateId,
      );

      expect(response, isNull);
      expect(workflow.activeSessions, isEmpty);
      expect(convRepo.deletedIds, isNotEmpty);
    });
  });

  group('sendMessage', () {
    late MockAgentTemplateService mockTemplateService;
    late MockAgentSyncService mockSyncService;

    setUp(() {
      mockTemplateService = MockAgentTemplateService();
      mockSyncService = MockAgentSyncService();
    });

    test('sends user message and returns assistant response', () async {
      stubProviderResolution();
      final convRepo = _TestConversationRepository(
        assistantResponse: 'Here are my observations.',
      );

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: convRepo,
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
      );

      // Manually register an active session.
      workflow.activeSessions['session-1'] = ActiveEvolutionSession(
        sessionId: 'session-1',
        templateId: kTestTemplateId,
        conversationId: 'test-conv-id',
        strategy: EvolutionStrategy(),
        modelId: 'models/gemini-3.1-pro-preview',
      );

      final response = await workflow.sendMessage(
        sessionId: 'session-1',
        userMessage: 'What patterns do you see?',
      );

      expect(response, 'Here are my observations.');
    });

    test('returns null for unknown session', () async {
      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(),
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
      );

      final response = await workflow.sendMessage(
        sessionId: 'nonexistent',
        userMessage: 'Hello',
      );

      expect(response, isNull);
    });

    test('returns null when sendMessage throws', () async {
      stubProviderResolution();
      final convRepo = _TestConversationRepository(
        assistantResponse: 'response',
      )..sendMessageDelegate = () async {
          throw Exception('Connection failed');
        };

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: convRepo,
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
      );

      workflow.activeSessions['session-1'] = ActiveEvolutionSession(
        sessionId: 'session-1',
        templateId: kTestTemplateId,
        conversationId: 'test-conv-id',
        strategy: EvolutionStrategy(),
        modelId: 'models/gemini-3.1-pro-preview',
      );

      final response = await workflow.sendMessage(
        sessionId: 'session-1',
        userMessage: 'Test',
      );

      expect(response, isNull);
    });

    test('returns null when provider cannot be resolved', () async {
      when(() => mockAiConfig.getConfigsByType(AiConfigType.model))
          .thenAnswer((_) async => []);

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(),
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
      );

      workflow.activeSessions['session-1'] = ActiveEvolutionSession(
        sessionId: 'session-1',
        templateId: kTestTemplateId,
        conversationId: 'test-conv-id',
        strategy: EvolutionStrategy(),
        modelId: 'models/gemini-3.1-pro-preview',
      );

      final response = await workflow.sendMessage(
        sessionId: 'session-1',
        userMessage: 'Hello',
      );

      expect(response, isNull);
      // Session should still be active (not abandoned on provider failure).
      expect(workflow.activeSessions, hasLength(1));
    });
  });

  group('getCurrentProposal', () {
    test('returns proposal when one exists', () async {
      final strategy = EvolutionStrategy();
      final manager = ConversationManager(conversationId: 'conv-1')
        ..initialize();
      const toolCall = ChatCompletionMessageToolCall(
        id: 'call-1',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'propose_directives',
          arguments: '{"directives":"New approach","rationale":"Data-driven"}',
        ),
      );
      manager.addAssistantMessage(toolCalls: [toolCall]);
      await strategy.processToolCalls(toolCalls: [toolCall], manager: manager);

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(),
        aiConfigRepository: MockAiConfigRepository(),
        cloudInferenceRepository: MockCloudInferenceRepository(),
      );

      workflow.activeSessions['session-1'] = ActiveEvolutionSession(
        sessionId: 'session-1',
        templateId: kTestTemplateId,
        conversationId: 'conv-1',
        strategy: strategy,
        modelId: 'model',
      );

      final proposal = workflow.getCurrentProposal(sessionId: 'session-1');
      expect(proposal, isNotNull);
      expect(proposal!.directives, 'New approach');
      expect(proposal.rationale, 'Data-driven');
    });

    test('returns null when no proposal exists', () {
      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(),
        aiConfigRepository: MockAiConfigRepository(),
        cloudInferenceRepository: MockCloudInferenceRepository(),
      );

      workflow.activeSessions['session-1'] = ActiveEvolutionSession(
        sessionId: 'session-1',
        templateId: kTestTemplateId,
        conversationId: 'conv-1',
        strategy: EvolutionStrategy(),
        modelId: 'model',
      );

      expect(workflow.getCurrentProposal(sessionId: 'session-1'), isNull);
    });

    test('returns null for unknown session', () {
      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(),
        aiConfigRepository: MockAiConfigRepository(),
        cloudInferenceRepository: MockCloudInferenceRepository(),
      );

      expect(workflow.getCurrentProposal(sessionId: 'nonexistent'), isNull);
    });

    test('returns independent proposals for different sessions', () async {
      final strategy1 = EvolutionStrategy();
      final strategy2 = EvolutionStrategy();

      final manager = ConversationManager(conversationId: 'conv-1')
        ..initialize();
      const call1 = ChatCompletionMessageToolCall(
        id: 'call-1',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'propose_directives',
          arguments: '{"directives":"Proposal A","rationale":"Reason A"}',
        ),
      );
      manager.addAssistantMessage(toolCalls: [call1]);
      await strategy1.processToolCalls(
        toolCalls: [call1],
        manager: manager,
      );

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(),
        aiConfigRepository: MockAiConfigRepository(),
        cloudInferenceRepository: MockCloudInferenceRepository(),
      );

      workflow.activeSessions['s1'] = ActiveEvolutionSession(
        sessionId: 's1',
        templateId: 'tpl-1',
        conversationId: 'conv-1',
        strategy: strategy1,
        modelId: 'model',
      );
      workflow.activeSessions['s2'] = ActiveEvolutionSession(
        sessionId: 's2',
        templateId: 'tpl-2',
        conversationId: 'conv-2',
        strategy: strategy2,
        modelId: 'model',
      );

      expect(workflow.getCurrentProposal(sessionId: 's1')?.directives,
          'Proposal A');
      expect(workflow.getCurrentProposal(sessionId: 's2'), isNull);
    });
  });

  group('approveProposal', () {
    late MockAgentTemplateService mockTemplateService;
    late MockAgentSyncService mockSyncService;
    late MockAgentRepository mockRepository;

    setUp(() {
      mockTemplateService = MockAgentTemplateService();
      mockSyncService = MockAgentSyncService();
      mockRepository = MockAgentRepository();
      when(() => mockTemplateService.repository).thenReturn(mockRepository);
    });

    test('creates new version, persists notes, and completes session',
        () async {
      final newVersion = makeTestTemplateVersion(
        id: 'new-version-id',
        version: 2,
        directives: 'Improved directives',
        authoredBy: 'evolution_agent',
      );

      when(
        () => mockTemplateService.createVersion(
          templateId: any(named: 'templateId'),
          directives: any(named: 'directives'),
          authoredBy: any(named: 'authoredBy'),
        ),
      ).thenAnswer((_) async => newVersion);
      when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
      when(() => mockRepository.getEntity(any()))
          .thenAnswer((_) async => makeTestEvolutionSession());

      final convRepo = _TestConversationRepository();
      final strategy = EvolutionStrategy()
          // Simulate a proposal being recorded by directly setting it via
          // processToolCalls.
          ;

      // Manually add a proposal by processing a tool call.
      final manager = ConversationManager(conversationId: 'conv-1')
        ..initialize();
      const toolCall = ChatCompletionMessageToolCall(
        id: 'call-1',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'propose_directives',
          arguments:
              '{"directives":"Improved directives","rationale":"Based on data"}',
        ),
      );
      manager.addAssistantMessage(toolCalls: [toolCall]);
      await strategy.processToolCalls(toolCalls: [toolCall], manager: manager);

      // Also add a pending note.
      const noteCall = ChatCompletionMessageToolCall(
        id: 'call-2',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'record_evolution_note',
          arguments: '{"kind":"reflection","content":"Users prefer brevity"}',
        ),
      );
      manager.addAssistantMessage(toolCalls: [noteCall]);
      await strategy.processToolCalls(
        toolCalls: [noteCall],
        manager: manager,
      );

      expect(strategy.latestProposal, isNotNull);
      expect(strategy.pendingNotes, hasLength(1));

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: convRepo,
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
      );

      workflow.activeSessions['session-1'] = ActiveEvolutionSession(
        sessionId: 'session-1',
        templateId: kTestTemplateId,
        conversationId: 'test-conv-id',
        strategy: strategy,
        modelId: 'model',
      );

      final result = await workflow.approveProposal(
        sessionId: 'session-1',
        userRating: 4.5,
        feedbackSummary: 'Great improvement',
      );

      expect(result, isNotNull);
      expect(result!.directives, 'Improved directives');

      // Verify version was created with correct parameters.
      verify(
        () => mockTemplateService.createVersion(
          templateId: kTestTemplateId,
          directives: 'Improved directives',
          authoredBy: 'evolution_agent',
        ),
      ).called(1);

      // Verify notes and session completion were persisted.
      // upsertEntity is called for: note + session completion = 2 calls.
      final capturedEntities =
          verify(() => mockSyncService.upsertEntity(captureAny())).captured;

      final noteEntities =
          capturedEntities.whereType<EvolutionNoteEntity>().toList();
      expect(noteEntities, hasLength(1));
      expect(noteEntities.first.kind, EvolutionNoteKind.reflection);
      expect(noteEntities.first.content, 'Users prefer brevity');

      final sessionEntities =
          capturedEntities.whereType<EvolutionSessionEntity>().toList();
      expect(sessionEntities, hasLength(1));
      expect(
        sessionEntities.first.status,
        EvolutionSessionStatus.completed,
      );
      expect(sessionEntities.first.proposedVersionId, 'new-version-id');
      expect(sessionEntities.first.userRating, 4.5);
      expect(sessionEntities.first.feedbackSummary, 'Great improvement');

      // Verify session was cleaned up.
      expect(workflow.activeSessions, isEmpty);
      expect(convRepo.deletedIds, contains('test-conv-id'));
    });

    test('returns null when no proposal exists', () async {
      when(() => mockTemplateService.repository).thenReturn(mockRepository);

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(),
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
      );

      workflow.activeSessions['session-1'] = ActiveEvolutionSession(
        sessionId: 'session-1',
        templateId: kTestTemplateId,
        conversationId: 'conv-1',
        strategy: EvolutionStrategy(),
        modelId: 'model',
      );

      final result = await workflow.approveProposal(sessionId: 'session-1');
      expect(result, isNull);
      // Session should NOT be cleaned up — it's still active.
      expect(workflow.activeSessions, hasLength(1));
    });

    test('returns null for unknown session', () async {
      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(),
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
      );

      final result = await workflow.approveProposal(sessionId: 'nonexistent');
      expect(result, isNull);
    });

    test('returns null when createVersion throws', () async {
      when(
        () => mockTemplateService.createVersion(
          templateId: any(named: 'templateId'),
          directives: any(named: 'directives'),
          authoredBy: any(named: 'authoredBy'),
        ),
      ).thenThrow(StateError('Template not found'));
      when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});

      final strategy = EvolutionStrategy();
      final manager = ConversationManager(conversationId: 'conv-1')
        ..initialize();
      const toolCall = ChatCompletionMessageToolCall(
        id: 'call-1',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'propose_directives',
          arguments: '{"directives":"New text","rationale":"R"}',
        ),
      );
      manager.addAssistantMessage(toolCalls: [toolCall]);
      await strategy.processToolCalls(toolCalls: [toolCall], manager: manager);

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(),
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
      );

      workflow.activeSessions['session-1'] = ActiveEvolutionSession(
        sessionId: 'session-1',
        templateId: kTestTemplateId,
        conversationId: 'test-conv-id',
        strategy: strategy,
        modelId: 'model',
      );

      final result = await workflow.approveProposal(sessionId: 'session-1');
      expect(result, isNull);
      // Session should NOT be cleaned up on error — caller can retry.
    });

    test('completes even when session entity not found in DB', () async {
      final newVersion = makeTestTemplateVersion(
        id: 'new-ver',
        version: 2,
        directives: 'Updated directives',
      );

      when(
        () => mockTemplateService.createVersion(
          templateId: any(named: 'templateId'),
          directives: any(named: 'directives'),
          authoredBy: any(named: 'authoredBy'),
        ),
      ).thenAnswer((_) async => newVersion);
      when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
      // Session entity not found in DB.
      when(() => mockRepository.getEntity(any())).thenAnswer((_) async => null);

      final strategy = EvolutionStrategy();
      final manager = ConversationManager(conversationId: 'conv-1')
        ..initialize();
      const toolCall = ChatCompletionMessageToolCall(
        id: 'call-1',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'propose_directives',
          arguments: '{"directives":"Updated directives","rationale":"R"}',
        ),
      );
      manager.addAssistantMessage(toolCalls: [toolCall]);
      await strategy.processToolCalls(toolCalls: [toolCall], manager: manager);

      final convRepo = _TestConversationRepository();
      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: convRepo,
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
      );

      workflow.activeSessions['session-1'] = ActiveEvolutionSession(
        sessionId: 'session-1',
        templateId: kTestTemplateId,
        conversationId: 'test-conv-id',
        strategy: strategy,
        modelId: 'model',
      );

      // Should still succeed — version is created, session entity update
      // is skipped gracefully.
      final result = await workflow.approveProposal(sessionId: 'session-1');
      expect(result, isNotNull);
      expect(result!.directives, 'Updated directives');
      expect(workflow.activeSessions, isEmpty);
    });
  });

  group('rejectProposal', () {
    test('clears proposal from strategy', () async {
      final strategy = EvolutionStrategy();

      // Add a proposal.
      final manager = ConversationManager(conversationId: 'conv-1')
        ..initialize();
      const toolCall = ChatCompletionMessageToolCall(
        id: 'call-1',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'propose_directives',
          arguments: '{"directives":"New text","rationale":"Reason"}',
        ),
      );
      manager.addAssistantMessage(toolCalls: [toolCall]);
      await strategy.processToolCalls(toolCalls: [toolCall], manager: manager);
      expect(strategy.latestProposal, isNotNull);

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(),
        aiConfigRepository: MockAiConfigRepository(),
        cloudInferenceRepository: MockCloudInferenceRepository(),
      );

      workflow.activeSessions['session-1'] = ActiveEvolutionSession(
        sessionId: 'session-1',
        templateId: kTestTemplateId,
        conversationId: 'conv-1',
        strategy: strategy,
        modelId: 'model',
      );

      workflow.rejectProposal(sessionId: 'session-1');

      expect(strategy.latestProposal, isNull);
      // Session is still active (conversation continues).
      expect(workflow.activeSessions, hasLength(1));
    });

    test('is safe when no proposal exists', () {
      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(),
        aiConfigRepository: MockAiConfigRepository(),
        cloudInferenceRepository: MockCloudInferenceRepository(),
      );

      workflow.activeSessions['session-1'] = ActiveEvolutionSession(
        sessionId: 'session-1',
        templateId: kTestTemplateId,
        conversationId: 'conv-1',
        strategy: EvolutionStrategy(),
        modelId: 'model',
      );

      // Should not throw.
      workflow.rejectProposal(sessionId: 'session-1');
      expect(workflow.activeSessions, hasLength(1));
    });

    test('is safe for unknown session', () {
      // Should not throw.
      TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(),
        aiConfigRepository: MockAiConfigRepository(),
        cloudInferenceRepository: MockCloudInferenceRepository(),
      ).rejectProposal(sessionId: 'nonexistent');
    });
  });

  group('abandonSession', () {
    late MockAgentSyncService mockSyncService;
    late MockAgentTemplateService mockTemplateService;
    late MockAgentRepository mockRepository;

    setUp(() {
      mockSyncService = MockAgentSyncService();
      mockTemplateService = MockAgentTemplateService();
      mockRepository = MockAgentRepository();
      when(() => mockTemplateService.repository).thenReturn(mockRepository);
    });

    test('persists pending notes and marks session abandoned', () async {
      when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
      when(() => mockRepository.getEntity(any()))
          .thenAnswer((_) async => makeTestEvolutionSession());

      final strategy = EvolutionStrategy();

      // Add a note.
      final manager = ConversationManager(conversationId: 'conv-1')
        ..initialize();
      const toolCall = ChatCompletionMessageToolCall(
        id: 'call-1',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'record_evolution_note',
          arguments: '{"kind":"decision","content":"Decided to keep tone"}',
        ),
      );
      manager.addAssistantMessage(toolCalls: [toolCall]);
      await strategy.processToolCalls(toolCalls: [toolCall], manager: manager);

      final convRepo = _TestConversationRepository();
      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: convRepo,
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
      );

      workflow.activeSessions['session-1'] = ActiveEvolutionSession(
        sessionId: 'session-1',
        templateId: kTestTemplateId,
        conversationId: 'test-conv-id',
        strategy: strategy,
        modelId: 'model',
      );

      await workflow.abandonSession(sessionId: 'session-1');

      expect(workflow.activeSessions, isEmpty);
      expect(convRepo.deletedIds, contains('test-conv-id'));

      final capturedEntities =
          verify(() => mockSyncService.upsertEntity(captureAny())).captured;

      final noteEntities =
          capturedEntities.whereType<EvolutionNoteEntity>().toList();
      expect(noteEntities, hasLength(1));
      expect(noteEntities.first.kind, EvolutionNoteKind.decision);

      final sessionEntities =
          capturedEntities.whereType<EvolutionSessionEntity>().toList();
      expect(sessionEntities, hasLength(1));
      expect(
        sessionEntities.first.status,
        EvolutionSessionStatus.abandoned,
      );
    });

    test('handles missing sync service gracefully', () async {
      final convRepo = _TestConversationRepository();
      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: convRepo,
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
      );

      workflow.activeSessions['session-1'] = ActiveEvolutionSession(
        sessionId: 'session-1',
        templateId: kTestTemplateId,
        conversationId: 'test-conv-id',
        strategy: EvolutionStrategy(),
        modelId: 'model',
      );

      // Should not throw.
      await workflow.abandonSession(sessionId: 'session-1');

      expect(workflow.activeSessions, isEmpty);
      expect(convRepo.deletedIds, contains('test-conv-id'));
    });
  });

  group('getActiveSessionForTemplate', () {
    test('returns active session matching template', () {
      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(),
        aiConfigRepository: MockAiConfigRepository(),
        cloudInferenceRepository: MockCloudInferenceRepository(),
      );

      workflow.activeSessions['session-1'] = ActiveEvolutionSession(
        sessionId: 'session-1',
        templateId: 'template-abc',
        conversationId: 'conv-1',
        strategy: EvolutionStrategy(),
        modelId: 'model',
      );

      expect(
        workflow.getActiveSessionForTemplate('template-abc'),
        isNotNull,
      );
      expect(
        workflow.getActiveSessionForTemplate('template-other'),
        isNull,
      );
    });
  });

  // ── Robustness / regression tests ─────────────────────────────────────────

  group('startSession failure cleanup', () {
    late MockAgentTemplateService mockTemplateService;
    late MockAgentSyncService mockSyncService;
    late MockAgentRepository mockRepository;

    setUp(() {
      mockTemplateService = MockAgentTemplateService();
      mockSyncService = MockAgentSyncService();
      mockRepository = MockAgentRepository();
      when(() => mockTemplateService.repository).thenReturn(mockRepository);
    });

    void stubFullContext() {
      stubProviderResolution();
      when(() => mockTemplateService.getTemplate(any()))
          .thenAnswer((_) async => makeTestTemplate());
      when(() => mockTemplateService.getActiveVersion(any()))
          .thenAnswer((_) async => makeTestTemplateVersion());
      when(() => mockTemplateService.computeMetrics(any()))
          .thenAnswer((_) async => makeTestMetrics());
      when(() => mockTemplateService.getVersionHistory(any(),
              limit: any(named: 'limit')))
          .thenAnswer((_) async => [makeTestTemplateVersion()]);
      when(() => mockTemplateService.getRecentInstanceReports(any()))
          .thenAnswer((_) async => []);
      when(() => mockTemplateService.getRecentInstanceObservations(any()))
          .thenAnswer((_) async => []);
      when(
        () => mockTemplateService.getRecentEvolutionNotes(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => []);
      when(() => mockTemplateService.getEvolutionSessions(any()))
          .thenAnswer((_) async => []);
      when(() => mockTemplateService.countChangesSince(any(), any()))
          .thenAnswer((_) async => 0);
    }

    test(
      'marks persisted session as abandoned when error occurs before '
      'activeSessions is populated',
      () async {
        stubFullContext();

        // First upsertEntity call (session creation) succeeds.
        // Subsequent calls also succeed (for abandon cleanup).
        when(() => mockSyncService.upsertEntity(any()))
            .thenAnswer((_) async {});

        // Make the conversation repo throw during sendMessage, which happens
        // AFTER the session entity is persisted but the error path should
        // still clean up via abandonSession.
        final convRepo = _TestConversationRepository(
          assistantResponse: 'response',
        )..sendMessageDelegate = () async {
            throw Exception('LLM call failed');
          };

        // Return the active session entity when looked up for abandon.
        when(() => mockRepository.getEntity(any())).thenAnswer(
          (_) async => makeTestEvolutionSession(),
        );

        final workflow = TemplateEvolutionWorkflow(
          conversationRepository: convRepo,
          aiConfigRepository: mockAiConfig,
          cloudInferenceRepository: mockCloudInference,
          templateService: mockTemplateService,
          syncService: mockSyncService,
        );

        final response = await workflow.startSession(
          templateId: kTestTemplateId,
        );

        expect(response, isNull);
        expect(workflow.activeSessions, isEmpty);

        // Verify the session entity was marked as abandoned.
        final allUpserts =
            verify(() => mockSyncService.upsertEntity(captureAny())).captured;
        final sessionUpserts =
            allUpserts.whereType<EvolutionSessionEntity>().toList();

        // Should have 2 session upserts: initial creation + abandon.
        expect(sessionUpserts, hasLength(2));
        expect(sessionUpserts[0].status, EvolutionSessionStatus.active);
        expect(sessionUpserts[1].status, EvolutionSessionStatus.abandoned);
      },
    );

    test(
      'abandonSession marks DB session abandoned even without in-memory state',
      () async {
        when(() => mockSyncService.upsertEntity(any()))
            .thenAnswer((_) async {});
        when(() => mockRepository.getEntity('orphan-session')).thenAnswer(
          (_) async => makeTestEvolutionSession(
            id: 'orphan-session',
          ),
        );

        final convRepo = _TestConversationRepository();
        final workflow = TemplateEvolutionWorkflow(
          conversationRepository: convRepo,
          aiConfigRepository: mockAiConfig,
          cloudInferenceRepository: mockCloudInference,
          templateService: mockTemplateService,
          syncService: mockSyncService,
        );

        // No entry in activeSessions — simulates orphaned DB record.
        expect(workflow.activeSessions, isEmpty);

        await workflow.abandonSession(sessionId: 'orphan-session');

        final captured =
            verify(() => mockSyncService.upsertEntity(captureAny())).captured;
        final sessionEntity = captured.first as EvolutionSessionEntity;
        expect(sessionEntity.status, EvolutionSessionStatus.abandoned);
        expect(sessionEntity.completedAt, isNotNull);
      },
    );
  });

  group('approveProposal idempotency', () {
    late MockAgentTemplateService mockTemplateService;
    late MockAgentSyncService mockSyncService;
    late MockAgentRepository mockRepository;

    setUp(() {
      mockTemplateService = MockAgentTemplateService();
      mockSyncService = MockAgentSyncService();
      mockRepository = MockAgentRepository();
      when(() => mockTemplateService.repository).thenReturn(mockRepository);
    });

    test('retry does not create duplicate version or notes', () async {
      final newVersion = makeTestTemplateVersion(
        id: 'v2',
        version: 2,
        directives: 'Better directives',
        authoredBy: 'evolution_agent',
      );

      when(
        () => mockTemplateService.createVersion(
          templateId: any(named: 'templateId'),
          directives: any(named: 'directives'),
          authoredBy: any(named: 'authoredBy'),
        ),
      ).thenAnswer((_) async => newVersion);

      // First attempt: upsert fails on session completion (after version
      // creation and note persistence succeed).
      var callCount = 0;
      when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {
        callCount++;
        // Fail on the second upsert (session completion), succeed on notes.
        if (callCount == 2) {
          throw StateError('Transient DB error');
        }
      });

      when(() => mockRepository.getEntity(any()))
          .thenAnswer((_) async => makeTestEvolutionSession());

      final strategy = EvolutionStrategy();
      final manager = ConversationManager(conversationId: 'conv-1')
        ..initialize();

      // Add proposal.
      const proposalCall = ChatCompletionMessageToolCall(
        id: 'call-1',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'propose_directives',
          arguments:
              '{"directives":"Better directives","rationale":"Evidence"}',
        ),
      );
      manager.addAssistantMessage(toolCalls: [proposalCall]);
      await strategy.processToolCalls(
        toolCalls: [proposalCall],
        manager: manager,
      );

      // Add a note.
      const noteCall = ChatCompletionMessageToolCall(
        id: 'call-2',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'record_evolution_note',
          arguments: '{"kind":"reflection","content":"Tone works well"}',
        ),
      );
      manager.addAssistantMessage(toolCalls: [noteCall]);
      await strategy.processToolCalls(
        toolCalls: [noteCall],
        manager: manager,
      );

      final convRepo = _TestConversationRepository();
      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: convRepo,
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
      );

      workflow.activeSessions['session-1'] = ActiveEvolutionSession(
        sessionId: 'session-1',
        templateId: kTestTemplateId,
        conversationId: 'test-conv-id',
        strategy: strategy,
        modelId: 'model',
      );

      // First attempt fails.
      final firstResult = await workflow.approveProposal(
        sessionId: 'session-1',
      );
      expect(firstResult, isNull);
      // Session should still be in activeSessions for retry.
      expect(workflow.activeSessions, hasLength(1));

      // Reset mock so all upserts succeed on retry.
      reset(mockSyncService);
      when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});

      // Second attempt should succeed without creating another version.
      final secondResult = await workflow.approveProposal(
        sessionId: 'session-1',
      );
      expect(secondResult, isNotNull);
      expect(secondResult!.id, 'v2');

      // createVersion should only have been called once (during first attempt).
      verify(
        () => mockTemplateService.createVersion(
          templateId: any(named: 'templateId'),
          directives: any(named: 'directives'),
          authoredBy: any(named: 'authoredBy'),
        ),
      ).called(1);
    });
  });

  group('startSession note limit contract', () {
    late MockAgentTemplateService mockTemplateService;
    late MockAgentSyncService mockSyncService;
    late MockAgentRepository mockRepository;

    setUp(() {
      mockTemplateService = MockAgentTemplateService();
      mockSyncService = MockAgentSyncService();
      mockRepository = MockAgentRepository();
      when(() => mockTemplateService.repository).thenReturn(mockRepository);
    });

    test('passes bounded limit to getRecentEvolutionNotes', () async {
      stubProviderResolution();
      when(() => mockTemplateService.getTemplate(any()))
          .thenAnswer((_) async => makeTestTemplate());
      when(() => mockTemplateService.getActiveVersion(any()))
          .thenAnswer((_) async => makeTestTemplateVersion());
      when(() => mockTemplateService.computeMetrics(any()))
          .thenAnswer((_) async => makeTestMetrics());
      when(() => mockTemplateService.getVersionHistory(any(),
          limit: any(named: 'limit'))).thenAnswer((_) async => []);
      when(() => mockTemplateService.getRecentInstanceReports(any()))
          .thenAnswer((_) async => []);
      when(() => mockTemplateService.getRecentInstanceObservations(any()))
          .thenAnswer((_) async => []);
      when(
        () => mockTemplateService.getRecentEvolutionNotes(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => []);
      when(() => mockTemplateService.getEvolutionSessions(any()))
          .thenAnswer((_) async => []);
      when(() => mockTemplateService.countChangesSince(any(), any()))
          .thenAnswer((_) async => 0);
      when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(
          assistantResponse: 'Hello',
        ),
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
      );

      await workflow.startSession(templateId: kTestTemplateId);

      // Verify a bounded limit was passed (not the default 50).
      final captured = verify(
        () => mockTemplateService.getRecentEvolutionNotes(
          any(),
          limit: captureAny(named: 'limit'),
        ),
      ).captured;
      final limit = captured.first as int;
      expect(limit, lessThanOrEqualTo(30));
      expect(limit, greaterThan(0));
    });
  });
}
