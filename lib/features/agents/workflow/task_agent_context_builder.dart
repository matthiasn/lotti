import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/projection/decision_events.dart';
import 'package:lotti/features/agents/service/attention_claim_maintenance_service.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/tools/correction_examples_builder.dart';
import 'package:lotti/features/agents/tools/task_agent_tool_gate.dart';
import 'package:lotti/features/agents/tools/task_label_handler.dart';
import 'package:lotti/features/agents/workflow/agent_observations.dart';
import 'package:lotti/features/agents/workflow/project_agent_context_builder.dart'
    show LogErrorCallback;
import 'package:lotti/features/agents/workflow/task_agent_evidence_synthesis.dart';
import 'package:lotti/features/agents/workflow/task_agent_report_policy.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/tasks/model/directed_relation.dart';
import 'package:lotti/services/time_service.dart';
import 'package:openai_dart/openai_dart.dart';

part 'task_agent_context_builder_formatters.dart';

/// Builds the task-agent wake prompt: attention claims, linked tasks,
/// observation payloads, timer/time-entry sections, tool definitions, and the
/// final user message.
///
/// Extracted from `TaskAgentWorkflow` as a standalone collaborator. Every
/// method here reads from the injected repositories (or transforms its inputs)
/// and produces a context string / object — none mutate workflow state. The
/// workflow holds an instance and delegates to it.
/// How many of its newest observations a task agent's wake reads.
const taskObservationLookback = 20;

class TaskAgentContextBuilder {
  TaskAgentContextBuilder({
    required this.agentRepository,
    required this.syncService,
    required this.aiInputRepository,
    required this.journalDb,
    required this.logError,
  });

  final AgentRepository agentRepository;
  final AgentSyncService syncService;
  final AiInputRepository aiInputRepository;
  final JournalDb journalDb;
  final LogErrorCallback logError;

  Future<List<AttentionRequestEntity>> attentionClaimsForTask(
    String taskId,
  ) async {
    try {
      return await agentRepository.getAttentionClaimsForTarget(
        targetKind: 'task',
        targetId: taskId,
        limit: 20,
      );
    } catch (e, s) {
      logError(
        'failed to load task attention requests',
        error: e,
        stackTrace: s,
      );
      return const [];
    }
  }

  Future<({List<AttentionRequestEntity> claims, Task? task})>
  maintainAndLoadAttentionClaims({
    required String agentId,
    required String taskId,
    Task? task,
  }) async {
    var resolvedTask = task;
    try {
      if (resolvedTask == null) {
        final entity = await journalDb.journalEntityById(taskId);
        if (entity is Task) resolvedTask = entity;
      }
      if (resolvedTask != null) {
        await AttentionClaimMaintenanceService(
          agentRepository: agentRepository,
          syncService: syncService,
        ).settleTerminalTaskClaims(agentId: agentId, task: resolvedTask);
      }
    } catch (e, s) {
      logError(
        'failed to maintain task attention requests',
        error: e,
        stackTrace: s,
      );
    }
    return (
      claims: await attentionClaimsForTask(taskId),
      task: resolvedTask,
    );
  }

