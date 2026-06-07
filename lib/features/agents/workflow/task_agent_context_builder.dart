part of 'task_agent_workflow.dart';

/// Context-section builders of [TaskAgentWorkflow]: attention claims,
/// linked tasks, observation payloads, timer/time-entry sections, and
/// tool definitions.
extension TaskAgentContextBuilder on TaskAgentWorkflow {
  Future<List<AttentionRequestEntity>> _attentionClaimsForTask(
    String taskId,
  ) async {
    try {
      return await agentRepository.getAttentionClaimsForTarget(
        targetKind: 'task',
        targetId: taskId,
        limit: 20,
      );
    } catch (e, s) {
      _logError(
        'failed to load task attention requests',
        error: e,
        stackTrace: s,
      );
      return const [];
    }
  }

  Future<({List<AttentionRequestEntity> claims, Task? task})>
  _maintainAndLoadAttentionClaims({
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
      _logError(
        'failed to maintain task attention requests',
        error: e,
        stackTrace: s,
      );
    }
    return (
      claims: await _attentionClaimsForTask(taskId),
      task: resolvedTask,
    );
  }

  String _formatTaskAttentionRequests(
    List<AttentionRequestEntity> claims, {
    required String agentId,
  }) {
    if (claims.isEmpty) return '';
    final rows = [
      for (final claim in claims)
        {
          'id': claim.id,
          'agentId': claim.agentId,
          'ownedByThisAgent': claim.agentId == agentId,
          'title': claim.title,
          'requestedMinutes': claim.requestedMinutes,
          'impact': claim.impact,
          'urgency': claim.urgency,
          'energyFit': claim.energyFit.name,
          'scopeKind': claim.scopeKind.name,
          'earliestStart': claim.earliestStart?.toIso8601String(),
          'latestEnd': claim.latestEnd?.toIso8601String(),
          'deadline': claim.deadline?.toIso8601String(),
          'nextReviewAt': claim.nextReviewAt?.toIso8601String(),
          'rationale': claim.rationale,
        },
    ];
    return (StringBuffer()
          ..writeln('## Attention Requests For This Task')
          ..writeln()
          ..writeln(
            'These active requests are already visible to the day planner. '
            'Maintain only rows where ownedByThisAgent is true. If one of '
            'your requests is no longer needed, call '
            '`resolve_attention_request` with withdrawn or satisfied. If the '
            'task still needs attention but the ask materially changed (for '
            'example amount, impact, urgency, energy fit, scope, timing '
            'window, review time, or rationale), call `request_attention` '
            'with the new ask; it supersedes your old active request. Do not '
            'call `request_attention` again for an equivalent ask.',
          )
          ..writeln()
          ..writeln('```json')
          ..writeln(const JsonEncoder.withIndent('  ').convert(rows))
          ..writeln('```')
          ..writeln())
        .toString();
  }

