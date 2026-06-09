import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/projection/content_digest.dart';
import 'package:lotti/features/agents/projection/decision_events.dart';
import 'package:lotti/features/agents/service/agent_log_llm_summarizer.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/service/attention_claim_maintenance_service.dart';
import 'package:lotti/features/agents/service/change_set_notification_service.dart';
import 'package:lotti/features/agents/service/soul_document_service.dart';
import 'package:lotti/features/agents/service/suggestion_retraction_service.dart';
import 'package:lotti/features/agents/service/task_agent_service.dart';
import 'package:lotti/features/agents/sync/agent_input_capture_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/tools/correction_examples_builder.dart';
import 'package:lotti/features/agents/tools/task_label_handler.dart';
import 'package:lotti/features/agents/workflow/agent_wake_memory.dart';
import 'package:lotti/features/agents/workflow/change_proposal_filter.dart';
import 'package:lotti/features/agents/workflow/change_set_builder.dart';
import 'package:lotti/features/agents/workflow/prompt_record.dart';
import 'package:lotti/features/agents/workflow/task_agent_strategy.dart';
import 'package:lotti/features/agents/workflow/task_source_renderer.dart';
import 'package:lotti/features/agents/workflow/task_tool_dispatcher.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/database/embedding_store.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';
import 'package:lotti/features/ai/repository/ollama_embedding_repository.dart';
import 'package:lotti/features/ai/service/embedding_processor.dart';
import 'package:lotti/features/ai/util/profile_resolver.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/projects/repository/project_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/time_service.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

export 'package:lotti/features/agents/workflow/wake_result.dart';

part 'task_agent_context_builder.dart';
part 'task_agent_persistence_helpers.dart';
part 'task_agent_prompt_builder.dart';
part 'task_agent_user_message_builder.dart';
part 'task_agent_execute.dart';
part 'task_agent_persist_outputs.dart';

/// Assembles context, runs a conversation, and persists results for a single
/// Task Agent wake cycle.
///
/// ## Lifecycle
///
/// 1. Load agent identity, state, current report, and agentJournal observations.
/// 2. Build task context from journal domain via [AiInputRepository].
/// 3. Resolve the agent's template and active version.
/// 4. Resolve an inference profile (or legacy modelId fallback) to a
///    thinking model/provider.
/// 5. Assemble conversation context (system prompt + user message).
/// 6. Create a [ConversationRepository] conversation with tool definitions.
/// 7. Persist the user message as an [AgentMessageKind.user] entity for
///    inspectability (non-fatal if it fails).
/// 8. Invoke the LLM and execute tool calls via [AgentToolExecutor].
/// 9. Persist the final assistant response as a thought message.
/// 10. Extract and persist the updated report (from `update_report` tool call).
/// 11. Persist new observation notes (agentJournal entries).
/// 12. Persist updated agent state (revision, wake counter, failure count).
/// 13. Clean up the in-memory conversation in a `finally` block.
class TaskAgentWorkflow {
  TaskAgentWorkflow({
    required this.agentRepository,
    required this.conversationRepository,
    required this.aiInputRepository,
    required this.aiConfigRepository,
    required this.journalDb,
    required this.cloudInferenceRepository,
    required this.journalRepository,
    required this.checklistRepository,
    required this.labelsRepository,
    required this.syncService,
    required this.templateService,
    this.soulDocumentService,
    this.domainLogger,
    this.embeddingStore,
    this.embeddingRepository,
    this.taskAgentService,
    this.projectRepository,
    this.changeSetNotificationService,
    this.inputCaptureService,
    this.logSummarizer,
    this.compactionTailBudgetTokens = 50000,
    this.compactionTailRetainTokens = 20000,
  });

  final AgentRepository agentRepository;