  /// Builds linked-task context JSON for the wake prompt.
  ///
  /// Forked from [AiInputRepository.buildLinkedTasksJson] for the task-agent
  /// wake path:
  /// 1. Builds linked task context directly from linked task entities.
  /// 2. Removes legacy `latestSummary` fields.
  /// 3. Injects a compact summary (oneLiner/tldr) of the latest task-agent
  ///    report for each linked task when present — not the full body, to keep
  ///    wake prefill small.
  ///
  /// This keeps prompt context aligned with the Agent Capabilities architecture
  /// where task summaries are being phased out in favor of task-agent reports.
  Future<String> buildLinkedTasksContextJson(String taskId) async {
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

      await _annotateRelations(taskId, allRows);

      final taskIds = allRows
          .map((row) => row['id'])
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();

      // Two bulk queries replace the prior `Future.wait(map →
      // _resolveLatestTaskAgentReport(id))` fan-out. The fan-out hit
      // 2 203 `agent_links WHERE to_id = ? AND type = ?` queries plus
      // a compounding 2 484 `agent_entities WHERE id = ?` queries on
      // the 2026-05-10 desktop slow_queries log; each per-row request
      // queued independently behind the writer lock. The bulk path is
      // `getLinksToMultiple` + `getLatestReportsByAgentIds`, mirroring
      // the already-batched implementation in
      // `ProjectAgentContextBuilder.buildLinkedTasksContext`.
      final reportByTaskId = <String, _LinkedTaskAgentReport>{};
      if (taskIds.isNotEmpty) {
        var linksByTaskId = const <String, List<AgentLink>>{};
        try {
          linksByTaskId = await agentRepository.getLinksToMultiple(
            taskIds.toList(),
            type: AgentLinkTypes.agentTask,
          );
        } catch (e, s) {
          logError(
            'batch agent_task link lookup failed',
            error: e,
            stackTrace: s,
          );
        }

        final linkedAgentIds = linksByTaskId.values
            .expand((links) => links.map((link) => link.fromId))
            .toSet()
            .toList();

        var reportsByAgentId = const <String, AgentReportEntity>{};
        if (linkedAgentIds.isNotEmpty) {
          try {
            reportsByAgentId = await agentRepository.getLatestReportsByAgentIds(
              linkedAgentIds,
              AgentReportScopes.current,
            );
          } catch (e, s) {
            logError(
              'batch agent report lookup failed',
              error: e,
              stackTrace: s,
            );
          }
        }

        // Sort matches the prior per-task `orderedPrimaryFirst` shape
        // (createdAt DESC, then id DESC): newest link wins, but only if
        // its agent has a non-empty current report — otherwise fall
        // back to the next link, exactly as the pre-batch code did.
        for (final taskId in taskIds) {
          final links = linksByTaskId[taskId];
          if (links == null || links.isEmpty) continue;
          for (final link in links.orderedPrimaryFirst()) {
            final report = reportsByAgentId[link.fromId];
            if (report == null) continue;
            // Gate on a non-empty body so only "real" reports surface, but
            // embed just the compact summary to keep wake prefill small.
            if (report.content.trim().isEmpty) continue;
            reportByTaskId[taskId] = _LinkedTaskAgentReport(
              agentId: link.fromId,
              oneLiner: report.oneLiner,
              tldr: report.tldr,
            );
            break;
          }
        }
      }

      for (final row in allRows) {
        final linkedTaskId = row['id'];
        if (linkedTaskId is! String || linkedTaskId.isEmpty) {
          continue;
        }

        final linkedReport = reportByTaskId[linkedTaskId];
        if (linkedReport == null) {
          // Static absence marker so the model can distinguish "no report
          // published yet" from "no work" — and so it never has to infer
          // either from missing fields. Static (not derived from createdAt),
          // so it does not churn the prompt.
          row['summaryStatus'] = 'none';
          continue;
        }

        row['summaryStatus'] = 'present';
        row['taskAgentId'] = linkedReport.agentId;
        row['latestTaskAgentReportOneLiner'] = linkedReport.oneLiner;
        row['latestTaskAgentReportTldr'] = linkedReport.tldr;
      }

      return const JsonEncoder.withIndent('    ').convert(<String, dynamic>{
        'linked_from': linkedFromRows,
        'linked_to': linkedToRows,
      });
    } catch (e, stackTrace) {
      logError(
        'failed to build linked tasks context',
        error: e,
        stackTrace: stackTrace,
      );
      return '{}';
    }
  }

  /// Adds a `relations` array to each linked-task row: the directed wire
  /// phrases (ADR 0042) describing how the CURRENT task relates to that row's
  /// task, e.g. `["blocks"]` or `["is_superseded_by", "relates_to"]`.
  ///
  /// One bulk link query; failures leave the rows unannotated rather than
  /// failing the wake. The phrases are the same vocabulary the `link_task`
  /// tool accepts, so the model can read a row's existing relationships in
  /// exactly the terms it would use to propose a new one.
  Future<void> _annotateRelations(
    String taskId,
    List<Map<String, dynamic>> rows,
  ) async {
    try {
      final links = await journalDb.linksForEntryIdsBidirectional({taskId});
      final relationsByOtherId = <String, List<String>>{};
      for (final link in links) {
        if (link.deletedAt != null || link.hidden == true) continue;
        final type = entryLinkTypeOf(link);
        if (type == EntryLinkType.rating || type == EntryLinkType.project) {
          continue;
        }
        // The anchor reads a link it originates as the primary phrase and an
        // incoming one as the inverse phrase — the same swap the UI renders.
        final String otherId;
        final DirectedRelation relation;
        if (link.fromId == taskId) {
          otherId = link.toId;
          relation = DirectedRelation(type);
        } else if (link.toId == taskId) {
          otherId = link.fromId;
          relation = DirectedRelation(type, inverse: true);
        } else {
          continue;
        }
        relationsByOtherId
            .putIfAbsent(otherId, () => <String>[])
            .add(relation.wireName);
      }

      for (final row in rows) {
        final rowTaskId = row['id'];
        if (rowTaskId is! String) continue;
        final relations = relationsByOtherId[rowTaskId];
        if (relations != null && relations.isNotEmpty) {
          row['relations'] = relations;
        }
      }
    } catch (e, s) {
      logError(
        'failed to annotate linked-task relations',
        error: e,
        stackTrace: s,
      );
    }
  }

  /// Renders an "Active Running Timer" section describing whatever timer
  /// is currently running.
  ///
  /// Two shapes:
  ///
  /// - **Same task** — the timer belongs to the task being woken. The agent
  ///   gets the entryId, started time, tracked range, elapsed minutes, and
  ///   current entry text, and is told to propose `update_time_entry` with
  ///   only a summary instead of a parallel `create_time_entry` for that
  ///   ongoing work.
  /// - **Other task** — the timer belongs to a different task. The agent is
  ///   only told the tracked range (no id, no source task, no entry text)
  ///   so it can avoid proposing `create_time_entry` entries for this task
  ///   that overlap with that range. Details about the other task are
  ///   intentionally withheld.
  ///
  /// Returns an empty string when no timer is active.
  ///
  /// [TimeService] says which entry is running and for which task; the entry
  /// itself is read from the database. A text confirmed on another device
  /// arrives by sync and never passes through this device's service, whose
  /// snapshot keeps the text the timer started with until it restarts — the
  /// wake after that confirm must not show the agent the old text and invite
  /// it to propose the new one again. The snapshot stands in when the read
  /// fails.
  Future<String> _buildActiveTimerSection(
    TimeService? timeService,
    String taskId,
  ) async {
    if (timeService == null) return '';
    final snapshot = timeService.getCurrent();
    if (snapshot is! JournalEntry) return '';
    final current = await _storedTimer(snapshot);

    final dateFrom = current.meta.dateFrom;
    final now = clock.now();
    // A running timer's stored `dateTo` is whatever was last persisted — its
    // start, or the moment of its last save; [TimeService.start] emits the
    // live end only on its broadcast stream. Use `now` as the running endpoint
    // so the prompt — and the overlap guard for the cross-task branch —
    // reflects the actual tracked range. If `dateTo` is somehow ahead of
    // `now` (e.g. an injected fixture), respect it as a defensive upper bound.
    final dateTo = current.meta.dateTo.isAfter(now) ? current.meta.dateTo : now;
    final elapsedMinutes = dateTo.difference(dateFrom).inMinutes;
    final isSameTask = timeService.linkedFrom?.id == taskId;

    final buffer = StringBuffer()..writeln('## Active Running Timer');

    if (isSameTask) {
      final entryText = current.entryText?.plainText.trim() ?? '';
      buffer
        ..writeln(
          'A timer is currently running for THIS task. Do NOT propose a '
          'new `create_time_entry` for the work covered by this timer — '
          'propose `update_time_entry` with this entryId and only a richer '
          '`summary` instead; its start and end cannot change while it runs. '
          '`create_time_entry` is still appropriate for clearly distinct '
          'completed sessions that do not overlap this timer.',
        )
        ..writeln('- entryId: ${current.meta.id}')
        ..writeln('- started: ${dateFrom.toIso8601String()}')
        ..writeln(
          '- tracked: ${dateFrom.toIso8601String()} → '
          '${dateTo.toIso8601String()} '
          '(~$elapsedMinutes min elapsed)',
        )
        ..writeln(
          '- current text: '
          '${entryText.isEmpty ? '(empty)' : '"$entryText"'}',
        );
    } else {
      buffer
        ..writeln(
          'A timer is currently running for a DIFFERENT task. Details '
          'about that task are intentionally withheld. Do NOT propose '
          '`create_time_entry` entries on this task whose [startTime, '
          'endTime] interval overlaps the tracked range below — that '
          'time is already being recorded elsewhere. You may still '
          'propose entries for non-overlapping completed intervals. '
          'That timer is not part of this task, so it cannot be updated '
          'from this wake.',
        )
        ..writeln(
          '- tracked elsewhere: ${dateFrom.toIso8601String()} → '
          '${dateTo.toIso8601String()} '
          '(~$elapsedMinutes min elapsed)',
        );
    }

    buffer.writeln();
    return buffer.toString();
  }

  /// The running timer as stored, or [snapshot] when it cannot be read or is
  /// no longer a time entry.
  Future<JournalEntry> _storedTimer(JournalEntry snapshot) async {
    try {
      final stored = await journalDb.journalEntityById(snapshot.meta.id);
      if (stored is JournalEntry) return stored;
    } catch (error, stackTrace) {
      logError(
        'failed to read the running timer',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return snapshot;
  }

  Future<String> _buildEditableTimeEntriesSection(
    TimeService? timeService,
    String taskId,
  ) async {
    try {
      final runningId = timeService?.getCurrent()?.meta.id;
      final linkedEntries = await journalDb.getLinkedEntities(taskId);
      final entries =
          linkedEntries
              .whereType<JournalEntry>()
              .where((entry) => entry.meta.id != runningId)
              .toList()
            ..sort((a, b) => b.meta.dateFrom.compareTo(a.meta.dateFrom));

      if (entries.isEmpty) return '';

      final buffer = StringBuffer()
        ..writeln('## Editable Time Entries')
        ..writeln(
          'These completed time-entry IDs are linked from THIS task. Only '
          "pass an `entryId` listed here — or the running timer's from the "
          'Active Running Timer section — to `update_time_entry`.',
        );

      for (final entry in entries) {
        final text = entry.entryText?.plainText.trim() ?? '';
        buffer
          ..writeln('- id: ${entry.meta.id}')
          ..writeln('  dateFrom: ${entry.meta.dateFrom.toIso8601String()}')
          ..writeln('  dateTo: ${entry.meta.dateTo.toIso8601String()}')
          ..writeln('  text: ${jsonEncode(text)}');
      }

      buffer.writeln();
      return buffer.toString();
    } catch (error, stackTrace) {
      logError(
        'failed to build editable time entries section',
        error: error,
        stackTrace: stackTrace,
      );
      return '';
    }
  }

  /// Converts [AgentToolRegistry.taskAgentTools] to OpenAI-compatible
  /// [ChatCompletionTool] objects.
  ///
  /// [facts] drops tools whose precondition this wake does not meet. It
  /// defaults to permissive, so a caller that does not pass it advertises
  /// exactly what it always has.
  List<ChatCompletionTool> buildToolDefinitions({
    TaskAgentWakeFacts facts = TaskAgentWakeFacts.permissive,
  }) {
    final visible = visibleTaskAgentToolNames(facts);
    return AgentToolRegistry.taskAgentTools
        .where((def) => def.enabled && visible.contains(def.name))
        .map((def) {
          final optimizeReport = def.name == TaskAgentToolNames.updateReport;
          return ChatCompletionTool(
            type: ChatCompletionToolType.function,
            function: FunctionObject(
              name: def.name,
              description: TaskAgentEvidenceSynthesis.toolDescription(
                def.name,
                def.description,
              ),
              parameters: optimizeReport
                  ? TaskAgentEvidenceSynthesis.updateReportParameters(
                      def.parameters,
                    )
                  : def.parameters,
            ),
          );
        })
        .toList();
  }

  /// Extracts the final assistant text content from the conversation manager.
  String? extractFinalAssistantContent(ConversationManager? manager) {
    if (manager == null) return null;

    // Walk backwards through messages to find the last assistant message
    // with text content (not a tool-call-only message).
    for (final message in manager.messages.reversed) {
      if (message case ChatCompletionMessage(
        role: ChatCompletionMessageRole.assistant,
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

  /// Builds the user message for a wake cycle. [taskDetails] is the compact
  /// markdown task state when the read-flip succeeds, or the full JSON header
  /// (inline log included) for fallback prompts. [hasReport] makes report
  /// existence explicit and selects first-publication or material-change
  /// guidance; the prior report's prose is never injected. [statusTransition]
  /// is a status change since that report, stated as a material change.
  ///
  /// [categoryKnowledge] is the user-written brief of the task's category
  /// (see `AiInputRepository.buildCategoryKnowledge`); it opens the stable
  /// prefix as a `## Category Knowledge` section and is omitted when blank.
  ///
  /// Returns the full text plus the offsets of the embedded (derivable) log
  /// block, so the persisted prompt record can store only the non-derivable
  /// halves (ADR 0020 v2 prompt records).
  Future<({String text, int? logStart, int? logEnd})> buildUserMessage({
    required String agentId,
    required bool hasReport,
    required List<RecalledObservation> journalObservations,
    required String taskDetails,
    required String projectContextJson,
    required String linkedTasksJson,
    required Set<String> triggerTokens,
    required String taskId,
    ProposalLedger ledger = const ProposalLedger.empty(),
    List<AttentionRequestEntity> attentionClaims = const [],
    Task? task,
    TimeService? timeService,
    String? compactedTaskLog,
    String? categoryKnowledge,
    TaskStatusTransition? statusTransition,
  }) async {
    final buffer = StringBuffer();

    // Ordering is by volatility, least-volatile first, so provider prefix
    // caches survive consecutive wakes. The stable header is label / correction
    // context (rare-change, user-gated), the category knowledge brief (typed
    // by the user, rarer still) and then the compacted task log (append-only
    // between folds), which ends the prefix. Everything that
    // changes more often than the log lives in the volatile tail below:
    // the task-state JSON (ticking timeSpent), the parent-project and
    // linked-task summaries (which embed OTHER agents' reports and so change
    // out-of-band with this task's wakes — see ADR 0027), timer, ledger,
    // attention, observations, and trigger tokens. One flipped byte voids the
    // cache for every byte after it, so nothing that changes more often than
    // the log may precede it. (This matches the project agent's ordering.)

    // Inject label context and correction examples.
    try {
      final taskEntity = task ?? await journalDb.journalEntityById(taskId);
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
    } catch (e, s) {
      logError(
        'failed to build label/correction context',
        error: e,
        stackTrace: s,
      );
      // Non-fatal: continue without context.
    }

    // The category brief is shared by every task in the category, so an edit
    // voids each task's cached prefix once — the price of text a person
    // changes by hand, and why it sits above the log rather than below it.
    final trimmedKnowledge = categoryKnowledge?.trim();
    if (trimmedKnowledge != null && trimmedKnowledge.isNotEmpty) {
      buffer
        ..writeln('## Category Knowledge')
        ..writeln()
        ..writeln(trimmedKnowledge)
        ..writeln();
    }

    final useCompactedLog =
        compactedTaskLog != null && compactedTaskLog.trim().isNotEmpty;

    int? logStart;
    int? logEnd;
    if (useCompactedLog) {
      // With compaction on (ADR 0017/0020), the task log is supplied as the
      // active summary + uncovered verbatim event tail from the captured log.
      // It is the largest stable block — the summary changes only at folds and
      // the tail is append-only between them — so it ends the stable prefix.
      // The task STATE moves BELOW it into the volatile tail: its time fields
      // tick on every working wake, and a single byte flipped upstream voids
      // the provider prefix cache for everything after it.
      buffer.writeln('## Task Log');
      logStart = buffer.length;
      buffer.write(compactedTaskLog);
      logEnd = buffer.length;
      buffer
        ..writeln()
        ..writeln();
    } else {
      buffer
        ..writeln('## Current Task Context')
        ..writeln('```json')
        ..writeln(taskDetails)
        ..writeln('```')
        ..writeln();
    }

    // --- Volatile tail: changes most across wakes, so it follows the stable
    // header above to keep that header byte-identical and prefix-cacheable. ---

    // Parent-project and linked-task summaries embed OTHER agents' latest
    // reports (their oneLiner / tldr), which change out-of-band with this
    // task's wakes (ADR 0027). They live here in the volatile tail — never in
    // the stable prefix — so a neighbor's republish cannot void this task's
    // warm log/prefix cache. Placed ahead of the ticking task-state so they
    // remain cacheable within the tail on wakes where no neighbor changed.
    if (projectContextJson.isNotEmpty && projectContextJson != '{}') {
      buffer
        ..writeln('## Parent Project Context')
        ..writeln('```json')
        ..writeln(projectContextJson)
        ..writeln('```')
        ..writeln();
    }

    if (linkedTasksJson.isNotEmpty && linkedTasksJson != '{}') {
      buffer
        ..writeln('## Linked Tasks')
        ..writeln('```json')
        ..writeln(linkedTasksJson)
        ..writeln('```')
        ..writeln();
    }

    if (useCompactedLog) {
      buffer
        ..writeln('## Current Task Context')
        ..writeln(taskDetails)
        ..writeln();
    }

    final activeTimerSection = await _buildActiveTimerSection(
      timeService,
      taskId,
    );
    if (activeTimerSection.isNotEmpty) {
      buffer.write(activeTimerSection);
    }

    final editableTimeEntriesSection = await _buildEditableTimeEntriesSection(
      timeService,
      taskId,
    );
    if (editableTimeEntriesSection.isNotEmpty) {
      buffer.write(editableTimeEntriesSection);
    }

    // In compacted mode, resolved verdicts live in the `## Task Log` as
    // decision-tagged events and open proposal details render once in the
    // guard near the final instruction. Legacy fallback mode keeps a bounded
    // resolved-history ledger because it lacks the compacted decision events.
    final proposalLedgerSection = _formatProposalLedger(
      ledger,
      includeResolved: !useCompactedLog,
    );
    if (proposalLedgerSection.isNotEmpty) {
      buffer.write(proposalLedgerSection);
    }

    final attentionSection = _formatTaskAttentionRequests(
      attentionClaims,
      agentId: agentId,
    );
    if (attentionSection.isNotEmpty) {
      buffer.write(attentionSection);
    }

    if (journalObservations.isNotEmpty) {
      // Inject prior critical observations first so the agent addresses
      // grievances and excellence notes before routine work.
      _writePriorCriticalObservations(buffer, journalObservations);

      // With compaction on, observations live in the `## Task Log` event tail
      // (interleaved as observation-tagged lines, folded into summaries by
      // the same watermarks) — a separate journal section would duplicate
      // them.
      if (!useCompactedLog) {
        buffer.writeln('## Agent Journal');
        // Recalled newest-first; reversed so the LLM reads them in
        // chronological order.
        for (final obs in journalObservations.reversed) {
          buffer.writeln('- [${obs.at.toIso8601String()}] ${obs.text}');
        }
        buffer.writeln();
      }
    }

    // The prior report's PROSE is deliberately NOT injected: the report is a
    // projection of the task log, not agent memory. Re-reading its own stale
    // conclusions as ground truth creates a feedback loop (a wrong "learning"
    // re-published verbatim every wake), and everything report-worthy is
    // already in the log, the observations, and the task state.
    buffer
      ..write(
        hasReport
            ? TaskAgentReportPolicy.existingReportContext
            : TaskAgentReportPolicy.firstReportContext,
      )
      ..write(
        hasReport && statusTransition != null
            ? TaskAgentReportPolicy.statusTransitionContext(statusTransition)
            : '',
      )
      ..write(
        TaskAgentReportPolicy.changedEntitiesContext(
          triggerTokens: triggerTokens,
          hasReport: hasReport,
        ),
      );

    final openProposalGuard = _formatOpenProposalGuard(ledger);
    if (openProposalGuard.isNotEmpty) {
      buffer.write(openProposalGuard);
    }

    buffer.writeln(TaskAgentReportPolicy.closingInstruction);

    return (text: buffer.toString(), logStart: logStart, logEnd: logEnd);
  }

  /// Writes a dedicated section for prior critical observations so the
  /// task agent can self-correct on grievances and reinforce excellence.
  static void _writePriorCriticalObservations(
    StringBuffer buffer,
    List<RecalledObservation> observations,
  ) {
    final grievances = <(DateTime, String)>[];
    final excellence = <(DateTime, String)>[];

    for (final obs in observations) {
      if (obs.priority != ObservationPriority.critical) continue;
      if (obs.category == ObservationCategory.excellence) {
        excellence.add((obs.at, obs.text));
      } else {
        // grievance, templateImprovement, or an unrecognized category
        grievances.add((obs.at, obs.text));
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
  });

  final String agentId;
  final String? oneLiner;
  final String? tldr;
}
