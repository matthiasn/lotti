part of 'day_agent_workflow.dart';

/// Tool-call handling for [DayAgentWorkflow]: the tool-handler dispatch and
/// the memory-search tool. Split from the main workflow file for size; all
/// members are library-private.
extension DayAgentToolHandlers on DayAgentWorkflow {
  Future<DayAgentToolResult> _executeToolHandler({
    required String agentId,
    required String threadId,
    required String runKey,
    required String dayId,
    required String toolName,
    required Map<String, dynamic> args,
  }) async {
    // `write_day_summary` is dispatched BEFORE the blanket workspace-day
    // guard below: its dayId is anchored to the wall clock (today/yesterday,
    // enforced inside the service), independent of the wake's workspace —
    // the ADR-governed exception to ADR 0022 Decision 4 (a drafting-tomorrow
    // wake writes yesterday's missing summary without mutating another day's
    // plan state).
    if (DayAgentToolNames.isWeekContextTool(toolName)) {
      final service = weekContextService;
      if (service == null) {
        return const DayAgentToolResult(
          success: false,
          output: 'Error: week-context tools are not configured.',
        );
      }
      final result = await service.executeTool(
        agentId: agentId,
        toolName: toolName,
        args: args,
      );
      return DayAgentToolResult(
        success: result.success,
        output: result.output,
      );
    }

    // Reject day-scoped tool calls targeting a day other than this wake's
    // workspace (ADR 0022 Decision 4). Under one planner the model must never
    // mutate a different day than the wake it is running.
    final argDayId = args['dayId'];
    if (argDayId is String &&
        argDayId.trim().isNotEmpty &&
        argDayId.trim() != dayId) {
      return DayAgentToolResult(
        success: false,
        output:
            'Error: tool dayId "${argDayId.trim()}" does not match the wake '
            'workspace "$dayId".',
      );
    }

    if (DayAgentToolNames.isCaptureReconcileTool(toolName)) {
      final service = captureService;
      if (service == null) {
        return const DayAgentToolResult(
          success: false,
          output: 'Error: capture/reconcile tools are not configured.',
        );
      }
      final result = await service.executeTool(
        agentId: agentId,
        threadId: threadId,
        runKey: runKey,
        toolName: toolName,
        args: args,
      );
      return DayAgentToolResult(
        success: result.success,
        output: result.output,
      );
    }

    if (DayAgentToolNames.isPlanTool(toolName)) {
      final service = planService;
      if (service == null) {
        return const DayAgentToolResult(
          success: false,
          output: 'Error: day-plan tools are not configured.',
        );
      }
      final result = await service.executeTool(
        agentId: agentId,
        threadId: threadId,
        runKey: runKey,
        toolName: toolName,
        args: args,
      );
      return DayAgentToolResult(
        success: result.success,
        output: result.output,
      );
    }

    if (DayAgentToolNames.isKnowledgeTool(toolName)) {
      final service = knowledgeService;
      if (service == null) {
        return const DayAgentToolResult(
          success: false,
          output: 'Error: durable-knowledge tools are not configured.',
        );
      }
      final result = await service.executeTool(
        agentId: agentId,
        toolName: toolName,
        args: args,
      );
      return DayAgentToolResult(
        success: result.success,
        output: result.output,
      );
    }

    if (DayAgentToolNames.isSearchMemoryTool(toolName)) {
      return _searchMemory(agentId: agentId, args: args);
    }

    if (!DayAgentToolNames.isSetNextWakeTool(toolName)) {
      return DayAgentToolResult(
        success: false,
        output: 'Error: unknown day-agent tool "$toolName".',
      );
    }

    final rawAt = args['at'];
    final reasonValue = args['reason'];
    final reason = reasonValue is String ? reasonValue.trim() : '';
    if (rawAt is! String || rawAt.trim().isEmpty) {
      return const DayAgentToolResult(
        success: false,
        output: 'Error: "at" must be an ISO-8601 date-time string.',
      );
    }
    if (reason.isEmpty) {
      return const DayAgentToolResult(
        success: false,
        output: 'Error: "reason" must not be empty.',
      );
    }

    late final DateTime scheduledAt;
    try {
      // Normalize to local: the tool asks for a local ISO-8601 time, but an LLM
      // may emit a `Z`/offset form. `getDueScheduledWakeRecords` compares the
      // stored `scheduledAt` string lexicographically against a naive-local
      // `now`, so a `…Z` suffix (or offset) would make the due check disagree
      // with wall-clock — and differ across devices in other timezones. Coerce
      // to naive-local here so the persisted form is always suffix-free and
      // ordering-consistent. Instant-based validation below is unaffected.
      scheduledAt = DateTime.parse(rawAt.trim()).toLocal();
    } catch (_) {
      return const DayAgentToolResult(
        success: false,
        output: 'Error: "at" must be parseable as an ISO-8601 date-time.',
      );
    }

    final now = clock.now();
    final earliestAllowed = now.add(DayAgentWorkflow.minScheduledWakeLeadTime);
    if (scheduledAt.isBefore(earliestAllowed)) {
      return DayAgentToolResult(
        success: false,
        output:
            'Error: next wake must be at least '
            '${DayAgentWorkflow.minScheduledWakeLeadTime.inMinutes} minutes in the future.',
      );
    }

    // Cap is keyed by (dayId, date) so an active multi-day planner can still
    // pre-warm each day; a single calendar-date key would let three planned
    // days exhaust one shared budget (ADR 0022 Decision 12).
    final wakeCountKey = _scheduledWakeCountKey(now, dayId);
    final workspaceKey = dayAgentWorkspaceKey(dayId);
    try {
      await syncService.runInTransaction(() async {
        final state = await agentRepository.getAgentState(agentId);
        if (state == null) {
          throw const _DayAgentToolException('Error: agent state not found.');
        }

        final currentCount = state.toolCounterByKey[wakeCountKey] ?? 0;
        if (currentCount >= DayAgentWorkflow.maxScheduledWakeWritesPerDay) {
          throw const _DayAgentToolException(
            'Error: daily scheduled-wake cap reached.',
          );
        }

        // Persist the pre-warm as a day-scoped scheduled-wake record rather
        // than the single, clobberable AgentState.scheduledWakeAt: a
        // long-lived planner has several outstanding day wakes, and each must
        // restore with its own workspace + trigger tokens. The deterministic
        // id overwrites a prior pending pre-warm for the same day.
        await syncService.upsertEntity(
          AgentDomainEntity.scheduledWake(
            id: scheduledWakeRecordId(agentId, workspaceKey: workspaceKey),
            agentId: agentId,
            scheduledAt: scheduledAt,
            status: ScheduledWakeStatus.pending,
            reason: WakeReason.scheduled.name,
            updatedAt: now,
            vectorClock: null,
            triggerTokens: [dayAgentPlanningDayToken(dayId)],
            workspaceKey: workspaceKey,
          ),
        );

        // The cap counter still lives on the per-agent state.
        await syncService.upsertEntity(
          state.copyWith(
            updatedAt: now,
            toolCounterByKey: _nextToolCounterByKey(
              state.toolCounterByKey,
              wakeCountKey,
              currentCount + 1,
            ),
          ),
        );
      });
      onPersistedStateChanged?.call(agentId);

      return DayAgentToolResult(
        success: true,
        output: 'Next wake scheduled for ${scheduledAt.toIso8601String()}.',
      );
    } on _DayAgentToolException catch (e) {
      return DayAgentToolResult(success: false, output: e.message);
    }
  }

