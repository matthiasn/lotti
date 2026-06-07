import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
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

/// Stubs `AgentTemplateService.createVersion` (any-matcher form) to return
/// [version] — shared by the approval-path tests.
void _stubCreateVersion(
  MockAgentTemplateService service,
  AgentTemplateVersionEntity version,
) {
  when(
    () => service.createVersion(
      templateId: any(named: 'templateId'),
      directives: any(named: 'directives'),
      authoredBy: any(named: 'authoredBy'),
      generalDirective: any(named: 'generalDirective'),
      reportDirective: any(named: 'reportDirective'),
    ),
  ).thenAnswer((_) async => version);
}

/// Builds an [EvolutionStrategy] that has accumulated one
/// `propose_directives` proposal, plus the conversation manager that fed it.
Future<({EvolutionStrategy strategy, ConversationManager manager})>
_strategyWithProposal({
  String generalDirective = 'New text',
  String reportDirective = '',
  String rationale = 'R',
}) async {
  final strategy = EvolutionStrategy();
  final manager = ConversationManager(conversationId: 'conv-1')..initialize();
  final toolCall = ChatCompletionMessageToolCall(
    id: 'call-1',
    type: ChatCompletionMessageToolCallType.function,
    function: ChatCompletionMessageFunctionCall(
      name: 'propose_directives',
      arguments: jsonEncode({
        'general_directive': generalDirective,
        'report_directive': reportDirective,
        'rationale': rationale,
      }),
    ),
  );
  manager.addAssistantMessage(toolCalls: [toolCall]);
  await strategy.processToolCalls(toolCalls: [toolCall], manager: manager);
  return (strategy: strategy, manager: manager);
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

  /// Stubs all service calls needed by [startSession]. Shared across groups
  /// that test the multi-turn session flow.
  void stubFullSessionContext({
    required MockAgentTemplateService templateService,
    required MockAgentSyncService syncService,
  }) {
    stubProviderResolution();
    when(
      () => templateService.getTemplate(any()),
    ).thenAnswer((_) async => makeTestTemplate());
    when(
      () => templateService.getActiveVersion(any()),
    ).thenAnswer((_) async => makeTestTemplateVersion());
    when(
      () => templateService.gatherEvolutionData(any()),
    ).thenAnswer((_) async => makeTestEvolutionDataBundle());
    when(
      () => templateService.getEvolutionSessions(
        any(),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => <EvolutionSessionEntity>[]);
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
      MockSoulDocumentService? soulDocumentService,
    }) {
      return TemplateEvolutionWorkflow(
        conversationRepository:
            convRepo ??
            _TestConversationRepository(
              assistantResponse: 'I see some patterns in the data.',
            ),
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
        soulDocumentService: soulDocumentService,
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
      final captured = verify(
        () => mockSyncService.upsertEntity(captureAny()),
      ).captured;
      final sessionEntity =
          captured.firstWhere(
                (e) => e is EvolutionSessionEntity,
              )
              as EvolutionSessionEntity;
      expect(sessionEntity.templateId, kTestTemplateId);
      expect(sessionEntity.status, EvolutionSessionStatus.active);
      expect(sessionEntity.sessionNumber, 1);
    });

    test('computes session number from existing sessions', () async {
      stubFullContext();
      when(() => mockTemplateService.gatherEvolutionData(any())).thenAnswer(
        (_) async => makeTestEvolutionDataBundle(
          sessions: [
            makeTestEvolutionSession(sessionNumber: 3),
            makeTestEvolutionSession(
              id: 'evo-session-002',
              sessionNumber: 2,
            ),
          ],
        ),
      );
      final workflow = buildSessionWorkflow();

      await workflow.startSession(templateId: kTestTemplateId);

      final captured = verify(
        () => mockSyncService.upsertEntity(captureAny()),
      ).captured;
      final sessionEntity =
          captured.firstWhere(
                (e) => e is EvolutionSessionEntity,
              )
              as EvolutionSessionEntity;
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
      when(
        () => mockTemplateService.getTemplate(any()),
      ).thenAnswer((_) async => null);
      final workflow = buildSessionWorkflow();

      final response = await workflow.startSession(
        templateId: kTestTemplateId,
      );

      expect(response, isNull);
    });

    test('returns null when no active version', () async {
      stubFullContext();
      when(
        () => mockTemplateService.getActiveVersion(any()),
      ).thenAnswer((_) async => null);
      final workflow = buildSessionWorkflow();

      final response = await workflow.startSession(
        templateId: kTestTemplateId,
      );

      expect(response, isNull);
    });

    test('returns null when provider cannot be resolved', () async {
      stubFullContext();
      when(
        () => mockAiConfig.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => []);
      final workflow = buildSessionWorkflow();

      final response = await workflow.startSession(
        templateId: kTestTemplateId,
      );

      expect(response, isNull);
    });

    test('abandons session on sendMessage failure', () async {
      stubFullContext();
      final convRepo =
          _TestConversationRepository(
              assistantResponse: 'response',
            )
            ..sendMessageDelegate = () async {
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

    test(
      'continues when best-effort soul enrichment fails',
      () async {
        stubFullContext();
        final soulService = MockSoulDocumentService();
        when(
          () => soulService.resolveActiveSoulForTemplate(any()),
        ).thenAnswer((_) async => throw StateError('soul lookup failed'));

        final workflow = buildSessionWorkflow(
          soulDocumentService: soulService,
        );

        final response = await workflow.startSession(
          templateId: kTestTemplateId,
        );

        expect(response, 'I see some patterns in the data.');
        expect(workflow.activeSessions, hasLength(1));
        verify(
          () => soulService.resolveActiveSoulForTemplate(kTestTemplateId),
        ).called(2);
      },
    );

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
      final convRepo =
          _TestConversationRepository(
              assistantResponse: 'response',
            )
            ..sendMessageDelegate = () async {
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
      expect(workflow.activeSessions.containsKey('session-1'), isTrue);
      expect(convRepo.deletedIds, isEmpty);
    });

    test('returns null when provider cannot be resolved', () async {
      when(
        () => mockAiConfig.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => []);

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
      final (:strategy, :manager) = await _strategyWithProposal(
        generalDirective: 'New approach',
        rationale: 'Data-driven',
      );

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
      expect(proposal!.generalDirective, 'New approach');
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
          arguments:
              '{"general_directive":"Proposal A","report_directive":"","rationale":"Reason A"}',
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

      expect(
        workflow.getCurrentProposal(sessionId: 's1')?.generalDirective,
        'Proposal A',
      );
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
      // Stub for auto-abandon of stale sessions during approval.
      when(
        () => mockTemplateService.getEvolutionSessions(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => <EvolutionSessionEntity>[]);
    });

    test('creates new version, persists notes, and completes session', () async {
      final newVersion = makeTestTemplateVersion(
        id: 'new-version-id',
        version: 2,
        directives: 'Improved directives',
        authoredBy: 'evolution_agent',
      );

      _stubCreateVersion(mockTemplateService, newVersion);
      when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
      when(
        () => mockRepository.getEntity(any()),
      ).thenAnswer((_) async => makeTestEvolutionSession());

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
              '{"general_directive":"Improved directives","report_directive":"","rationale":"Based on data"}',
        ),
      );
      manager.addAssistantMessage(toolCalls: [toolCall]);
      await strategy.processToolCalls(toolCalls: [toolCall], manager: manager);

      // Also add a structured recap.
      const recapCall = ChatCompletionMessageToolCall(
        id: 'call-recap',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'publish_ritual_recap',
          arguments:
              r'{"tldr":"Tightened the prompt around brevity.","content":"## Session recap\n\nWe tightened the opening prompt and removed repeated self-congratulation."}',
        ),
      );
      manager.addAssistantMessage(toolCalls: [recapCall]);
      await strategy.processToolCalls(
        toolCalls: [recapCall],
        manager: manager,
      );

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
      expect(strategy.latestRecap, isNotNull);
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
          generalDirective: 'Improved directives',
          // ignore: avoid_redundant_argument_values
          reportDirective: '',
          authoredBy: 'evolution_agent',
        ),
      ).called(1);

      // Verify recap, notes, and session completion were persisted.
      final capturedEntities = verify(
        () => mockSyncService.upsertEntity(captureAny()),
      ).captured;

      final recapEntities = capturedEntities
          .whereType<EvolutionSessionRecapEntity>()
          .toList();
      expect(recapEntities, hasLength(1));
      expect(recapEntities.first.tldr, 'Tightened the prompt around brevity.');
      expect(
        recapEntities.first.recapMarkdown,
        '## Session recap\n\nWe tightened the opening prompt and removed repeated self-congratulation.',
      );
      expect(recapEntities.first.approvedChangeSummary, 'Based on data');

      final noteEntities = capturedEntities
          .whereType<EvolutionNoteEntity>()
          .toList();
      expect(noteEntities, hasLength(1));
      expect(noteEntities.first.kind, EvolutionNoteKind.reflection);
      expect(noteEntities.first.content, 'Users prefer brevity');

      final sessionEntities = capturedEntities
          .whereType<EvolutionSessionEntity>()
          .toList();
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
          generalDirective: any(named: 'generalDirective'),
          reportDirective: any(named: 'reportDirective'),
        ),
      ).thenThrow(StateError('Template not found'));
      when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});

      final (:strategy, :manager) = await _strategyWithProposal();

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

    test(
      'recovers when createVersion throws after the version was committed '
      '(post-commit sync failure)',
      () async {
        // createVersion throws, but the version actually landed: the
        // active version matches the proposal's directives and the
        // evolution-agent author, so _createVersionIdempotent must return
        // it instead of rethrowing.
        final committedVersion = makeTestTemplateVersion(
          id: 'committed-ver',
          version: 2,
          directives: 'New text',
          generalDirective: 'New text',
          authoredBy: AgentAuthors.evolutionAgent,
        );

        when(
          () => mockTemplateService.createVersion(
            templateId: any(named: 'templateId'),
            directives: any(named: 'directives'),
            authoredBy: any(named: 'authoredBy'),
            generalDirective: any(named: 'generalDirective'),
            reportDirective: any(named: 'reportDirective'),
          ),
        ).thenThrow(StateError('post-commit sync failure'));
        when(
          () => mockTemplateService.getActiveVersion(kTestTemplateId),
        ).thenAnswer((_) async => committedVersion);
        when(
          () => mockSyncService.upsertEntity(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockRepository.getEntity(any()),
        ).thenAnswer((_) async => null);

        final (:strategy, :manager) = await _strategyWithProposal();

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

        // Approval succeeds with the already-committed version.
        expect(result, isNotNull);
        expect(result!.id, 'committed-ver');
        expect(workflow.activeSessions, isEmpty);
      },
    );

    test('completes even when session entity not found in DB', () async {
      final newVersion = makeTestTemplateVersion(
        id: 'new-ver',
        version: 2,
        directives: 'Updated directives',
      );

      _stubCreateVersion(mockTemplateService, newVersion);
      when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
      // Session entity not found in DB.
      when(() => mockRepository.getEntity(any())).thenAnswer((_) async => null);

      final (:strategy, :manager) = await _strategyWithProposal(
        generalDirective: 'Updated directives',
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

      // Should still succeed — version is created, session entity update
      // is skipped gracefully.
      final result = await workflow.approveProposal(sessionId: 'session-1');
      expect(result, isNotNull);
      expect(result!.directives, 'Updated directives');
      expect(workflow.activeSessions, isEmpty);
    });

    test(
      'returns success when stale-session cleanup throws during approval',
      () async {
        final newVersion = makeTestTemplateVersion(
          id: 'new-ver',
          version: 2,
          directives: 'Updated directives',
        );

        _stubCreateVersion(mockTemplateService, newVersion);
        when(
          () => mockSyncService.upsertEntity(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockRepository.getEntity(any()),
        ).thenAnswer((_) async => makeTestEvolutionSession());
        when(
          () => mockTemplateService.getEvolutionSessions(
            any(),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(StateError('cleanup failed'));

        final (:strategy, :manager) = await _strategyWithProposal(
          generalDirective: 'Updated directives',
        );

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

        expect(result, isNotNull);
        expect(result!.id, 'new-ver');
        expect(workflow.activeSessions, isEmpty);
      },
    );

    /// Shared helper: stubs services, adds a proposal to [strategy]
    /// via a tool call, wires up a workflow + session, calls
    /// `approveProposal`, and returns the `feedbackSummary` persisted
    /// on the captured [EvolutionSessionEntity].
    /// Runs the approve flow and returns BOTH the persisted session entity's
    /// feedbackSummary and the full captured upsert list, so callers can
    /// layer further assertions without re-draining the interaction log
    /// (verify(...).captured consumes it).
    Future<({String? summary, List<Object?> captured})> approveSummaryWith(
      EvolutionStrategy strategy, {
      required String versionId,
    }) async {
      final newVersion = makeTestTemplateVersion(
        id: versionId,
        version: 2,
        directives: 'Improved directives',
      );

      _stubCreateVersion(mockTemplateService, newVersion);
      when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
      when(
        () => mockRepository.getEntity(any()),
      ).thenAnswer((_) async => makeTestEvolutionSession());

      // Add a proposal.
      final manager = ConversationManager(conversationId: 'conv-1')
        ..initialize();
      const toolCall = ChatCompletionMessageToolCall(
        id: 'call-1',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'propose_directives',
          arguments:
              '{"general_directive":"Improved directives","report_directive":"","rationale":"Based on data"}',
        ),
      );
      manager.addAssistantMessage(toolCalls: [toolCall]);
      await strategy.processToolCalls(
        toolCalls: [toolCall],
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

      final result = await workflow.approveProposal(sessionId: 'session-1');
      expect(result, isNotNull);

      final capturedEntities = verify(
        () => mockSyncService.upsertEntity(captureAny()),
      ).captured;

      final sessionEntities = capturedEntities
          .whereType<EvolutionSessionEntity>()
          .toList();
      expect(sessionEntities, hasLength(1));

      return (
        summary: sessionEntities.first.feedbackSummary,
        captured: capturedEntities,
      );
    }

    test('uses recap TLDR as feedbackSummary when available', () async {
      final strategy = EvolutionStrategy();

      // Pre-populate a recap with non-empty TLDR via tool call processing
      // (must happen before approveSummaryWith, which creates its own
      // ConversationManager for the proposal).
      final manager = ConversationManager(conversationId: 'conv-recap')
        ..initialize();
      const recapCall = ChatCompletionMessageToolCall(
        id: 'call-recap',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'publish_ritual_recap',
          arguments:
              r'{"tldr":"Tightened the prompt around brevity.","content":"## Session recap\n\nDetails here."}',
        ),
      );
      manager.addAssistantMessage(toolCalls: [recapCall]);
      await strategy.processToolCalls(
        toolCalls: [recapCall],
        manager: manager,
      );
      expect(strategy.latestRecap, isNotNull);

      final result = await approveSummaryWith(
        strategy,
        versionId: 'ver-tldr',
      );
      expect(result.summary, 'Tightened the prompt around brevity.');
    });

    test('falls back to proposal.rationale when recap TLDR is empty', () async {
      // Override latestRecap with empty TLDR directly — processToolCalls
      // rejects empty TLDRs, so we bypass it to test the fallback in
      // approveProposal's normalizedSummary logic.
      final strategy = _TestableEvolutionStrategy()
        ..overrideRecap(
          const PendingRitualRecap(
            tldr: '',
            content: '## Session recap\n\nDetails here.',
          ),
        );

      final result = await approveSummaryWith(
        strategy,
        versionId: 'ver-empty-tldr',
      );
      // With empty recap TLDR, falls back to proposal.rationale.
      expect(result.summary, 'Based on data');
    });

    test(
      'persists no recap entity when rationale, recap, and transcript are '
      'all empty',
      () async {
        // propose_directives with a non-empty directive but EMPTY rationale,
        // no published recap, and a conversation id with no stored
        // conversation — every _buildSessionRecapEntity input is empty, so
        // the builder returns null and nothing recap-shaped is upserted.
        final strategy = EvolutionStrategy();

        final newVersion = makeTestTemplateVersion(
          id: 'ver-all-empty',
          version: 2,
          directives: 'Improved directives',
        );
        _stubCreateVersion(mockTemplateService, newVersion);
        when(
          () => mockSyncService.upsertEntity(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockRepository.getEntity(any()),
        ).thenAnswer((_) async => makeTestEvolutionSession());

        final manager = ConversationManager(conversationId: 'conv-empty')
          ..initialize();
        const toolCall = ChatCompletionMessageToolCall(
          id: 'call-1',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'propose_directives',
            arguments:
                // ignore: missing_whitespace_between_adjacent_strings
                '{"general_directive":"Improved directives",'
                '"report_directive":"","rationale":""}',
          ),
        );
        manager.addAssistantMessage(toolCalls: [toolCall]);
        await strategy.processToolCalls(
          toolCalls: [toolCall],
          manager: manager,
        );

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
        expect(result, isNotNull);

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        expect(
          captured.whereType<EvolutionSessionRecapEntity>(),
          isEmpty,
          reason: 'all-empty recap inputs must not persist a recap entity',
        );
      },
    );

    test('falls back to proposal.rationale when recap is null', () async {
      final strategy = EvolutionStrategy();

      final result = await approveSummaryWith(
        strategy,
        versionId: 'ver-no-recap',
      );
      // With no recap, normalizedSummary falls back to proposal.rationale.
      expect(result.summary, 'Based on data');
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
          arguments:
              '{"general_directive":"New text","report_directive":"","rationale":"Reason"}',
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
      when(
        () => mockRepository.getEntity(any()),
      ).thenAnswer((_) async => makeTestEvolutionSession());

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

      final capturedEntities = verify(
        () => mockSyncService.upsertEntity(captureAny()),
      ).captured;

      final noteEntities = capturedEntities
          .whereType<EvolutionNoteEntity>()
          .toList();
      expect(noteEntities, hasLength(1));
      expect(noteEntities.first.kind, EvolutionNoteKind.decision);

      final sessionEntities = capturedEntities
          .whereType<EvolutionSessionEntity>()
          .toList();
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
      when(
        () => mockRepository.getEntity(any()),
      ).thenAnswer((_) async => makeTestEvolutionSession());

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
      final captured = verify(
        () => mockSyncService.upsertEntity(captureAny()),
      ).captured;
      final sessionEntities = captured
          .whereType<EvolutionSessionEntity>()
          .toList();
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
        final convRepo =
            _TestConversationRepository(
                assistantResponse: 'response',
              )
              ..createConversationDelegate = () {
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
        final allUpserts = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        final sessionUpserts = allUpserts
            .whereType<EvolutionSessionEntity>()
            .toList();

        // Should have 2 session upserts: initial creation + abandon.
        expect(sessionUpserts, hasLength(2));
        expect(sessionUpserts[0].status, EvolutionSessionStatus.active);
        expect(sessionUpserts[1].status, EvolutionSessionStatus.abandoned);
      },
    );

    test(
      'abandonSession marks DB session abandoned even without in-memory state',
      () async {
        when(
          () => mockSyncService.upsertEntity(any()),
        ).thenAnswer((_) async {});
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

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
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
      when(
        () => mockTemplateService.getEvolutionSessions(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => <EvolutionSessionEntity>[]);
    });

    test('retry does not create duplicate version or notes', () async {
      final newVersion = makeTestTemplateVersion(
        id: 'v2',
        version: 2,
        directives: 'Better directives',
        authoredBy: 'evolution_agent',
      );

      _stubCreateVersion(mockTemplateService, newVersion);

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

      when(
        () => mockRepository.getEntity(any()),
      ).thenAnswer((_) async => makeTestEvolutionSession());

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
              '{"general_directive":"Better directives","report_directive":"","rationale":"Evidence"}',
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
          generalDirective: any(named: 'generalDirective'),
          reportDirective: any(named: 'reportDirective'),
        ),
      ).called(1);

      // Exactly one note entity across both attempts (no duplicate).
      final noteEntities = allUpserted
          .whereType<EvolutionNoteEntity>()
          .toList();
      expect(noteEntities, hasLength(1));
      expect(noteEntities.first.content, 'Tone works well');

      // Session entity upserted once for completion (the failed attempt threw
      // before the session completion upsert could record, so only the
      // successful retry wrote it).
      final sessionEntities = allUpserted
          .whereType<EvolutionSessionEntity>()
          .toList();
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
            generalDirective: any(named: 'generalDirective'),
            reportDirective: any(named: 'reportDirective'),
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
        when(
          () => mockRepository.getEntity(any()),
        ).thenAnswer((_) async => makeTestEvolutionSession());

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
                '{"general_directive":"Old proposal","report_directive":"","rationale":"First attempt"}',
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
                '{"general_directive":"New proposal","report_directive":"","rationale":"Revised attempt"}',
          ),
        );
        manager.addAssistantMessage(toolCalls: [secondProposal]);
        await strategy.processToolCalls(
          toolCalls: [secondProposal],
          manager: manager,
        );

        // Reset mock so upserts succeed.
        reset(mockSyncService);
        when(
          () => mockSyncService.upsertEntity(any()),
        ).thenAnswer((_) async {});

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

        _stubCreateVersion(mockTemplateService, newVersion);
        when(
          () => mockRepository.getEntity(any()),
        ).thenAnswer((_) async => makeTestEvolutionSession());

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
                '{"general_directive":"Good directives","report_directive":"","rationale":"Evidence"}',
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
        when(
          () => mockSyncService.upsertEntity(any()),
        ).thenAnswer((_) async {});

        final second = await workflow.approveProposal(sessionId: 'session-1');
        expect(second, isNotNull);

        // Verify Note B was persisted in the retry.
        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
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

        _stubCreateVersion(mockTemplateService, newVersion);
        when(
          () => mockRepository.getEntity(any()),
        ).thenAnswer((_) async => makeTestEvolutionSession());

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
                '{"general_directive":"Some directives","report_directive":"","rationale":"Reason"}',
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
        final firstAttemptNotes = allUpserted
            .whereType<EvolutionNoteEntity>()
            .toList();
        expect(firstAttemptNotes, hasLength(1));
        expect(firstAttemptNotes.first.content, 'Note 0');

        // Version was created via createVersion and cached for retry.
        verify(
          () => mockTemplateService.createVersion(
            templateId: any(named: 'templateId'),
            directives: any(named: 'directives'),
            authoredBy: any(named: 'authoredBy'),
            generalDirective: any(named: 'generalDirective'),
            reportDirective: any(named: 'reportDirective'),
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
        final retryNotes = allUpserted
            .whereType<EvolutionNoteEntity>()
            .toList();
        expect(retryNotes, isEmpty);
      },
    );
  });

  group('startSession data gathering', () {
    late MockAgentTemplateService mockTemplateService;
    late MockAgentSyncService mockSyncService;
    late MockAgentRepository mockRepository;

    setUp(() {
      mockTemplateService = MockAgentTemplateService();
      mockSyncService = MockAgentSyncService();
      mockRepository = MockAgentRepository();
      when(() => mockTemplateService.repository).thenReturn(mockRepository);
    });

    test('calls gatherEvolutionData for the template', () async {
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

      verify(
        () => mockTemplateService.gatherEvolutionData(kTestTemplateId),
      ).called(1);
    });
  });

  group('startSession soul context resolution', () {
    late MockAgentTemplateService mockTemplateService;
    late MockAgentSyncService mockSyncService;
    late MockAgentRepository mockRepository;

    setUp(() {
      mockTemplateService = MockAgentTemplateService();
      mockSyncService = MockAgentSyncService();
      mockRepository = MockAgentRepository();
      when(() => mockTemplateService.repository).thenReturn(mockRepository);
    });

    test('resolves soul version and populates strategy', () async {
      stubFullSessionContext(
        templateService: mockTemplateService,
        syncService: mockSyncService,
      );

      final mockSoulService = MockSoulDocumentService();
      final soulVersion = makeTestSoulDocumentVersion(
        voiceDirective: 'Warm and clear.',
        toneBounds: 'Never sarcastic.',
        coachingStyle: 'Celebrate wins.',
        antiSycophancyPolicy: 'Push back firmly.',
      );
      when(
        () => mockSoulService.resolveActiveSoulForTemplate(any()),
      ).thenAnswer((_) async => soulVersion);
      when(
        () => mockSoulService.getVersionHistory(any()),
      ).thenAnswer((_) async => <SoulDocumentVersionEntity>[soulVersion]);
      when(
        () => mockSoulService.getTemplatesUsingSoul(any()),
      ).thenAnswer((_) async => <String>[kTestTemplateId]);

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(
          assistantResponse: 'Hello',
        ),
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
        soulDocumentService: mockSoulService,
      );

      await workflow.startSession(templateId: kTestTemplateId);

      expect(workflow.activeSessions, hasLength(1));
      final session = workflow.activeSessions.values.first;
      // Strategy should have current soul values for before/after comparison.
      expect(session.strategy.currentVoiceDirective, 'Warm and clear.');
      expect(session.strategy.currentToneBounds, 'Never sarcastic.');
      expect(session.strategy.currentCoachingStyle, 'Celebrate wins.');
      expect(
        session.strategy.currentAntiSycophancyPolicy,
        'Push back firmly.',
      );

      // Should have resolved exactly once (reused in strategy).
      verify(
        () => mockSoulService.resolveActiveSoulForTemplate(kTestTemplateId),
      ).called(1);
    });

    test('strategy has empty soul values when no soul assigned', () async {
      stubFullSessionContext(
        templateService: mockTemplateService,
        syncService: mockSyncService,
      );

      final mockSoulService = MockSoulDocumentService();
      when(
        () => mockSoulService.resolveActiveSoulForTemplate(any()),
      ).thenAnswer((_) async => null);

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(
          assistantResponse: 'Hello',
        ),
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
        soulDocumentService: mockSoulService,
      );

      await workflow.startSession(templateId: kTestTemplateId);

      expect(workflow.activeSessions, hasLength(1));
      final session = workflow.activeSessions.values.first;
      expect(session.strategy.currentVoiceDirective, isEmpty);
      expect(session.strategy.currentToneBounds, isEmpty);
      expect(session.strategy.currentCoachingStyle, isEmpty);
      expect(session.strategy.currentAntiSycophancyPolicy, isEmpty);
    });

    test('strategy has empty soul values when no soul service', () async {
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
        // No soul service
      );

      await workflow.startSession(templateId: kTestTemplateId);

      expect(workflow.activeSessions, hasLength(1));
      final session = workflow.activeSessions.values.first;
      expect(session.strategy.currentVoiceDirective, isEmpty);
      expect(session.strategy.currentToneBounds, isEmpty);
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

    test('returns null when gatherEvolutionData throws', () async {
      stubFullSessionContext(
        templateService: mockTemplateService,
        syncService: mockSyncService,
      );
      // Stub getEntity for abandonSession cleanup path.
      when(() => mockRepository.getEntity(any())).thenAnswer((_) async => null);
      // Override gatherEvolutionData to throw.
      when(
        () => mockTemplateService.gatherEvolutionData(any()),
      ).thenThrow(StateError('DB error'));

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

    test(
      'returns null when a session is already active for the template',
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
      },
    );

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
      when(
        () => mockTemplateService.getEvolutionSessions(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => <EvolutionSessionEntity>[]);
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
        () => mockNotifications.notifyUiOnly(
          {kTestTemplateId, agentNotification},
        ),
      ).called(1);
    });

    test('approveProposal fires notification on success', () async {
      final newVersion = makeTestTemplateVersion(
        id: 'v2',
        version: 2,
        directives: 'Improved',
      );
      _stubCreateVersion(mockTemplateService, newVersion);
      when(
        () => mockRepository.getEntity(any()),
      ).thenAnswer((_) async => makeTestEvolutionSession());
      when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});

      final strategy = EvolutionStrategy();
      final manager = ConversationManager(conversationId: 'conv-1')
        ..initialize();
      const proposalCall = ChatCompletionMessageToolCall(
        id: 'call-1',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'propose_directives',
          arguments:
              '{"general_directive":"Improved","report_directive":"","rationale":"Better"}',
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
        () => mockNotifications.notifyUiOnly(
          {kTestTemplateId, agentNotification},
        ),
      ).called(1);
    });

    test('abandonSession fires notification', () async {
      when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
      when(
        () => mockRepository.getEntity(any()),
      ).thenAnswer((_) async => makeTestEvolutionSession());

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
        () => mockNotifications.notifyUiOnly(
          {kTestTemplateId, agentNotification},
        ),
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
      when(
        () => mockTemplateService.getEvolutionSessions(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => <EvolutionSessionEntity>[]);
    });

    test(
      'uses contextOverride instead of building context internally',
      () async {
        stubProviderResolution();
        when(
          () => mockTemplateService.getTemplate(any()),
        ).thenAnswer((_) async => makeTestTemplate());
        when(
          () => mockTemplateService.getActiveVersion(any()),
        ).thenAnswer((_) async => makeTestTemplateVersion());
        when(
          () => mockSyncService.upsertEntity(any()),
        ).thenAnswer((_) async {});

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
          sessionNumberOverride: 5,
        );

        expect(response, 'Ritual response');
        expect(workflow.activeSessions, hasLength(1));

        // When both contextOverride and sessionNumberOverride are provided,
        // gatherEvolutionData should NOT be called.
        verifyNever(() => mockTemplateService.gatherEvolutionData(any()));
      },
    );

    test('uses override system prompt for conversation', () async {
      stubProviderResolution();
      when(
        () => mockTemplateService.getTemplate(any()),
      ).thenAnswer((_) async => makeTestTemplate());
      when(
        () => mockTemplateService.getActiveVersion(any()),
      ).thenAnswer((_) async => makeTestTemplateVersion());
      when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});

      final convRepo = _TestConversationRepository(
        assistantResponse: 'Response',
      );

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
        sessionNumberOverride: 1,
      );

      // Session was created successfully with the override context.
      expect(response, isNotNull);
      expect(workflow.activeSessions, hasLength(1));

      // Verify the override system prompt was passed to createConversation.
      expect(
        convRepo.lastSystemMessage,
        'Ritual-specific system prompt',
      );
    });

    test('contextOverride without sessionNumberOverride '
        'fetches only sessions', () async {
      stubProviderResolution();
      when(
        () => mockTemplateService.getTemplate(any()),
      ).thenAnswer((_) async => makeTestTemplate());
      when(
        () => mockTemplateService.getActiveVersion(any()),
      ).thenAnswer((_) async => makeTestTemplateVersion());
      when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
      when(() => mockTemplateService.getEvolutionSessions(any())).thenAnswer(
        (_) async => [
          makeTestEvolutionSession(
            sessionNumber: 5,
            status: EvolutionSessionStatus.completed,
          ),
          makeTestEvolutionSession(
            id: 'evo-session-002',
            sessionNumber: 3,
            status: EvolutionSessionStatus.completed,
          ),
        ],
      );

      final convRepo = _TestConversationRepository(
        assistantResponse: 'Optimized response',
      );

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: convRepo,
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
      );

      const overrideContext = EvolutionContext(
        systemPrompt: 'Ritual system prompt',
        initialUserMessage: 'Ritual user message',
      );

      final response = await workflow.startSession(
        templateId: kTestTemplateId,
        contextOverride: overrideContext,
        // sessionNumberOverride intentionally omitted.
      );

      expect(response, isNotNull);

      // Should fetch sessions to compute next session number (once) and
      // to check for stale sessions to auto-abandon (once).
      verify(
        () => mockTemplateService.getEvolutionSessions(kTestTemplateId),
      ).called(2);

      // Should NOT call the full gatherEvolutionData.
      verifyNever(() => mockTemplateService.gatherEvolutionData(any()));

      // Session number should be max(5, 3) + 1 = 6.
      final captured = verify(
        () => mockSyncService.upsertEntity(captureAny()),
      ).captured;
      final sessionEntity =
          captured.firstWhere(
                (e) => e is EvolutionSessionEntity,
              )
              as EvolutionSessionEntity;
      expect(sessionEntity.sessionNumber, 6);
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
      when(
        () => mockTemplateService.getEvolutionSessions(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => <EvolutionSessionEntity>[]);
    });

    test('fires callback after approveProposal completes', () async {
      final newVersion = makeTestTemplateVersion(
        id: 'new-version',
        version: 2,
        directives: 'New directives',
        authoredBy: 'evolution_agent',
      );

      _stubCreateVersion(mockTemplateService, newVersion);
      when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
      when(
        () => mockRepository.getEntity(any()),
      ).thenAnswer((_) async => makeTestEvolutionSession());

      String? callbackTemplateId;
      String? callbackSessionId;

      final convRepo = _TestConversationRepository();
      final (:strategy, :manager) = await _strategyWithProposal(
        generalDirective: 'New directives',
      );

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
          generalDirective: any(named: 'generalDirective'),
          reportDirective: any(named: 'reportDirective'),
        ),
      ).thenThrow(StateError('DB error'));

      var callbackFired = false;

      final (:strategy, :manager) = await _strategyWithProposal(
        generalDirective: 'X',
      );

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(),
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
        onSessionCompleted: (_, _) {
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

    test('callback exception does not prevent successful return', () async {
      final newVersion = makeTestTemplateVersion(
        id: 'new-version',
        version: 2,
        directives: 'New directives',
        authoredBy: 'evolution_agent',
      );

      _stubCreateVersion(mockTemplateService, newVersion);
      when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
      when(
        () => mockRepository.getEntity(any()),
      ).thenAnswer((_) async => makeTestEvolutionSession());

      final convRepo = _TestConversationRepository();
      final (:strategy, :manager) = await _strategyWithProposal(
        generalDirective: 'New directives',
      );

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: convRepo,
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
        onSessionCompleted: (_, _) {
          throw StateError('Callback explosion');
        },
      );

      workflow.activeSessions['session-1'] = ActiveEvolutionSession(
        sessionId: 'session-1',
        templateId: kTestTemplateId,
        conversationId: 'test-conv-id',
        strategy: strategy,
        modelId: 'model',
      );

      // The approval should still succeed despite the callback throwing.
      final result = await workflow.approveProposal(sessionId: 'session-1');
      expect(result, isNotNull);
      expect(result!.id, 'new-version');
    });
  });

  group('auto-abandon stale sessions', () {
    late MockAgentTemplateService mockTemplateService;
    late MockAgentSyncService mockSyncService;
    late MockAgentRepository mockRepository;

    setUp(() {
      mockTemplateService = MockAgentTemplateService();
      mockSyncService = MockAgentSyncService();
      mockRepository = MockAgentRepository();
      when(() => mockTemplateService.repository).thenReturn(mockRepository);
    });

    test(
      'startSession abandons stale active sessions for same template',
      () async {
        stubProviderResolution();
        stubFullSessionContext(
          templateService: mockTemplateService,
          syncService: mockSyncService,
        );

        // Return a stale active session from the DB.
        final staleSession = makeTestEvolutionSession(
          id: 'stale-session-id',
        );
        when(
          () => mockTemplateService.getEvolutionSessions(
            any(),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => [staleSession]);

        final workflow = TemplateEvolutionWorkflow(
          conversationRepository: _TestConversationRepository(
            assistantResponse: 'Opening response.',
          ),
          aiConfigRepository: mockAiConfig,
          cloudInferenceRepository: mockCloudInference,
          templateService: mockTemplateService,
          syncService: mockSyncService,
        );

        await workflow.startSession(templateId: kTestTemplateId);

        // Verify that the stale session was abandoned.
        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        final abandonedEntities = captured
            .whereType<EvolutionSessionEntity>()
            .where(
              (e) =>
                  e.id == 'stale-session-id' &&
                  e.status == EvolutionSessionStatus.abandoned,
            )
            .toList();
        expect(abandonedEntities, hasLength(1));
      },
    );

    test('startSession does not abandon non-active sessions '
        'for the same template', () async {
      stubProviderResolution();
      stubFullSessionContext(
        templateService: mockTemplateService,
        syncService: mockSyncService,
      );

      // Return a completed session — should not be re-abandoned.
      final completedSession = makeTestEvolutionSession(
        id: 'completed-session-id',
        status: EvolutionSessionStatus.completed,
      );
      when(
        () => mockTemplateService.getEvolutionSessions(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [completedSession]);

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(
          assistantResponse: 'Opening response.',
        ),
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
        templateService: mockTemplateService,
        syncService: mockSyncService,
      );

      await workflow.startSession(templateId: kTestTemplateId);

      // Verify that no session was abandoned — the only upserted entities
      // should be the new session (active status).
      final captured = verify(
        () => mockSyncService.upsertEntity(captureAny()),
      ).captured;
      final abandonedEntities = captured
          .whereType<EvolutionSessionEntity>()
          .where(
            (e) => e.status == EvolutionSessionStatus.abandoned,
          )
          .toList();
      expect(abandonedEntities, isEmpty);
    });
  });

  group('getCurrentRecap', () {
    test('returns recap when one exists on the session', () async {
      final strategy = EvolutionStrategy();
      final manager = ConversationManager(conversationId: 'conv-recap')
        ..initialize();
      // Publish a ritual recap so latestRecap is non-null.
      const recapCall = ChatCompletionMessageToolCall(
        id: 'call-recap',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'publish_ritual_recap',
          arguments:
              r'{"tldr":"Good session.","content":"## Recap\n\nWent well."}',
        ),
      );
      manager.addAssistantMessage(toolCalls: [recapCall]);
      await strategy.processToolCalls(
        toolCalls: [recapCall],
        manager: manager,
      );
      expect(strategy.latestRecap, isNotNull);

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(),
        aiConfigRepository: MockAiConfigRepository(),
        cloudInferenceRepository: MockCloudInferenceRepository(),
      );
      workflow.activeSessions['session-recap'] = ActiveEvolutionSession(
        sessionId: 'session-recap',
        templateId: kTestTemplateId,
        conversationId: 'conv-recap',
        strategy: strategy,
        modelId: 'model',
      );

      final recap = workflow.getCurrentRecap(sessionId: 'session-recap');
      expect(recap, isNotNull);
      expect(recap!.tldr, 'Good session.');
    });

    test('returns null for unknown session', () {
      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(),
        aiConfigRepository: MockAiConfigRepository(),
        cloudInferenceRepository: MockCloudInferenceRepository(),
      );

      expect(workflow.getCurrentRecap(sessionId: 'nonexistent'), isNull);
    });

    test('returns null when session has no recap', () {
      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(),
        aiConfigRepository: MockAiConfigRepository(),
        cloudInferenceRepository: MockCloudInferenceRepository(),
      );
      workflow.activeSessions['session-no-recap'] = ActiveEvolutionSession(
        sessionId: 'session-no-recap',
        templateId: kTestTemplateId,
        conversationId: 'conv-1',
        strategy: EvolutionStrategy(),
        modelId: 'model',
      );

      expect(
        workflow.getCurrentRecap(sessionId: 'session-no-recap'),
        isNull,
      );
    });
  });

  group('getSession', () {
    test('returns the active session by session ID', () {
      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(),
        aiConfigRepository: MockAiConfigRepository(),
        cloudInferenceRepository: MockCloudInferenceRepository(),
      );
      workflow.activeSessions['sess-abc'] = ActiveEvolutionSession(
        sessionId: 'sess-abc',
        templateId: kTestTemplateId,
        conversationId: 'conv-1',
        strategy: EvolutionStrategy(),
        modelId: 'model',
      );

      final session = workflow.getSession('sess-abc');
      expect(session, isNotNull);
      expect(session!.sessionId, 'sess-abc');
    });

    test('returns null for unknown session ID', () {
      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: _TestConversationRepository(),
        aiConfigRepository: MockAiConfigRepository(),
        cloudInferenceRepository: MockCloudInferenceRepository(),
      );

      expect(workflow.getSession('missing'), isNull);
    });
  });

  group('_createVersionIdempotent recovery', () {
    late MockAgentTemplateService mockTemplateService;
    late MockAgentSyncService mockSyncService;
    late MockAgentRepository mockRepository;

    setUp(() {
      mockTemplateService = MockAgentTemplateService();
      mockSyncService = MockAgentSyncService();
      mockRepository = MockAgentRepository();
      when(() => mockTemplateService.repository).thenReturn(mockRepository);
      when(
        () => mockTemplateService.getEvolutionSessions(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => <EvolutionSessionEntity>[]);
    });

    test(
      'recovers when createVersion throws but version was already persisted',
      () async {
        // The version that was persisted despite the throw.
        final persistedVersion = makeTestTemplateVersion(
          id: 'v-idempotent',
          version: 2,
          directives: 'Recovered directives',
          authoredBy: 'evolution_agent',
          generalDirective: 'Recovered directives',
          // ignore: avoid_redundant_argument_values
          reportDirective: '',
        );

        // createVersion throws, but getActiveVersion returns the persisted one.
        when(
          () => mockTemplateService.createVersion(
            templateId: any(named: 'templateId'),
            directives: any(named: 'directives'),
            authoredBy: any(named: 'authoredBy'),
            generalDirective: any(named: 'generalDirective'),
            reportDirective: any(named: 'reportDirective'),
          ),
        ).thenThrow(Exception('Post-commit sync failure'));
        when(
          () => mockTemplateService.getActiveVersion(any()),
        ).thenAnswer((_) async => persistedVersion);
        when(
          () => mockSyncService.upsertEntity(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockRepository.getEntity(any()),
        ).thenAnswer((_) async => makeTestEvolutionSession());

        final strategy = EvolutionStrategy();
        final manager = ConversationManager(conversationId: 'conv-idempotent')
          ..initialize();
        const toolCall = ChatCompletionMessageToolCall(
          id: 'call-idempotent',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'propose_directives',
            arguments:
                '{"general_directive":"Recovered directives", '
                '"report_directive":"", '
                '"rationale":"R"}',
          ),
        );
        manager.addAssistantMessage(toolCalls: [toolCall]);
        await strategy.processToolCalls(
          toolCalls: [toolCall],
          manager: manager,
        );

        final workflow = TemplateEvolutionWorkflow(
          conversationRepository: _TestConversationRepository(),
          aiConfigRepository: mockAiConfig,
          cloudInferenceRepository: mockCloudInference,
          templateService: mockTemplateService,
          syncService: mockSyncService,
        );
        workflow.activeSessions['session-idempotent'] = ActiveEvolutionSession(
          sessionId: 'session-idempotent',
          templateId: kTestTemplateId,
          conversationId: 'conv-idempotent',
          strategy: strategy,
          modelId: 'model',
        );

        // Should succeed using the recovered version.
        final result = await workflow.approveProposal(
          sessionId: 'session-idempotent',
        );
        expect(result, isNotNull);
        expect(result!.id, 'v-idempotent');
      },
    );

    test(
      'rethrows when createVersion throws and active version does not match',
      () async {
        // Active version has different directives — not the right one.
        final differentVersion = makeTestTemplateVersion(
          id: 'v-different',
          version: 2,
          directives: 'Different directives',
          // ignore: avoid_redundant_argument_values
          authoredBy: 'user',
          generalDirective: 'Different directives',
          // ignore: avoid_redundant_argument_values
          reportDirective: '',
        );

        when(
          () => mockTemplateService.createVersion(
            templateId: any(named: 'templateId'),
            directives: any(named: 'directives'),
            authoredBy: any(named: 'authoredBy'),
            generalDirective: any(named: 'generalDirective'),
            reportDirective: any(named: 'reportDirective'),
          ),
        ).thenThrow(Exception('DB error'));
        when(
          () => mockTemplateService.getActiveVersion(any()),
        ).thenAnswer((_) async => differentVersion);
        when(
          () => mockSyncService.upsertEntity(any()),
        ).thenAnswer((_) async {});

        final strategy = EvolutionStrategy();
        final manager = ConversationManager(conversationId: 'conv-rethrow')
          ..initialize();
        const toolCall = ChatCompletionMessageToolCall(
          id: 'call-rethrow',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'propose_directives',
            arguments:
                '{"general_directive":"Proposed directives", '
                '"report_directive":"", '
                '"rationale":"R"}',
          ),
        );
        manager.addAssistantMessage(toolCalls: [toolCall]);
        await strategy.processToolCalls(
          toolCalls: [toolCall],
          manager: manager,
        );

        final workflow = TemplateEvolutionWorkflow(
          conversationRepository: _TestConversationRepository(),
          aiConfigRepository: mockAiConfig,
          cloudInferenceRepository: mockCloudInference,
          templateService: mockTemplateService,
          syncService: mockSyncService,
        );
        workflow.activeSessions['session-rethrow'] = ActiveEvolutionSession(
          sessionId: 'session-rethrow',
          templateId: kTestTemplateId,
          conversationId: 'conv-rethrow',
          strategy: strategy,
          modelId: 'model',
        );

        // approveProposal catches the rethrow and returns null.
        final result = await workflow.approveProposal(
          sessionId: 'session-rethrow',
        );
        expect(result, isNull);
      },
    );
  });

  group('_buildSessionRecapEntity null guard', () {
    late MockAgentTemplateService mockTemplateService;
    late MockAgentSyncService mockSyncService;
    late MockAgentRepository mockRepository;

    setUp(() {
      mockTemplateService = MockAgentTemplateService();
      mockSyncService = MockAgentSyncService();
      mockRepository = MockAgentRepository();
      when(() => mockTemplateService.repository).thenReturn(mockRepository);
      when(
        () => mockTemplateService.getEvolutionSessions(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => <EvolutionSessionEntity>[]);
    });

    test(
      'approveProposal skips recap upsert when all recap fields are empty',
      () async {
        final newVersion = makeTestTemplateVersion(
          id: 'v-no-recap',
          version: 2,
          directives: 'Some directive',
          authoredBy: 'evolution_agent',
          generalDirective: 'Some directive',
          // ignore: avoid_redundant_argument_values
          reportDirective: '',
        );

        _stubCreateVersion(mockTemplateService, newVersion);
        when(
          () => mockSyncService.upsertEntity(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockRepository.getEntity(any()),
        ).thenAnswer((_) async => makeTestEvolutionSession());

        // Proposal with non-empty directive but empty rationale so that
        // approvedChangeSummary and recapTldr both trim to ''.
        // Combined with an empty overridden recap and no transcript,
        // _buildSessionRecapEntity must return null.
        final strategy = _TestableEvolutionStrategy()
          ..overrideRecap(
            const PendingRitualRecap(
              tldr: '',
              content: '',
            ),
          );
        final manager = ConversationManager(conversationId: 'conv-no-recap')
          ..initialize();
        const toolCall = ChatCompletionMessageToolCall(
          id: 'call-no-recap',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'propose_directives',
            // rationale must be empty; at least one directive non-empty.
            arguments:
                '{"general_directive":"Some directive", '
                '"report_directive":"", '
                '"rationale":""}',
          ),
        );
        manager.addAssistantMessage(toolCalls: [toolCall]);
        await strategy.processToolCalls(
          toolCalls: [toolCall],
          manager: manager,
        );
        // Manually clear the proposal's rationale field via the strategy
        // override (processToolCalls sets rationale from the JSON, but we want
        // it empty). Instead, inject the proposal directly via overrideRecap
        // and set up a PendingProposal with empty rationale.
        //
        // Because processToolCalls accepts rationale:'', the proposal IS set
        // with generalDirective='Some directive' but rationale=''.
        // recapTldr = '' (overridden) → falls back to proposal.rationale = ''.
        // approvedChangeSummary = proposal.rationale.trim() = ''.
        // transcript = [] (no messages in conv repo).
        // → _buildSessionRecapEntity returns null.
        expect(strategy.latestProposal, isNotNull);

        // Use a conv repo that returns no messages (empty transcript).
        final workflow = TemplateEvolutionWorkflow(
          conversationRepository: _TestConversationRepository(),
          aiConfigRepository: mockAiConfig,
          cloudInferenceRepository: mockCloudInference,
          templateService: mockTemplateService,
          syncService: mockSyncService,
        );
        workflow.activeSessions['session-no-recap'] = ActiveEvolutionSession(
          sessionId: 'session-no-recap',
          templateId: kTestTemplateId,
          conversationId: 'conv-no-recap',
          strategy: strategy,
          modelId: 'model',
        );

        final result = await workflow.approveProposal(
          sessionId: 'session-no-recap',
        );
        expect(result, isNotNull);

        final capturedEntities = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        // No recap entity should be present.
        final recapEntities = capturedEntities
            .whereType<EvolutionSessionRecapEntity>()
            .toList();
        expect(recapEntities, isEmpty);
      },
    );
  });

  group('_snapshotTranscript user message path', () {
    late MockAgentTemplateService mockTemplateService;
    late MockAgentSyncService mockSyncService;
    late MockAgentRepository mockRepository;

    setUp(() {
      mockTemplateService = MockAgentTemplateService();
      mockSyncService = MockAgentSyncService();
      mockRepository = MockAgentRepository();
      when(() => mockTemplateService.repository).thenReturn(mockRepository);
      when(
        () => mockTemplateService.getEvolutionSessions(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => <EvolutionSessionEntity>[]);
    });

    test(
      'recap transcript includes user messages alongside assistant messages',
      () async {
        final newVersion = makeTestTemplateVersion(
          id: 'v-transcript',
          version: 2,
          directives: 'Better directives',
          authoredBy: 'evolution_agent',
        );

        _stubCreateVersion(mockTemplateService, newVersion);
        when(
          () => mockSyncService.upsertEntity(any()),
        ).thenAnswer((_) async {});
        when(
          () => mockRepository.getEntity(any()),
        ).thenAnswer((_) async => makeTestEvolutionSession());

        // Set up a ConversationManager with both user and assistant messages.
        final convManager = ConversationManager(conversationId: 'conv-trans')
          ..initialize()
          ..addUserMessage('What should I improve?')
          ..addAssistantMessage(content: 'Focus on tone.');

        // ConversationRepository that returns our pre-built manager.
        final convRepo = _ConversationRepositoryWithManager(
          conversationId: 'conv-trans',
          manager: convManager,
        );

        final strategy = EvolutionStrategy();
        final manager = ConversationManager(conversationId: 'conv-propose')
          ..initialize();
        const toolCall = ChatCompletionMessageToolCall(
          id: 'call-trans',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'propose_directives',
            arguments:
                '{"general_directive":"Better directives", '
                '"report_directive":"", '
                '"rationale":"User insights"}',
          ),
        );
        manager.addAssistantMessage(toolCalls: [toolCall]);
        await strategy.processToolCalls(
          toolCalls: [toolCall],
          manager: manager,
        );

        final workflow = TemplateEvolutionWorkflow(
          conversationRepository: convRepo,
          aiConfigRepository: mockAiConfig,
          cloudInferenceRepository: mockCloudInference,
          templateService: mockTemplateService,
          syncService: mockSyncService,
        );
        workflow.activeSessions['session-trans'] = ActiveEvolutionSession(
          sessionId: 'session-trans',
          templateId: kTestTemplateId,
          conversationId: 'conv-trans',
          strategy: strategy,
          modelId: 'model',
        );

        final result = await workflow.approveProposal(
          sessionId: 'session-trans',
        );
        expect(result, isNotNull);

        final capturedEntities = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        final recapEntities = capturedEntities
            .whereType<EvolutionSessionRecapEntity>()
            .toList();
        expect(recapEntities, hasLength(1));

        final transcript = recapEntities.first.transcript;
        expect(transcript, isNotEmpty);

        // User message should appear in transcript.
        final userEntries = transcript
            .where((e) => e['role'] == 'user')
            .toList();
        expect(userEntries, hasLength(1));
        expect(userEntries.first['text'], 'What should I improve?');

        // Assistant message should also appear.
        final assistantEntries = transcript
            .where((e) => e['role'] == 'assistant')
            .toList();
        expect(assistantEntries, isNotEmpty);
      },
    );
  });
}

/// A [ConversationRepository] that returns a specific pre-built
/// [ConversationManager] for a given conversation ID. Used to inject
/// transcripts (user + assistant messages) in tests that exercise the
/// `_snapshotTranscript` code path.
class _ConversationRepositoryWithManager extends ConversationRepository {
  _ConversationRepositoryWithManager({
    required String conversationId,
    required ConversationManager manager,
  }) : _conversationId = conversationId, // ignore: prefer_initializing_formals
       _manager = manager; // ignore: prefer_initializing_formals

  final String _conversationId;
  final ConversationManager _manager;

  @override
  void build() {}

  @override
  String createConversation({
    String? systemMessage,
    int maxTurns = 20,
  }) => _conversationId;

  @override
  ConversationManager? getConversation(String conversationId) => _manager;

  @override
  void deleteConversation(String conversationId) {}

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
  }) async => null;
}