  /// Formats the [ProposalLedger] into a single markdown section the agent
  /// consumes during a wake.
  ///
  /// The ledger is the agent's memory of its own suggestions for this task.
  /// Open entries carry fingerprints so the agent can call
  /// `retract_suggestions` with those fingerprints when a proposal is no
  /// longer relevant.
  ///
  /// [includeResolved] selects the legacy full view (resolved verdicts
  /// rendered here); with compaction on, resolved verdicts are
  /// decision-tagged events in the task log instead, so this section carries
  /// only the open (actionable) state.
  String _formatProposalLedger(
    ProposalLedger ledger, {
    required bool includeResolved,
  }) {
    if (ledger.isEmpty) return '';
    if (!includeResolved && ledger.open.isEmpty) return '';

    final buffer = StringBuffer()
      ..writeln('## Proposal Ledger')
      ..writeln()
      ..writeln(
        includeResolved
            ? 'This is a complete record of suggestions you have produced '
                  'for this task. Do not re-propose an identical OPEN item. '
                  'If an OPEN item is no longer relevant (the current task '
                  'state already matches it, or it duplicates another open '
                  'proposal), call `retract_suggestions` with its '
                  'fingerprint. For RESOLVED items, learn from the verdict: '
                  'do not re-propose rejected items unless the task context '
                  'has materially changed.'
            : 'These are your OPEN suggestions for this task. Do not '
                  're-propose an identical item. If one is no longer '
                  'relevant (the current task state already matches it, or '
                  'it duplicates another open proposal), call '
                  '`retract_suggestions` with its fingerprint. Past '
                  'verdicts appear as decision-tagged events in the Task Log: '
                  'learn from them and do not re-propose rejected items '
                  'unless the task context has materially changed.',
      )
      ..writeln()
      ..writeln('### Open (${ledger.open.length})')
      ..writeln(
        ledger.open.isEmpty
            ? '- (none)'
            : ledger.open
                  .map(
                    (e) =>
                        '- [fp=${e.fingerprint}] `${e.toolName}`: '
                        '${e.humanSummary.trim()}',
                  )
                  .join('\n'),
      )
      ..writeln();

    if (includeResolved && ledger.resolved.isNotEmpty) {
      buffer.writeln('### Resolved (${ledger.resolved.length}, most recent)');
      for (final e in ledger.resolved) {
        buffer.writeln('- ${formatResolvedLedgerLine(e)}');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Renders a compact, high-salience guard immediately before the final wake
  /// instruction so OPEN proposals are treated as current work-cycle state,
  /// not just historical context earlier in the prompt.
  String _formatOpenProposalGuard(ProposalLedger ledger) {
    if (ledger.open.isEmpty) return '';

    final buffer = StringBuffer()
      ..writeln('## Open Proposal Guard')
      ..writeln()
      ..writeln(
        'Before proposing any change, compare it against these OPEN '
        'proposals. Do not propose the same user-facing action again '
        '(for `update_running_timer`, compare per `timerId`). If an OPEN '
        'proposal is stale, call `retract_suggestions` with its fingerprint; '
        'otherwise leave it open.',
      )
      ..writeln()
      ..writeln(
        ledger.open
            .map(
              (e) =>
                  '- [fp=${e.fingerprint}] `${e.toolName}`: '
                  '${e.humanSummary.trim()}',
            )
            .join('\n'),
      )
      ..writeln();

    return buffer.toString();
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
  Future<String> _buildLinkedTasksContextJson(String taskId) async {
    try {
      final linkedFrom = await this.aiInputRepository.buildLinkedFromContext(
        taskId,
      );
      final linkedTo = await this.aiInputRepository.buildLinkedToContext(
        taskId,
      );

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

      // Two bulk queries replace the prior `Future.wait(map →
      // _resolveLatestTaskAgentReport(id))` fan-out. The fan-out hit
      // 2 203 `agent_links WHERE to_id = ? AND type = ?` queries plus
      // a compounding 2 484 `agent_entities WHERE id = ?` queries on
      // the 2026-05-10 desktop slow_queries log; each per-row request
      // queued independently behind the writer lock. The bulk path is
      // `getLinksToMultiple` + `getLatestReportsByAgentIds`, mirroring
      // the already-batched implementation in
      // `ProjectAgentWorkflow._buildLinkedTasksContext`.
      final reportByTaskId = <String, _LinkedTaskAgentReport>{};
      if (taskIds.isNotEmpty) {
        var linksByTaskId = const <String, List<AgentLink>>{};
        try {
          linksByTaskId = await agentRepository.getLinksToMultiple(
            taskIds.toList(),
            type: AgentLinkTypes.agentTask,
          );
        } catch (e, s) {
          _logError(
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
            _logError(
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
              createdAt: report.createdAt,
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
          continue;
        }

        row['taskAgentId'] = linkedReport.agentId;
        row['latestTaskAgentReportOneLiner'] = linkedReport.oneLiner;
        row['latestTaskAgentReportTldr'] = linkedReport.tldr;
        row['latestTaskAgentReportCreatedAt'] = linkedReport.createdAt
            .toIso8601String();
      }

      return const JsonEncoder.withIndent('    ').convert(<String, dynamic>{
        'linked_from': linkedFromRows,
        'linked_to': linkedToRows,
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

  /// Batch-resolves all observation payloads into a map keyed by payload ID.
  Future<Map<String, AgentMessagePayloadEntity>> _resolveObservationPayloads(
    List<AgentMessageEntity> observations,
  ) async {
    final payloadIds = observations
        .map((o) => o.contentEntryId)
        .whereType<String>()
        .toSet();

    if (payloadIds.isEmpty) {
      return const <String, AgentMessagePayloadEntity>{};
    }

    // Single batched IN-list lookup instead of `Future.wait(map →
    // getEntity)`. See `AgentRepository.getEntitiesByIds` for the slow-
    // log evidence behind the rewrite. Non-payload entities (or ids
    // with no row / soft-deleted) are silently dropped — the caller
    // renders a placeholder, same as the pre-batch failure mode.
    final Map<String, AgentDomainEntity> entitiesById;
    try {
      entitiesById = await agentRepository.getEntitiesByIds(payloadIds);
    } catch (e) {
      // Non-fatal — observation will render with placeholder text.
      return const <String, AgentMessagePayloadEntity>{};
    }

    final result = <String, AgentMessagePayloadEntity>{};
    for (final entry in entitiesById.entries) {
      final entity = entry.value;
      if (entity is AgentMessagePayloadEntity) {
        result[entry.key] = entity;
      }
    }
    return result;
  }

  /// Renders an "Active Running Timer" section describing whatever timer
  /// is currently running.
  ///
  /// Two shapes:
  ///
  /// - **Same task** — the timer belongs to the task being woken. The agent
  ///   gets the timerId, started time, tracked range, elapsed minutes, and
  ///   current entry text, and is told to propose `update_running_timer`
  ///   instead of a parallel `create_time_entry` for that ongoing work.
  /// - **Other task** — the timer belongs to a different task. The agent is
  ///   only told the tracked range (no id, no source task, no entry text)
  ///   so it can avoid proposing `create_time_entry` entries for this task
  ///   that overlap with that range. Details about the other task are
  ///   intentionally withheld.
  ///
  /// Returns an empty string when no timer is active.
  String _buildActiveTimerSection(TimeService? timeService, String taskId) {
    if (timeService == null) return '';
    final current = timeService.getCurrent();
    if (current is! JournalEntry) return '';

    final dateFrom = current.meta.dateFrom;
    final now = clock.now();
    // [TimeService.start] only emits live `dateTo` updates on its broadcast
    // stream; the in-memory `_current` entity returned by `getCurrent()`
    // still carries the original `dateTo` recorded when the timer was
    // started. Use `now` as the running endpoint so the prompt — and the
    // overlap guard for the cross-task branch — reflects the actual
    // tracked range. If `current.meta.dateTo` is somehow ahead of `now`
    // (e.g. an injected fixture), respect it as a defensive upper bound.
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
          'propose `update_running_timer` instead with a richer description. '
          '`create_time_entry` is still appropriate for clearly distinct '
          'completed sessions that do not overlap this timer.',
        )
        ..writeln('- timerId: ${current.meta.id}')
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
          '`update_running_timer` is NOT available in '
          'this wake because the timer is not for this task.',
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
          'pass an `entryId` listed here to `update_time_entry`. Do not use '
          '`update_time_entry` for the currently running timer.',
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
      _logError(
        'failed to build editable time entries section',
        error: error,
        stackTrace: stackTrace,
      );
      return '';
    }
  }

  /// Converts [AgentToolRegistry.taskAgentTools] to [AiTool] objects.
  List<AiTool> _buildToolDefinitions() {
    return AgentToolRegistry.taskAgentTools
        .where((def) => def.enabled)
        .map(
          (def) => AiTool(
            name: def.name,
            description: def.description,
            parameters: def.parameters,
          ),
        )
        .toList();
  }

  /// Extracts the final assistant text content from the conversation manager.
  String? _extractFinalAssistantContent(ConversationManager? manager) {
    if (manager == null) return null;

    // Walk backwards through messages to find the last assistant message
    // with text content (not a tool-call-only message).
    for (final message in manager.messages.reversed) {
      if (message is AiAssistantMessage) {
        final content = message.content;
        if (content != null && content.isNotEmpty) {
          return content;
        }
      }
    }
    return null;
  }
}