  /// Recall handler for `search_memory`: keyword-scans the full immutable
  /// memory log — including detail folded out of the compacted summary — for
  /// entries matching the query. Built over the same lazy capture resolution
  /// the wake uses, so it spans folded + tail without the per-wake path ever
  /// loading everything; this opt-in recall is the only reader beyond the tail.
  Future<DayAgentToolResult> _searchMemory({
    required String agentId,
    required Map<String, dynamic> args,
  }) async {
    final rawIds = args['ids'];
    final ids = rawIds is List
        ? <String>{
            for (final e in rawIds)
              if (e is String && e.trim().isNotEmpty) e.trim(),
          }
        : const <String>{};
    final rawQuery = args['query'];
    final query = rawQuery is String ? rawQuery.trim() : '';
    if (ids.isEmpty && query.isEmpty) {
      return const DayAgentToolResult(
        success: false,
        output: 'Error: provide "query" keywords or "ids" to recall.',
      );
    }
    final rawLimit = args['limit'];
    final limit = rawLimit is int ? rawLimit.clamp(1, 20) : 8;

    var captureMetas = const <CaptureEventMeta>[];
    try {
      captureMetas = await agentRepository.getCaptureEventMetaByAgentId(
        agentId,
      );
    } catch (e) {
      _logError('search_memory: failed to load capture metadata', error: e);
    }

    // Widen link validation beyond the episodic log so a note that links to a
    // durable-knowledge entry (e.g. a `moc-<topic>` map) resolves instead of
    // rendering as a dead link. Durable knowledge lives outside the memory log,
    // so the agent cites it by key; include keys and entity ids. Non-fatal.
    final extraKnownIds = <String>{};
    try {
      final knowledge = await knowledgeService?.allFor(agentId) ?? const [];
      for (final entry in knowledge) {
        extraKnownIds
          ..add(entry.key)
          ..add(entry.id);
      }
    } catch (e) {
      _logError('search_memory: failed to load knowledge ids', error: e);
    }

    final compactor = AgentLogCompactor(
      syncService: syncService,
      inlineEvents: dayCaptureEvents(captureMetas),
      resolveInlineContent: _resolveCaptureContent,
    );

    final List<MemoryLogHit> hits;
    try {
      hits = ids.isNotEmpty
          ? await compactor.resolveByIds(
              agentId,
              ids: ids,
              extraKnownIds: extraKnownIds,
            )
          : await compactor.searchLog(
              agentId,
              query: query,
              limit: limit,
              extraKnownIds: extraKnownIds,
            );
    } catch (e, s) {
      _logError('search_memory failed', error: e, stackTrace: s);
      return const DayAgentToolResult(
        success: false,
        output: 'Error: memory search failed.',
      );
    }

    final subject = ids.isNotEmpty ? 'ids ${ids.join(', ')}' : '"$query"';
    if (hits.isEmpty) {
      return DayAgentToolResult(
        success: true,
        output: 'No memory entries match $subject.',
      );
    }

    final buf = StringBuffer(
      'Found ${hits.length} memory match(es) for $subject (most recent first):',
    );
    for (final hit in hits) {
      buf
        ..writeln()
        ..write(
          '- [${hit.at.toIso8601String()}] '
          '(${hit.type}${hit.edited ? ', edited' : ''}) '
          '(id: ${hit.contentEntryId}) ${hit.text}',
        );
      if (hit.supersededByEntryId != null) {
        buf.write(' [superseded by ${hit.supersededByEntryId}]');
      }
      if (hit.links.isNotEmpty) {
        buf
          ..writeln()
          ..write('  links: ${hit.links.map(_formatLink).join(', ')}');
      }
    }
    return DayAgentToolResult(success: true, output: buf.toString());
  }

  Future<_TemplateContext?> _resolveTemplate(String agentId) async {
    final template = await templateService.getTemplateForAgent(agentId);
    if (template == null) return null;

    final version = await templateService.getActiveVersion(template.id);
    if (version == null) return null;

    final soulVersion = await soulDocumentService?.resolveActiveSoulForTemplate(
      template.id,
    );

    return _TemplateContext(
      template: template,
      version: version,
      soulVersion: soulVersion,
    );
  }
}
