import 'dart:developer' as developer;

import 'package:clock/clock.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
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
    final state = await agentRepository.getAgentState(agentId);
    if (state == null) {
      _log('no agent state found — aborting wake', subDomain: 'execute');
      return const WakeResult(success: false, error: 'No agent state found');
    }

    final projectId = state.slots.activeProjectId;
    if (projectId == null) {
      _log('no active project ID — aborting wake', subDomain: 'execute');
      return const WakeResult(
        success: false,
        error: 'No active project ID',
      );
    }

    // 2. Load project entity and linked task context.
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

    // 3. Load previous report and observations.
    final lastReport = await agentRepository.getLatestReport(
      agentId,
      AgentReportScopes.current,
    );
    final journalObservations = await agentRepository.getMessagesByKind(
      agentId,
      AgentMessageKind.observation,
    );

    // 4. Resolve template and active version.
    final templateCtx = await _resolveTemplate(agentId);

    // 5. Resolve inference profile → provider.
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

    // 6. Assemble system prompt and user message.
    final systemPrompt = _buildSystemPrompt(templateCtx);
    final userMessage = _buildUserMessage(
      projectEntity: projectEntity,
      lastReport: lastReport,
      observations: journalObservations,
      triggerTokens: triggerTokens,
    );

    // 7. Create conversation and run with strategy.
    final conversationId = conversationRepository.createConversation(
      systemMessage: systemPrompt,
      maxTurns: agentIdentity.config.maxTurnsPerWake,
    );

    final now = clock.now();

    // 7a. Persist user message for inspectability.
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

      // 8. Run the conversation.
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
      final observations = strategy.extractObservations();

      await syncService.runInTransaction(() async {
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

        // Update state.
        await syncService.upsertEntity(
          state.copyWith(
            revision: state.revision + 1,
            lastWakeAt: now,
            updatedAt: now,
            consecutiveFailureCount: 0,
            wakeCounter: state.wakeCounter + 1,
          ),
        );
      });

      _log(
        'wake completed: ${observations.length} observations',
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
with the full updated report as markdown. Structure the report as follows:

### Required Sections

1. **📋 TLDR** — A concise 1-3 sentence overview of the project's current
   state. This is the first and most important section.
2. **📊 Progress Overview** — Summary of task completion rates and overall
   project health.
3. **✅ Recent Achievements** — What was accomplished since the last report.
   Omit if nothing new.
4. **📌 Active Work** — Currently in-progress tasks and their status.
   Omit if no active work.
5. **⚠️ Risks & Blockers** — Issues that could delay the project.
   Omit if none.
6. **📅 Next Steps** — Recommended priorities for the next work cycle.

## Observations

Use `record_observations` for private notes that should persist across wakes
but are not shown in the user-facing report.

## Deferred Tools

The `recommend_next_steps`, `update_project_status`, and `create_task` tools
are deferred — they queue changes for user review rather than executing
immediately.''';

    if (ctx == null) return scaffold;

    final version = ctx.version;
    final directive = version.generalDirective.isNotEmpty
        ? version.generalDirective
        : version.directives;

    if (directive.trim().isEmpty) return scaffold;

    return '$scaffold\n\n## Your Personality & Directives\n\n$directive';
  }

  String _buildUserMessage({
    required JournalEntity projectEntity,
    required AgentReportEntity? lastReport,
    required List<AgentMessageEntity> observations,
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

    if (observations.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('## Recent Observations')
        ..writeln();
      for (final obs in observations.take(20)) {
        buf.writeln('- [${obs.createdAt.toIso8601String()}] ${obs.id}');
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
      ..writeln('- **Status**: ${data.status.toDbString}')
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
}

class _TemplateContext {
  const _TemplateContext({required this.template, required this.version});
  final AgentTemplateEntity template;
  final AgentTemplateVersionEntity version;
}
