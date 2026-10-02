import 'package:clock/clock.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/project_agent_report_contract.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/service/agent_log_llm_summarizer.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/service/project_recommendation_service.dart';
import 'package:lotti/features/agents/service/soul_document_service.dart';
import 'package:lotti/features/agents/service/suggestion_retraction_service.dart';
import 'package:lotti/features/agents/sync/agent_input_capture_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/tools/project_tool_definitions.dart';
import 'package:lotti/features/agents/util/agent_error_logging.dart';
import 'package:lotti/features/agents/util/text_utils.dart';
import 'package:lotti/features/agents/wake/project_update_slots.dart';
import 'package:lotti/features/agents/workflow/agent_observations.dart';
import 'package:lotti/features/agents/workflow/agent_wake_memory.dart';
import 'package:lotti/features/agents/workflow/carrierless_attribution.dart';
import 'package:lotti/features/agents/workflow/deferred_change_items.dart';
import 'package:lotti/features/agents/workflow/project_agent_context_builder.dart';
import 'package:lotti/features/agents/workflow/project_agent_strategy.dart';
import 'package:lotti/features/agents/workflow/project_proposal_reconciler.dart';
import 'package:lotti/features/agents/workflow/prompt_record.dart';
import 'package:lotti/features/agents/workflow/task_source_renderer.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';
import 'package:lotti/features/ai/util/profile_resolver.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_service.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

part 'project_agent_execute.dart';

/// Assembles context, runs a conversation, and persists results for a single
/// Project Agent wake cycle.
///
/// Standalone class (no base class, following the `ImproverAgentWorkflow`
/// pattern). Fetches the project entity + linked tasks, builds a system prompt
/// with project context, runs the conversation, and persists report,
/// observations, and state updates.
class ProjectAgentWorkflow with AgentErrorLogging {
  ProjectAgentWorkflow({
    required this.agentRepository,
    required this.conversationRepository,
    required this.aiConfigRepository,
    required this.cloudInferenceRepository,
    required this.journalRepository,
    required this.syncService,
    required this.templateService,
    this.soulDocumentService,
    this.domainLogger,
    this.onPersistedStateChanged,
    this.inputCaptureService,
    this.logSummarizer,
    this.armProjectUpdate,
    this.compactionTailBudgetTokens = 50000,
    this.compactionTailRetainTokens = 20000,
  });

  final AgentRepository agentRepository;
  final AgentSyncService syncService;
  final ConversationRepository conversationRepository;
  final AiConfigRepository aiConfigRepository;
  final CloudInferenceRepository cloudInferenceRepository;
  final JournalRepository journalRepository;
  final AgentTemplateService templateService;
  final SoulDocumentService? soulDocumentService;
  @override
  final DomainLogger? domainLogger;

  @override
  LogDomain get errorLogDomain => LogDomain.agentWorkflow;
  final void Function(String agentId)? onPersistedStateChanged;

  /// Captures the wake's project-linked journal entries into the agent's
  /// append-only log (ADR 0020).
  final AgentInputCaptureService? inputCaptureService;

  /// LLM edge for compaction folds (ADR 0017).
  final AgentLogLlmSummarizer? logSummarizer;

  /// Arms the agent's next update slot when its report is still stale and
  /// automatic updates are on (`ProjectUpdateCadence.arm`). Called after a
  /// run, successful or not; arming is inert and idempotent.
  final Future<void> Function(String agentId)? armProjectUpdate;

  /// Compaction watermarks — see `TaskAgentWorkflow` for the rationale.
  final int compactionTailBudgetTokens;
  final int compactionTailRetainTokens;

  static const _uuid = Uuid();

  /// Prompt/context assembly collaborator. Reads from the injected
  /// repositories and builds prompt strings / context objects; the workflow
  /// delegates to it (see the `_build*` / `_resolve*` helpers below).
  late final ProjectAgentContextBuilder _contextBuilder =
      ProjectAgentContextBuilder(
        agentRepository: agentRepository,
        journalRepository: journalRepository,
        logError: logError,
      );

  void _log(String message, {String? subDomain}) {
    domainLogger?.log(
      LogDomain.agentWorkflow,
      message,
      subDomain: subDomain,
    );
  }

