import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_service.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_agent_workflow.dart';
import 'package:lotti/features/daily_os_next/agents/workflow/day_capture_events.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';
import 'package:lotti/features/daily_os_next/logic/real_day_agent.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_processor.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_runtime.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_job_wiring.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../agents/sync/in_memory_agent_repository.dart';
import '../../agents/test_data/template_factories.dart';

/// Wires the full ADR 0032 durable draft/refine pipeline out of real
/// production classes — [DayProcessingOutboxRepository] (real,
/// file-backed), [DayProcessingRuntime], [DayProcessingOutboxProcessor],
/// `DayAgentJobExecutor` (via the real [buildDayAgentJobExecutor] wiring),
/// [WakeOrchestrator]/[WakeQueue]/[WakeRunner], [DayAgentWorkflow],
/// [DayAgentPlanService], [DayAgentCaptureService], [DayAgentService], and
/// [RealDayAgent] — with only the conversation/inference layer injected by
/// the caller.
///
/// Shared by two callers with different LLM layers:
///
///  * `day_agent_durable_jobs_smoke_test.dart` — scripted tool calls, no
///    network, runs in the normal unit-test lane.
///  * `../eval/day_agent_draft_live_eval_test.dart` — the real
///    [ConversationRepository] + [CloudInferenceRepository] against a live
///    provider, gated behind `LOTTI_DAY_AGENT_DRAFT_EVAL_LIVE=1`.
class DayAgentPipelineHarness {
  DayAgentPipelineHarness._({
    required this.root,
    required this.agentRepository,
    required this.syncService,
    required this.templateService,
    required this.domainLogger,
    required this.journalDb,
    required this.wakeRunner,
    required this.orchestrator,
    required this.outbox,
    required this.runtime,
    required this.realDayAgent,
  });

