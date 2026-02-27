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
import 'package:lotti/features/agents/service/agent_template_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/tools/correction_examples_builder.dart';
import 'package:lotti/features/agents/tools/task_label_handler.dart';
import 'package:lotti/features/agents/util/inference_provider_resolver.dart';
import 'package:lotti/features/agents/workflow/task_agent_strategy.dart';
import 'package:lotti/features/agents/workflow/task_tool_dispatcher.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

export 'package:lotti/features/agents/workflow/wake_result.dart';

/// Assembles context, runs a conversation, and persists results for a single
/// Task Agent wake cycle.
///
/// ## Lifecycle
///
/// 1. Load agent identity, state, current report, and agentJournal observations.
/// 2. Build task context from journal domain via [AiInputRepository].
/// 3. Resolve a Gemini inference provider from the AI config database.
/// 4. Assemble conversation context (system prompt + user message).
/// 5. Create a [ConversationRepository] conversation with tool definitions.
/// 6. Persist the user message as an [AgentMessageKind.user] entity for
///    inspectability (non-fatal if it fails).
/// 7. Invoke the LLM and execute tool calls via [AgentToolExecutor].
/// 8. Persist the final assistant response as a thought message.
/// 9. Extract and persist the updated report (from `update_report` tool call).
/// 10. Persist new observation notes (agentJournal entries).
/// 11. Persist updated agent state (revision, wake counter, failure count).
/// 12. Clean up the in-memory conversation in a `finally` block.
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

  static const _uuid = Uuid();

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
  }) async {
    final agentId = agentIdentity.id;

    developer.log(
      'Starting wake for agent $agentId (runKey: $runKey, '
      'triggers: ${triggerTokens.length})',
      name: 'TaskAgentWorkflow',
    );

    // 1. Load current state + both memory types.
    final state = await agentRepository.getAgentState(agentId);
    if (state == null) {
      developer.log(
        'No agent state found for $agentId — aborting wake',
        name: 'TaskAgentWorkflow',
      );
      return const WakeResult(success: false, error: 'No agent state found');
    }

    final taskId = state.slots.activeTaskId;
    if (taskId == null) {
      developer.log(
        'No active task ID in agent state for $agentId — aborting wake',
        name: 'TaskAgentWorkflow',
      );
      return const WakeResult(success: false, error: 'No active task ID');
    }

    final lastReport = await agentRepository.getLatestReport(
      agentId,
      AgentReportScopes.current,
    );
    final journalObservations = await agentRepository.getMessagesByKind(
      agentId,
      AgentMessageKind.observation,
    );

    // 2. Build task context from journal domain.
    final taskDetailsJson =
        await aiInputRepository.buildTaskDetailsJson(id: taskId);
    final linkedTasksJson = await _buildLinkedTasksContextJson(taskId);

    if (taskDetailsJson == null) {
      developer.log(
        'Task $taskId not found in journal — aborting wake',
        name: 'TaskAgentWorkflow',
      );
      return const WakeResult(success: false, error: 'Task not found');
    }

    // 3. Resolve the agent's template and active version.
    final templateCtx = await _resolveTemplate(agentId);
    if (templateCtx == null) {
      developer.log(
        'No template assigned to agent $agentId — aborting wake',
        name: 'TaskAgentWorkflow',
      );
      return const WakeResult(
        success: false,
        error: 'No template assigned to agent',
      );
    }

    // 4. Resolve a Gemini inference provider from the template version.
    final modelId = templateCtx.version.modelId ?? templateCtx.template.modelId;
    final provider = await resolveInferenceProvider(
      modelId: modelId,
      aiConfigRepository: aiConfigRepository,
      logTag: 'TaskAgentWorkflow',
    );
    if (provider == null) {
      developer.log(
        'No Gemini provider configured for model $modelId — aborting wake',
        name: 'TaskAgentWorkflow',
      );
      return const WakeResult(
        success: false,
        error: 'No Gemini provider configured',
      );
    }

    // 5. Assemble conversation context.
    final systemPrompt = _buildSystemPrompt(templateCtx);
    final userMessage = await _buildUserMessage(
      lastReport: lastReport,
      journalObservations: journalObservations,
      taskDetailsJson: taskDetailsJson,
      linkedTasksJson: linkedTasksJson,
      triggerTokens: triggerTokens,
      taskId: taskId,
    );

    // 6. Create conversation and run with strategy.
    final conversationId = conversationRepository.createConversation(
      systemMessage: systemPrompt,
      maxTurns: agentIdentity.config.maxTurnsPerWake,
    );

    // Capture timestamp once for all persistence in this wake (both success
    // and failure paths) so causality tracking is consistent.
    final now = clock.now();

    // 6a. Persist the user message for inspectability before sending to LLM.
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
      developer.log(
        'Failed to persist user message for agent $agentId',
        name: 'TaskAgentWorkflow',
        error: e,
      );
      // Non-fatal: continue with execution even if audit fails.
    }

    try {
      final executor = AgentToolExecutor(
        syncService: syncService,
        allowedCategoryIds: agentIdentity.allowedCategoryIds,
        runKey: runKey,
        agentId: agentId,
        threadId: threadId,
      );

      final toolDispatcher = TaskToolDispatcher(
        journalDb: journalDb,
        journalRepository: journalRepository,
        checklistRepository: checklistRepository,
        labelsRepository: labelsRepository,
      );

      final strategy = TaskAgentStrategy(
        executor: executor,
        syncService: syncService,
        agentId: agentId,
        threadId: threadId,
        runKey: runKey,
        taskId: taskId,
        resolveCategoryId: (entityId) async {
          final entity = await journalDb.journalEntityById(entityId);
          return entity?.categoryId;
        },
        readVectorClock: (entityId) async {
          final entity = await journalDb.journalEntityById(entityId);
          return entity?.meta.vectorClock;
        },
        executeToolHandler: (toolName, args, manager) =>
            toolDispatcher.dispatch(toolName, args, taskId),
      );

      final tools = _buildToolDefinitions();
      final inferenceRepo = CloudInferenceWrapper(
        cloudRepository: cloudInferenceRepository,
      );

      // Record template provenance on the wake run log entry.
      try {
        await agentRepository.updateWakeRunTemplate(
          runKey,
          templateCtx.template.id,
          templateCtx.version.id,
        );
      } catch (e) {
        developer.log(
          'Failed to record template provenance for run $runKey: $e',
          name: 'TaskAgentWorkflow',
        );
        // Non-fatal: the wake can proceed without provenance tracking.
      }

      // 7. Invoke the LLM and execute tool calls via AgentToolExecutor.
      await conversationRepository.sendMessage(
        conversationId: conversationId,
        message: userMessage,
        model: modelId,
        provider: provider,
        inferenceRepo: inferenceRepo,
        tools: tools,
        temperature: 0.3,
        strategy: strategy,
      );

      // Capture the final assistant response from the conversation manager.
      final manager = conversationRepository.getConversation(conversationId);
      final finalContent = _extractFinalAssistantContent(manager);
      strategy.recordFinalResponse(finalContent);

      // 7–11. Persist all wake outputs atomically. Wrapping in a transaction
      // ensures the state revision is only bumped if all outputs (thought,
      // report, observations) are successfully written.
      final reportContent = strategy.extractReportContent();
      if (reportContent.isEmpty) {
        developer.log(
          'Agent $agentId did not publish a report during this wake '
          '(runKey: $runKey). This violates the "must call update_report" '
          'contract.',
          name: 'TaskAgentWorkflow',
        );
      }

      final observations = strategy.extractObservations();

      await syncService.runInTransaction(() async {
        // 8. Persist the final assistant response as a thought message.
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

        // 9. Extract and persist updated report (from update_report tool call).
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
              threadId: threadId,
            ),
          );

          // Update the report head pointer.
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

        // 10. Persist new observation notes (agentJournal entries).
        for (final note in observations) {
          final payloadId = _uuid.v4();
          await syncService.upsertEntity(
            AgentDomainEntity.agentMessagePayload(
              id: payloadId,
              agentId: agentId,
              createdAt: now,
              vectorClock: null,
              content: <String, Object?>{'text': note},
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

        // 11. Persist state.
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

      developer.log(
        'Wake completed for agent $agentId: '
        '${observations.length} observations, '
        '${executor.mutatedEntries.length} mutations',
        name: 'TaskAgentWorkflow',
      );

      return WakeResult(
        success: true,
        mutatedEntries: executor.mutatedEntries,
      );
    } catch (e, s) {
      developer.log(
        'Wake failed for agent $agentId',
        name: 'TaskAgentWorkflow',
        error: e,
        stackTrace: s,
      );

      // Update failure count in state.
      try {
        await syncService.upsertEntity(
          state.copyWith(
            revision: state.revision + 1,
            updatedAt: now,
            consecutiveFailureCount: state.consecutiveFailureCount + 1,
          ),
        );
      } catch (stateError) {
        developer.log(
          'Failed to update failure count for agent $agentId',
          name: 'TaskAgentWorkflow',
          error: stateError,
        );
      }

      return WakeResult(success: false, error: e.toString());
    } finally {
      // 12. Clean up in-memory conversation to prevent resource leaks.
      conversationRepository.deleteConversation(conversationId);
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  /// Resolves the template and its active version for the given [agentId].
  ///
  /// Returns `null` if no template is assigned or if the active version
  /// cannot be resolved.
  Future<_TemplateContext?> _resolveTemplate(String agentId) async {
    final template = await templateService.getTemplateForAgent(agentId);
    if (template == null) {
      developer.log(
        'No template assigned to agent $agentId',
        name: 'TaskAgentWorkflow',
      );
      return null;
    }

    final version = await templateService.getActiveVersion(template.id);
    if (version == null) {
      developer.log(
        'No active version for template ${template.id}',
        name: 'TaskAgentWorkflow',
      );
      return null;
    }

    return _TemplateContext(template: template, version: version);
  }

  /// Builds the full system prompt by appending the template's directives
  /// to the rigid scaffold.
  String _buildSystemPrompt(_TemplateContext ctx) {
    return '$taskAgentScaffold\n\n'
        '## Your Personality & Directives\n\n'
        '${ctx.version.directives}';
  }

  /// The rigid scaffold of the Task Agent system prompt.
  ///
  /// Contains role description, report format, tool usage guidelines, and
  /// important constraints. Template-specific directives are appended after
  /// this scaffold.
  static const taskAgentScaffold = '''
You are a Task Agent — a persistent assistant that maintains a summary report
for a single task. Your job is to:

1. Analyze the current task state and any changes since your last wake.
2. Call tools when appropriate to update task metadata (estimates, due dates,
   priorities, checklist items, title, labels).
3. Publish an updated report via the `update_report` tool.
4. Record observations worth remembering for future wakes.

## Report

You MUST call `update_report` exactly once at the end of every wake with the
full updated report as markdown. The report must follow this standardized
structure with emojis for visual consistency:

### Required Sections

1. **📋 TLDR** — A concise 1-3 sentence overview of the task's current state.
   This is the first and most important section — it is what the user sees in
   the collapsed view.
2. **✅ Achieved** — What has been accomplished (bulleted list). Omit if
   nothing has been achieved yet.
3. **📌 What is left to do** — Remaining work items (bulleted list). Omit if
   the task is complete.
4. **💡 Learnings** — Key insights, patterns, or decisions worth surfacing to
   the user. Omit if there are no noteworthy learnings.

Do NOT include a title line (H1) or a status bar — these are already shown in
the task header UI. Do NOT include a "Goal / Context" section — this is
redundant with the task description.

You MAY add additional sections if they add value (e.g., ⚠️ Blockers,
📊 Metrics), but the core sections above should always be present when
applicable.

### Example report:

```
## 📋 TLDR
OAuth2 integration is 60% complete. Login UI is done, logout flow and
integration tests remain.

## ✅ Achieved
- Set up OAuth provider configuration
- Implemented token refresh logic
- Built login UI with error handling

## 📌 What is left to do
- Add logout flow with token revocation
- Write integration tests for auth endpoints

## 💡 Learnings
- Token refresh needs a 30s buffer before expiry to avoid race conditions
- Error handling for expired sessions requires a dedicated middleware
```

### Writing style
- Write in the task's detected language (match the language of the task
  content). If the task content is in German, write the report in German.
- Express your personality and voice as defined in your directives.
- Keep the report user-facing. No meta-commentary about being an agent.
- Use present tense for current state, past tense for completed work.

## Report vs Observations — Separation of Concerns

The report (`update_report`) is the PUBLIC, user-facing summary. It should contain:
- Task status, progress, and key metrics
- What was achieved and what remains
- Any deadlines or priorities

The report MUST NOT contain:
- Internal reasoning or decision logs
- "I noticed..." or "I decided to..." commentary
- Debugging notes, failure analysis, or retry logs
- Agent self-reflection or meta-commentary

Use `record_observations` for ALL internal notes. Observations are private
and never shown to the user. They persist as your memory across wakes.

## Tool Usage Guidelines

- **No-op rule**: Before calling ANY metadata tool (status, priority, due date,
  estimate, language, labels), check the current value in the task context. If
  the value is already what you would set, do NOT call the tool. Every
  unnecessary tool call wastes a turn and clutters the audit log.
- Only call tools when you have sufficient confidence in the change.
- Do not call tools speculatively or redundantly.
- When a tool call fails, note the failure in observations and move on.
- Each tool call is audited and must stay within the task's category scope.
- **Observations**: Record private notes worth remembering for future wakes.
  Good observations include:
  - Why you transitioned a status (e.g., "Set BLOCKED because user mentioned
    waiting for API credentials in note from 2026-02-25")
  - Rationale behind metadata changes (priority shifts, estimate adjustments,
    due date changes)
  - Time-vs-progress analysis (e.g., "12h logged over 3 days but only 2 of 8
    checklist items completed; may need scope review")
  - Decisions between alternatives you considered
  - Blockers or scope changes not obvious from individual tool calls
  Skip routine progress that the report already captures.
  Do NOT embed observations in the report text — always use the tool.
- **Title**: Only set the title when the task has no title yet. Do not
  change an existing title unless the user explicitly asks for it.
- **Estimates**: Only set or update an estimate when the user explicitly
  requests it, or when no estimate exists and you have high confidence.
  Do not retroactively adjust estimates based on time already spent
  unless specifically asked to do so.
- **Status**: Do NOT call `set_task_status` if the task is already at the
  target status. Only transition when there is clear evidence of a change:
  - Set "IN PROGRESS" when time is being logged on the task (especially
    combined with checklist items being checked off).
  - Set "BLOCKED" when the user mentions a blocker (always provide a reason).
  - Set "ON HOLD" when work is intentionally paused (always provide a reason).
  - DONE and REJECTED are user-only — never set these.
  - Do NOT set status speculatively or based on assumptions.
- **Language**: If the task has no language set (languageCode is null), detect
  the language from the task content and set it. Always do this on the first
  wake.
- **Labels**: If the task has fewer than 3 labels, assign relevant labels from
  the available list. Order by confidence (highest first), omit low confidence,
  cap at 3 per call. Never propose suppressed labels.

## Important

- You observe journal-domain data but do not own it.
- Your report and observations are your persistent memory across wakes.
- Be concise. Focus on what changed and what matters.
''';

  /// Builds the user message for a wake cycle.
  Future<String> _buildUserMessage({
    required AgentReportEntity? lastReport,
    required List<AgentMessageEntity> journalObservations,
    required String taskDetailsJson,
    required String linkedTasksJson,
    required Set<String> triggerTokens,
    required String taskId,
  }) async {
    final buffer = StringBuffer();

    if (lastReport != null && lastReport.content.isNotEmpty) {
      buffer
        ..writeln('## Current Report')
        ..writeln(lastReport.content)
        ..writeln();
    } else {
      buffer
        ..writeln(
          '## First Wake — No prior report exists. '
          'Produce an initial report.',
        )
        ..writeln();
    }

    if (journalObservations.isNotEmpty) {
      buffer.writeln('## Agent Journal');
      // Cap to most recent 20 to prevent unbounded context growth.
      // journalObservations is ordered newest-first from the DB query;
      // reverse so the LLM sees them in chronological order.
      final recentObs = (journalObservations.length > 20
              ? journalObservations.sublist(0, 20)
              : journalObservations)
          .reversed
          .toList();

      // Batch-resolve all observation texts in parallel to avoid N+1 queries.
      final texts = await Future.wait(
        recentObs.map(_resolveObservationText),
      );

      for (var i = 0; i < recentObs.length; i++) {
        buffer.writeln(
          '- [${recentObs[i].createdAt.toIso8601String()}] ${texts[i]}',
        );
      }
      buffer.writeln();
    }

    buffer
      ..writeln('## Current Task Context')
      ..writeln('```json')
      ..writeln(taskDetailsJson)
      ..writeln('```')
      ..writeln();

    if (linkedTasksJson.isNotEmpty && linkedTasksJson != '{}') {
      buffer
        ..writeln('## Linked Tasks')
        ..writeln('```json')
        ..writeln(linkedTasksJson)
        ..writeln('```')
        ..writeln();
    }

    // Inject label context and correction examples.
    try {
      final taskEntity = await journalDb.journalEntityById(taskId);
      if (taskEntity is Task) {
        // Label context for the assign_task_labels tool.
        final labelContext = await TaskLabelHandler.buildLabelContext(
          task: taskEntity,
          journalDb: journalDb,
        );
        if (labelContext.isNotEmpty) {
          buffer.write(labelContext);
        }

        // Correction examples for checklist item title accuracy.
        final correctionContext = await CorrectionExamplesBuilder.buildContext(
          task: taskEntity,
          journalDb: journalDb,
        );
        if (correctionContext.isNotEmpty) {
          buffer.write(correctionContext);
        }
      }
    } catch (e) {
      developer.log(
        'Failed to build label/correction context: $e',
        name: 'TaskAgentWorkflow',
      );
      // Non-fatal: continue without context.
    }

    if (triggerTokens.isNotEmpty) {
      buffer
        ..writeln('## Changed Since Last Wake')
        ..writeln(
          'The following entity IDs changed: ${triggerTokens.join(", ")}',
        )
        ..writeln();
    }

    buffer.writeln(
      'Analyze the current state, call tools if needed, then call '
      '`update_report` with the full updated report. '
      'Add observations if warranted.',
    );

    return buffer.toString();
  }

  /// Builds linked-task context JSON for the wake prompt.
  ///
  /// Forked from [AiInputRepository.buildLinkedTasksJson] for the task-agent
  /// wake path:
  /// 1. Builds linked task context directly from linked task entities.
  /// 2. Removes legacy `latestSummary` fields.
  /// 3. Injects the latest task-agent report for each linked task when present.
  ///
  /// This keeps prompt context aligned with the Agent Capabilities architecture
  /// where task summaries are being phased out in favor of task-agent reports.
  Future<String> _buildLinkedTasksContextJson(String taskId) async {
    try {
      final linkedFrom = await aiInputRepository.buildLinkedFromContext(taskId);
      final linkedTo = await aiInputRepository.buildLinkedToContext(taskId);

      final linkedFromRows = linkedFrom
          .map((context) => Map<String, dynamic>.from(context.toJson()))
          .toList();
      final linkedToRows = linkedTo
          .map((context) => Map<String, dynamic>.from(context.toJson()))
          .toList();
      final allRows = [...linkedFromRows, ...linkedToRows];

      if (allRows.isEmpty) {
        return '{}';
      }

      for (final row in allRows) {
        row.remove('latestSummary');
      }

      final taskIds = allRows
          .map((row) => row['id'])
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();

      final reportByTaskId = <String, _LinkedTaskAgentReport?>{};
      await Future.wait(
        taskIds.map((id) async {
          reportByTaskId[id] = await _resolveLatestTaskAgentReport(id);
        }),
      );

      for (final row in allRows) {
        final linkedTaskId = row['id'];
        if (linkedTaskId is! String || linkedTaskId.isEmpty) {
          continue;
        }

        final linkedReport = reportByTaskId[linkedTaskId];
        if (linkedReport == null) {
          continue;
        }

        row['taskAgentId'] = linkedReport.agentId;
        row['latestTaskAgentReport'] = linkedReport.content;
        row['latestTaskAgentReportCreatedAt'] =
            linkedReport.createdAt.toIso8601String();
      }

      return const JsonEncoder.withIndent('    ').convert(<String, dynamic>{
        'linked_from': linkedFromRows,
        'linked_to': linkedToRows,
      });
    } catch (e, stackTrace) {
      developer.log(
        'Failed to build linked tasks context for task $taskId: $e',
        name: 'TaskAgentWorkflow',
        error: e,
        stackTrace: stackTrace,
      );
      return '{}';
    }
  }

  Future<_LinkedTaskAgentReport?> _resolveLatestTaskAgentReport(
    String linkedTaskId,
  ) async {
    try {
      final links = await agentRepository.getLinksTo(
        linkedTaskId,
        type: AgentLinkTypes.agentTask,
      );
      if (links.isEmpty) {
        return null;
      }

      final sortedLinks = links.toList()
        ..sort((a, b) {
          final byCreatedAt = b.createdAt.compareTo(a.createdAt);
          if (byCreatedAt != 0) return byCreatedAt;
          return b.id.compareTo(a.id);
        });

      for (final link in sortedLinks) {
        final report = await agentRepository.getLatestReport(
          link.fromId,
          AgentReportScopes.current,
        );
        if (report == null) {
          continue;
        }
        final content = report.content.trim();
        if (content.isEmpty) {
          continue;
        }
        return _LinkedTaskAgentReport(
          agentId: link.fromId,
          content: content,
          createdAt: report.createdAt,
        );
      }
      return null;
    } catch (e) {
      developer.log(
        'Failed to resolve linked task-agent report for task $linkedTaskId: $e',
        name: 'TaskAgentWorkflow',
      );
      return null;
    }
  }

  /// Resolves the text content of an observation message.
  ///
  /// Looks up the [AgentMessagePayloadEntity] via the message's
  /// `contentEntryId` and extracts the `text` field from its content map.
  /// Falls back to a placeholder when the payload is missing or malformed.
  Future<String> _resolveObservationText(AgentMessageEntity obs) async {
    final payloadId = obs.contentEntryId;
    if (payloadId == null) return '(no content)';

    final payload = await agentRepository.getEntity(payloadId);
    if (payload is AgentMessagePayloadEntity) {
      final text = payload.content['text'];
      if (text is String && text.isNotEmpty) return text;
    }
    return '(no content)';
  }

  /// Converts [AgentToolRegistry.taskAgentTools] to OpenAI-compatible
  /// [ChatCompletionTool] objects.
  List<ChatCompletionTool> _buildToolDefinitions() {
    return AgentToolRegistry.taskAgentTools.map((def) {
      return ChatCompletionTool(
        type: ChatCompletionToolType.function,
        function: FunctionObject(
          name: def.name,
          description: def.description,
          parameters: def.parameters,
        ),
      );
    }).toList();
  }

  /// Extracts the final assistant text content from the conversation manager.
  String? _extractFinalAssistantContent(ConversationManager? manager) {
    if (manager == null) return null;

    // Walk backwards through messages to find the last assistant message
    // with text content (not a tool-call-only message).
    for (final message in manager.messages.reversed) {
      if (message
          case ChatCompletionMessage(
            role: ChatCompletionMessageRole.assistant
          )) {
        final content = message.mapOrNull(
          assistant: (m) => m.content,
        );
        if (content != null && content.isNotEmpty) {
          return content;
        }
      }
    }
    return null;
  }
}

class _LinkedTaskAgentReport {
  const _LinkedTaskAgentReport({
    required this.agentId,
    required this.content,
    required this.createdAt,
  });

  final String agentId;
  final String content;
  final DateTime createdAt;
}

/// Resolved template and version pair for prompt composition.
class _TemplateContext {
  _TemplateContext({required this.template, required this.version});

  final AgentTemplateEntity template;
  final AgentTemplateVersionEntity version;
}
