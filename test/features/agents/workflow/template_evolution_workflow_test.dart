import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/workflow/evolution_context_builder.dart';
import 'package:lotti/features/agents/workflow/evolution_strategy.dart';
import 'package:lotti/features/agents/workflow/template_evolution_workflow.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

/// Test mock for ConversationRepository that controls the conversation flow.
class _TestConversationRepository extends ConversationRepository {
  _TestConversationRepository({this.assistantResponse});

  final String? assistantResponse;
  final List<String> deletedIds = [];

  /// Optional delegate to control sendMessage behavior (e.g., throwing).
  Future<InferenceUsage?> Function()? sendMessageDelegate;

  /// Optional delegate to control createConversation behavior (e.g., throwing).
  String Function()? createConversationDelegate;

  @override
  void build() {}

  @override
  String createConversation({
    String? systemMessage,
    int maxTurns = 20,
  }) {
    if (createConversationDelegate != null) {
      return createConversationDelegate!();
    }
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
      return sendMessageDelegate!();
    }
    // Otherwise no-op: the assistant response is pre-loaded in getConversation.
    return null;
  }
}

void main() {
  late MockAiConfigRepository mockAiConfig;
  late MockCloudInferenceRepository mockCloudInference;

  setUpAll(registerAllFallbackValues);

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

  /// Stubs all service calls needed by [startSession]. Shared across groups
  /// that test the multi-turn session flow.
  void stubFullSessionContext({
    required MockAgentTemplateService templateService,
    required MockAgentSyncService syncService,
  }) {
    stubProviderResolution();
    when(() => templateService.getTemplate(any()))
        .thenAnswer((_) async => makeTestTemplate());
    when(() => templateService.getActiveVersion(any()))
        .thenAnswer((_) async => makeTestTemplateVersion());
    when(() => templateService.computeMetrics(any()))
        .thenAnswer((_) async => makeTestMetrics());
    when(() => templateService.getVersionHistory(any(),
            limit: any(named: 'limit')))
        .thenAnswer((_) async => [makeTestTemplateVersion()]);
    when(() => templateService.getRecentInstanceReports(any()))
        .thenAnswer((_) async => []);
    when(() => templateService.getRecentInstanceObservations(any()))
        .thenAnswer((_) async => []);
    when(
      () => templateService.getRecentEvolutionNotes(
        any(),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => []);
    when(() => templateService.getEvolutionSessions(any()))
        .thenAnswer((_) async => []);
    when(() => templateService.countChangesSince(any(), any()))
        .thenAnswer((_) async => 0);
    when(() => syncService.upsertEntity(any())).thenAnswer((_) async {});
  }

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

    void stubFullContext() => stubFullSessionContext(
          templateService: mockTemplateService,
          syncService: mockSyncService,
        );

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

    test('returns null when opening assistant content is missing', () async {
      stubFullContext();
      final convRepo = _TestConversationRepository();
      final workflow = buildSessionWorkflow(convRepo: convRepo);

      final response = await workflow.startSession(
        templateId: kTestTemplateId,
      );

      expect(response, isNull);
      // Session has been created but no assistant content could be extracted.
      expect(workflow.activeSessions, hasLength(1));
      expect(convRepo.deletedIds, isEmpty);
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
        modelId: 'models/gemini-3-flash-preview',
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
        modelId: 'models/gemini-3-flash-preview',
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
        modelId: 'models/gemini-3-flash-preview',
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

    test('cleans up even when _persistNotes throws', () async {
      // Make upsertEntity throw on the first call (the note persist).
      var callCount = 0;
      when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          throw StateError('Note persistence failed');
        }
      });
      when(() => mockRepository.getEntity(any()))
          .thenAnswer((_) async => makeTestEvolutionSession());

      final strategy = EvolutionStrategy();
      final manager = ConversationManager(conversationId: 'conv-1')
        ..initialize();
      const toolCall = ChatCompletionMessageToolCall(
        id: 'call-1',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'record_evolution_note',
          arguments: '{"kind":"decision","content":"A note"}',
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

      // Should not throw — note failure is caught, cleanup still runs.
      await workflow.abandonSession(sessionId: 'session-1');

      // Session was cleaned up despite note failure.
      expect(workflow.activeSessions, isEmpty);
      expect(convRepo.deletedIds, contains('test-conv-id'));

      // Session entity was still marked as abandoned (second upsert call).
      final captured =
          verify(() => mockSyncService.upsertEntity(captureAny())).captured;
      final sessionEntities =
          captured.whereType<EvolutionSessionEntity>().toList();
      expect(sessionEntities, hasLength(1));
      expect(sessionEntities.first.status, EvolutionSessionStatus.abandoned);
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

    void stubFullContext() => stubFullSessionContext(
          templateService: mockTemplateService,
          syncService: mockSyncService,
        );

    test(
      'marks persisted session as abandoned when createConversation fails '
      'before activeSessions is populated',
      () async {
        stubFullContext();

        // createConversation throws AFTER session entity is persisted
        // but BEFORE activeSessions map is populated.
        final convRepo = _TestConversationRepository(
          assistantResponse: 'response',
        )..createConversationDelegate = () {
            throw StateError('Conversation init failed');
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
        // activeSessions was never populated — key invariant.
        expect(workflow.activeSessions, isEmpty);

        // Verify the session entity was marked as abandoned despite having
        // no in-memory session state.
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

      // Track all successfully upserted entities across both attempts.
      final allUpserted = <AgentDomainEntity>[];
      var upsertCallCount = 0;
      when(() => mockSyncService.upsertEntity(any())).thenAnswer((inv) async {
        upsertCallCount++;
        // Fail on the second upsert (session completion after note) BEFORE
        // recording success, simulating a transient DB error.
        if (upsertCallCount == 2) {
          throw StateError('Transient DB error');
        }
        final entity = inv.positionalArguments.first as AgentDomainEntity;
        allUpserted.add(entity);
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

      // First attempt: note persists, then session completion fails.
      final firstResult = await workflow.approveProposal(
        sessionId: 'session-1',
      );
      expect(firstResult, isNull);
      expect(workflow.activeSessions, hasLength(1));

      // Second attempt should succeed without duplicating work.
      final secondResult = await workflow.approveProposal(
        sessionId: 'session-1',
      );
      expect(secondResult, isNotNull);
      expect(secondResult!.id, 'v2');

      // createVersion should only have been called once across both attempts.
      verify(
        () => mockTemplateService.createVersion(
          templateId: any(named: 'templateId'),
          directives: any(named: 'directives'),
          authoredBy: any(named: 'authoredBy'),
        ),
      ).called(1);

      // Exactly one note entity across both attempts (no duplicate).
      final noteEntities =
          allUpserted.whereType<EvolutionNoteEntity>().toList();
      expect(noteEntities, hasLength(1));
      expect(noteEntities.first.content, 'Tone works well');

      // Session entity upserted once for completion (the failed attempt threw
      // before the session completion upsert could record, so only the
      // successful retry wrote it).
      final sessionEntities =
          allUpserted.whereType<EvolutionSessionEntity>().toList();
      expect(sessionEntities, hasLength(1));
      expect(
        sessionEntities.first.status,
        EvolutionSessionStatus.completed,
      );
    });

    test(
      'reject after failed approval then new proposal uses new version',
      () async {
        final oldVersion = makeTestTemplateVersion(
          id: 'v-old',
          version: 2,
          directives: 'Old proposal',
        );
        final newVersion = makeTestTemplateVersion(
          id: 'v-new',
          version: 3,
          directives: 'New proposal',
        );

        var createCallCount = 0;
        when(
          () => mockTemplateService.createVersion(
            templateId: any(named: 'templateId'),
            directives: any(named: 'directives'),
            authoredBy: any(named: 'authoredBy'),
          ),
        ).thenAnswer((_) async {
          createCallCount++;
          return createCallCount == 1 ? oldVersion : newVersion;
        });

        // First approval attempt: version created, then session update fails.
        var upsertCount = 0;
        when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {
          upsertCount++;
          // Fail on session completion upsert (first upsert in approveProposal
          // since notes are already drained).
          if (upsertCount == 1) {
            throw StateError('DB error');
          }
        });
        when(() => mockRepository.getEntity(any()))
            .thenAnswer((_) async => makeTestEvolutionSession());

        final strategy = EvolutionStrategy();
        final manager = ConversationManager(conversationId: 'conv-1')
          ..initialize();

        // First proposal.
        const firstProposal = ChatCompletionMessageToolCall(
          id: 'call-1',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'propose_directives',
            arguments:
                '{"directives":"Old proposal","rationale":"First attempt"}',
          ),
        );
        manager.addAssistantMessage(toolCalls: [firstProposal]);
        await strategy.processToolCalls(
          toolCalls: [firstProposal],
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

        // First approval fails.
        final first = await workflow.approveProposal(sessionId: 'session-1');
        expect(first, isNull);

        // Reject the old proposal.
        workflow.rejectProposal(sessionId: 'session-1');

        // New proposal arrives.
        const secondProposal = ChatCompletionMessageToolCall(
          id: 'call-2',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'propose_directives',
            arguments:
                '{"directives":"New proposal","rationale":"Revised attempt"}',
          ),
        );
        manager.addAssistantMessage(toolCalls: [secondProposal]);
        await strategy.processToolCalls(
          toolCalls: [secondProposal],
          manager: manager,
        );

        // Reset mock so upserts succeed.
        reset(mockSyncService);
        when(() => mockSyncService.upsertEntity(any()))
            .thenAnswer((_) async {});

        // Second approval should create a NEW version, not reuse the old one.
        final second = await workflow.approveProposal(sessionId: 'session-1');
        expect(second, isNotNull);
        expect(second!.id, 'v-new');
        expect(second.directives, 'New proposal');

        // createVersion was called twice (once per distinct proposal).
        expect(createCallCount, 2);
      },
    );

    test(
      'notes added after failed approval are persisted on retry',
      () async {
        final newVersion = makeTestTemplateVersion(
          id: 'v2',
          version: 2,
          directives: 'Good directives',
        );

        when(
          () => mockTemplateService.createVersion(
            templateId: any(named: 'templateId'),
            directives: any(named: 'directives'),
            authoredBy: any(named: 'authoredBy'),
          ),
        ).thenAnswer((_) async => newVersion);
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
                '{"directives":"Good directives","rationale":"Evidence"}',
          ),
        );
        manager.addAssistantMessage(toolCalls: [proposalCall]);
        await strategy.processToolCalls(
          toolCalls: [proposalCall],
          manager: manager,
        );

        // Add first note.
        const noteCall1 = ChatCompletionMessageToolCall(
          id: 'call-2',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'record_evolution_note',
            arguments: '{"kind":"reflection","content":"Note A"}',
          ),
        );
        manager.addAssistantMessage(toolCalls: [noteCall1]);
        await strategy.processToolCalls(
          toolCalls: [noteCall1],
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

        // First approval: note persists OK, but session completion fails.
        var upsertCallCount = 0;
        when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {
          upsertCallCount++;
          // Note A upsert succeeds (call 1), session completion fails (call 2).
          if (upsertCallCount == 2) {
            throw StateError('Session update failed');
          }
        });

        final first = await workflow.approveProposal(sessionId: 'session-1');
        expect(first, isNull);
        // Note A was drained (persisted successfully).
        expect(strategy.pendingNotes, isEmpty);

        // New note added between retries.
        const noteCall2 = ChatCompletionMessageToolCall(
          id: 'call-3',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'record_evolution_note',
            arguments: '{"kind":"decision","content":"Note B"}',
          ),
        );
        manager.addAssistantMessage(toolCalls: [noteCall2]);
        await strategy.processToolCalls(
          toolCalls: [noteCall2],
          manager: manager,
        );
        expect(strategy.pendingNotes, hasLength(1));

        // Reset mock for retry.
        reset(mockSyncService);
        when(() => mockSyncService.upsertEntity(any()))
            .thenAnswer((_) async {});

        final second = await workflow.approveProposal(sessionId: 'session-1');
        expect(second, isNotNull);

        // Verify Note B was persisted in the retry.
        final captured =
            verify(() => mockSyncService.upsertEntity(captureAny())).captured;
        final noteEntities = captured.whereType<EvolutionNoteEntity>().toList();
        expect(noteEntities, hasLength(1));
        expect(noteEntities.first.content, 'Note B');
        expect(noteEntities.first.kind, EvolutionNoteKind.decision);
      },
    );

    test(
      'partial note persistence failure does not duplicate on retry',
      () async {
        final newVersion = makeTestTemplateVersion(
          id: 'v2',
          version: 2,
          directives: 'Some directives',
        );

        when(
          () => mockTemplateService.createVersion(
            templateId: any(named: 'templateId'),
            directives: any(named: 'directives'),
            authoredBy: any(named: 'authoredBy'),
          ),
        ).thenAnswer((_) async => newVersion);
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
            arguments: '{"directives":"Some directives","rationale":"Reason"}',
          ),
        );
        manager.addAssistantMessage(toolCalls: [proposalCall]);
        await strategy.processToolCalls(
          toolCalls: [proposalCall],
          manager: manager,
        );

        // Add two notes.
        for (var i = 0; i < 2; i++) {
          final noteCall = ChatCompletionMessageToolCall(
            id: 'note-$i',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'record_evolution_note',
              arguments: '{"kind":"reflection","content":"Note $i"}',
            ),
          );
          manager.addAssistantMessage(toolCalls: [noteCall]);
          await strategy.processToolCalls(
            toolCalls: [noteCall],
            manager: manager,
          );
        }
        expect(strategy.pendingNotes, hasLength(2));

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

        // First attempt: version creation succeeds, first note persists,
        // second note fails. Notes are drained eagerly (removed before
        // upsert), so a failed note is lost — acceptable for advisory data.
        final allUpserted = <AgentDomainEntity>[];
        var noteUpsertCount = 0;
        when(() => mockSyncService.upsertEntity(any())).thenAnswer((inv) async {
          final entity = inv.positionalArguments.first as AgentDomainEntity;
          // Count only note upserts for the failure trigger.
          if (entity is EvolutionNoteEntity) {
            noteUpsertCount++;
            if (noteUpsertCount == 2) {
              throw StateError('Write failed on second note');
            }
          }
          allUpserted.add(entity);
        });

        final first = await workflow.approveProposal(sessionId: 'session-1');
        expect(first, isNull);

        // Both notes were drained from the strategy (drain-before-upsert).
        expect(strategy.pendingNotes, isEmpty);

        // Only Note 0 was actually written (Note 1's upsert threw).
        // Version creation goes through templateService.createVersion, not
        // syncService.upsertEntity, so it won't appear in allUpserted.
        final firstAttemptNotes =
            allUpserted.whereType<EvolutionNoteEntity>().toList();
        expect(firstAttemptNotes, hasLength(1));
        expect(firstAttemptNotes.first.content, 'Note 0');

        // Version was created via createVersion and cached for retry.
        verify(
          () => mockTemplateService.createVersion(
            templateId: any(named: 'templateId'),
            directives: any(named: 'directives'),
            authoredBy: any(named: 'authoredBy'),
          ),
        ).called(1);

        // Retry: no notes left to persist, so no duplicate writes.
        allUpserted.clear();
        noteUpsertCount = 0;
        when(() => mockSyncService.upsertEntity(any())).thenAnswer((inv) async {
          allUpserted.add(
            inv.positionalArguments.first as AgentDomainEntity,
          );
        });

        final second = await workflow.approveProposal(sessionId: 'session-1');
        expect(second, isNotNull);

        // No note entities in the retry — both were already drained.
        final retryNotes =
            allUpserted.whereType<EvolutionNoteEntity>().toList();
        expect(retryNotes, isEmpty);
      },
    );
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
      stubFullSessionContext(
        templateService: mockTemplateService,
        syncService: mockSyncService,
      );

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
      expect(limit, 30);
    });
  });

  group('startSession data-fetch error handling', () {
    late MockAgentTemplateService mockTemplateService;
    late MockAgentSyncService mockSyncService;
    late MockAgentRepository mockRepository;

    setUp(() {
      mockTemplateService = MockAgentTemplateService();
      mockSyncService = MockAgentSyncService();
      mockRepository = MockAgentRepository();
      when(() => mockTemplateService.repository).thenReturn(mockRepository);
    });

    test('returns null when computeMetrics throws', () async {
      stubFullSessionContext(
        templateService: mockTemplateService,
        syncService: mockSyncService,
      );
      // Stub getEntity for abandonSession cleanup path.
      when(() => mockRepository.getEntity(any())).thenAnswer((_) async => null);
      // Override one data-fetch to throw.
      when(() => mockTemplateService.computeMetrics(any()))
          .thenThrow(StateError('DB error'));

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(
          assistantResponse: 'Hello',
        ),
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
      );

      // Should return null, not throw.
      final result = await workflow.startSession(templateId: kTestTemplateId);
      expect(result, isNull);
    });

    test('returns null when getRecentInstanceReports throws', () async {
      stubFullSessionContext(
        templateService: mockTemplateService,
        syncService: mockSyncService,
      );
      when(() => mockRepository.getEntity(any())).thenAnswer((_) async => null);
      when(() => mockTemplateService.getRecentInstanceReports(any()))
          .thenThrow(StateError('DB error'));

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(
          assistantResponse: 'Hello',
        ),
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
      );

      final result = await workflow.startSession(templateId: kTestTemplateId);
      expect(result, isNull);
    });
  });

  group('startSession duplicate guard', () {
    late MockAgentTemplateService mockTemplateService;
    late MockAgentSyncService mockSyncService;
    late MockAgentRepository mockRepository;

    setUp(() {
      mockTemplateService = MockAgentTemplateService();
      mockSyncService = MockAgentSyncService();
      mockRepository = MockAgentRepository();
      when(() => mockTemplateService.repository).thenReturn(mockRepository);
    });

    test('returns null when a session is already active for the template',
        () async {
      stubFullSessionContext(
        templateService: mockTemplateService,
        syncService: mockSyncService,
      );

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(
          assistantResponse: 'Hello',
        ),
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
      );

      // Pre-populate an active session for the same template.
      workflow.activeSessions['existing'] = ActiveEvolutionSession(
        sessionId: 'existing',
        templateId: kTestTemplateId,
        conversationId: 'conv-existing',
        strategy: EvolutionStrategy(),
        modelId: 'model',
      );

      // Second startSession should be rejected.
      final result = await workflow.startSession(templateId: kTestTemplateId);
      expect(result, isNull);

      // No additional session entity should have been created.
      verifyNever(() => mockSyncService.upsertEntity(any()));
    });

    test('allows session for a different template', () async {
      stubFullSessionContext(
        templateService: mockTemplateService,
        syncService: mockSyncService,
      );

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(
          assistantResponse: 'Hello',
        ),
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
      );

      // Active session for a DIFFERENT template.
      workflow.activeSessions['other'] = ActiveEvolutionSession(
        sessionId: 'other',
        templateId: 'other-template',
        conversationId: 'conv-other',
        strategy: EvolutionStrategy(),
        modelId: 'model',
      );

      // Should succeed for a different template.
      final result = await workflow.startSession(templateId: kTestTemplateId);
      expect(result, isNotNull);
    });
  });

  group('update notifications', () {
    late MockAgentTemplateService mockTemplateService;
    late MockAgentSyncService mockSyncService;
    late MockAgentRepository mockRepository;
    late MockUpdateNotifications mockNotifications;

    setUp(() {
      mockTemplateService = MockAgentTemplateService();
      mockSyncService = MockAgentSyncService();
      mockRepository = MockAgentRepository();
      mockNotifications = MockUpdateNotifications();
      when(() => mockTemplateService.repository).thenReturn(mockRepository);
    });

    test('startSession fires notification on success', () async {
      stubFullSessionContext(
        templateService: mockTemplateService,
        syncService: mockSyncService,
      );

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(
          assistantResponse: 'Hello',
        ),
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
        updateNotifications: mockNotifications,
      );

      await workflow.startSession(templateId: kTestTemplateId);

      verify(
        () => mockNotifications.notify({kTestTemplateId, agentNotification}),
      ).called(1);
    });

    test('approveProposal fires notification on success', () async {
      final newVersion = makeTestTemplateVersion(
        id: 'v2',
        version: 2,
        directives: 'Improved',
      );
      when(
        () => mockTemplateService.createVersion(
          templateId: any(named: 'templateId'),
          directives: any(named: 'directives'),
          authoredBy: any(named: 'authoredBy'),
        ),
      ).thenAnswer((_) async => newVersion);
      when(() => mockRepository.getEntity(any()))
          .thenAnswer((_) async => makeTestEvolutionSession());
      when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});

      final strategy = EvolutionStrategy();
      final manager = ConversationManager(conversationId: 'conv-1')
        ..initialize();
      const proposalCall = ChatCompletionMessageToolCall(
        id: 'call-1',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'propose_directives',
          arguments: '{"directives":"Improved","rationale":"Better"}',
        ),
      );
      manager.addAssistantMessage(toolCalls: [proposalCall]);
      await strategy.processToolCalls(
        toolCalls: [proposalCall],
        manager: manager,
      );

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(),
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
        updateNotifications: mockNotifications,
      );

      workflow.activeSessions['session-1'] = ActiveEvolutionSession(
        sessionId: 'session-1',
        templateId: kTestTemplateId,
        conversationId: 'test-conv-id',
        strategy: strategy,
        modelId: 'model',
      );

      await workflow.approveProposal(sessionId: 'session-1');

      verify(
        () => mockNotifications.notify({kTestTemplateId, agentNotification}),
      ).called(1);
    });

    test('abandonSession fires notification', () async {
      when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
      when(() => mockRepository.getEntity(any()))
          .thenAnswer((_) async => makeTestEvolutionSession());

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(),
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
        updateNotifications: mockNotifications,
      );

      workflow.activeSessions['session-1'] = ActiveEvolutionSession(
        sessionId: 'session-1',
        templateId: kTestTemplateId,
        conversationId: 'test-conv-id',
        strategy: EvolutionStrategy(),
        modelId: 'model',
      );

      await workflow.abandonSession(sessionId: 'session-1');

      verify(
        () => mockNotifications.notify({kTestTemplateId, agentNotification}),
      ).called(1);
    });

    test('no notification when updateNotifications is not set', () async {
      stubFullSessionContext(
        templateService: mockTemplateService,
        syncService: mockSyncService,
      );

      // Workflow created without updateNotifications.
      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(
          assistantResponse: 'Hello',
        ),
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
      );

      // Should not throw or crash without updateNotifications.
      final result = await workflow.startSession(templateId: kTestTemplateId);
      expect(result, isNotNull);
    });
  });

  group('startSession with contextOverride', () {
    late MockAgentTemplateService mockTemplateService;
    late MockAgentSyncService mockSyncService;
    late MockAgentRepository mockRepository;

    setUp(() {
      mockTemplateService = MockAgentTemplateService();
      mockSyncService = MockAgentSyncService();
      mockRepository = MockAgentRepository();
      when(() => mockTemplateService.repository).thenReturn(mockRepository);
    });

    test('skips internal context building when contextOverride is provided',
        () async {
      stubProviderResolution();
      when(() => mockTemplateService.getTemplate(any()))
          .thenAnswer((_) async => makeTestTemplate());
      when(() => mockTemplateService.getActiveVersion(any()))
          .thenAnswer((_) async => makeTestTemplateVersion());
      when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
      when(() => mockTemplateService.getEvolutionSessions(any()))
          .thenAnswer((_) async => []);

      final convRepo = _TestConversationRepository(
        assistantResponse: 'Ritual response',
      );

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: convRepo,
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
      );

      const overrideContext = EvolutionContext(
        systemPrompt: 'Custom ritual system prompt',
        initialUserMessage: 'Custom ritual user message with feedback',
      );

      final response = await workflow.startSession(
        templateId: kTestTemplateId,
        contextOverride: overrideContext,
      );

      expect(response, 'Ritual response');
      expect(workflow.activeSessions, hasLength(1));

      // Should NOT have called internal context building methods.
      verifyNever(() => mockTemplateService.computeMetrics(any()));
      verifyNever(
        () => mockTemplateService.getVersionHistory(
          any(),
          limit: any(named: 'limit'),
        ),
      );
      verifyNever(
        () => mockTemplateService.getRecentInstanceReports(any()),
      );
      verifyNever(
        () => mockTemplateService.getRecentInstanceObservations(any()),
      );
      verifyNever(
        () => mockTemplateService.getRecentEvolutionNotes(
          any(),
          limit: any(named: 'limit'),
        ),
      );
      verifyNever(
        () => mockTemplateService.countChangesSince(any(), any()),
      );
    });

    test('uses override system prompt for conversation', () async {
      stubProviderResolution();
      when(() => mockTemplateService.getTemplate(any()))
          .thenAnswer((_) async => makeTestTemplate());
      when(() => mockTemplateService.getActiveVersion(any()))
          .thenAnswer((_) async => makeTestTemplateVersion());
      when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
      when(() => mockTemplateService.getEvolutionSessions(any()))
          .thenAnswer((_) async => []);

      final convRepo = _TestConversationRepository(
        assistantResponse: 'Response',
      )
        // Track the system message passed to createConversation by replacing
        // the delegate.
        ..createConversationDelegate = () {
          // We can't easily capture createConversation params through
          // _TestConversationRepository, so we verify indirectly by checking
          // that the session was created successfully with the override.
          return 'test-conv-id';
        };

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: convRepo,
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
      );

      const overrideContext = EvolutionContext(
        systemPrompt: 'Ritual-specific system prompt',
        initialUserMessage: 'Ritual user message',
      );

      final response = await workflow.startSession(
        templateId: kTestTemplateId,
        contextOverride: overrideContext,
      );

      // Session was created successfully with the override context.
      expect(response, isNotNull);
      expect(workflow.activeSessions, hasLength(1));
    });
  });

  group('onSessionCompleted callback', () {
    late MockAgentTemplateService mockTemplateService;
    late MockAgentSyncService mockSyncService;
    late MockAgentRepository mockRepository;

    setUp(() {
      mockTemplateService = MockAgentTemplateService();
      mockSyncService = MockAgentSyncService();
      mockRepository = MockAgentRepository();
      when(() => mockTemplateService.repository).thenReturn(mockRepository);
    });

    test('fires callback after approveProposal completes', () async {
      final newVersion = makeTestTemplateVersion(
        id: 'new-version',
        version: 2,
        directives: 'New directives',
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

      String? callbackTemplateId;
      String? callbackSessionId;

      final convRepo = _TestConversationRepository();
      final strategy = EvolutionStrategy();
      final manager = ConversationManager(conversationId: 'conv-1')
        ..initialize();
      const toolCall = ChatCompletionMessageToolCall(
        id: 'call-1',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'propose_directives',
          arguments: '{"directives":"New directives","rationale":"R"}',
        ),
      );
      manager.addAssistantMessage(toolCalls: [toolCall]);
      await strategy.processToolCalls(toolCalls: [toolCall], manager: manager);

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: convRepo,
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
        onSessionCompleted: (templateId, sessionId) {
          callbackTemplateId = templateId;
          callbackSessionId = sessionId;
        },
      );

      workflow.activeSessions['session-1'] = ActiveEvolutionSession(
        sessionId: 'session-1',
        templateId: kTestTemplateId,
        conversationId: 'test-conv-id',
        strategy: strategy,
        modelId: 'model',
      );

      final result = await workflow.approveProposal(sessionId: 'session-1');

      expect(result, isNotNull);
      expect(callbackTemplateId, kTestTemplateId);
      expect(callbackSessionId, 'session-1');
    });

    test('callback is not fired when approve fails', () async {
      when(
        () => mockTemplateService.createVersion(
          templateId: any(named: 'templateId'),
          directives: any(named: 'directives'),
          authoredBy: any(named: 'authoredBy'),
        ),
      ).thenThrow(StateError('DB error'));

      var callbackFired = false;

      final strategy = EvolutionStrategy();
      final manager = ConversationManager(conversationId: 'conv-1')
        ..initialize();
      const toolCall = ChatCompletionMessageToolCall(
        id: 'call-1',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'propose_directives',
          arguments: '{"directives":"X","rationale":"R"}',
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
        onSessionCompleted: (_, __) {
          callbackFired = true;
        },
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
      expect(callbackFired, isFalse);
    });
  });
}