  /// Sync-aware write service. All entity writes go through this so they
  /// are automatically enqueued for cross-device sync.
  final AgentSyncService syncService;
  final ConversationRepository conversationRepository;
  final AiInputRepository aiInputRepository;
  final AiConfigRepository aiConfigRepository;
  final JournalDb journalDb;
  final CloudInferenceRepository cloudInferenceRepository;
  final JournalRepository journalRepository;
  final ChecklistRepository checklistRepository;
  final LabelsRepository labelsRepository;
  final AgentTemplateService templateService;
  final SoulDocumentService? soulDocumentService;

  /// Optional domain logger for structured, PII-safe logging.
  final DomainLogger? domainLogger;

  /// Optional embedding dependencies. When both are provided, agent reports
  /// are embedded for vector search after persistence. The pipeline is
  /// non-essential — if unavailable, reports are still persisted normally.
  final EmbeddingStore? embeddingStore;
  final OllamaEmbeddingRepository? embeddingRepository;

  /// Optional task agent service for auto-assigning agents to follow-up tasks.
  final TaskAgentService? taskAgentService;

  /// Optional project repository for inheriting projects on follow-up tasks.
  final ProjectRepository? projectRepository;

  /// Optional bridge that keeps task-suggestion notifications aligned with
  /// agent change-set resolution.
  final ChangeSetNotificationService? changeSetNotificationService;

  /// Optional input-capture service (ADR 0020). When present, each wake
  /// snapshots the user-content sources it read (per-source, content-addressed)
  /// into the append-only log, so the agent's inputs become a projection of the
  /// log rather than a live journal read. Null disables capture (unit tests
  /// that don't exercise it); production wires it in `agent_workflow_providers`.
  final AgentInputCaptureService? inputCaptureService;

  /// Optional LLM summarizer used by compaction to distill folded input
  /// sources (ADR 0017), invoked with the wake's resolved model/provider.
  /// Required to actually emit summaries; null leaves emission inert while
  /// reads still assemble the captured event tail.
  final AgentLogLlmSummarizer? logSummarizer;

  /// Token budget for the verbatim uncovered tail before compaction folds its
  /// oldest entries (ADR 0017). This is the *trigger* (high watermark): no
  /// summarization happens while the tail fits it.
  ///
  /// Sized generously (50k) because the tail is append-only and therefore
  /// prefix-cached: warm wakes pay cache-read rates (or, on local inference
  /// with a persistent KV cache, nothing) for the history. The remaining real
  /// costs are the cold prefill on the first wake of a session and attention
  /// quality on very long raw logs — which is why the fold still exists at
  /// all rather than the tail growing without bound. Deployments on
  /// small-context/local models can pass tighter values here.
  final int compactionTailBudgetTokens;

  /// Low watermark for the fold (hysteresis): once
  /// [compactionTailBudgetTokens] is exceeded, the tail is folded down so only
  /// this many tokens of the most recent verbatim entries remain — leaving
  /// `budget - retain` tokens of headroom before the next summarization. Keeps
  /// the summarizer infrequent (one fold per ~30k tokens of NEW activity at
  /// the defaults) and the prompt's summary block stable between folds
  /// (prefix-cache friendly).
  final int compactionTailRetainTokens;

  /// How many resolved proposal verdicts the wake projects into the event
  /// substrate (and the legacy ledger view). Sized far above any realistic
  /// per-task verdict count — each one is a human confirmation click — and
  /// saturation is logged loudly rather than silently truncating.
  static const resolvedDecisionWindow = 500;

  static const _uuid = Uuid();

  void _log(String message, {String? subDomain}) {
    domainLogger?.log(
      LogDomain.agentWorkflow,
      message,
      subDomain: subDomain,
    );
  }

  void _logError(String message, {Object? error, StackTrace? stackTrace}) {
    if (domainLogger != null) {
      domainLogger!.error(
        LogDomain.agentWorkflow,
        error ?? message,
        message: error != null ? message : null,
        stackTrace: stackTrace,
      );
    } else {
      developer.log(
        '$message${error != null ? ' (errorType=${error.runtimeType})' : ''}',
        name: 'TaskAgentWorkflow',
        error: error?.runtimeType,
        stackTrace: stackTrace,
      );
    }
  }

