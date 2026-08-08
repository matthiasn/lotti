import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/projection/input_capture.dart';
import 'package:lotti/features/agents/service/agent_log_llm_summarizer.dart';
import 'package:lotti/features/agents/sync/agent_input_capture_service.dart';
import 'package:lotti/features/agents/workflow/task_agent_workflow.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
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
import '../test_utils.dart';

// ── Mock conversation repository hierarchy ───────────────────────────────────

/// Minimal mock of [ConversationRepository] that avoids Riverpod build().
///
/// ConversationRepository is a Riverpod notifier, so we extend it directly and
/// override the methods the workflow calls rather than using `Mock`.
class MockConversationRepository extends ConversationRepository {
  MockConversationRepository(this._mockManager, {this.onSystemMessage});

  final MockConversationManager _mockManager;

  /// Optional callback capturing the system message passed to
  /// [createConversation] (used by the project-agent workflow tests).
  final void Function(String? systemMessage)? onSystemMessage;

  final List<String> deletedConversationIds = [];

  /// Delegate for sendMessage — set in tests to control behavior.
  Future<InferenceUsage?> Function({
    required String conversationId,
    required String message,
    required String model,
    required AiConfigInferenceProvider provider,
    required InferenceRepositoryInterface inferenceRepo,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
    double temperature,
    ConversationStrategy? strategy,
  })?
  sendMessageDelegate;

  /// Number of times [sendMessage] has actually forwarded to
  /// [sendMessageDelegate]. Incremented each time the gate is open.
  int sendMessageDelegateCallCount = 0;

  /// Upper bound on delegate invocations (`1` by default). The production
  /// workflow now fires a forced-`update_report` retry whenever the strategy
  /// ended without a report, so without this gate most test delegates would
  /// be invoked twice and cause duplicate side effects. Tests that want to
  /// exercise both the primary call and the retry can set this to `2` (or
  /// higher).
  int maxDelegateCalls = 1;

  /// Consumption owner ids captured from the most recent [sendMessage] call,
  /// so tests can assert the workflow's pass-through wiring without widening
  /// the [sendMessageDelegate] signature.
  String? lastConsumptionAgentId;
  String? lastConsumptionTaskId;
  String? lastConsumptionCategoryId;
  String? lastConsumptionWakeRunKey;
  String? lastConsumptionThreadId;

  @override
  void build() {
    // No-op for test mock.
  }

  @override
  String createConversation({String? systemMessage, int maxTurns = 20}) {
    onSystemMessage?.call(systemMessage);
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
    ChatCompletionToolChoiceOption? toolChoice,
    double temperature = 0.7,
    ConversationStrategy? strategy,
    String? consumptionAgentId,
    String? consumptionTaskId,
    String? consumptionCategoryId,
    String? consumptionWakeRunKey,
    String? consumptionThreadId,
    bool rethrowInferenceErrors = false,
  }) async {
    lastConsumptionAgentId = consumptionAgentId;
    lastConsumptionTaskId = consumptionTaskId;
    lastConsumptionCategoryId = consumptionCategoryId;
    lastConsumptionWakeRunKey = consumptionWakeRunKey;
    lastConsumptionThreadId = consumptionThreadId;
    if (sendMessageDelegate != null &&
        sendMessageDelegateCallCount < maxDelegateCalls) {
      sendMessageDelegateCallCount++;
      return sendMessageDelegate!(
        conversationId: conversationId,
        message: message,
        model: model,
        provider: provider,
        inferenceRepo: inferenceRepo,
        tools: tools,
        toolChoice: toolChoice,
        temperature: temperature,
        strategy: strategy,
      );
    }
    return null;
  }
}

/// Like [MockConversationRepository] but returns null from getConversation,
/// simulating a scenario where the conversation was already cleaned up.
class NullManagerConversationRepository extends MockConversationRepository {
  // ignore: use_super_parameters
  NullManagerConversationRepository(MockConversationManager mockManager)
    : super(mockManager);

  @override
  ConversationManager? getConversation(String conversationId) => null;
}

// ── Common stub helpers ──────────────────────────────────────────────────────

/// Stubs the minimal set of dependencies needed to reach the "resolve provider"
/// step in [TaskAgentWorkflow.execute]. Most error-path tests share this setup.
void stubPreExecuteDefaults({
  required MockAgentRepository mockAgentRepository,
  required MockAiInputRepository mockAiInputRepository,
  required AgentStateEntity testAgentState,
  required String agentId,
  required String taskId,
}) {
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
    () => mockAiInputRepository.buildLinkedTasksJson(taskId),
  ).thenAnswer((_) async => '{}');
  when(
    () => mockAiInputRepository.buildProjectContextJsonForTask(taskId),
  ).thenAnswer((_) async => '{}');
}

