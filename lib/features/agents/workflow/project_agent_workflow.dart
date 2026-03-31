import 'dart:convert';
import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/model/agent_time_utils.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/project_agent_report_contract.dart';
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/tools/project_tool_definitions.dart';
import 'package:lotti/features/agents/workflow/project_agent_strategy.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';
import 'package:lotti/features/ai/util/profile_resolver.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

/// Assembles context, runs a conversation, and persists results for a single
/// Project Agent wake cycle.
///
/// Standalone class (no base class, following the `ImproverAgentWorkflow`
/// pattern). Fetches the project entity + linked tasks, builds a system prompt
/// with project context, runs the conversation, and persists report,
/// observations, and state updates.
class ProjectAgentWorkflow {
  ProjectAgentWorkflow({
    required this.agentRepository,
    required this.conversationRepository,
    required this.aiConfigRepository,
    required this.cloudInferenceRepository,
    required this.journalRepository,
    required this.syncService,
    required this.templateService,
    this.domainLogger,
  });

  final AgentRepository agentRepository;
  final AgentSyncService syncService;
  final ConversationRepository conversationRepository;
  final AiConfigRepository aiConfigRepository;
  final CloudInferenceRepository cloudInferenceRepository;
  final JournalRepository journalRepository;
  final AgentTemplateService templateService;
  final DomainLogger? domainLogger;

  static const _uuid = Uuid();

  void _log(String message, {String? subDomain}) {
    domainLogger?.log(
      LogDomains.agentWorkflow,
      message,
      subDomain: subDomain,
    );
  }

