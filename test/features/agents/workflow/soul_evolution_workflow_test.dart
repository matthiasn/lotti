import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/classified_feedback.dart';
import 'package:lotti/features/agents/workflow/evolution_strategy.dart';
import 'package:lotti/features/agents/workflow/template_evolution_workflow.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
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

  /// Captured system message from the last [createConversation] call.
  String? lastSystemMessage;

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
    lastSystemMessage = systemMessage;
    if (createConversationDelegate != null) {
      return createConversationDelegate!();
    }
    return 'test-conv-id';
  }

  @override
  ConversationManager? getConversation(String conversationId) {
    if (assistantResponse == null) return null;

    final manager =
        ConversationManager(
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
    ChatCompletionToolChoiceOption? toolChoice,
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

/// Test subclass of [EvolutionStrategy] that allows directly setting
/// [latestRecap] and [latestSoulProposal] to values not reachable through
/// normal tool-call processing (e.g. empty TLDR or empty rationale).
class _TestableEvolutionStrategy extends EvolutionStrategy {
  PendingRitualRecap? _overriddenRecap;
  bool _recapOverridden = false;

  PendingSoulProposal? _overriddenSoulProposal;
  bool _soulProposalOverridden = false;

  void overrideRecap(PendingRitualRecap? recap) {
    _overriddenRecap = recap;
    _recapOverridden = true;
  }

  void overrideSoulProposal(PendingSoulProposal? proposal) {
    _overriddenSoulProposal = proposal;
    _soulProposalOverridden = true;
  }

  @override
  PendingRitualRecap? get latestRecap =>
      _recapOverridden ? _overriddenRecap : super.latestRecap;

  @override
  PendingSoulProposal? get latestSoulProposal => _soulProposalOverridden
      ? _overriddenSoulProposal
      : super.latestSoulProposal;
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
    when(
      () => mockAiConfig.getConfigsByType(AiConfigType.model),
    ).thenAnswer((_) async => [testAiModel()]);
    when(
      () => mockAiConfig.getConfigById('provider-1'),
    ).thenAnswer((_) async => testInferenceProvider(apiKey: apiKey));
  }

  group('approveSoulProposal', () {
    test('creates soul version and clears proposal', () async {
      final mockSoulService = MockSoulDocumentService();
      final soulVersion = makeTestSoulDocumentVersion(
        id: 'sv-active',
        voiceDirective: 'Current voice.',
        toneBounds: 'Current bounds.',
      );
      when(
        () => mockSoulService.resolveActiveSoulForTemplate(kTestTemplateId),
      ).thenAnswer((_) async => soulVersion);

      final newVersion = makeTestSoulDocumentVersion(
        id: 'sv-new',
        version: 2,
        voiceDirective: 'Updated voice.',
      );
      when(
        () => mockSoulService.createVersion(
          soulId: any(named: 'soulId'),
          voiceDirective: any(named: 'voiceDirective'),
          authoredBy: any(named: 'authoredBy'),
          toneBounds: any(named: 'toneBounds'),
          coachingStyle: any(named: 'coachingStyle'),
          antiSycophancyPolicy: any(named: 'antiSycophancyPolicy'),
          sourceSessionId: any(named: 'sourceSessionId'),
        ),
      ).thenAnswer((_) async => newVersion);

      final strategy = EvolutionStrategy();
      final manager = ConversationManager(conversationId: 'conv-soul')
        ..initialize();
      const toolCall = ChatCompletionMessageToolCall(
        id: 'call-soul',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'propose_soul_directives',
          arguments:
              '{"voice_directive":"Updated voice.","rationale":"Reason"}',
        ),
      );
      manager.addAssistantMessage(toolCalls: [toolCall]);
      await strategy.processToolCalls(
        toolCalls: [toolCall],
        manager: manager,
      );
      expect(strategy.latestSoulProposal, isNotNull);

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(),
        aiConfigRepository: MockAiConfigRepository(),
        cloudInferenceRepository: MockCloudInferenceRepository(),
        soulDocumentService: mockSoulService,
      );

      workflow.activeSessions['session-soul'] = ActiveEvolutionSession(
        sessionId: 'session-soul',
        templateId: kTestTemplateId,
        conversationId: 'conv-soul',
        strategy: strategy,
        modelId: 'model',
      );

      final result = await workflow.approveSoulProposal(
        sessionId: 'session-soul',
      );

      expect(result, isNotNull);
      expect(result!.id, 'sv-new');
      expect(strategy.latestSoulProposal, isNull);
      // Session still active — not completed by soul approval.
      expect(workflow.activeSessions, hasLength(1));
      // Strategy baseline should be refreshed to the new version's values.
      expect(strategy.currentVoiceDirective, 'Updated voice.');
    });

    test('refreshes strategy soul baseline after approval', () async {
      final mockSoulService = MockSoulDocumentService();
      final soulVersion = makeTestSoulDocumentVersion(
        id: 'sv-active',
        voiceDirective: 'Old voice.',
        toneBounds: 'Old bounds.',
        coachingStyle: 'Old coaching.',
        antiSycophancyPolicy: 'Old policy.',
      );
      when(
        () => mockSoulService.resolveActiveSoulForTemplate(kTestTemplateId),
      ).thenAnswer((_) async => soulVersion);

      final newVersion = makeTestSoulDocumentVersion(
        id: 'sv-new',
        version: 2,
        voiceDirective: 'New voice.',
        toneBounds: 'New bounds.',
        coachingStyle: 'New coaching.',
        antiSycophancyPolicy: 'New policy.',
      );
      when(
        () => mockSoulService.createVersion(
          soulId: any(named: 'soulId'),
          voiceDirective: any(named: 'voiceDirective'),
          authoredBy: any(named: 'authoredBy'),
          toneBounds: any(named: 'toneBounds'),
          coachingStyle: any(named: 'coachingStyle'),
          antiSycophancyPolicy: any(named: 'antiSycophancyPolicy'),
          sourceSessionId: any(named: 'sourceSessionId'),
        ),
      ).thenAnswer((_) async => newVersion);

      final strategy = EvolutionStrategy(
        currentVoiceDirective: 'Old voice.',
        currentToneBounds: 'Old bounds.',
        currentCoachingStyle: 'Old coaching.',
        currentAntiSycophancyPolicy: 'Old policy.',
      );
      final manager = ConversationManager(conversationId: 'conv-refresh')
        ..initialize();
      const toolCall = ChatCompletionMessageToolCall(
        id: 'call-refresh',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'propose_soul_directives',
          arguments:
              '{"voice_directive":"New voice.",'
              ' "tone_bounds":"New bounds.",'
              ' "coaching_style":"New coaching.",'
              ' "anti_sycophancy_policy":"New policy.",'
              ' "rationale":"Full update."}',
        ),
      );
      manager.addAssistantMessage(toolCalls: [toolCall]);
      await strategy.processToolCalls(
        toolCalls: [toolCall],
        manager: manager,
      );

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(),
        aiConfigRepository: MockAiConfigRepository(),
        cloudInferenceRepository: MockCloudInferenceRepository(),
        soulDocumentService: mockSoulService,
      );

      workflow.activeSessions['session-refresh'] = ActiveEvolutionSession(
        sessionId: 'session-refresh',
        templateId: kTestTemplateId,
        conversationId: 'conv-refresh',
        strategy: strategy,
        modelId: 'model',
      );

      await workflow.approveSoulProposal(sessionId: 'session-refresh');

      // Strategy baseline should be updated to the new version's values.
      expect(strategy.currentVoiceDirective, 'New voice.');
      expect(strategy.currentToneBounds, 'New bounds.');
      expect(strategy.currentCoachingStyle, 'New coaching.');
      expect(strategy.currentAntiSycophancyPolicy, 'New policy.');
    });

    test('falls back to current values for empty proposal fields', () async {
      final mockSoulService = MockSoulDocumentService();
      final soulVersion = makeTestSoulDocumentVersion(
        id: 'sv-active',
        voiceDirective: 'Current voice.',
        toneBounds: 'Current bounds.',
        coachingStyle: 'Current coaching.',
        antiSycophancyPolicy: 'Current policy.',
      );
      when(
        () => mockSoulService.resolveActiveSoulForTemplate(kTestTemplateId),
      ).thenAnswer((_) async => soulVersion);

      final newVersion = makeTestSoulDocumentVersion(
        id: 'sv-new',
        version: 2,
        voiceDirective: 'Updated voice.',
      );
      when(
        () => mockSoulService.createVersion(
          soulId: any(named: 'soulId'),
          voiceDirective: any(named: 'voiceDirective'),
          authoredBy: any(named: 'authoredBy'),
          toneBounds: any(named: 'toneBounds'),
          coachingStyle: any(named: 'coachingStyle'),
          antiSycophancyPolicy: any(named: 'antiSycophancyPolicy'),
          sourceSessionId: any(named: 'sourceSessionId'),
        ),
      ).thenAnswer((_) async => newVersion);

      // Propose only voice — other fields are empty.
      final strategy = EvolutionStrategy();
      final manager = ConversationManager(conversationId: 'conv-merge')
        ..initialize();
      const toolCall = ChatCompletionMessageToolCall(
        id: 'call-merge',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'propose_soul_directives',
          arguments: '{"voice_directive":"New voice.","rationale":"Reason"}',
        ),
      );
      manager.addAssistantMessage(toolCalls: [toolCall]);
      await strategy.processToolCalls(
        toolCalls: [toolCall],
        manager: manager,
      );

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(),
        aiConfigRepository: MockAiConfigRepository(),
        cloudInferenceRepository: MockCloudInferenceRepository(),
        soulDocumentService: mockSoulService,
      );

      workflow.activeSessions['session-merge'] = ActiveEvolutionSession(
        sessionId: 'session-merge',
        templateId: kTestTemplateId,
        conversationId: 'conv-merge',
        strategy: strategy,
        modelId: 'model',
      );

      await workflow.approveSoulProposal(sessionId: 'session-merge');

      // Verify createVersion was called with the merged values:
      // - voiceDirective: "New voice." (from proposal)
      // - toneBounds, coachingStyle, antiSycophancyPolicy: current values
      final captured = verify(
        () => mockSoulService.createVersion(
          soulId: captureAny(named: 'soulId'),
          voiceDirective: captureAny(named: 'voiceDirective'),
          authoredBy: captureAny(named: 'authoredBy'),
          toneBounds: captureAny(named: 'toneBounds'),
          coachingStyle: captureAny(named: 'coachingStyle'),
          antiSycophancyPolicy: captureAny(named: 'antiSycophancyPolicy'),
          sourceSessionId: captureAny(named: 'sourceSessionId'),
        ),
      ).captured;

      // captured is a flat list: [soulId, voice, authoredBy, tone, coaching,
      //                           antiSycophancy, sourceSessionId]
      final voice = captured[1] as String;
      final tone = captured[3] as String;
      final coaching = captured[4] as String;
      final antiSycophancy = captured[5] as String;

      expect(voice, 'New voice.');
      expect(tone, 'Current bounds.');
      expect(coaching, 'Current coaching.');
      expect(antiSycophancy, 'Current policy.');
    });

    test(
      'falls back to current voiceDirective when proposal voice is empty',
      () async {
        final mockSoulService = MockSoulDocumentService();
        final soulVersion = makeTestSoulDocumentVersion(
          id: 'sv-active',
          voiceDirective: 'Current voice.',
          toneBounds: 'Current bounds.',
          coachingStyle: 'Current coaching.',
          antiSycophancyPolicy: 'Current policy.',
        );
        when(
          () => mockSoulService.resolveActiveSoulForTemplate(kTestTemplateId),
        ).thenAnswer((_) async => soulVersion);

        final newVersion = makeTestSoulDocumentVersion(
          id: 'sv-new',
          version: 2,
          voiceDirective: 'Current voice.',
          toneBounds: 'Updated bounds.',
        );
        when(
          () => mockSoulService.createVersion(
            soulId: any(named: 'soulId'),
            voiceDirective: any(named: 'voiceDirective'),
            authoredBy: any(named: 'authoredBy'),
            toneBounds: any(named: 'toneBounds'),
            coachingStyle: any(named: 'coachingStyle'),
            antiSycophancyPolicy: any(named: 'antiSycophancyPolicy'),
            sourceSessionId: any(named: 'sourceSessionId'),
          ),
        ).thenAnswer((_) async => newVersion);

        // Propose only tone_bounds; voice_directive is absent (empty) so it
        // must fall back to the current soul version's voiceDirective.
        final strategy = EvolutionStrategy();
        final manager = ConversationManager(conversationId: 'conv-empty-voice')
          ..initialize();
        const toolCall = ChatCompletionMessageToolCall(
          id: 'call-empty-voice',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'propose_soul_directives',
            arguments:
                '{"tone_bounds":"Updated bounds.","rationale":"Tone only."}',
          ),
        );
        manager.addAssistantMessage(toolCalls: [toolCall]);
        await strategy.processToolCalls(
          toolCalls: [toolCall],
          manager: manager,
        );
        expect(strategy.latestSoulProposal, isNotNull);
        expect(strategy.latestSoulProposal!.voiceDirective, isEmpty);

        final workflow = TemplateEvolutionWorkflow(
          conversationRepository: _TestConversationRepository(),
          aiConfigRepository: MockAiConfigRepository(),
          cloudInferenceRepository: MockCloudInferenceRepository(),
          soulDocumentService: mockSoulService,
        );
        workflow.activeSessions['session-empty-voice'] = ActiveEvolutionSession(
          sessionId: 'session-empty-voice',
          templateId: kTestTemplateId,
          conversationId: 'conv-empty-voice',
          strategy: strategy,
          modelId: 'model',
        );

        await workflow.approveSoulProposal(sessionId: 'session-empty-voice');

        final captured = verify(
          () => mockSoulService.createVersion(
            soulId: captureAny(named: 'soulId'),
            voiceDirective: captureAny(named: 'voiceDirective'),
            authoredBy: captureAny(named: 'authoredBy'),
            toneBounds: captureAny(named: 'toneBounds'),
            coachingStyle: captureAny(named: 'coachingStyle'),
            antiSycophancyPolicy: captureAny(named: 'antiSycophancyPolicy'),
            sourceSessionId: captureAny(named: 'sourceSessionId'),
          ),
        ).captured;

        // voiceDirective falls back to current; toneBounds is the proposal.
        expect(captured[1], 'Current voice.');
        expect(captured[3], 'Updated bounds.');
      },
    );

    test('returns null when no soul proposal exists', () async {
      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(),
        aiConfigRepository: MockAiConfigRepository(),
        cloudInferenceRepository: MockCloudInferenceRepository(),
        soulDocumentService: MockSoulDocumentService(),
      );

      workflow.activeSessions['session-1'] = ActiveEvolutionSession(
        sessionId: 'session-1',
        templateId: kTestTemplateId,
        conversationId: 'conv-1',
        strategy: EvolutionStrategy(),
        modelId: 'model',
      );

      final result = await workflow.approveSoulProposal(
        sessionId: 'session-1',
      );

      expect(result, isNull);
    });

    test('returns null when no soul service available', () async {
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

      final result = await workflow.approveSoulProposal(
        sessionId: 'session-1',
      );

      expect(result, isNull);
    });

    test('returns null when no soul assigned to template', () async {
      final mockSoulService = MockSoulDocumentService();
      when(
        () => mockSoulService.resolveActiveSoulForTemplate(kTestTemplateId),
      ).thenAnswer((_) async => null);

      final strategy = EvolutionStrategy();
      final manager = ConversationManager(conversationId: 'conv-no-soul')
        ..initialize();
      const toolCall = ChatCompletionMessageToolCall(
        id: 'call-ns',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'propose_soul_directives',
          arguments: '{"voice_directive":"V","rationale":"R"}',
        ),
      );
      manager.addAssistantMessage(toolCalls: [toolCall]);
      await strategy.processToolCalls(
        toolCalls: [toolCall],
        manager: manager,
      );

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(),
        aiConfigRepository: MockAiConfigRepository(),
        cloudInferenceRepository: MockCloudInferenceRepository(),
        soulDocumentService: mockSoulService,
      );

      workflow.activeSessions['session-ns'] = ActiveEvolutionSession(
        sessionId: 'session-ns',
        templateId: kTestTemplateId,
        conversationId: 'conv-no-soul',
        strategy: strategy,
        modelId: 'model',
      );

      final result = await workflow.approveSoulProposal(
        sessionId: 'session-ns',
      );

      expect(result, isNull);
    });
  });

  group('rejectSoulProposal', () {
    test('clears soul proposal from strategy', () async {
      final strategy = EvolutionStrategy();
      final manager = ConversationManager(conversationId: 'conv-1')
        ..initialize();
      const toolCall = ChatCompletionMessageToolCall(
        id: 'call-1',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'propose_soul_directives',
          arguments: '{"voice_directive":"V","rationale":"R"}',
        ),
      );
      manager.addAssistantMessage(toolCalls: [toolCall]);
      await strategy.processToolCalls(
        toolCalls: [toolCall],
        manager: manager,
      );
      expect(strategy.latestSoulProposal, isNotNull);

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

      workflow.rejectSoulProposal(sessionId: 'session-1');

      expect(strategy.latestSoulProposal, isNull);
      expect(workflow.activeSessions, hasLength(1));
    });

    test('is safe for unknown session', () {
      TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(),
        aiConfigRepository: MockAiConfigRepository(),
        cloudInferenceRepository: MockCloudInferenceRepository(),
      ).rejectSoulProposal(sessionId: 'nonexistent');
    });
  });

  group('startSoulSession', () {
    late MockAgentTemplateService mockTemplateService;
    late MockAgentSyncService mockSyncService;
    late MockSoulDocumentService mockSoulService;
    late MockAgentRepository mockRepository;

    setUp(() {
      mockTemplateService = MockAgentTemplateService();
      mockSyncService = MockAgentSyncService();
      mockSoulService = MockSoulDocumentService();
      mockRepository = MockAgentRepository();
      when(() => mockTemplateService.repository).thenReturn(mockRepository);
    });

    TemplateEvolutionWorkflow buildSoulWorkflow({
      _TestConversationRepository? convRepo,
    }) {
      return TemplateEvolutionWorkflow(
        conversationRepository:
            convRepo ??
            _TestConversationRepository(
              assistantResponse: 'Hi! How has my tone been landing?',
            ),
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
        soulDocumentService: mockSoulService,
      );
    }

    void stubSoulContext() {
      stubProviderResolution();
      when(() => mockSoulService.getSoul(any())).thenAnswer(
        (_) async => makeTestSoulDocument(),
      );
      when(() => mockSoulService.getActiveSoulVersion(any())).thenAnswer(
        (_) async => makeTestSoulDocumentVersion(),
      );
      when(() => mockSoulService.getTemplatesUsingSoul(any())).thenAnswer(
        (_) async => [kTestTemplateId],
      );
      when(() => mockSoulService.getVersionHistory(any())).thenAnswer(
        (_) async => <SoulDocumentVersionEntity>[],
      );
      when(() => mockTemplateService.getTemplate(any())).thenAnswer(
        (_) async => makeTestTemplate(),
      );
      when(
        () => mockTemplateService.getRecentEvolutionNotes(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => <EvolutionNoteEntity>[]);
      when(
        () => mockTemplateService.getEvolutionSessions(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => <EvolutionSessionEntity>[]);
      when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
    }

    test('creates soul session and returns response', () async {
      stubSoulContext();
      final workflow = buildSoulWorkflow();

      final response = await workflow.startSoulSession(soulId: kTestSoulId);

      expect(response, 'Hi! How has my tone been landing?');
      expect(workflow.activeSessions, hasLength(1));

      final session = workflow.activeSessions.values.first;
      expect(session.templateId, kTestSoulId);

      // Verify session entity was persisted.
      final captured = verify(
        () => mockSyncService.upsertEntity(captureAny()),
      ).captured;
      final sessionEntity = captured.whereType<EvolutionSessionEntity>().first;
      expect(sessionEntity.agentId, kTestSoulId);
      expect(sessionEntity.templateId, kTestSoulId);
      expect(sessionEntity.status, EvolutionSessionStatus.active);
      expect(sessionEntity.sessionNumber, 1);
    });

    test('returns null when soul not found', () async {
      stubProviderResolution();
      when(() => mockSoulService.getSoul(any())).thenAnswer((_) async => null);

      final workflow = buildSoulWorkflow();
      final response = await workflow.startSoulSession(soulId: 'missing');

      expect(response, isNull);
      expect(workflow.activeSessions, isEmpty);
    });

    test('returns null when no templates use the soul', () async {
      stubSoulContext();
      when(
        () => mockSoulService.getTemplatesUsingSoul(any()),
      ).thenAnswer((_) async => []);

      final workflow = buildSoulWorkflow();
      final response = await workflow.startSoulSession(soulId: kTestSoulId);

      expect(response, isNull);
    });

    test('returns null when soul has no active version', () async {
      stubSoulContext();
      when(
        () => mockSoulService.getActiveSoulVersion(any()),
      ).thenAnswer((_) async => null);

      final workflow = buildSoulWorkflow();
      final response = await workflow.startSoulSession(soulId: kTestSoulId);

      expect(response, isNull);
    });

    test('prevents concurrent sessions for same soul', () async {
      stubSoulContext();
      final workflow = buildSoulWorkflow();

      await workflow.startSoulSession(soulId: kTestSoulId);
      final second = await workflow.startSoulSession(soulId: kTestSoulId);

      expect(second, isNull);
      expect(workflow.activeSessions, hasLength(1));
    });

    test('getActiveSessionForSoul finds session', () async {
      stubSoulContext();
      final workflow = buildSoulWorkflow();

      await workflow.startSoulSession(soulId: kTestSoulId);

      final session = workflow.getActiveSessionForSoul(kTestSoulId);
      expect(session, isNotNull);
      expect(session!.templateId, kTestSoulId);
    });
  });

  group('completeSoulSession', () {
    late MockAgentTemplateService mockTemplateService;
    late MockAgentSyncService mockSyncService;
    late MockSoulDocumentService mockSoulService;
    late MockAgentRepository mockRepository;

    setUp(() {
      mockTemplateService = MockAgentTemplateService();
      mockSyncService = MockAgentSyncService();
      mockSoulService = MockSoulDocumentService();
      mockRepository = MockAgentRepository();
      when(() => mockTemplateService.repository).thenReturn(mockRepository);
    });

    TemplateEvolutionWorkflow buildSoulWorkflow({
      _TestConversationRepository? convRepo,
    }) {
      return TemplateEvolutionWorkflow(
        conversationRepository:
            convRepo ??
            _TestConversationRepository(
              assistantResponse: 'Soul session started.',
            ),
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
        soulDocumentService: mockSoulService,
      );
    }

    void stubSoulContext() {
      stubProviderResolution();
      when(() => mockSoulService.getSoul(any())).thenAnswer(
        (_) async => makeTestSoulDocument(),
      );
      when(() => mockSoulService.getActiveSoulVersion(any())).thenAnswer(
        (_) async => makeTestSoulDocumentVersion(),
      );
      when(() => mockSoulService.getTemplatesUsingSoul(any())).thenAnswer(
        (_) async => [kTestTemplateId],
      );
      when(() => mockSoulService.getVersionHistory(any())).thenAnswer(
        (_) async => <SoulDocumentVersionEntity>[],
      );
      when(() => mockTemplateService.getTemplate(any())).thenAnswer(
        (_) async => makeTestTemplate(),
      );
      when(
        () => mockTemplateService.getRecentEvolutionNotes(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => <EvolutionNoteEntity>[]);
      when(
        () => mockTemplateService.getEvolutionSessions(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => <EvolutionSessionEntity>[]);
      when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
    }

    test('returns null when no active session', () async {
      final workflow = buildSoulWorkflow();
      final result = await workflow.completeSoulSession(
        sessionId: 'nonexistent',
      );
      expect(result, isNull);
    });

    test('creates soul version on approval', () async {
      stubSoulContext();

      final newVersion = makeTestSoulDocumentVersion(
        id: 'new-version',
        version: 2,
        voiceDirective: 'Updated voice.',
      );
      when(
        () => mockSoulService.createVersion(
          soulId: any(named: 'soulId'),
          voiceDirective: any(named: 'voiceDirective'),
          authoredBy: any(named: 'authoredBy'),
          toneBounds: any(named: 'toneBounds'),
          coachingStyle: any(named: 'coachingStyle'),
          antiSycophancyPolicy: any(named: 'antiSycophancyPolicy'),
          sourceSessionId: any(named: 'sourceSessionId'),
        ),
      ).thenAnswer((_) async => newVersion);

      // Need a session entity for the completion path.
      when(() => mockRepository.getEntity(any())).thenAnswer((_) async => null);

      final workflow = buildSoulWorkflow();
      await workflow.startSoulSession(soulId: kTestSoulId);

      // Inject a soul proposal into the strategy via processToolCalls.
      final session = workflow.activeSessions.values.first;
      final manager = ConversationManager(
        conversationId: 'test',
        maxTurns: 1,
      )..initialize();
      await session.strategy.processToolCalls(
        toolCalls: [
          const ChatCompletionMessageToolCall(
            id: 'call-1',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'propose_soul_directives',
              arguments:
                  '{"voice_directive":"Updated voice.", '
                  '"rationale":"Warmer tone needed."}',
            ),
          ),
        ],
        manager: manager,
      );

      final result = await workflow.completeSoulSession(
        sessionId: session.sessionId,
      );

      expect(result, isNotNull);
      expect(result!.version, 2);

      // Session should be cleaned up.
      expect(workflow.activeSessions, isEmpty);
    });

    test('returns null when no soul proposal pending', () async {
      stubSoulContext();
      final workflow = buildSoulWorkflow();
      await workflow.startSoulSession(soulId: kTestSoulId);

      final session = workflow.activeSessions.values.first;
      final result = await workflow.completeSoulSession(
        sessionId: session.sessionId,
      );

      expect(result, isNull);
    });

    test(
      'does not touch soul services when active session has no proposal',
      () async {
        final workflow = buildSoulWorkflow();
        workflow.activeSessions['manual-soul-session'] = ActiveEvolutionSession(
          sessionId: 'manual-soul-session',
          templateId: kTestSoulId,
          conversationId: 'manual-conversation',
          strategy: EvolutionStrategy(),
          modelId: 'models/gemini-3-flash-preview',
        );

        final result = await workflow.completeSoulSession(
          sessionId: 'manual-soul-session',
        );

        expect(result, isNull);
        expect(
          workflow.activeSessions.containsKey('manual-soul-session'),
          isTrue,
        );
        verifyNever(() => mockSoulService.getActiveSoulVersion(any()));
        verifyNever(() => mockSyncService.upsertEntity(any()));
      },
    );

    test('handles createVersion failure gracefully', () async {
      stubSoulContext();

      when(
        () => mockSoulService.createVersion(
          soulId: any(named: 'soulId'),
          voiceDirective: any(named: 'voiceDirective'),
          authoredBy: any(named: 'authoredBy'),
          toneBounds: any(named: 'toneBounds'),
          coachingStyle: any(named: 'coachingStyle'),
          antiSycophancyPolicy: any(named: 'antiSycophancyPolicy'),
          sourceSessionId: any(named: 'sourceSessionId'),
        ),
      ).thenThrow(Exception('DB error'));

      when(() => mockRepository.getEntity(any())).thenAnswer((_) async => null);

      final workflow = buildSoulWorkflow();
      await workflow.startSoulSession(soulId: kTestSoulId);

      final session = workflow.activeSessions.values.first;
      final manager = ConversationManager(
        conversationId: 'test',
        maxTurns: 1,
      )..initialize();
      await session.strategy.processToolCalls(
        toolCalls: const [
          ChatCompletionMessageToolCall(
            id: 'call-1',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'propose_soul_directives',
              arguments:
                  '{"voice_directive":"Updated voice.",'
                  ' "rationale":"Warmer tone needed."}',
            ),
          ),
        ],
        manager: manager,
      );

      final result = await workflow.completeSoulSession(
        sessionId: session.sessionId,
      );

      expect(result, isNull);
      // Session should still be in active map (not cleaned up on failure).
      expect(workflow.activeSessions, hasLength(1));
    });

    test('completes session entity and persists recap', () async {
      stubSoulContext();

      final newVersion = makeTestSoulDocumentVersion(
        id: 'new-version-2',
        version: 2,
        voiceDirective: 'Updated voice.',
      );
      when(
        () => mockSoulService.createVersion(
          soulId: any(named: 'soulId'),
          voiceDirective: any(named: 'voiceDirective'),
          authoredBy: any(named: 'authoredBy'),
          toneBounds: any(named: 'toneBounds'),
          coachingStyle: any(named: 'coachingStyle'),
          antiSycophancyPolicy: any(named: 'antiSycophancyPolicy'),
          sourceSessionId: any(named: 'sourceSessionId'),
        ),
      ).thenAnswer((_) async => newVersion);

      // Return a session entity so the completion path updates it.
      final existingSession = makeTestEvolutionSession(
        agentId: kTestSoulId,
        templateId: kTestSoulId,
      );
      when(() => mockRepository.getEntity(any())).thenAnswer(
        (_) async => existingSession,
      );

      final workflow = buildSoulWorkflow();
      await workflow.startSoulSession(soulId: kTestSoulId);

      // Inject a soul proposal.
      final session = workflow.activeSessions.values.first;
      final manager = ConversationManager(
        conversationId: 'test',
        maxTurns: 1,
      )..initialize();
      await session.strategy.processToolCalls(
        toolCalls: [
          const ChatCompletionMessageToolCall(
            id: 'call-1',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'propose_soul_directives',
              arguments:
                  '{"voice_directive":"Updated voice.",'
                  ' "rationale":"Warmer tone needed."}',
            ),
          ),
          const ChatCompletionMessageToolCall(
            id: 'call-2',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'publish_ritual_recap',
              arguments:
                  '{"tldr":"Refined voice", '
                  r'"content":"## Recap\n\nRefined the voice."}',
            ),
          ),
        ],
        manager: manager,
      );

      final result = await workflow.completeSoulSession(
        sessionId: session.sessionId,
        categoryRatings: {'language': 4, 'tone': 3},
      );

      expect(result, isNotNull);
      expect(result!.version, 2);

      // Verify session entity was completed (upsert called multiple times).
      final captured = verify(
        () => mockSyncService.upsertEntity(captureAny()),
      ).captured;

      // Find the completed session entity.
      final completedSession = captured
          .whereType<EvolutionSessionEntity>()
          .where(
            (s) => s.status == EvolutionSessionStatus.completed,
          );
      expect(completedSession, isNotEmpty);
      expect(completedSession.first.proposedSoulVersionId, 'new-version-2');
      expect(completedSession.first.userRating, 3.5); // avg of 4 and 3

      // Verify recap entity was persisted.
      final recapEntities = captured.whereType<EvolutionSessionRecapEntity>();
      expect(recapEntities, isNotEmpty);

      // Session should be cleaned up.
      expect(workflow.activeSessions, isEmpty);
    });

    test(
      'returns null when no active soul version during completion',
      () async {
        stubSoulContext();

        // Override to return null for getActiveSoulVersion during completion.
        when(
          () => mockSoulService.getActiveSoulVersion(any()),
        ).thenAnswer((_) async => null);

        final convRepo = _TestConversationRepository(
          assistantResponse: 'Soul session started.',
        );
        final workflow = TemplateEvolutionWorkflow(
          conversationRepository: convRepo,
          aiConfigRepository: mockAiConfig,
          cloudInferenceRepository: mockCloudInference,
          templateService: mockTemplateService,
          syncService: mockSyncService,
          soulDocumentService: mockSoulService,
        );

        // Manually inject a session to bypass startSoulSession which also
        // checks for active version.
        final strategy = EvolutionStrategy();
        const sessionId = 'manual-session';
        workflow.activeSessions[sessionId] = ActiveEvolutionSession(
          sessionId: sessionId,
          templateId: kTestSoulId,
          conversationId: 'conv-1',
          strategy: strategy,
          modelId: 'model-1',
        );

        // Inject a soul proposal.
        final manager = ConversationManager(
          conversationId: 'test',
          maxTurns: 1,
        )..initialize();
        await strategy.processToolCalls(
          toolCalls: [
            const ChatCompletionMessageToolCall(
              id: 'call-1',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: 'propose_soul_directives',
                arguments:
                    '{"voice_directive":"New voice.",'
                    ' "rationale":"Better."}',
              ),
            ),
          ],
          manager: manager,
        );

        final result = await workflow.completeSoulSession(
          sessionId: sessionId,
        );

        expect(result, isNull);
      },
    );

    test('fires onSessionCompleted callback', () async {
      stubSoulContext();

      final newVersion = makeTestSoulDocumentVersion(
        id: 'cb-version',
        version: 2,
        voiceDirective: 'Updated.',
      );
      when(
        () => mockSoulService.createVersion(
          soulId: any(named: 'soulId'),
          voiceDirective: any(named: 'voiceDirective'),
          authoredBy: any(named: 'authoredBy'),
          toneBounds: any(named: 'toneBounds'),
          coachingStyle: any(named: 'coachingStyle'),
          antiSycophancyPolicy: any(named: 'antiSycophancyPolicy'),
          sourceSessionId: any(named: 'sourceSessionId'),
        ),
      ).thenAnswer((_) async => newVersion);
      when(() => mockRepository.getEntity(any())).thenAnswer((_) async => null);

      String? capturedTemplateId;
      String? capturedSessionId;

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(
          assistantResponse: 'Soul session started.',
        ),
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
        soulDocumentService: mockSoulService,
        onSessionCompleted: (templateId, sessionId) {
          capturedTemplateId = templateId;
          capturedSessionId = sessionId;
        },
      );

      await workflow.startSoulSession(soulId: kTestSoulId);
      final session = workflow.activeSessions.values.first;

      // Inject a soul proposal.
      final manager = ConversationManager(
        conversationId: 'test',
        maxTurns: 1,
      )..initialize();
      await session.strategy.processToolCalls(
        toolCalls: [
          const ChatCompletionMessageToolCall(
            id: 'call-1',
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: 'propose_soul_directives',
              arguments:
                  '{"voice_directive":"Updated.",'
                  ' "rationale":"Better."}',
            ),
          ),
        ],
        manager: manager,
      );

      await workflow.completeSoulSession(sessionId: session.sessionId);

      expect(capturedTemplateId, kTestSoulId);
      expect(capturedSessionId, session.sessionId);
    });
  });

  group('startSoulSession with feedback extraction', () {
    late MockAgentTemplateService mockTemplateService;
    late MockAgentSyncService mockSyncService;
    late MockSoulDocumentService mockSoulService;
    late MockAgentRepository mockRepository;
    late MockFeedbackExtractionService mockFeedbackService;

    setUp(() {
      mockTemplateService = MockAgentTemplateService();
      mockSyncService = MockAgentSyncService();
      mockSoulService = MockSoulDocumentService();
      mockRepository = MockAgentRepository();
      mockFeedbackService = MockFeedbackExtractionService();
      when(() => mockTemplateService.repository).thenReturn(mockRepository);
    });

    void stubSoulContextWithFeedback() {
      stubProviderResolution();
      when(() => mockSoulService.getSoul(any())).thenAnswer(
        (_) async => makeTestSoulDocument(),
      );
      when(() => mockSoulService.getActiveSoulVersion(any())).thenAnswer(
        (_) async => makeTestSoulDocumentVersion(),
      );
      when(() => mockSoulService.getTemplatesUsingSoul(any())).thenAnswer(
        (_) async => [kTestTemplateId],
      );
      when(() => mockSoulService.getVersionHistory(any())).thenAnswer(
        (_) async => <SoulDocumentVersionEntity>[],
      );
      when(() => mockTemplateService.getTemplate(any())).thenAnswer(
        (_) async => makeTestTemplate(),
      );
      when(
        () => mockTemplateService.getRecentEvolutionNotes(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => <EvolutionNoteEntity>[]);
      when(
        () => mockTemplateService.getEvolutionSessions(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => <EvolutionSessionEntity>[]);
      when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
    }

    test('invokes feedback extraction service when available', () async {
      stubSoulContextWithFeedback();
      when(
        () => mockFeedbackService.extractForSoul(
          soulId: any(named: 'soulId'),
          since: any(named: 'since'),
          until: any(named: 'until'),
        ),
      ).thenAnswer(
        (_) async => <String, ClassifiedFeedback>{},
      );

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(
          assistantResponse: 'Hello from soul session.',
        ),
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
        soulDocumentService: mockSoulService,
        feedbackService: mockFeedbackService,
      );

      final response = await workflow.startSoulSession(soulId: kTestSoulId);

      expect(response, 'Hello from soul session.');
      verify(
        () => mockFeedbackService.extractForSoul(
          soulId: kTestSoulId,
          since: any(named: 'since'),
          until: any(named: 'until'),
        ),
      ).called(1);
    });

    test(
      'continues session start when feedback extraction fails',
      () async {
        stubSoulContextWithFeedback();
        when(
          () => mockFeedbackService.extractForSoul(
            soulId: any(named: 'soulId'),
            since: any(named: 'since'),
            until: any(named: 'until'),
          ),
        ).thenThrow(Exception('feedback extraction error'));

        final workflow = TemplateEvolutionWorkflow(
          conversationRepository: _TestConversationRepository(
            assistantResponse: 'Hello despite error.',
          ),
          aiConfigRepository: mockAiConfig,
          cloudInferenceRepository: mockCloudInference,
          templateService: mockTemplateService,
          syncService: mockSyncService,
          soulDocumentService: mockSoulService,
          feedbackService: mockFeedbackService,
        );

        final response = await workflow.startSoulSession(soulId: kTestSoulId);

        // Session should still start despite feedback extraction failure.
        expect(response, 'Hello despite error.');
        expect(workflow.activeSessions, hasLength(1));
      },
    );
  });

  group('startSoulSession — error paths', () {
    late MockAgentTemplateService mockTemplateService;
    late MockAgentSyncService mockSyncService;
    late MockSoulDocumentService mockSoulService;
    late MockAgentRepository mockRepository;

    setUp(() {
      mockTemplateService = MockAgentTemplateService();
      mockSyncService = MockAgentSyncService();
      mockSoulService = MockSoulDocumentService();
      mockRepository = MockAgentRepository();
      when(() => mockTemplateService.repository).thenReturn(mockRepository);
    });

    test('returns null when soulDocumentService is null', () async {
      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(),
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
      );

      final response = await workflow.startSoulSession(soulId: kTestSoulId);
      expect(response, isNull);
    });

    test('returns null when templateService is null', () async {
      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(),
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        soulDocumentService: mockSoulService,
        syncService: mockSyncService,
      );

      final response = await workflow.startSoulSession(soulId: kTestSoulId);
      expect(response, isNull);
    });

    test('returns null when syncService is null', () async {
      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(),
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        soulDocumentService: mockSoulService,
      );

      final response = await workflow.startSoulSession(soulId: kTestSoulId);
      expect(response, isNull);
    });

    test('returns null when provider resolution fails', () async {
      // Don't stub provider resolution — it will fail.
      when(
        () => mockAiConfig.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => []);

      when(() => mockSoulService.getSoul(any())).thenAnswer(
        (_) async => makeTestSoulDocument(),
      );
      when(() => mockSoulService.getActiveSoulVersion(any())).thenAnswer(
        (_) async => makeTestSoulDocumentVersion(),
      );
      when(() => mockSoulService.getTemplatesUsingSoul(any())).thenAnswer(
        (_) async => [kTestTemplateId],
      );
      when(() => mockTemplateService.getTemplate(any())).thenAnswer(
        (_) async => makeTestTemplate(),
      );

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(),
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
        soulDocumentService: mockSoulService,
      );

      final response = await workflow.startSoulSession(soulId: kTestSoulId);
      expect(response, isNull);
    });
  });

  // ── Additional coverage tests ──────────────────────────────────────────────

  group('approveSoulProposal error path', () {
    test('returns null when createVersion throws', () async {
      final mockSoulService = MockSoulDocumentService();
      final soulVersion = makeTestSoulDocumentVersion(
        id: 'sv-active',
        voiceDirective: 'Current voice.',
      );
      when(
        () => mockSoulService.resolveActiveSoulForTemplate(kTestTemplateId),
      ).thenAnswer((_) async => soulVersion);
      when(
        () => mockSoulService.createVersion(
          soulId: any(named: 'soulId'),
          voiceDirective: any(named: 'voiceDirective'),
          authoredBy: any(named: 'authoredBy'),
          toneBounds: any(named: 'toneBounds'),
          coachingStyle: any(named: 'coachingStyle'),
          antiSycophancyPolicy: any(named: 'antiSycophancyPolicy'),
          sourceSessionId: any(named: 'sourceSessionId'),
        ),
      ).thenThrow(Exception('DB failure'));

      final strategy = EvolutionStrategy();
      final manager = ConversationManager(conversationId: 'conv-err')
        ..initialize();
      const toolCall = ChatCompletionMessageToolCall(
        id: 'call-err',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'propose_soul_directives',
          arguments: '{"voice_directive":"New voice.","rationale":"Reason"}',
        ),
      );
      manager.addAssistantMessage(toolCalls: [toolCall]);
      await strategy.processToolCalls(toolCalls: [toolCall], manager: manager);
      expect(strategy.latestSoulProposal, isNotNull);

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(),
        aiConfigRepository: MockAiConfigRepository(),
        cloudInferenceRepository: MockCloudInferenceRepository(),
        soulDocumentService: mockSoulService,
      );
      workflow.activeSessions['session-err'] = ActiveEvolutionSession(
        sessionId: 'session-err',
        templateId: kTestTemplateId,
        conversationId: 'conv-err',
        strategy: strategy,
        modelId: 'model',
      );

      final result = await workflow.approveSoulProposal(
        sessionId: 'session-err',
      );

      expect(result, isNull);
      // Proposal should still be present so caller can retry.
      expect(strategy.latestSoulProposal, isNotNull);
      // Session is still active.
      expect(workflow.activeSessions.containsKey('session-err'), isTrue);
    });
  });

  group('startSoulSession catch path', () {
    late MockAgentTemplateService mockTemplateService;
    late MockAgentSyncService mockSyncService;
    late MockSoulDocumentService mockSoulService;
    late MockAgentRepository mockRepository;

    setUp(() {
      mockTemplateService = MockAgentTemplateService();
      mockSyncService = MockAgentSyncService();
      mockSoulService = MockSoulDocumentService();
      mockRepository = MockAgentRepository();
      when(() => mockTemplateService.repository).thenReturn(mockRepository);
    });

    void stubSoulContext() {
      stubProviderResolution();
      when(
        () => mockSoulService.getSoul(any()),
      ).thenAnswer((_) async => makeTestSoulDocument());
      when(
        () => mockSoulService.getActiveSoulVersion(any()),
      ).thenAnswer((_) async => makeTestSoulDocumentVersion());
      when(
        () => mockSoulService.getTemplatesUsingSoul(any()),
      ).thenAnswer((_) async => [kTestTemplateId]);
      when(
        () => mockSoulService.getVersionHistory(any()),
      ).thenAnswer((_) async => <SoulDocumentVersionEntity>[]);
      when(
        () => mockTemplateService.getTemplate(any()),
      ).thenAnswer((_) async => makeTestTemplate());
      when(
        () => mockTemplateService.getRecentEvolutionNotes(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => <EvolutionNoteEntity>[]);
      when(
        () => mockTemplateService.getEvolutionSessions(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => <EvolutionSessionEntity>[]);
      when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
    }

    test(
      'returns null and calls abandonSession when sendMessage throws',
      () async {
        stubSoulContext();

        // Make sendMessage throw so the catch block fires.
        final convRepo =
            _TestConversationRepository(
                assistantResponse: 'response',
              )
              ..sendMessageDelegate = () async {
                throw Exception('LLM error in soul session');
              };

        // Stub getEntity for the abandon path.
        when(
          () => mockRepository.getEntity(any()),
        ).thenAnswer((_) async => null);

        final workflow = TemplateEvolutionWorkflow(
          conversationRepository: convRepo,
          aiConfigRepository: mockAiConfig,
          cloudInferenceRepository: mockCloudInference,
          templateService: mockTemplateService,
          syncService: mockSyncService,
          soulDocumentService: mockSoulService,
        );

        final response = await workflow.startSoulSession(soulId: kTestSoulId);

        expect(response, isNull);
        // Session must have been cleaned up by abandonSession.
        expect(workflow.activeSessions, isEmpty);
        expect(convRepo.deletedIds, isNotEmpty);
      },
    );

    test(
      'computes soul session number from existing sessions fold',
      () async {
        stubSoulContext();
        // Return multiple sessions so the fold picks the max.
        when(
          () => mockTemplateService.getEvolutionSessions(
            any(),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => [
            makeTestEvolutionSession(
              // ignore: avoid_redundant_argument_values
              id: 'evo-session-001',
              sessionNumber: 4,
            ),
            makeTestEvolutionSession(
              id: 'evo-session-002',
              sessionNumber: 2,
            ),
          ],
        );

        final workflow = TemplateEvolutionWorkflow(
          conversationRepository: _TestConversationRepository(
            assistantResponse: 'Soul reply.',
          ),
          aiConfigRepository: mockAiConfig,
          cloudInferenceRepository: mockCloudInference,
          templateService: mockTemplateService,
          syncService: mockSyncService,
          soulDocumentService: mockSoulService,
        );

        await workflow.startSoulSession(soulId: kTestSoulId);

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        // The stale sessions are abandoned first (upserted with status=abandoned).
        // The NEW session is the one with status=active.
        final newSessionEntity = captured
            .whereType<EvolutionSessionEntity>()
            .firstWhere((s) => s.status == EvolutionSessionStatus.active);
        // Max session number in existing list is 4, so next = 5.
        expect(newSessionEntity.sessionNumber, 5);
      },
    );
  });

  group('completeSoulSession — empty proposal field fallbacks', () {
    late MockAgentTemplateService mockTemplateService;
    late MockAgentSyncService mockSyncService;
    late MockSoulDocumentService mockSoulService;
    late MockAgentRepository mockRepository;

    setUp(() {
      mockTemplateService = MockAgentTemplateService();
      mockSyncService = MockAgentSyncService();
      mockSoulService = MockSoulDocumentService();
      mockRepository = MockAgentRepository();
      when(() => mockTemplateService.repository).thenReturn(mockRepository);
    });

    test(
      'falls back to current soul version fields when proposal fields are empty',
      () async {
        // Active soul version with all fields populated.
        final currentSoulVersion = makeTestSoulDocumentVersion(
          id: 'sv-current',
          // ignore: avoid_redundant_argument_values
          agentId: kTestSoulId,
          voiceDirective: 'Current voice.',
          toneBounds: 'Current bounds.',
          coachingStyle: 'Current coaching.',
          antiSycophancyPolicy: 'Current policy.',
        );
        when(
          () => mockSoulService.getActiveSoulVersion(kTestSoulId),
        ).thenAnswer((_) async => currentSoulVersion);

        final newVersion = makeTestSoulDocumentVersion(
          id: 'sv-new',
          version: 2,
          voiceDirective: 'Current voice.',
          toneBounds: 'Current bounds.',
          coachingStyle: 'Current coaching.',
          antiSycophancyPolicy: 'Current policy.',
        );
        when(
          () => mockSoulService.createVersion(
            soulId: any(named: 'soulId'),
            voiceDirective: any(named: 'voiceDirective'),
            authoredBy: any(named: 'authoredBy'),
            toneBounds: any(named: 'toneBounds'),
            coachingStyle: any(named: 'coachingStyle'),
            antiSycophancyPolicy: any(named: 'antiSycophancyPolicy'),
            sourceSessionId: any(named: 'sourceSessionId'),
          ),
        ).thenAnswer((_) async => newVersion);
        when(
          () => mockSyncService.upsertEntity(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockRepository.getEntity(any()),
        ).thenAnswer((_) async => null);

        final strategy = EvolutionStrategy();
        // Propose only voiceDirective; tone, coaching, antiSycophancy all empty
        // so they fall back to the current soul version values.
        final manager = ConversationManager(conversationId: 'conv-fallback')
          ..initialize();
        const toolCall = ChatCompletionMessageToolCall(
          id: 'call-fallback',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'propose_soul_directives',
            // voice_directive is provided but tone, coaching, and policy are
            // absent — the workflow must fall back to current version values
            // for the three empty fields.
            arguments:
                '{"voice_directive":"Current voice.", '
                '"rationale":"Full fallback test."}',
          ),
        );
        manager.addAssistantMessage(toolCalls: [toolCall]);
        await strategy.processToolCalls(
          toolCalls: [toolCall],
          manager: manager,
        );
        expect(strategy.latestSoulProposal, isNotNull);

        final workflow = TemplateEvolutionWorkflow(
          conversationRepository: _TestConversationRepository(),
          aiConfigRepository: MockAiConfigRepository(),
          cloudInferenceRepository: MockCloudInferenceRepository(),
          templateService: mockTemplateService,
          syncService: mockSyncService,
          soulDocumentService: mockSoulService,
        );
        workflow.activeSessions['sess-fallback'] = ActiveEvolutionSession(
          sessionId: 'sess-fallback',
          templateId: kTestSoulId,
          conversationId: 'conv-fallback',
          strategy: strategy,
          modelId: 'model',
        );

        final result = await workflow.completeSoulSession(
          sessionId: 'sess-fallback',
        );
        expect(result, isNotNull);

        // Verify createVersion was called with the fallback values from current.
        final captured = verify(
          () => mockSoulService.createVersion(
            soulId: captureAny(named: 'soulId'),
            voiceDirective: captureAny(named: 'voiceDirective'),
            authoredBy: captureAny(named: 'authoredBy'),
            toneBounds: captureAny(named: 'toneBounds'),
            coachingStyle: captureAny(named: 'coachingStyle'),
            antiSycophancyPolicy: captureAny(named: 'antiSycophancyPolicy'),
            sourceSessionId: captureAny(named: 'sourceSessionId'),
          ),
        ).captured;

        // Captured: [soulId, voice, authoredBy, tone, coaching, anti, srcSession]
        expect(captured[1], 'Current voice.');
        expect(captured[3], 'Current bounds.');
        expect(captured[4], 'Current coaching.');
        expect(captured[5], 'Current policy.');
      },
    );

    test(
      'falls back to current voiceDirective when proposal voice is empty',
      () async {
        final currentSoulVersion = makeTestSoulDocumentVersion(
          id: 'sv-current',
          // ignore: avoid_redundant_argument_values
          agentId: kTestSoulId,
          voiceDirective: 'Current voice.',
          toneBounds: 'Current bounds.',
          coachingStyle: 'Current coaching.',
          antiSycophancyPolicy: 'Current policy.',
        );
        when(
          () => mockSoulService.getActiveSoulVersion(kTestSoulId),
        ).thenAnswer((_) async => currentSoulVersion);

        final newVersion = makeTestSoulDocumentVersion(
          id: 'sv-new',
          version: 2,
          voiceDirective: 'Current voice.',
          toneBounds: 'Updated bounds.',
        );
        when(
          () => mockSoulService.createVersion(
            soulId: any(named: 'soulId'),
            voiceDirective: any(named: 'voiceDirective'),
            authoredBy: any(named: 'authoredBy'),
            toneBounds: any(named: 'toneBounds'),
            coachingStyle: any(named: 'coachingStyle'),
            antiSycophancyPolicy: any(named: 'antiSycophancyPolicy'),
            sourceSessionId: any(named: 'sourceSessionId'),
          ),
        ).thenAnswer((_) async => newVersion);
        when(
          () => mockSyncService.upsertEntity(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockRepository.getEntity(any()),
        ).thenAnswer((_) async => null);

        // Propose only tone_bounds; voice_directive is absent (empty) so it
        // must fall back to the current soul version's voiceDirective.
        final strategy = EvolutionStrategy();
        final manager = ConversationManager(
          conversationId: 'conv-empty-voice',
        )..initialize();
        const toolCall = ChatCompletionMessageToolCall(
          id: 'call-empty-voice',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'propose_soul_directives',
            arguments:
                '{"tone_bounds":"Updated bounds.","rationale":"Tone only."}',
          ),
        );
        manager.addAssistantMessage(toolCalls: [toolCall]);
        await strategy.processToolCalls(
          toolCalls: [toolCall],
          manager: manager,
        );
        expect(strategy.latestSoulProposal, isNotNull);
        expect(strategy.latestSoulProposal!.voiceDirective, isEmpty);

        final workflow = TemplateEvolutionWorkflow(
          conversationRepository: _TestConversationRepository(),
          aiConfigRepository: MockAiConfigRepository(),
          cloudInferenceRepository: MockCloudInferenceRepository(),
          templateService: mockTemplateService,
          syncService: mockSyncService,
          soulDocumentService: mockSoulService,
        );
        workflow.activeSessions['sess-empty-voice'] = ActiveEvolutionSession(
          sessionId: 'sess-empty-voice',
          templateId: kTestSoulId,
          conversationId: 'conv-empty-voice',
          strategy: strategy,
          modelId: 'model',
        );

        final result = await workflow.completeSoulSession(
          sessionId: 'sess-empty-voice',
        );
        expect(result, isNotNull);

        final captured = verify(
          () => mockSoulService.createVersion(
            soulId: captureAny(named: 'soulId'),
            voiceDirective: captureAny(named: 'voiceDirective'),
            authoredBy: captureAny(named: 'authoredBy'),
            toneBounds: captureAny(named: 'toneBounds'),
            coachingStyle: captureAny(named: 'coachingStyle'),
            antiSycophancyPolicy: captureAny(named: 'antiSycophancyPolicy'),
            sourceSessionId: captureAny(named: 'sourceSessionId'),
          ),
        ).captured;

        // voiceDirective falls back to current; toneBounds is the proposal.
        expect(captured[1], 'Current voice.');
        expect(captured[3], 'Updated bounds.');
      },
    );

    test(
      'uses proposal.rationale as feedbackSummary when recap TLDR is empty',
      () async {
        final currentSoulVersion = makeTestSoulDocumentVersion(
          id: 'sv-current',
          // ignore: avoid_redundant_argument_values
          agentId: kTestSoulId,
          voiceDirective: 'Current voice.',
        );
        when(
          () => mockSoulService.getActiveSoulVersion(kTestSoulId),
        ).thenAnswer((_) async => currentSoulVersion);

        final newVersion = makeTestSoulDocumentVersion(
          id: 'sv-new',
          version: 2,
          voiceDirective: 'Updated voice.',
        );
        when(
          () => mockSoulService.createVersion(
            soulId: any(named: 'soulId'),
            voiceDirective: any(named: 'voiceDirective'),
            authoredBy: any(named: 'authoredBy'),
            toneBounds: any(named: 'toneBounds'),
            coachingStyle: any(named: 'coachingStyle'),
            antiSycophancyPolicy: any(named: 'antiSycophancyPolicy'),
            sourceSessionId: any(named: 'sourceSessionId'),
          ),
        ).thenAnswer((_) async => newVersion);
        when(
          () => mockSyncService.upsertEntity(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockRepository.getEntity(any()),
        ).thenAnswer(
          (_) async => makeTestEvolutionSession(
            agentId: kTestSoulId,
            templateId: kTestSoulId,
          ),
        );

        // Use a testable strategy to inject an empty-TLDR recap.
        final strategy = _TestableEvolutionStrategy()
          ..overrideRecap(
            const PendingRitualRecap(
              tldr: '',
              content: '',
            ),
          );
        final manager = ConversationManager(
          conversationId: 'conv-tldr-fallback',
        )..initialize();
        const toolCall = ChatCompletionMessageToolCall(
          id: 'call-tldr',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'propose_soul_directives',
            arguments:
                '{"voice_directive":"Updated voice.", '
                '"rationale":"Better engagement"}',
          ),
        );
        manager.addAssistantMessage(toolCalls: [toolCall]);
        await strategy.processToolCalls(
          toolCalls: [toolCall],
          manager: manager,
        );

        final workflow = TemplateEvolutionWorkflow(
          conversationRepository: _TestConversationRepository(),
          aiConfigRepository: MockAiConfigRepository(),
          cloudInferenceRepository: MockCloudInferenceRepository(),
          templateService: mockTemplateService,
          syncService: mockSyncService,
          soulDocumentService: mockSoulService,
        );
        workflow.activeSessions['sess-tldr-fallback'] = ActiveEvolutionSession(
          sessionId: 'sess-tldr-fallback',
          templateId: kTestSoulId,
          conversationId: 'conv-tldr-fallback',
          strategy: strategy,
          modelId: 'model',
        );

        await workflow.completeSoulSession(sessionId: 'sess-tldr-fallback');

        final capturedEntities = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        final completedSessions = capturedEntities
            .whereType<EvolutionSessionEntity>()
            .where((s) => s.status == EvolutionSessionStatus.completed)
            .toList();
        expect(completedSessions, hasLength(1));
        // With empty recap TLDR, feedbackSummary falls back to proposal.rationale.
        expect(completedSessions.first.feedbackSummary, 'Better engagement');
      },
    );

    test(
      'onSessionCompleted callback exception does not prevent return',
      () async {
        final currentSoulVersion = makeTestSoulDocumentVersion(
          id: 'sv-current',
          // ignore: avoid_redundant_argument_values
          agentId: kTestSoulId,
          voiceDirective: 'Current voice.',
        );
        when(
          () => mockSoulService.getActiveSoulVersion(kTestSoulId),
        ).thenAnswer((_) async => currentSoulVersion);

        final newVersion = makeTestSoulDocumentVersion(
          id: 'sv-new-cb',
          version: 2,
          voiceDirective: 'Updated voice.',
        );
        when(
          () => mockSoulService.createVersion(
            soulId: any(named: 'soulId'),
            voiceDirective: any(named: 'voiceDirective'),
            authoredBy: any(named: 'authoredBy'),
            toneBounds: any(named: 'toneBounds'),
            coachingStyle: any(named: 'coachingStyle'),
            antiSycophancyPolicy: any(named: 'antiSycophancyPolicy'),
            sourceSessionId: any(named: 'sourceSessionId'),
          ),
        ).thenAnswer((_) async => newVersion);
        when(
          () => mockSyncService.upsertEntity(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockRepository.getEntity(any()),
        ).thenAnswer((_) async => null);

        final strategy = EvolutionStrategy();
        final manager = ConversationManager(conversationId: 'conv-cb-soul')
          ..initialize();
        const toolCall = ChatCompletionMessageToolCall(
          id: 'call-cb-soul',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'propose_soul_directives',
            arguments: '{"voice_directive":"Updated voice.", "rationale":"R"}',
          ),
        );
        manager.addAssistantMessage(toolCalls: [toolCall]);
        await strategy.processToolCalls(
          toolCalls: [toolCall],
          manager: manager,
        );

        final workflow = TemplateEvolutionWorkflow(
          conversationRepository: _TestConversationRepository(),
          aiConfigRepository: MockAiConfigRepository(),
          cloudInferenceRepository: MockCloudInferenceRepository(),
          templateService: mockTemplateService,
          syncService: mockSyncService,
          soulDocumentService: mockSoulService,
          onSessionCompleted: (_, _) {
            throw StateError('Soul callback explosion');
          },
        );
        workflow.activeSessions['sess-cb-soul'] = ActiveEvolutionSession(
          sessionId: 'sess-cb-soul',
          templateId: kTestSoulId,
          conversationId: 'conv-cb-soul',
          strategy: strategy,
          modelId: 'model',
        );

        // Should succeed despite the callback throwing.
        final result = await workflow.completeSoulSession(
          sessionId: 'sess-cb-soul',
        );
        expect(result, isNotNull);
        expect(result!.id, 'sv-new-cb');
        // Session should be cleaned up.
        expect(workflow.activeSessions, isEmpty);
      },
    );
  });

  group('_buildSoulSessionRecapEntity null guard', () {
    late MockAgentTemplateService mockTemplateService;
    late MockAgentSyncService mockSyncService;
    late MockSoulDocumentService mockSoulService;
    late MockAgentRepository mockRepository;

    setUp(() {
      mockTemplateService = MockAgentTemplateService();
      mockSyncService = MockAgentSyncService();
      mockSoulService = MockSoulDocumentService();
      mockRepository = MockAgentRepository();
      when(() => mockTemplateService.repository).thenReturn(mockRepository);
    });

    test(
      'completeSoulSession skips recap upsert when all recap fields are empty',
      () async {
        final currentSoulVersion = makeTestSoulDocumentVersion(
          id: 'sv-current',
          // ignore: avoid_redundant_argument_values
          agentId: kTestSoulId,
          voiceDirective: 'Current voice.',
        );
        when(
          () => mockSoulService.getActiveSoulVersion(kTestSoulId),
        ).thenAnswer((_) async => currentSoulVersion);

        final newVersion = makeTestSoulDocumentVersion(
          id: 'sv-new',
          version: 2,
          voiceDirective: 'Updated voice.',
        );
        when(
          () => mockSoulService.createVersion(
            soulId: any(named: 'soulId'),
            voiceDirective: any(named: 'voiceDirective'),
            authoredBy: any(named: 'authoredBy'),
            toneBounds: any(named: 'toneBounds'),
            coachingStyle: any(named: 'coachingStyle'),
            antiSycophancyPolicy: any(named: 'antiSycophancyPolicy'),
            sourceSessionId: any(named: 'sourceSessionId'),
          ),
        ).thenAnswer((_) async => newVersion);
        when(
          () => mockSyncService.upsertEntity(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockRepository.getEntity(any()),
        ).thenAnswer((_) async => null);

        // Use a testable strategy to inject a soul proposal with empty rationale
        // AND an empty recap, so all recap fields are empty and
        // _buildSoulSessionRecapEntity returns null.
        // (Bypasses processToolCalls validation which rejects empty rationale.)
        final strategy = _TestableEvolutionStrategy()
          ..overrideSoulProposal(
            const PendingSoulProposal(
              voiceDirective: 'Updated voice.',
              toneBounds: '',
              coachingStyle: '',
              antiSycophancyPolicy: '',
              rationale: '',
            ),
          )
          ..overrideRecap(
            const PendingRitualRecap(
              tldr: '',
              content: '',
            ),
          );

        final workflow = TemplateEvolutionWorkflow(
          conversationRepository: _TestConversationRepository(),
          aiConfigRepository: MockAiConfigRepository(),
          cloudInferenceRepository: MockCloudInferenceRepository(),
          templateService: mockTemplateService,
          syncService: mockSyncService,
          soulDocumentService: mockSoulService,
        );
        workflow.activeSessions['sess-soul-no-recap'] = ActiveEvolutionSession(
          sessionId: 'sess-soul-no-recap',
          templateId: kTestSoulId,
          conversationId: 'conv-soul-no-recap',
          strategy: strategy,
          modelId: 'model',
        );

        final result = await workflow.completeSoulSession(
          sessionId: 'sess-soul-no-recap',
        );
        expect(result, isNotNull);
        // No entities should be upserted — recap was null and session entity
        // was not found in DB.
        verifyNever(() => mockSyncService.upsertEntity(any()));
      },
    );
  });
}