/// Extends [stubPreExecuteDefaults] with the model/provider stubs needed for
/// a successful execute path (including the conversation).
void stubFullExecutePath({
  required MockAgentRepository mockAgentRepository,
  required MockAiInputRepository mockAiInputRepository,
  required MockAiConfigRepository mockAiConfigRepository,
  required MockConversationManager mockConversationManager,
  required AgentStateEntity testAgentState,
  required AiConfigModel geminiModel,
  required AiConfigInferenceProvider geminiProvider,
  required String agentId,
  required String taskId,
}) {
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
    () => mockAiConfigRepository.getConfigById(geminiModel.inferenceProviderId),
  ).thenAnswer((_) async => geminiProvider);
  when(
    () => mockAgentRepository.getReportHead(agentId, 'current'),
  ).thenAnswer((_) async => null);
  when(() => mockConversationManager.messages).thenReturn([]);
}

// ── Workflow factory ─────────────────────────────────────────────────────────

/// Creates a [TaskAgentWorkflow] with all standard mocks. Avoids repeating
/// the 12-parameter constructor in every test that needs a custom repo.
TaskAgentWorkflow createTestWorkflow({
  required MockAgentRepository agentRepository,
  required MockConversationRepository conversationRepository,
  required MockAiInputRepository aiInputRepository,
  required MockAiConfigRepository aiConfigRepository,
  required MockJournalDb journalDb,
  required MockCloudInferenceRepository cloudInferenceRepository,
  required MockJournalRepository journalRepository,
  required MockChecklistRepository checklistRepository,
  required MockLabelsRepository labelsRepository,
  required MockAgentSyncService syncService,
  required MockAgentTemplateService templateService,
  MockSoulDocumentService? soulDocumentService,
  AgentInputCaptureService? inputCaptureService,
  AgentLogLlmSummarizer? logSummarizer,
  DomainLogger? domainLogger,
  int compactionTailBudgetTokens = 50000,
  int compactionTailRetainTokens = 20000,
}) {
  return TaskAgentWorkflow(
    agentRepository: agentRepository,
    conversationRepository: conversationRepository,
    aiInputRepository: aiInputRepository,
    aiConfigRepository: aiConfigRepository,
    journalDb: journalDb,
    cloudInferenceRepository: cloudInferenceRepository,
    journalRepository: journalRepository,
    checklistRepository: checklistRepository,
    labelsRepository: labelsRepository,
    syncService: syncService,
    templateService: templateService,
    soulDocumentService: soulDocumentService,
    inputCaptureService: inputCaptureService,
    logSummarizer: logSummarizer,
    domainLogger: domainLogger,
    compactionTailBudgetTokens: compactionTailBudgetTokens,
    compactionTailRetainTokens: compactionTailRetainTokens,
  );
}

/// A stubbed [MockAgentLogLlmSummarizer] that returns [summary] (or throws
/// [error]) for any fold — the workflow's compaction seam in tests.
MockAgentLogLlmSummarizer stubLogSummarizer({
  String summary = 'SUMMARY',
  Object? error,
}) {
  final mock = MockAgentLogLlmSummarizer();
  final stub = when(
    () => mock.summarize(
      sources: any(named: 'sources'),
      priorSummary: any(named: 'priorSummary'),
      model: any(named: 'model'),
      provider: any(named: 'provider'),
    ),
  );
  if (error != null) {
    stub.thenAnswer((_) => Future<String>.error(error));
  } else {
    stub.thenAnswer((_) async => summary);
  }
  return mock;
}

// ── Capture helpers ──────────────────────────────────────────────────────────

/// Extracts all [AgentDomainEntity] instances of type [T] from a list of
/// captured `upsertEntity` arguments.
List<T> capturedEntitiesOfType<T extends AgentDomainEntity>(
  List<dynamic> captured,
) {
  return captured.whereType<AgentDomainEntity>().whereType<T>().toList();
}

/// Extracts [WakeTokenUsageEntity] instances from captured upsert arguments.
List<WakeTokenUsageEntity> capturedTokenUsageEntities(List<dynamic> captured) {
  return captured
      .whereType<AgentDomainEntity>()
      .where((e) => e.mapOrNull(wakeTokenUsage: (_) => true) ?? false)
      .cast<WakeTokenUsageEntity>()
      .toList();
}

/// Extracts [AgentStateEntity] instances from captured upsert arguments.
List<AgentStateEntity> capturedStateEntities(List<dynamic> captured) {
  return captured
      .whereType<AgentDomainEntity>()
      .where((e) => e.mapOrNull(agentState: (_) => true) ?? false)
      .cast<AgentStateEntity>()
      .toList();
}