  /// Execute a full wake cycle for the given project agent.
  Future<WakeResult> execute({
    required AgentIdentityEntity agentIdentity,
    required String runKey,
    required Set<String> triggerTokens,
    required String threadId,
  }) async {
    try {
      return await executeImpl(
        agentIdentity: agentIdentity,
        runKey: runKey,
        triggerTokens: triggerTokens,
        threadId: threadId,
      );
    } catch (error, stackTrace) {
      return _handleWakeFailure(
        agentIdentity: agentIdentity,
        runKey: runKey,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Arms the next update slot, containing a failure: a missed arm delays
  /// the next update, it must not fail the run that already happened.
  Future<void> _armNextUpdate(String agentId) async {
    final arm = armProjectUpdate;
    if (arm == null) return;
    try {
      await arm(agentId);
    } catch (error, stackTrace) {
      logError(
        'failed to arm the next update slot',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Records one failed attempt; the report stays stale, so the next update
  /// slot retries it — once per slot, within the daily budget, never on every
  /// scheduler scan.
  ///
  /// This is shared by inference failures inside [executeImpl] and setup
  /// failures caught by [execute].
  Future<WakeResult> _handleWakeFailure({
    required AgentIdentityEntity agentIdentity,
    required String runKey,
    required Object error,
    required StackTrace stackTrace,
  }) async {
    logError('wake failed', error: error, stackTrace: stackTrace);

    await finalizeCarrierlessAgentAttribution(
      runKey: runKey,
      logger: this,
      status: AiWorkStatus.failed,
      errorCode: error.runtimeType.toString(),
      errorSummary: error.toString(),
    );

    try {
      final failureAt = clock.now();
      var persistedFailure = false;
      await syncService.runInTransaction(() async {
        final latestState = await agentRepository.getAgentState(
          agentIdentity.agentId,
        );
        if (latestState == null) return;
        await syncService.upsertEntity(
          latestState.copyWith(
            updatedAt: failureAt,
            consecutiveFailureCount: latestState.consecutiveFailureCount + 1,
          ),
        );
        persistedFailure = true;
      });
      if (persistedFailure) {
        onPersistedStateChanged?.call(agentIdentity.agentId);
      }
      await _armNextUpdate(agentIdentity.agentId);
    } catch (stateError, stateStackTrace) {
      logError(
        'failed to update failure count',
        error: stateError,
        stackTrace: stateStackTrace,
      );
    }

    return WakeResult.failed(kind: 'Project agent', error: error);
  }

  Future<void> _persistTokenUsage({
    required InferenceUsage? usage,
    required String agentId,
    required String runKey,
    required String threadId,
    required String modelId,
    required _TemplateContext? templateCtx,
    required DateTime now,
  }) async {
    if (usage == null || !usage.hasData) return;

    try {
      await syncService.upsertEntity(
        AgentDomainEntity.wakeTokenUsage(
          id: _uuid.v4(),
          agentId: agentId,
          runKey: runKey,
          threadId: threadId,
          modelId: modelId,
          templateId: templateCtx?.template.id,
          templateVersionId: templateCtx?.version.id,
          soulDocumentId: templateCtx?.soulVersion?.agentId,
          soulDocumentVersionId: templateCtx?.soulVersion?.id,
          createdAt: now,
          vectorClock: null,
          inputTokens: usage.inputTokens,
          outputTokens: usage.outputTokens,
          thoughtsTokens: usage.thoughtsTokens,
          cachedInputTokens: usage.cachedInputTokens,
        ),
      );
    } catch (e, s) {
      logError('failed to persist token usage', error: e, stackTrace: s);
    }
  }

  Future<_TemplateContext?> _resolveTemplate(String agentId) async {
    final template = await templateService.getTemplateForAgent(agentId);
    if (template == null) return null;

    final version = await templateService.getActiveVersion(template.id);
    if (version == null) return null;

    // Resolve the soul document assigned to this template, if any.
    // Returns null when no soul is assigned — that's the legitimate fallback.
    // Exceptions propagate: a broken soul chain is a real error.
    final soulVersion = await soulDocumentService?.resolveActiveSoulForTemplate(
      template.id,
    );

    return _TemplateContext(
      template: template,
      version: version,
      soulVersion: soulVersion,
    );
  }

  // ── Prompt/context delegators ─────────────────────────────────────────────
  // These forward to [_contextBuilder]; the execute part keeps calling the
  // private helpers it always has.

  String _buildSystemPrompt(_TemplateContext? ctx) =>
      _contextBuilder.buildSystemPrompt(
        version: ctx?.version,
        soulVersion: ctx?.soulVersion,
      );

  ({String text, int? logStart, int? logEnd}) _buildUserMessage({
    required JournalEntity projectEntity,
    required AgentReportEntity? lastReport,
    required List<RecalledObservation> observations,
    required String linkedTasksContext,
    required Set<String> triggerTokens,
    required ProposalLedger ledger,
    String? compactedLog,
  }) => _contextBuilder.buildUserMessage(
    projectEntity: projectEntity,
    lastReport: lastReport,
    observations: observations,
    linkedTasksContext: linkedTasksContext,
    triggerTokens: triggerTokens,
    compactedLog: compactedLog,
    ledger: ledger,
  );

  List<ChatCompletionTool> _buildToolDefinitions({
    required bool hasOpenProposals,
  }) => _contextBuilder.buildToolDefinitions(
    hasOpenProposals: hasOpenProposals,
  );

  /// Reads every proposal this agent has open on [projectId], plus the recent
  /// verdicts, so the wake can list them in the prompt and refuse to write a
  /// duplicate. A failed read is non-fatal: the wake proceeds without the
  /// guard rather than not running at all.
  Future<ProposalLedger> _loadProposalLedger({
    required String agentId,
    required String projectId,
  }) async {
    try {
      return await agentRepository.getProposalLedger(
        agentId,
        taskId: projectId,
      );
    } catch (error, stackTrace) {
      logError(
        'failed to load the proposal ledger',
        error: error,
        stackTrace: stackTrace,
      );
      return const ProposalLedger.empty();
    }
  }

  String? _extractFinalAssistantContent(ConversationManager? manager) =>
      _contextBuilder.extractFinalAssistantContent(manager);

  Future<String> _buildLinkedTasksContext(String projectId) =>
      _contextBuilder.buildLinkedTasksContext(projectId);

  /// Builds a user-readable summary for a deferred tool call.
  static String _buildHumanSummary(
    String toolName,
    Map<String, dynamic> args,
  ) {
    switch (toolName) {
      case ProjectAgentToolNames.updateProjectStatus:
        final status = args['status'] ?? 'unknown';
        return 'Update project status to $status';
      case ProjectAgentToolNames.createTask:
        final title = args['title'] ?? 'untitled';
        return 'Create task: $title';
      default:
        return 'Deferred: $toolName';
    }
  }
}

class _TemplateContext {
  const _TemplateContext({
    required this.template,
    required this.version,
    this.soulVersion,
  });

  final AgentTemplateEntity template;
  final AgentTemplateVersionEntity version;

  /// Active soul version for this template, if a soul is assigned.
  final SoulDocumentVersionEntity? soulVersion;
}
