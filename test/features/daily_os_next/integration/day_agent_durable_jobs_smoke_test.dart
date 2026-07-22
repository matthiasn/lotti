import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_database.dart'
    hide AgentLink;
import 'package:lotti/features/agents/database/agent_db_conversions.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/model/attention_negotiation.dart';
import 'package:lotti/features/agents/service/agent_service.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/agents/wake/wake_queue.dart';
import 'package:lotti/features/agents/wake/wake_runner.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_identity.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_service.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_agent_workflow.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_capture_events.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';
import 'package:lotti/features/daily_os_next/logic/real_day_agent.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_processor.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_runtime.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_job_wiring.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../agents/sync/in_memory_agent_repository.dart';
import '../../agents/test_data/ai_config_factories.dart';
import '../../agents/test_data/template_factories.dart';

/// End-to-end smoke test for the ADR 0032 durable draft/refine pipeline.
///
/// Unlike the unit tests elsewhere in this branch (which fake or mock the
/// outbox, the executor, or the workflow individually), this wires the real
/// production classes together — [DayProcessingOutboxRepository] (real,
/// file-backed), [DayProcessingRuntime], [DayProcessingOutboxProcessor],
/// `DayAgentJobExecutor` (via the real [buildDayAgentJobExecutor] wiring),
/// [WakeOrchestrator]/[WakeQueue]/[WakeRunner], [DayAgentWorkflow],
/// [DayAgentPlanService], [DayAgentCaptureService], [DayAgentService], and
/// [RealDayAgent] — and drives a draft then a refine through the whole
/// chain. Only the LLM response is scripted (no network call), matching the
/// pattern already used by `day_agent_workflow_test.dart`.
///
/// This is the closest thing to a live manual smoke test that is available
/// without GUI/microphone automation: it proves the new outbox → runtime →
/// executor → orchestrator → workflow → plan-service → outbox-completion
/// round trip genuinely works, not just that each link passes its own
/// mocked unit test.
void main() {
  setUpAll(registerAllFallbackValues);

  // Fixed well into the future (rather than tied to whatever "today" is at
  // test-run time) so drafted blocks never trip the real
  // `DayAgentPlanWriter.persistDraftPlan` "must not start before current
  // time" guard, which compares against the real `clock.now()` whenever the
  // plan's day is today's local day.
  final now = DateTime(2030, 1, 15, 9);
  final dayDate = DateTime(2030, 1, 15);
  final dayId = dayAgentIdForDate(dayDate);

  late Directory root;
  late _TestAgentRepository agentRepository;
  late _DelegatingAgentSyncService syncService;
  late MockAgentTemplateService templateService;
  late MockDomainLogger domainLogger;
  late MockJournalDb journalDb;
  late MockFts5Db fts5Db;
  late MockJournalRepository journalRepository;
  late MockAiConfigRepository aiConfigRepository;
  late MockCloudInferenceRepository cloudInferenceRepository;
  late _ScriptedConversationRepository conversationRepository;
  late WakeQueue wakeQueue;
  late WakeRunner wakeRunner;
  late WakeOrchestrator orchestrator;
  late DayProcessingOutboxRepository outbox;
  late DayProcessingRuntime runtime;
  late RealDayAgent realDayAgent;

  void stubInferenceProfile() {
    when(
      () => aiConfigRepository.getConfigById('profile-day'),
    ).thenAnswer(
      (_) async => testInferenceProfile(
        id: 'profile-day',
        thinkingModelId: 'models/day',
      ),
    );
    when(
      () => aiConfigRepository.getConfigsByType(AiConfigType.model),
    ).thenAnswer(
      (_) async => [
        testAiModel(
          id: 'model-day',
          providerModelId: 'models/day',
          inferenceProviderId: 'provider-day',
        ),
      ],
    );
    when(
      () => aiConfigRepository.getConfigById('provider-day'),
    ).thenAnswer(
      (_) async => testInferenceProvider(
        id: 'provider-day',
        apiKey: 'provider-key',
      ),
    );
  }

  setUp(() async {
    root = Directory.systemTemp.createTempSync('day-agent-smoke-test-');
    agentRepository = _TestAgentRepository();
    syncService = _DelegatingAgentSyncService(agentRepository);
    templateService = MockAgentTemplateService();
    domainLogger = MockDomainLogger();
    journalDb = MockJournalDb();
    fts5Db = MockFts5Db();
    journalRepository = MockJournalRepository();
    aiConfigRepository = MockAiConfigRepository();
    cloudInferenceRepository = MockCloudInferenceRepository();
    conversationRepository = _ScriptedConversationRepository();
    wakeQueue = WakeQueue();
    wakeRunner = WakeRunner();

    stubAppendMilestone(syncService);

    when(
      () => domainLogger.log(
        any(),
        any(),
        subDomain: any(named: 'subDomain'),
        level: any(named: 'level'),
      ),
    ).thenReturn(null);
    when(
      () => domainLogger.error(
        any(),
        any(),
        message: any(named: 'message'),
        stackTrace: any(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);

    // Day-agent template: seeded for real (DayAgentService reads it directly
    // via `repository.getEntity`), version/directives are mocked (only
    // consumed for prompt rendering by DayAgentWorkflow).
    agentRepository.seed([
      AgentDomainEntity.agentTemplate(
            id: dayAgentTemplateId,
            agentId: dayAgentTemplateId,
            displayName: 'Shepherd',
            kind: AgentTemplateKind.dayAgent,
            modelId: 'models/day',
            categoryIds: const {},
            profileId: 'profile-day',
            createdAt: now,
            updatedAt: now,
            vectorClock: null,
          )
          as AgentTemplateEntity,
    ]);
    when(() => templateService.getTemplateForAgent(any())).thenAnswer(
      (_) async => makeTestTemplate(
        id: dayAgentTemplateId,
        agentId: dayAgentTemplateId,
        kind: AgentTemplateKind.dayAgent,
        modelId: 'models/day',
        profileId: 'profile-day',
      ),
    );
    when(() => templateService.getActiveVersion(dayAgentTemplateId)).thenAnswer(
      (_) async => makeTestTemplateVersion(
        id: 'version-day',
        agentId: dayAgentTemplateId,
        generalDirective: 'Plan the day well.',
        reportDirective: 'Report clearly.',
        profileId: 'profile-day',
      ),
    );

    stubInferenceProfile();
    when(() => journalDb.getCategoryById(any())).thenAnswer((_) async => null);
    when(
      () => journalDb.getOpenTasksForDayAgentCorpus(
        categoryIds: any(named: 'categoryIds'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const []);
    when(
      () => journalDb.getTasksDueOn(any()),
    ).thenAnswer((_) async => const []);
    when(
      () => journalDb.getTasksDueOnOrBefore(any()),
    ).thenAnswer((_) async => const []);
    when(
      () => journalDb.getInProgressTasks(
        categoryIds: any(named: 'categoryIds'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => const []);
    when(
      () => journalDb.getMissedRecurringTasks(
        asOf: any(named: 'asOf'),
        lookbackDays: any(named: 'lookbackDays'),
        categoryIds: any(named: 'categoryIds'),
      ),
    ).thenAnswer((_) async => const []);

    final planService = DayAgentPlanService(
      agentRepository: agentRepository,
      syncService: syncService,
      journalDb: journalDb,
      domainLogger: domainLogger,
    );
    final captureService = DayAgentCaptureService(
      agentRepository: agentRepository,
      syncService: syncService,
      journalDb: journalDb,
      journalRepository: journalRepository,
      fts5Db: fts5Db,
      orchestrator: WakeOrchestrator(
        repository: agentRepository,
        queue: wakeQueue,
        runner: wakeRunner,
      ),
      domainLogger: domainLogger,
    );

    final dayWorkflow = DayAgentWorkflow(
      agentRepository: agentRepository,
      conversationRepository: conversationRepository,
      aiConfigRepository: aiConfigRepository,
      cloudInferenceRepository: cloudInferenceRepository,
      syncService: syncService,
      templateService: templateService,
      captureService: captureService,
      planService: planService,
      domainLogger: domainLogger,
    );

    orchestrator = WakeOrchestrator(
      repository: agentRepository,
      queue: wakeQueue,
      runner: wakeRunner,
      domainLogger: domainLogger,
    );
    addTearDown(orchestrator.stop);
    // Routes exactly like the real `wireWakeExecutor` day-agent branch
    // (agent_wiring.dart), minus the kinds this test never exercises.
    orchestrator.wakeExecutor = (agentId, runKey, triggers, threadId) async {
      final identity = await agentRepository.getEntity(agentId);
      if (identity is! AgentIdentityEntity) return null;
      final result = await dayWorkflow.execute(
        agentIdentity: identity,
        runKey: runKey,
        triggerTokens: triggers,
        threadId: threadId,
      );
      if (!result.success) {
        throw StateError(result.error ?? 'Day agent wake failed');
      }
      return result.mutatedEntries;
    };

    final agentService = AgentService(
      repository: agentRepository,
      orchestrator: orchestrator,
      syncService: syncService,
    );
    final dayAgentService = DayAgentService(
      agentService: agentService,
      repository: agentRepository,
      orchestrator: orchestrator,
      syncService: syncService,
      templateService: templateService,
      domainLogger: domainLogger,
    );

    outbox = DayProcessingOutboxRepository(rootDirectory: root);
    addTearDown(outbox.dispose);

    final executor = buildDayAgentJobExecutor(
      dayAgentService: dayAgentService,
      planService: planService,
      captureService: captureService,
      orchestrator: orchestrator,
    );
    final processor = DayProcessingOutboxProcessor(
      repository: outbox,
      // Only the agent-job lane is exercised; this smoke test doesn't touch
      // transcription.
      transcribe: (_) async => throw UnimplementedError(),
      attachTranscript: (_, _) async => false,
      agentJobExecutor: executor.execute,
    );
    runtime = DayProcessingRuntime(
      repository: outbox,
      drain: () => processor.drain(kinds: dayAgentJobKinds),
    )..start();
    addTearDown(runtime.dispose);

    realDayAgent = RealDayAgent(
      captureService: captureService,
      planService: planService,
      dayAgentService: dayAgentService,
      journalDb: journalDb,
      mockFallback: MockDayAgent(),
      outbox: outbox,
      nudgeProcessing: () => unawaited(runtime.nudge()),
    );
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test(
    'draft then refine round-trip through the real outbox/executor/ '
    'orchestrator/workflow chain, with only the LLM response scripted',
    () async {
      // ── Draft ────────────────────────────────────────────────────────────
      conversationRepository.toolCalls = [
        _toolCall(
          id: 'draft-call',
          name: DayAgentToolNames.draftDayPlan,
          args: {
            'dayId': dayId,
            'blocks': [
              {
                'title': 'Deep work',
                'categoryId': 'work',
                'start': dayDate
                    .add(const Duration(hours: 9))
                    .toIso8601String(),
                'end': dayDate.add(const Duration(hours: 10)).toIso8601String(),
                'reason': 'Morning focus window.',
              },
            ],
          },
        ),
      ];

      final draft = await realDayAgent.draftDayPlan(
        captureId: const CaptureId(''),
        decidedTaskIds: const [],
        dayDate: dayDate,
      );

      expect(draft.blocks, hasLength(1));
      expect(draft.blocks.single.title, 'Deep work');
      expect(draft.state, DayState.drafted);

      // The per-day agent identity was created for real, and the durable job
      // it ran through is on disk, terminal, and succeeded — proving the
      // whole round trip, not just the in-memory return value.
      final dayAgentId = perDayAgentId(dayId);
      final draftJob = await outbox.getById(
        DayProcessingOutboxRepository.draftJobId(dayId),
      );
      expect(draftJob, isNotNull);
      expect(draftJob!.isTerminal, isTrue);
      expect(draftJob.status.name, 'succeeded');
      final identity = await agentRepository.getEntity(dayAgentId);
      expect(identity, isA<AgentIdentityEntity>());

      // ── Refine ───────────────────────────────────────────────────────────
      conversationRepository.toolCalls = [
        _toolCall(
          id: 'refine-call',
          name: DayAgentToolNames.proposePlanDiff,
          args: {
            'dayId': dayId,
            'changes': [
              {
                'action': 'added',
                'reason': 'Add a stretch break.',
                'to': {
                  'start': dayDate
                      .add(const Duration(hours: 11))
                      .toIso8601String(),
                  'end': dayDate
                      .add(const Duration(hours: 11, minutes: 15))
                      .toIso8601String(),
                  'title': 'Stretch',
                  'categoryId': 'health',
                },
              },
            ],
          },
        ),
      ];

      final diff = await realDayAgent.proposePlanDiff(
        currentPlan: draft,
        voiceTranscript: 'add a stretch break around 11',
      );

      expect(diff.changes, hasLength(1));
      expect(diff.changes.single.kind, PlanDiffChangeKind.added);

      final refineJobs = (await outbox.getAll())
          .where((job) => job.kind.name == 'refinePlan')
          .toList();
      expect(refineJobs, hasLength(1));
      expect(refineJobs.single.isTerminal, isTrue);
      expect(refineJobs.single.status.name, 'succeeded');
      expect(refineJobs.single.resultEntityId, isNotNull);
    },
  );
}

/// A [MockAgentSyncService] whose writes go straight into the same
/// in-memory store the repository reads from, so writes made mid-wake
/// (plan drafts, refine diffs) are visible to later reads in the same test
/// — real read-after-write semantics without a real Matrix/sqlite backend.
class _DelegatingAgentSyncService extends MockAgentSyncService {
  _DelegatingAgentSyncService(this._repository);

  final _TestAgentRepository _repository;

  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) => action();

  @override
  Future<void> upsertEntity(
    AgentDomainEntity entity, {
    bool fromSync = false,
  }) => _repository.upsertEntity(entity);

  @override
  Future<void> upsertLink(AgentLink link, {bool fromSync = false}) =>
      _repository.upsertLink(link);

  @override
  Future<AgentStateEntity?> reconciledAgentState(String agentId) =>
      _repository.getAgentState(agentId);
}

ChatCompletionMessageToolCall _toolCall({
  required String id,
  required String name,
  required Map<String, Object?> args,
}) {
  return ChatCompletionMessageToolCall(
    id: id,
    type: ChatCompletionMessageToolCallType.function,
    function: ChatCompletionMessageFunctionCall(
      name: name,
      arguments: jsonEncode(args),
    ),
  );
}

/// Fake, in-process [ConversationRepository]: applies the scripted
/// [toolCalls] through the *real* `DayAgentStrategy`/tool dispatch (so real
/// production tool handlers run), without any network call. Mirrors
/// `_ConversationHarness` in `day_agent_workflow_test.dart`.
class _ScriptedConversationRepository extends ConversationRepository {
  final Map<String, ConversationManager> _managers = {};
  int _createdCount = 0;

  List<ChatCompletionMessageToolCall> toolCalls = const [];

  @override
  String createConversation({String? systemMessage, int maxTurns = 20}) {
    _createdCount++;
    final id = 'conversation-$_createdCount';
    _managers[id] = ConversationManager(conversationId: id, maxTurns: maxTurns)
      ..initialize(systemMessage: systemMessage);
    return id;
  }

  @override
  ConversationManager? getConversation(String conversationId) =>
      _managers[conversationId];

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
    final manager = _managers[conversationId]!..addUserMessage(message);
    if (toolCalls.isNotEmpty) {
      manager.addAssistantMessage(toolCalls: toolCalls);
      await strategy!.processToolCalls(toolCalls: toolCalls, manager: manager);
    }
    return null;
  }

  @override
  void deleteConversation(String conversationId) {
    _managers.remove(conversationId)?.dispose();
  }
}

/// Extends the shared [InMemoryAgentRepository] with the additional
/// real-semantics methods this smoke test's call path needs (wake-run
/// bookkeeping, agent listing, attention-planning inputs, capture
/// metadata) that the shared fixture's narrower call graph doesn't cover.
class _TestAgentRepository extends InMemoryAgentRepository {
  @override
  Future<void> insertWakeRun({required WakeRunLogData entry}) async {}

  @override
  Future<void> updateWakeRunStatus(
    String runKey,
    String status, {
    DateTime? completedAt,
    String? errorMessage,
    DateTime? startedAt,
  }) async {}

  @override
  Future<void> updateWakeRunTemplate(
    String runKey,
    String templateId,
    String versionId, {
    String? resolvedModelId,
    String? soulId,
    String? soulVersionId,
  }) async {}

  @override
  Future<List<AgentIdentityEntity>> getAgentIdentitiesByLifecycle(
    AgentLifecycle lifecycle,
  ) async => entities
      .whereType<AgentIdentityEntity>()
      .where((e) => e.lifecycle == lifecycle)
      .toList();

  @override
  Future<List<AgentIdentityEntity>> getAllAgentIdentities() async =>
      entities.whereType<AgentIdentityEntity>().toList();

  @override
  Future<AttentionPlanningInputs> getAttentionPlanningInputsForWindow({
    required DateTime start,
    required DateTime end,
    Set<AttentionClaimStatus> claimStatuses = const {},
    Set<StandingAgreementStatus> agreementStatuses = const {},
    Set<StandingAgreementScope>? agreementScopes,
    int claimLimit = 200,
    int agreementLimit = 200,
  }) async => const AttentionPlanningInputs.empty();

  @override
  Future<List<CaptureEventMeta>> getCaptureEventMetaByAgentId(
    String agentId,
  ) async => entities
      .whereType<CaptureEntity>()
      .where((c) => c.agentId == agentId && c.deletedAt == null)
      .map(
        (c) => (
          id: c.id,
          dayId: c.dayId,
          createdAt: c.createdAt,
          capturedAt: c.capturedAt,
        ),
      )
      .toList();

  @override
  Future<List<AgentDomainEntity>> getEntitiesByAgentId(
    String agentId, {
    String? type,
    int limit = -1,
  }) async => entities
      .where(
        (e) =>
            e.agentId == agentId &&
            (type == null || AgentDbConversions.entityType(e) == type),
      )
      .toList();
}