/// Extracts [AgentMessagePayloadEntity] instances from captured upsert
/// arguments.
List<AgentMessagePayloadEntity> capturedPayloadEntities(
  List<dynamic> captured,
) {
  return captured
      .whereType<AgentDomainEntity>()
      .where((e) => e.mapOrNull(agentMessagePayload: (_) => true) ?? false)
      .cast<AgentMessagePayloadEntity>()
      .toList();
}

// ── Deferred tool verification ───────────────────────────────────────────────

/// Verifies that a tool response was sent indicating the tool call was
/// deferred (proposal recorded / queued for review).
void verifyDeferredToolResponse(
  MockConversationManager mockConversationManager, {
  String toolCallId = 'tc-1',
}) {
  verify(
    () => mockConversationManager.addToolResponse(
      toolCallId: toolCallId,
      response: any(
        named: 'response',
        that: anyOf(contains('proposal recorded'), contains('Proposal queued')),
      ),
    ),
  ).called(1);
}

/// Captures the exact `response` string the strategy fed back to the LLM via
/// [ConversationManager.addToolResponse] for [toolCallId].
///
/// Lets callers assert on the *content* of the LLM-facing tool response (e.g.
/// that a deferral was reported as "proposal recorded" with the correct tool
/// name) rather than only that a response of some kind was sent.
String captureDeferredToolResponse(
  MockConversationManager mockConversationManager, {
  String toolCallId = 'tc-1',
}) {
  final captured = verify(
    () => mockConversationManager.addToolResponse(
      toolCallId: toolCallId,
      response: captureAny(named: 'response'),
    ),
  ).captured;
  expect(
    captured,
    hasLength(1),
    reason: 'expected exactly one tool response for $toolCallId',
  );
  return captured.single as String;
}

/// Verifies that a deferred tool call was NOT executed immediately (no
/// journal update).
void verifyNotExecutedImmediately(MockJournalRepository mockJournalRepository) {
  verifyNever(() => mockJournalRepository.updateJournalEntity(any()));
}

/// Combines [verifyNotExecutedImmediately] and [verifyDeferredToolResponse].
void verifyToolWasDeferred({
  required MockConversationManager mockConversationManager,
  required MockJournalRepository mockJournalRepository,
  String toolCallId = 'tc-1',
}) {
  verifyNotExecutedImmediately(mockJournalRepository);
  verifyDeferredToolResponse(mockConversationManager, toolCallId: toolCallId);
}

const taskAgentTestAgentId = 'agent-001';
const taskAgentTestTaskId = 'task-001';
const taskAgentTestRunKey = 'run-key-001';
const taskAgentTestThreadId = 'thread-001';

final taskAgentTestDate = DateTime(2024, 6, 15, 10, 30);

final AgentTemplateEntity taskAgentTestTemplate = makeTestTemplate();
final AgentTemplateVersionEntity taskAgentTestTemplateVersion =
    makeTestTemplateVersion(
      directives: 'You are a diligent task agent named Laura.',
    );