  /// Builds the full pipeline. [now] seeds template timestamps; [profile],
  /// [model], and [provider] are the inference configs the workflow resolves
  /// (the template's profile points at [profile], whose thinking model must
  /// equal [model]'s `providerModelId`, which must resolve to [provider]).
  ///
  /// With [logToStdout] the otherwise-swallowed domain logs are printed —
  /// useful for live eval runs where the model's behavior is the thing
  /// under observation.
  factory DayAgentPipelineHarness.create({
    required DateTime now,
    required ConversationRepository conversationRepository,
    required CloudInferenceRepository cloudInferenceRepository,
    required AiConfigInferenceProfile profile,
    required AiConfigModel model,
    required AiConfigInferenceProvider provider,
    bool logToStdout = false,
  }) {
    final root = Directory.systemTemp.createTempSync('day-agent-pipeline-');
    final agentRepository = PipelineAgentRepository();
    final syncService = DelegatingAgentSyncService(agentRepository);
    final templateService = MockAgentTemplateService();
    final domainLogger = MockDomainLogger();
    final journalDb = MockJournalDb();
    final fts5Db = MockFts5Db();
    final journalRepository = MockJournalRepository();
    final aiConfigRepository = MockAiConfigRepository();
    final wakeQueue = WakeQueue();
    final wakeRunner = WakeRunner();

    stubAppendMilestone(syncService);

    when(
      () => domainLogger.log(
        any(),
        any(),
        subDomain: any(named: 'subDomain'),
        level: any(named: 'level'),
      ),
    ).thenAnswer((invocation) {
      if (logToStdout) {
        debugPrint(
          '[${invocation.positionalArguments[0]}] '
          '${invocation.positionalArguments[1]}',
        );
      }
    });
    when(
      () => domainLogger.error(
        any(),
        any(),
        message: any(named: 'message'),
        stackTrace: any(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenAnswer((invocation) {
      if (logToStdout) {
        debugPrint(
          '[ERROR ${invocation.positionalArguments[0]}] '
          '${invocation.namedArguments[#message]}: '
          '${invocation.positionalArguments[1]}',
        );
      }
    });

    // Day-agent template: seeded for real (DayAgentService reads it directly
    // via `repository.getEntity`), version/directives are mocked (only
    // consumed for prompt rendering by DayAgentWorkflow).
    agentRepository.seed([
      AgentDomainEntity.agentTemplate(
            id: dayAgentTemplateId,
            agentId: dayAgentTemplateId,
            displayName: 'Shepherd',
            kind: AgentTemplateKind.dayAgent,
            modelId: model.providerModelId,
            categoryIds: const {},
            profileId: profile.id,
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
        modelId: model.providerModelId,
        profileId: profile.id,
      ),
    );
    when(() => templateService.getActiveVersion(dayAgentTemplateId)).thenAnswer(
      (_) async => makeTestTemplateVersion(
        id: 'version-day',
        agentId: dayAgentTemplateId,
        generalDirective: 'Plan the day well.',
        reportDirective: 'Report clearly.',
        profileId: profile.id,
      ),
    );

    when(
      () => aiConfigRepository.getConfigById(profile.id),
    ).thenAnswer((_) async => profile);
    when(
      () => aiConfigRepository.getConfigsByType(AiConfigType.model),
    ).thenAnswer((_) async => [model]);
    when(
      () => aiConfigRepository.getConfigById(provider.id),
    ).thenAnswer((_) async => provider);

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

    final orchestrator =
        WakeOrchestrator(
            repository: agentRepository,
            queue: wakeQueue,
            runner: wakeRunner,
            domainLogger: domainLogger,
          )
          // Routes exactly like the real `wireWakeExecutor` day-agent branch
          // (agent_wiring.dart), minus the kinds this harness never exercises.
          ..wakeExecutor = (agentId, runKey, triggers, threadId) async {
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

    final outbox = DayProcessingOutboxRepository(rootDirectory: root);

    final executor = buildDayAgentJobExecutor(
      dayAgentService: dayAgentService,
      planService: planService,
      captureService: captureService,
      orchestrator: orchestrator,
    );
    final processor = DayProcessingOutboxProcessor(
      repository: outbox,
      // Only the agent-job lane is exercised; this harness doesn't touch
      // transcription.
      transcribe: (_) async => throw UnimplementedError(),
      attachTranscript: (_, _) async => false,
      agentJobExecutor: executor.execute,
    );
    final runtime = DayProcessingRuntime(
      repository: outbox,
      drain: () => processor.drain(kinds: dayAgentJobKinds),
    )..start();

    final realDayAgent = RealDayAgent(
      captureService: captureService,
      planService: planService,
      dayAgentService: dayAgentService,
      journalDb: journalDb,
      mockFallback: MockDayAgent(),
      outbox: outbox,
      nudgeProcessing: () => unawaited(runtime.nudge()),
    );

    return DayAgentPipelineHarness._(
      root: root,
      agentRepository: agentRepository,
      syncService: syncService,
      templateService: templateService,
      domainLogger: domainLogger,
      journalDb: journalDb,
      wakeRunner: wakeRunner,
      orchestrator: orchestrator,
      outbox: outbox,
      runtime: runtime,
      realDayAgent: realDayAgent,
    );
  }

  final Directory root;
  final PipelineAgentRepository agentRepository;
  final DelegatingAgentSyncService syncService;
  final MockAgentTemplateService templateService;
  final MockDomainLogger domainLogger;
  final MockJournalDb journalDb;
  final WakeRunner wakeRunner;
  final WakeOrchestrator orchestrator;
  final DayProcessingOutboxRepository outbox;
  final DayProcessingRuntime runtime;
  final RealDayAgent realDayAgent;

  /// Stops the runtime/orchestrator, closes the outbox, and deletes the
  /// temp directory backing it.
  Future<void> dispose() async {
    await orchestrator.stop();
    await runtime.dispose();
    await outbox.dispose();
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}

/// A [MockAgentSyncService] whose writes go straight into the same
/// in-memory store the repository reads from, so writes made mid-wake
/// (plan drafts, refine diffs) are visible to later reads in the same test
/// — real read-after-write semantics without a real Matrix/sqlite backend.
class DelegatingAgentSyncService extends MockAgentSyncService {
  DelegatingAgentSyncService(this._repository);

  final PipelineAgentRepository _repository;

  @override
  AgentRepository get repository => _repository;

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

/// Extends the shared [InMemoryAgentRepository] with the additional
/// real-semantics methods the pipeline's call path needs (wake-run
/// bookkeeping, agent listing, attention-planning inputs, capture
/// metadata) that the shared fixture's narrower call graph doesn't cover.
class PipelineAgentRepository extends InMemoryAgentRepository {
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