  /// Execute a full wake cycle for the given agent.
  ///
  /// [agentIdentity] is the agent's identity entity.
  /// [runKey] is the deterministic run key for this wake cycle.
  /// [triggerTokens] is the set of entity IDs that triggered this wake.
  /// [threadId] is the conversation thread ID for this wake.
  ///
  /// Returns the set of mutated entity IDs and their vector clocks, for
  /// self-notification suppression by the orchestrator.
  Future<WakeResult> execute({
    required AgentIdentityEntity agentIdentity,
    required String runKey,
    required Set<String> triggerTokens,
    required String threadId,
  }) => executeImpl(
    agentIdentity: agentIdentity,
    runKey: runKey,
    triggerTokens: triggerTokens,
    threadId: threadId,
  );

  // ── Private helpers ──────────────────────────────────────────────────────

  /// Issues a second, forced inference pass to recover a missing report.
  ///
  /// Weaker local models (e.g. Qwen 3.6 via `mlx-vlm`) routinely stop
  /// generating before emitting the mandatory `update_report` tool call,
  /// which leaves the UI with nothing to display. This helper is invoked
  /// when the main wake loop returns without a published report: it sends
  /// one more `sendMessage` with `toolChoice` pinned to `update_report`
  /// and a blunt reminder message. On OpenAI-compatible endpoints this
  /// guarantees a final tool call; on providers that silently ignore
  /// `toolChoice` (Gemini / Ollama / Mistral sub-repos) the directive
  /// message alone still nudges most models into compliance.
  ///
  /// The tool list is restricted to only the report tool — the forced
  /// `toolChoice` is defense in depth, but on providers that drop the
  /// option the model would otherwise see the full tool surface again and
  /// could issue a duplicate metadata or checklist call. Narrowing the
  /// list guarantees that even a misbehaving provider can only emit the
  /// tool we actually want.
  ///
  /// Any failure inside the retry (network error, parser error on a
  /// truncated response, etc.) is caught and logged — the wake must still
  /// persist observations and metadata work collected in the main pass.
  ///
  /// Returns the retry's token usage (if any) so the caller can merge it
  /// into the wake's accumulated total.
  Future<InferenceUsage?> _forceUpdateReportIfMissing({
    required String conversationId,
    required String modelId,
    required AiConfigInferenceProvider provider,
    required CloudInferenceWrapper inferenceRepo,
    required List<ChatCompletionTool> tools,
    required TaskAgentStrategy strategy,
  }) async {
    _log(
      'no report published — retrying with forced update_report',
      subDomain: 'execute',
    );
    const forcedToolChoice = ChatCompletionToolChoiceOption.tool(
      ChatCompletionNamedToolChoice(
        type: ChatCompletionNamedToolChoiceType.function,
        function: ChatCompletionFunctionCallOption(
          name: TaskAgentStrategy.reportToolName,
        ),
      ),
    );
    final reportOnlyTools = tools
        .where((tool) => tool.function.name == TaskAgentStrategy.reportToolName)
        .toList(growable: false);

    try {
      return await conversationRepository.sendMessage(
        conversationId: conversationId,
        message:
            'You did not call `update_report` before stopping. Call it '
            'now. You MUST supply a concise `oneLiner`, a 1-3 sentence '
            '`tldr`, and the full markdown `content`. This is the final '
            'step of the wake and is mandatory — do not respond with '
            'anything else.',
        model: modelId,
        provider: provider,
        inferenceRepo: inferenceRepo,
        tools: reportOnlyTools,
        toolChoice: forcedToolChoice,
        temperature: 0.3,
        strategy: strategy,
      );
    } catch (e, s) {
      _logError(
        'forced update_report retry failed — persisting partial wake',
        error: e,
        stackTrace: s,
      );
      return null;
    }
  }