final taskAgentTestAgentIdentity =
    AgentDomainEntity.agent(
          id: taskAgentTestAgentId,
          agentId: taskAgentTestAgentId,
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

final taskAgentTestAgentState =
    AgentDomainEntity.agentState(
          id: 'state-001',
          agentId: taskAgentTestAgentId,
          revision: 3,
          slots: const AgentSlots(activeTaskId: taskAgentTestTaskId),
          updatedAt: taskAgentTestDate,
          vectorClock: null,
        )
        as AgentStateEntity;

final taskAgentTestGeminiProvider =
    AiConfig.inferenceProvider(
          id: 'gemini-provider-001',
          baseUrl: 'https://generativelanguage.googleapis.com',
          apiKey: 'test-api-key',
          name: 'Gemini',
          createdAt: DateTime(2024),
          inferenceProviderType: InferenceProviderType.gemini,
        )
        as AiConfigInferenceProvider;

final taskAgentTestGeminiModel =
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

Future<void> setUpTaskAgentWorkflowTestGetIt() async {
  registerAllFallbackValues();
  await setUpTestGetIt(
    additionalSetup: () {
      getIt
        ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
        ..registerSingleton<TimeService>(TimeService());
    },
  );
}

Future<void> tearDownTaskAgentWorkflowTestGetIt() => tearDownTestGetIt();

typedef TaskAgentWorkflowTestBench = ({
  MockAgentRepository mockAgentRepository,
  MockAgentSyncService mockSyncService,
  MockConversationRepository mockConversationRepository,
  MockAiInputRepository mockAiInputRepository,
  MockAiConfigRepository mockAiConfigRepository,
  MockJournalDb mockJournalDb,
  MockCloudInferenceRepository mockCloudInferenceRepository,
  MockConversationManager mockConversationManager,
  MockJournalRepository mockJournalRepository,
  MockChecklistRepository mockChecklistRepository,
  MockLabelsRepository mockLabelsRepository,
  MockAgentTemplateService mockTemplateService,
  TaskAgentWorkflow workflow,
});

/// Builds the shared task-agent workflow bench.
///
/// [narrowToolSurface] flips the workflow's agenda-gated tool exposure on, so
/// the wake resolves its gating facts and stages `update_report` (see
/// `docs/adr/0051-agenda-gated-tool-exposure.md`). Off by default, matching the
/// shipped wake.
TaskAgentWorkflowTestBench createTaskAgentWorkflowTestBench({
  bool narrowToolSurface = false,
}) {
  const agentId = taskAgentTestAgentId;
  final testTemplate = taskAgentTestTemplate;
  final testTemplateVersion = taskAgentTestTemplateVersion;

  final mockAgentRepository = MockAgentRepository();
  final mockSyncService = MockAgentSyncService();
  // A real sync service always exposes its repository; individual tests
  // re-stub specific ids on `mockAgentRepository`.
  when(() => mockSyncService.repository).thenReturn(mockAgentRepository);
  final mockConversationManager = MockConversationManager();
  final mockConversationRepository = MockConversationRepository(
    mockConversationManager,
  );
  final mockAiInputRepository = MockAiInputRepository();
  final mockAiConfigRepository = MockAiConfigRepository();
  final mockJournalDb = MockJournalDb();
  final mockCloudInferenceRepository = MockCloudInferenceRepository();
  final mockJournalRepository = MockJournalRepository();
  final mockChecklistRepository = MockChecklistRepository();
  final mockLabelsRepository = MockLabelsRepository();
  final mockTemplateService = MockAgentTemplateService();

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
  when(() => mockAgentRepository.getEntitiesByIds(any())).thenAnswer((
    invocation,
  ) async {
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
    () =>
        mockAgentRepository.getLinksToMultiple(any(), type: any(named: 'type')),
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
    () => mockAgentRepository.getAttentionClaimsForTarget(
      targetKind: any(named: 'targetKind'),
      targetId: any(named: 'targetId'),
      limit: any(named: 'limit'),
    ),
  ).thenAnswer((_) async => const <AttentionRequestEntity>[]);
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
    () => mockJournalDb.getLinkedEntities(any()),
  ).thenAnswer((_) async => <JournalEntity>[]);
  // Only read when the tool surface is gated, but harmless as a default: a
  // wake with no labels defined cannot assign one.
  when(
    mockJournalDb.getAllLabelDefinitions,
  ).thenAnswer((_) async => <LabelDefinition>[]);

  // Default template stubs — tests that need different behavior override.
  when(
    () => mockTemplateService.getTemplateForAgent(agentId),
  ).thenAnswer((_) async => testTemplate);
  when(
    () => mockTemplateService.getActiveVersion(testTemplate.id),
  ).thenAnswer((_) async => testTemplateVersion);

  final workflow = TaskAgentWorkflow(
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
    narrowToolSurface: narrowToolSurface,
    domainLogger: DomainLogger(loggingService: LoggingService())
      ..enabledDomains.add(LogDomain.agentWorkflow),
  );

  return (
    mockAgentRepository: mockAgentRepository,
    mockSyncService: mockSyncService,
    mockConversationRepository: mockConversationRepository,
    mockAiInputRepository: mockAiInputRepository,
    mockAiConfigRepository: mockAiConfigRepository,
    mockJournalDb: mockJournalDb,
    mockCloudInferenceRepository: mockCloudInferenceRepository,
    mockConversationManager: mockConversationManager,
    mockJournalRepository: mockJournalRepository,
    mockChecklistRepository: mockChecklistRepository,
    mockLabelsRepository: mockLabelsRepository,
    mockTemplateService: mockTemplateService,
    workflow: workflow,
  );
}

/// Records [AgentInputCaptureService.captureWakeInputs] calls so the wiring test
/// can assert what the workflow captured, without a real log.
class RecordingCaptureService implements AgentInputCaptureService {
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
class ThrowingCaptureService implements AgentInputCaptureService {
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

int countOccurrences(String haystack, String needle) {
  if (needle.isEmpty) return 0;
  var count = 0;
  var index = haystack.indexOf(needle);
  while (index != -1) {
    count++;
    index = haystack.indexOf(needle, index + needle.length);
  }
  return count;
}

Task makeWorkflowTestTask(String id, {String? languageCode, DateTime? due}) {
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
      due: due,
      languageCode: languageCode,
    ),
  );
}

JournalEntry makeLinkedTimeEntry({
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