  void _logError(String message, {Object? error, StackTrace? stackTrace}) {
    if (domainLogger != null) {
      domainLogger!.error(
        LogDomains.agentWorkflow,
        message,
        error: error,
        stackTrace: stackTrace,
      );
    } else {
      developer.log(
        '$message${error != null ? ': $error' : ''}',
        name: 'ProjectAgentWorkflow',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Execute a full wake cycle for the given project agent.
  Future<WakeResult> execute({
    required AgentIdentityEntity agentIdentity,
    required String runKey,
    required Set<String> triggerTokens,
    required String threadId,
  }) async {
    final agentId = agentIdentity.id;

    _log(
      'wake start: agent=${DomainLogger.sanitizeId(agentId)}, '
      'triggers=${triggerTokens.length}',
      subDomain: 'execute',
    );

    // 1. Load current state.
    final loadedState = await agentRepository.getAgentState(agentId);
    if (loadedState == null) {
      _log('no agent state found — aborting wake', subDomain: 'execute');
      return const WakeResult(success: false, error: 'No agent state found');
    }
    var state = loadedState;

    final projectId = state.slots.activeProjectId;
    if (projectId == null) {
      _log('no active project ID — aborting wake', subDomain: 'execute');
      return const WakeResult(
        success: false,
        error: 'No active project ID',
      );
    }

    final now = clock.now();

    // 2. Load the latest report and decide whether a due scheduled wake can be
    // skipped cheaply because no new project activity was recorded.
    final lastReport = await agentRepository.getLatestReport(
      agentId,
      AgentReportScopes.current,
    );
    final initialScheduledWakeWasDue =
        state.scheduledWakeAt != null && !state.scheduledWakeAt!.isAfter(now);
    if (initialScheduledWakeWasDue && lastReport != null) {
      final latestState = await agentRepository.getAgentState(agentId) ?? state;
      final latestScheduledWakeWasDue =
          latestState.scheduledWakeAt != null &&
          !latestState.scheduledWakeAt!.isAfter(now);

      if (!latestScheduledWakeWasDue) {
        _log(
          'scheduled wake already handled elsewhere — skipping duplicate run',
          subDomain: 'execute',
        );
        return const WakeResult(success: true);
      }

      if (latestState.slots.pendingProjectActivityAt == null) {
        await _skipDormantScheduledWake(
          state: latestState,
          now: now,
        );
        return const WakeResult(success: true);
      }

      state = latestState;
    }

    final scheduledWakeWasDue =
        state.scheduledWakeAt != null && !state.scheduledWakeAt!.isAfter(now);
    final shouldInitializeSchedule = state.scheduledWakeAt == null;

    // 3. Load project entity and linked task context.
    final projectEntity = await journalRepository.getJournalEntityById(
      projectId,
    );
    if (projectEntity == null) {
      _log(
        'project not found in journal — aborting wake',
        subDomain: 'execute',
      );
      return const WakeResult(
        success: false,
        error: 'Project not found',
      );
    }

    // 4. Load observations.
    final journalObservations = await agentRepository.getMessagesByKind(
      agentId,
      AgentMessageKind.observation,
    );

    // 5. Resolve template and active version.
    final templateCtx = await _resolveTemplate(agentId);

    // 6. Resolve inference profile → provider.
    final profileResolver = ProfileResolver(
      aiConfigRepository: aiConfigRepository,
    );
    final resolvedProfile = templateCtx != null
        ? await profileResolver.resolve(
            agentConfig: agentIdentity.config,
            template: templateCtx.template,
            version: templateCtx.version,
          )
        : null;
    if (resolvedProfile == null) {
      _log(
        'no provider configured — aborting wake',
        subDomain: 'execute',
      );
      return const WakeResult(
        success: false,
        error: 'No inference provider configured',
      );
    }
    final modelId = resolvedProfile.thinkingModelId;
    final provider = resolvedProfile.thinkingProvider;

    // 6b. Load observation payloads so we can render actual text.
    final observationPayloads = await _resolveObservationPayloads(
      journalObservations,
    );

    // 6c. Load linked tasks and their task-agent reports.
    final linkedTasksContext = await _buildLinkedTasksContext(projectId);

    // 7. Assemble system prompt and user message.
    final systemPrompt = _buildSystemPrompt(templateCtx);
    final userMessage = _buildUserMessage(
      projectEntity: projectEntity,
      lastReport: lastReport,
      observations: journalObservations,
      observationPayloads: observationPayloads,
      linkedTasksContext: linkedTasksContext,
      triggerTokens: triggerTokens,
    );

    // 8. Create conversation and run with strategy.
    final conversationId = conversationRepository.createConversation(
      systemMessage: systemPrompt,
      maxTurns: agentIdentity.config.maxTurnsPerWake,
    );

    // 8a. Persist user message for inspectability.
    try {
      final userPayloadId = _uuid.v4();
      await syncService.upsertEntity(
        AgentDomainEntity.agentMessagePayload(
          id: userPayloadId,
          agentId: agentId,
          createdAt: now,
          vectorClock: null,
          content: <String, Object?>{'text': userMessage},
        ),
      );
      await syncService.upsertEntity(
        AgentDomainEntity.agentMessage(
          id: _uuid.v4(),
          agentId: agentId,
          threadId: threadId,
          kind: AgentMessageKind.user,
          createdAt: now,
          vectorClock: null,
          contentEntryId: userPayloadId,
          metadata: AgentMessageMetadata(runKey: runKey),
        ),
      );
    } catch (e) {
      _logError('failed to persist user message', error: e);
    }

    try {
      final strategy = ProjectAgentStrategy(
        syncService: syncService,
        agentId: agentId,
        threadId: threadId,
        runKey: runKey,
        projectId: projectId,
      );

      final tools = _buildToolDefinitions();
      final inferenceRepo = CloudInferenceWrapper(
        cloudRepository: cloudInferenceRepository,
        isReasoningModel: true,
      );

      // Record template provenance on the wake run log.
      if (templateCtx != null) {
        try {
          await agentRepository.updateWakeRunTemplate(
            runKey,
            templateCtx.template.id,
            templateCtx.version.id,
            resolvedModelId: modelId,
          );
        } catch (e) {
          _logError('failed to record template provenance', error: e);
        }
      }

      // 9. Run the conversation.
      final usage = await conversationRepository.sendMessage(
        conversationId: conversationId,
        message: userMessage,
        model: modelId,
        provider: provider,
        inferenceRepo: inferenceRepo,
        tools: tools,
        temperature: 0.3,
        strategy: strategy,
      );

      // Persist token usage.
      await _persistTokenUsage(
        usage: usage,
        agentId: agentId,
        runKey: runKey,
        threadId: threadId,
        modelId: modelId,
        templateCtx: templateCtx,
        now: now,
      );

      // Capture final assistant response.
      final manager = conversationRepository.getConversation(conversationId);
      final finalContent = _extractFinalAssistantContent(manager);
      strategy.recordFinalResponse(finalContent);

      // 9. Persist all wake outputs.
      final reportContent = strategy.extractReportContent();
      final reportTldr = strategy.extractReportTldr();
      final reportHealthBand = strategy.extractReportHealthBand();
      final reportHealthRationale = strategy.extractReportHealthRationale();
      final reportHealthConfidence = strategy.extractReportHealthConfidence();
      final observations = strategy.extractObservations();
      final deferredItems = strategy.extractDeferredItems();
      await syncService.runInTransaction(() async {
        final latestState =
            await agentRepository.getAgentState(agentId) ?? state;

        // Persist thought.
        final thoughtText = strategy.finalResponse;
        if (thoughtText != null) {
          final thoughtPayloadId = _uuid.v4();
          await syncService.upsertEntity(
            AgentDomainEntity.agentMessagePayload(
              id: thoughtPayloadId,
              agentId: agentId,
              createdAt: now,
              vectorClock: null,
              content: <String, Object?>{'text': thoughtText},
            ),
          );
          await syncService.upsertEntity(
            AgentDomainEntity.agentMessage(
              id: _uuid.v4(),
              agentId: agentId,
              threadId: threadId,
              kind: AgentMessageKind.thought,
              createdAt: now,
              vectorClock: null,
              contentEntryId: thoughtPayloadId,
              metadata: AgentMessageMetadata(runKey: runKey),
            ),
          );
        }

        // Persist report.
        if (reportContent.isNotEmpty) {
          final reportId = _uuid.v4();

          await syncService.upsertEntity(
            AgentDomainEntity.agentReport(
              id: reportId,
              agentId: agentId,
              scope: AgentReportScopes.current,
              createdAt: now,
              vectorClock: null,
              content: reportContent,
              tldr: reportTldr,
              provenance: <String, Object?>{
                ProjectAgentReportProvenanceKeys.healthBand: reportHealthBand,
                ProjectAgentReportProvenanceKeys.healthRationale:
                    reportHealthRationale,
                ...?reportHealthConfidence == null
                    ? null
                    : <String, Object?>{
                        ProjectAgentReportProvenanceKeys.healthConfidence:
                            reportHealthConfidence,
                      },
              },
              threadId: threadId,
            ),
          );

          final existingHead = await agentRepository.getReportHead(
            agentId,
            AgentReportScopes.current,
          );
          final headId = existingHead?.id ?? _uuid.v4();

          await syncService.upsertEntity(
            AgentDomainEntity.agentReportHead(
              id: headId,
              agentId: agentId,
              scope: AgentReportScopes.current,
              reportId: reportId,
              updatedAt: now,
              vectorClock: null,
            ),
          );
        }

        // Persist observations.
        for (final observation in observations) {
          final payloadId = _uuid.v4();
          await syncService.upsertEntity(
            AgentDomainEntity.agentMessagePayload(
              id: payloadId,
              agentId: agentId,
              createdAt: now,
              vectorClock: null,
              content: <String, Object?>{
                'text': observation.text,
                'priority': observation.priority.name,
                'category': observation.category.name,
              },
            ),
          );

          await syncService.upsertEntity(
            AgentDomainEntity.agentMessage(
              id: _uuid.v4(),
              agentId: agentId,
              threadId: threadId,
              kind: AgentMessageKind.observation,
              createdAt: now,
              vectorClock: null,
              contentEntryId: payloadId,
              metadata: AgentMessageMetadata(runKey: runKey),
            ),
          );
        }

        // Persist deferred change set (if any items were accumulated).
        if (deferredItems.isNotEmpty) {
          final changeItems = deferredItems.map((item) {
            final toolName = item['toolName'] as String? ?? '';
            final args = item['args'] as Map<String, dynamic>? ?? {};
            return ChangeItem(
              toolName: toolName,
              args: args,
              humanSummary: _buildHumanSummary(toolName, args),
            );
          }).toList();

          await syncService.upsertEntity(
            AgentDomainEntity.changeSet(
              id: _uuid.v4(),
              agentId: agentId,
              taskId: projectId,
              threadId: threadId,
              runKey: runKey,
              status: ChangeSetStatus.pending,
              items: changeItems,
              createdAt: now,
              vectorClock: null,
            ),
          );
        }

        // Update state.
        final nextScheduledWakeAt =
            scheduledWakeWasDue || shouldInitializeSchedule
            ? nextLocalDayAtTime(
                now,
                hour: AgentSchedules.projectDailyDigestHour,
              )
            : latestState.scheduledWakeAt;
        final latestPendingActivityAt =
            latestState.slots.pendingProjectActivityAt;
        final nextPendingActivityAt =
            latestPendingActivityAt != null &&
                latestPendingActivityAt.isAfter(now)
            ? latestPendingActivityAt
            : null;
        final nextSlots = scheduledWakeWasDue
            ? latestState.slots.copyWith(lastDailyWakeAt: now)
            : latestState.slots;
        await syncService.upsertEntity(
          latestState.copyWith(
            revision: latestState.revision + 1,
            slots: nextSlots.copyWith(
              pendingProjectActivityAt: nextPendingActivityAt,
            ),
            lastWakeAt: now,
            scheduledWakeAt: nextScheduledWakeAt,
            updatedAt: now,
            consecutiveFailureCount: 0,
            wakeCounter: latestState.wakeCounter + 1,
          ),
        );
      });

      _log(
        'wake completed: ${observations.length} observations, '
        '${deferredItems.length} deferred items',
        subDomain: 'execute',
      );

      return const WakeResult(success: true);
    } catch (e, s) {
      _logError('wake failed', error: e, stackTrace: s);

      try {
        await syncService.upsertEntity(
          state.copyWith(
            revision: state.revision + 1,
            updatedAt: now,
            consecutiveFailureCount: state.consecutiveFailureCount + 1,
          ),
        );
      } catch (stateError, s) {
        _logError(
          'failed to update failure count',
          error: stateError,
          stackTrace: s,
        );
      }

      return WakeResult(success: false, error: e.toString());
    } finally {
      conversationRepository.deleteConversation(conversationId);
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<void> _skipDormantScheduledWake({
    required AgentStateEntity state,
    required DateTime now,
  }) async {
    await syncService.runInTransaction(() async {
      await syncService.upsertEntity(
        state.copyWith(
          revision: state.revision + 1,
          lastWakeAt: now,
          scheduledWakeAt: nextLocalDayAtTime(
            now,
            hour: AgentSchedules.projectDailyDigestHour,
          ),
          updatedAt: now,
          consecutiveFailureCount: 0,
          wakeCounter: state.wakeCounter + 1,
        ),
      );
    });

    _log(
      'scheduled wake skipped: no pending project activity',
      subDomain: 'execute',
    );
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
          createdAt: now,
          vectorClock: null,
          inputTokens: usage.inputTokens,
          outputTokens: usage.outputTokens,
          thoughtsTokens: usage.thoughtsTokens,
          cachedInputTokens: usage.cachedInputTokens,
        ),
      );
    } catch (e, s) {
      _logError('failed to persist token usage', error: e, stackTrace: s);
    }
  }

  Future<_TemplateContext?> _resolveTemplate(String agentId) async {
    final template = await templateService.getTemplateForAgent(agentId);
    if (template == null) return null;

    final version = await templateService.getActiveVersion(template.id);
    if (version == null) return null;

    return _TemplateContext(template: template, version: version);
  }

  String _buildSystemPrompt(_TemplateContext? ctx) {
    const scaffold = '''
You are a Project Agent — a persistent assistant that maintains a high-level
report for a project. Your job is to:

1. Monitor the overall health and progress of the project by analyzing linked
   tasks, their statuses, and task agent reports.
2. Identify cross-cutting concerns, blockers, and dependencies between tasks.
3. Publish an updated project report via the `update_project_report` tool.
4. Record observations worth remembering for future wakes.
5. Recommend next steps when appropriate.

## Report

You MUST call `update_project_report` exactly once at the end of every wake
with the updated expanded report body as markdown. Structure the report as
follows:

### Required Sections

1. **📊 Progress Overview** — Summary of task completion rates and overall
   project health.
2. **✅ Recent Achievements** — What was accomplished since the last report.
   Omit if nothing new.
3. **📌 Active Work** — Currently in-progress tasks and their status.
   Omit if no active work.
4. **⚠️ Risks & Blockers** — Issues that could delay the project.
   Omit if none.
5. **📅 Next Steps** — Recommended priorities for the next work cycle.

Do not add a separate markdown headline or repeat the project title above
these sections. The UI already renders the title independently. Do not
repeat the TLDR inside the markdown body; the UI renders it separately from
the `tldr` field.

## Health Assessment

Every `update_project_report` call must also include:

- `tldr`: a concise 1-3 sentence overview shown in the collapsed report view
- `health_band`: one of `surviving`, `on_track`, `watch`, `at_risk`, or
  `blocked`
- `health_rationale`: a short user-facing explanation of why the band fits
  right now
- `health_confidence`: optional number from 0 to 1

You are the source of truth for the user-facing project health band. Do not
treat this as a mechanical task-count rubric. Use your best overall judgment
from the project context, linked task reports, and the latest changes.

## Observations

Use `record_observations` for private notes that should persist across wakes
but are not shown in the user-facing report.

## Deferred Tools

The `recommend_next_steps`, `update_project_status`, and `create_task` tools
are deferred — they queue changes for user review rather than executing
immediately.''';

    if (ctx == null) return scaffold;

    final version = ctx.version;
    final generalDirective = version.generalDirective.trim();
    final reportDirective = version.reportDirective.trim();
    final hasNewDirectives =
        generalDirective.isNotEmpty || reportDirective.isNotEmpty;

    final buf = StringBuffer()..write(scaffold);

    if (hasNewDirectives) {
      if (reportDirective.isNotEmpty) {
        buf
          ..writeln()
          ..writeln()
          ..writeln('## Report Directive')
          ..writeln()
          ..write(reportDirective);
      }

      final effectiveGeneralDirective = generalDirective.isNotEmpty
          ? generalDirective
          : version.directives;
      if (effectiveGeneralDirective.trim().isNotEmpty) {
        buf
          ..writeln()
          ..writeln()
          ..writeln('## Your Personality & Directives')
          ..writeln()
          ..write(effectiveGeneralDirective);
      }
    } else {
      // Legacy fallback: single directives field.
      final legacyDirective = version.directives.trim();
      if (legacyDirective.isNotEmpty) {
        buf
          ..writeln()
          ..writeln()
          ..writeln('## Your Personality & Directives')
          ..writeln()
          ..write(legacyDirective);
      }
    }

    return buf.toString();
  }

  String _buildUserMessage({
    required JournalEntity projectEntity,
    required AgentReportEntity? lastReport,
    required List<AgentMessageEntity> observations,
    required Map<String, AgentMessagePayloadEntity> observationPayloads,
    required String linkedTasksContext,
    required Set<String> triggerTokens,
  }) {
    final buf = StringBuffer()
      ..writeln('## Project Context')
      ..writeln();

    _writeProjectContext(buf, projectEntity);

    if (lastReport != null) {
      buf
        ..writeln()
        ..writeln('## Previous Report')
        ..writeln()
        ..writeln(lastReport.content);
    }

    if (linkedTasksContext != '{}') {
      buf
        ..writeln()
        ..writeln('## Linked Tasks')
        ..writeln()
        ..writeln(linkedTasksContext);
    }

    if (observations.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('## Recent Observations')
        ..writeln();
      for (final obs in observations.take(20)) {
        final payload = obs.contentEntryId != null
            ? observationPayloads[obs.contentEntryId]
            : null;
        final text = _extractPayloadText(payload);
        buf.writeln('- [${obs.createdAt.toIso8601String()}] $text');
      }
    }

    if (triggerTokens.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('## Trigger Tokens')
        ..writeln()
        ..writeln(triggerTokens.join(', '));
    }

    return buf.toString();
  }

  void _writeProjectContext(StringBuffer buf, JournalEntity entity) {
    final project = entity.maybeMap(
      project: (p) => p,
      orElse: () => null,
    );

    if (project == null) {
      buf.writeln('Project entity: $entity');
      return;
    }

    final data = project.data;
    buf
      ..writeln('- **Title**: ${data.title}')
      ..writeln('- **Status**: ${data.status.label}')
      ..writeln(
        '- **Date range**: '
        '${data.dateFrom.toIso8601String().substring(0, 10)} → '
        '${data.dateTo.toIso8601String().substring(0, 10)}',
      );

    if (data.targetDate != null) {
      buf.writeln(
        '- **Target date**: '
        '${data.targetDate!.toIso8601String().substring(0, 10)}',
      );
    }

    final onHoldReason = data.status.maybeMap(
      onHold: (s) => s.reason,
      orElse: () => null,
    );
    if (onHoldReason != null && onHoldReason.isNotEmpty) {
      buf.writeln('- **On-hold reason**: $onHoldReason');
    }

    if (project.entryText?.plainText != null &&
        project.entryText!.plainText.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('### Description')
        ..writeln()
        ..writeln(project.entryText!.plainText);
    }
  }

  List<ChatCompletionTool> _buildToolDefinitions() {
    return projectAgentTools.map((tool) {
      return ChatCompletionTool(
        type: ChatCompletionToolType.function,
        function: FunctionObject(
          name: tool.name,
          description: tool.description,
          parameters: tool.parameters,
        ),
      );
    }).toList();
  }

  String? _extractFinalAssistantContent(ConversationManager? manager) {
    if (manager == null) return null;
    final messages = manager.messages;
    for (var i = messages.length - 1; i >= 0; i--) {
      final msg = messages[i];
      final content = msg.mapOrNull(assistant: (a) => a.content);
      if (content != null && content.isNotEmpty) {
        return content;
      }
    }
    return null;
  }

  // ── Linked-task context ───────────────────────────────────────────────────

  /// Builds a JSON string with linked tasks and their task-agent reports.
  ///
  /// Project links are stored as `project -> task`, so this must resolve the
  /// project's outgoing links. Uses batch queries (2 SQL statements total) for
  /// the agent-link and report lookups to avoid an N+1 pattern when many tasks
  /// are linked to the project.
  Future<String> _buildLinkedTasksContext(String projectId) async {
    try {
      final linkedEntities = await journalRepository.getLinkedEntities(
        linkedTo: projectId,
      );

      final taskEntities = linkedEntities.whereType<Task>().toList();

      if (taskEntities.isEmpty) return '{}';

      final taskIds = taskEntities.map((t) => t.meta.id).toList();

      // 1. Batch-fetch all agent_task links for the linked tasks (1 query).
      var linksByTaskId = <String, List<AgentLink>>{};
      try {
        linksByTaskId = await agentRepository.getLinksToMultiple(
          taskIds,
          type: AgentLinkTypes.agentTask,
        );
      } catch (e, s) {
        _logError('batch link lookup failed', error: e, stackTrace: s);
      }

      // 2. Batch-fetch the latest reports for all linked task agents (1 query).
      var reportsByAgentId = <String, AgentReportEntity>{};
      final linkedAgentIds = linksByTaskId.values
          .expand((links) => links.map((link) => link.fromId))
          .toSet()
          .toList();
      if (linkedAgentIds.isNotEmpty) {
        try {
          reportsByAgentId = await agentRepository.getLatestReportsByAgentIds(
            linkedAgentIds,
            AgentReportScopes.current,
          );
        } catch (e, s) {
          _logError('batch report lookup failed', error: e, stackTrace: s);
        }
      }

      // 3. Assemble rows, preserving the prior fallback behavior:
      // newest link wins only if that agent has a non-empty current report.
      final taskRows = <Map<String, dynamic>>[];
      for (final task in taskEntities) {
        final row = <String, dynamic>{
          'id': task.meta.id,
          'title': task.data.title,
          'status': _taskStatusLabel(task.data.status),
        };

        final taskLinks = linksByTaskId[task.meta.id];
        if (taskLinks != null) {
          for (final link in taskLinks.orderedPrimaryFirst()) {
            final report = reportsByAgentId[link.fromId];
            if (report == null) continue;
            final content = report.content.trim();
            if (content.isEmpty) continue;
            row['taskAgentId'] = link.fromId;
            row['latestTaskAgentReport'] = content;
            row['latestTaskAgentReportCreatedAt'] = report.createdAt
                .toIso8601String();
            break;
          }
        }

        taskRows.add(row);
      }

      return const JsonEncoder.withIndent('    ').convert(<String, dynamic>{
        'linked_tasks': taskRows,
      });
    } catch (e, stackTrace) {
      _logError(
        'failed to build linked tasks context',
        error: e,
        stackTrace: stackTrace,
      );
      return '{}';
    }
  }

  // ── Observation payload resolution ────────────────────────────────────────

  /// Batch-resolves all observation payloads into a map keyed by payload ID.
  Future<Map<String, AgentMessagePayloadEntity>> _resolveObservationPayloads(
    List<AgentMessageEntity> observations,
  ) async {
    final payloadIds = observations
        .map((o) => o.contentEntryId)
        .whereType<String>()
        .toSet();

    final entries = await Future.wait(
      payloadIds.map((id) async {
        try {
          final entity = await agentRepository.getEntity(id);
          if (entity is AgentMessagePayloadEntity) {
            return MapEntry(id, entity);
          }
        } catch (e) {
          // Non-fatal — observation will render with placeholder text.
        }
        return null;
      }),
    );

    return {
      for (final entry
          in entries.whereType<MapEntry<String, AgentMessagePayloadEntity>>())
        entry.key: entry.value,
    };
  }

  /// Extracts the text content from an observation payload.
  static String _extractPayloadText(AgentMessagePayloadEntity? payload) {
    if (payload == null) return '(no content)';
    final text = payload.content['text'];
    if (text is String && text.isNotEmpty) return text;
    return '(no content)';
  }

  static String _taskStatusLabel(TaskStatus status) {
    return switch (status) {
      TaskOpen() => 'open',
      TaskGroomed() => 'groomed',
      TaskInProgress() => 'in_progress',
      TaskBlocked() => 'blocked',
      TaskOnHold() => 'on_hold',
      TaskDone() => 'done',
      TaskRejected() => 'rejected',
    };
  }

  // ── Deferred item helpers ─────────────────────────────────────────────────

  /// Builds a user-readable summary for a deferred tool call.
  static String _buildHumanSummary(
    String toolName,
    Map<String, dynamic> args,
  ) {
    switch (toolName) {
      case ProjectAgentToolNames.recommendNextSteps:
        final steps = args['steps'];
        if (steps is List && steps.isNotEmpty) {
          return 'Recommend ${steps.length} next step(s)';
        }
        return 'Recommend next steps';
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
  const _TemplateContext({required this.template, required this.version});
  final AgentTemplateEntity template;
  final AgentTemplateVersionEntity version;
}