  /// Resolves the template and its active version for the given [agentId].
  ///
  /// Returns `null` if no template is assigned or if the active version
  /// cannot be resolved.
  Future<_TemplateContext?> _resolveTemplate(String agentId) async {
    final template = await templateService.getTemplateForAgent(agentId);
    if (template == null) {
      _log('no template assigned', subDomain: 'resolve');
      return null;
    }

    final version = await templateService.getActiveVersion(template.id);
    if (version == null) {
      _log('no active version for template', subDomain: 'resolve');
      return null;
    }

    // Resolve the soul document assigned to this template, if any.
    // Returns null when no soul is assigned — that's the legitimate fallback.
    // Exceptions propagate: a broken soul chain is a real error.
    final soulVersion = await soulDocumentService?.resolveActiveSoulForTemplate(
      template.id,
    );
    if (soulVersion != null) {
      _log(
        'resolved soul v${soulVersion.version} for template',
        subDomain: 'resolve',
      );
    }

    return _TemplateContext(
      template: template,
      version: version,
      soulVersion: soulVersion,
    );
  }

  /// Extracts the text content from an observation payload.
  static String _extractPayloadText(AgentMessagePayloadEntity? payload) {
    if (payload == null) return '(no content)';
    final text = payload.content['text'];
    if (text is String && text.isNotEmpty) return text;
    return '(no content)';
  }

  /// Writes a dedicated section for prior critical observations so the
  /// task agent can self-correct on grievances and reinforce excellence.
  static void _writePriorCriticalObservations(
    StringBuffer buffer,
    List<AgentMessageEntity> observations,
    Map<String, AgentMessagePayloadEntity> payloads,
  ) {
    final grievances = <(DateTime, String)>[];
    final excellence = <(DateTime, String)>[];

    for (final obs in observations) {
      final payload = obs.contentEntryId != null
          ? payloads[obs.contentEntryId]
          : null;
      if (payload == null) continue;

      final rawPriority = payload.content['priority'];
      final priority = rawPriority is String
          ? parseEnumByName(ObservationPriority.values, rawPriority)
          : null;
      if (priority != ObservationPriority.critical) continue;

      final text = payload.content['text'];
      if (text is! String || text.trim().isEmpty) continue;

      final rawCategory = payload.content['category'];
      final category = rawCategory is String
          ? parseEnumByName(ObservationCategory.values, rawCategory)
          : null;
      if (category == ObservationCategory.excellence) {
        excellence.add((obs.createdAt, text));
      } else {
        // grievance, template_improvement, or unrecognized critical
        grievances.add((obs.createdAt, text));
      }
    }

    if (grievances.isEmpty && excellence.isEmpty) return;

    buffer
      ..writeln('## Prior Critical Observations (Self-Review)')
      ..writeln(
        'The following critical observations were recorded in your previous '
        'wakes. Review them and adjust your behavior accordingly.',
      )
      ..writeln();

    if (grievances.isNotEmpty) {
      buffer.writeln('### Grievances');
      for (final (timestamp, text) in grievances) {
        buffer.writeln('- [${timestamp.toIso8601String()}] $text');
      }
      buffer.writeln();
    }

    if (excellence.isNotEmpty) {
      buffer.writeln('### Excellence (keep doing this)');
      for (final (timestamp, text) in excellence) {
        buffer.writeln('- [${timestamp.toIso8601String()}] $text');
      }
      buffer.writeln();
    }
  }
}

class _LinkedTaskAgentReport {
  const _LinkedTaskAgentReport({
    required this.agentId,
    required this.oneLiner,
    required this.tldr,
    required this.createdAt,
  });

  final String agentId;
  final String? oneLiner;
  final String? tldr;
  final DateTime createdAt;
}

/// Resolved template and version pair for prompt composition.
class _TemplateContext {
  _TemplateContext({
    required this.template,
    required this.version,
    this.soulVersion,
  });

  final AgentTemplateEntity template;
  final AgentTemplateVersionEntity version;

  /// Active soul version for this template, if a soul is assigned.
  final SoulDocumentVersionEntity? soulVersion;
}
