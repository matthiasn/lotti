part of 'task_agent_workflow.dart';

/// The full wake-cycle execution of [TaskAgentWorkflow]. Extracted into a
/// part-file extension to keep the workflow under the size limit; the class
/// keeps a thin public [TaskAgentWorkflow.execute] delegator so mocks keep
/// intercepting it.
extension TaskAgentExecute on TaskAgentWorkflow {
  /// Implementation of [TaskAgentWorkflow.execute].
  Future<WakeResult> executeImpl({
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

    // 1. Load current state + both memory types. The wake acts on the
    // log-reconciled state (PR 4 B6), so a watermark/slot the cache lost to LWW
    // self-heals before the agent decides anything.
    final state = await syncService.reconciledAgentState(agentId);
    if (state == null) {
      _log('no agent state found — aborting wake', subDomain: 'execute');
      return const WakeResult(success: false, error: 'No agent state found');
    }

    final taskId = state.slots.activeTaskId;
    if (taskId == null) {
      _log('no active task ID — aborting wake', subDomain: 'execute');
      return const WakeResult(success: false, error: 'No active task ID');
    }

    _log(
      'state resolved, taskId=${DomainLogger.sanitizeId(taskId)}',
      subDomain: 'execute',
    );

    // Capture timestamp once for the whole wake so all writes share causality.
    final now = clock.now();

    // 1a. Capture this wake's user-content sources into the log (ADR 0020),
    // per-source and content-addressed, BEFORE assembly so the input frontier
    // reflects the latest content. Non-fatal: a capture failure must not abort.
    final memory = AgentWakeMemory(
      syncService: syncService,
      inputCaptureService: inputCaptureService,
      logSummarizer: logSummarizer,
      domainLogger: domainLogger,
    );
    var captureSucceeded = false;
    if (inputCaptureService != null) {
      try {
        final linked = await journalDb.getLinkedEntities(taskId);
        captureSucceeded = await memory.capture(
          agentId: agentId,
          sources: renderTaskSources(
            linked,
            // A running timer's duration is still ticking; capturing it would
            // mint a new content version every wake (see renderTaskSources).
            runningEntryId: getIt<TimeService>().getCurrent()?.meta.id,
          ),
          at: now,
          threadId: threadId,
          runKey: runKey,
        );
      } catch (e) {
        // Source rendering failed (the capture call itself absorbs its own
        // errors inside [AgentWakeMemory.capture]).
        _logError('failed to capture wake inputs', error: e);
      }
    }

    // 2. Resolve the agent's template and active version. (Resolved before
    // compaction so the summarizer can use the wake's own model.)
    final templateCtx = await _resolveTemplate(agentId);
    if (templateCtx == null) {
      _log('no template assigned — aborting wake', subDomain: 'execute');
      return const WakeResult(
        success: false,
        error: 'No template assigned to agent',
      );
    }

    _log(
      'template=${DomainLogger.sanitizeId(templateCtx.template.id)}, '
      'version=${DomainLogger.sanitizeId(templateCtx.version.id)}, '
      'model=${templateCtx.version.modelId ?? templateCtx.template.modelId}',
      subDomain: 'execute',
    );

    // 3. Resolve inference profile (or legacy modelId) → provider.
    final profileResolver = ProfileResolver(
      aiConfigRepository: this.aiConfigRepository,
    );
    final resolvedProfile = await profileResolver.resolve(
      agentConfig: agentIdentity.config,
      template: templateCtx.template,
      version: templateCtx.version,
    );
    if (resolvedProfile == null) {
      final modelId =
          templateCtx.version.modelId ?? templateCtx.template.modelId;
      _log(
        'no provider configured for model $modelId — aborting wake',
        subDomain: 'execute',
      );
      return const WakeResult(
        success: false,
        error: 'No inference provider configured',
      );
    }
    final modelId = resolvedProfile.thinkingModelId;
    final provider = resolvedProfile.thinkingProvider;

    // One ledger fetch feeds the compactor's decision events (below), the
    // LLM prompt (open proposals + legacy resolved view) and the
    // ChangeSetBuilder (open pending sets for cross-wake dedup).
    final ledger = await agentRepository.getProposalLedger(
      agentId,
      taskId: taskId,
      resolvedLimit: TaskAgentWorkflow.resolvedDecisionWindow,
    );
    if (ledger.resolved.length >= TaskAgentWorkflow.resolvedDecisionWindow) {
      // No silent caps: beyond the window, the oldest UNFOLDED verdicts
      // would leave the event substrate before being summarized (folded
      // verdicts stay provably covered via the checkpoint's coveredSources).
      _log(
        'resolved-decision window saturated '
        '(${ledger.resolved.length} >= $TaskAgentWorkflow.resolvedDecisionWindow): oldest '
        'unfolded verdicts may drop from the event tail',
        subDomain: 'compaction',
      );
    }

    // 1b. Compaction (ADR 0017) — the shared per-wake memory pipeline: flag
    // read fresh each wake, fold past the trigger watermark with the wake's
    // resolved model, assemble the compacted log, evaluate the read-flip
    // gates. Resolved proposal verdicts join the event substrate as inline
    // events — they interleave chronologically with the content that
    // motivated them and fold into summaries, instead of being re-rendered
    // (and eventually capped away) in a separate prompt section every wake.
    final memoryView = await memory.compactAndAssemble(
      agentId: agentId,
      captureSucceeded: captureSucceeded,
      model: modelId,
      provider: provider,
      at: now,
      threadId: threadId,
      runKey: runKey,
      budget: compactionTailBudgetTokens,
      retainTokens: compactionTailRetainTokens,
      inlineEvents: decisionEventsFromLedger(ledger.resolved),
    );
    final compactedTaskLog = memoryView.compactedLog;
    final useCompactedLog = memoryView.useCompactedLog;

    final lastReport = await agentRepository.getLatestReport(
      agentId,
      AgentReportScopes.current,
    );
    final journalObservations = await agentRepository.getMessagesByKind(
      agentId,
      AgentMessageKind.observation,
    );

    // 2. Build task context from journal domain (independent fetches in
    //    parallel).
    // NOTE: Related-project task enrichment is intentionally disabled here.
    // Injecting sibling-task TLDRs polluted the context window, and the
    // related-task drill-down tool is currently hidden from the LLM until it
    // can be backed by a better retrieval path.
    // With compaction on, the inline log entries are dropped from the task
    // header and supplied instead as `active summary + uncovered tail` from
    // the captured log (the read-flip).
    final (
      taskDetails,
      projectContextJson,
      linkedTasksJson,
    ) = await (
      // Compacted wakes get the task STATE as compact markdown (the log is
      // event material supplied separately); legacy wakes keep the full JSON
      // header with the inline log entries.
      useCompactedLog
          ? this.aiInputRepository.buildTaskStateMarkdown(taskId)
          : this.aiInputRepository.buildTaskDetailsJson(id: taskId),
      this.aiInputRepository.buildProjectContextJsonForTask(taskId),
      _buildLinkedTasksContextJson(taskId),
    ).wait;

    if (taskDetails == null) {
      _log('task not found in journal — aborting wake', subDomain: 'execute');
      return const WakeResult(success: false, error: 'Task not found');
    }
    final taskAttentionContext = await _maintainAndLoadAttentionClaims(
      agentId: agentId,
      taskId: taskId,
    );

    // 5. Assemble conversation context (the ledger was fetched before
    // compaction, which consumes its resolved entries as decision events).
    final pendingSets = ledger.pendingSets;

    final systemPrompt = _buildSystemPrompt(templateCtx);
    final builtMessage = await _buildUserMessage(
      agentId: agentId,
      hasReport: lastReport != null,
      journalObservations: journalObservations,
      taskDetails: taskDetails,
      projectContextJson: projectContextJson,
      linkedTasksJson: linkedTasksJson,
      triggerTokens: triggerTokens,
      taskId: taskId,
      ledger: ledger,
      attentionClaims: taskAttentionContext.claims,
      task: taskAttentionContext.task,
      timeService: getIt<TimeService>(),
      // Only attach the compacted log when we're actually using it (the inline
      // log was dropped); otherwise the full inline log already carries it.
      compactedTaskLog: useCompactedLog ? compactedTaskLog : null,
    );
    final userMessage = builtMessage.text;

    // 6. Create conversation and run with strategy.
    final conversationId = conversationRepository.createConversation(
      systemMessage: systemPrompt,
      maxTurns: agentIdentity.config.maxTurnsPerWake,
    );

    // 6a. Persist the prompts for inspectability before sending to the LLM.
    // The system prompt is content-addressed: one payload per DISTINCT prompt
    // text (it only changes when the template/soul/scaffold change, so storage
    // does not grow per wake), referenced from each wake by a `system` message
    // with a `contentEntryId` so the conversation view can expand it. In the
    // actual LLM request the system prompt is always messages[0] — this row is
    // audit/inspection only.
    try {
      final systemPromptContent = <String, Object?>{
        'role': 'system',
        'text': systemPrompt,
      };
      final systemPromptPayloadId = ContentDigest.of(systemPromptContent);
      if (await agentRepository.getEntity(systemPromptPayloadId) == null) {
        await syncService.upsertEntity(
          AgentDomainEntity.agentMessagePayload(
            id: systemPromptPayloadId,
            agentId: AgentInputCaptureService.sharedContentAgentId,
            createdAt: now,
            vectorClock: null,
            content: systemPromptContent,
          ),
        );
      }
      // NB: a `system` message WITH a contentEntryId is how the conversation
      // UI identifies the prompt row (`_displayRank` ordering and the
      // "System Prompt" badge both key on it) — keep `system`-kind
      // bookkeeping rows (milestones, retractions) payload-free.
      await syncService.upsertEntity(
        AgentDomainEntity.agentMessage(
          id: TaskAgentWorkflow._uuid.v4(),
          agentId: agentId,
          threadId: threadId,
          kind: AgentMessageKind.system,
          createdAt: now,
          vectorClock: null,
          contentEntryId: systemPromptPayloadId,
          metadata: AgentMessageMetadata(runKey: runKey),
        ),
      );
    } catch (e) {
      _logError('failed to persist system prompt', error: e);
      // Non-fatal: continue with execution even if audit fails.
    }
    try {
      final userPayloadId = TaskAgentWorkflow._uuid.v4();
      // ADR 0020 v2 prompt records: when the read flipped, the embedded log
      // block is a pure function of the synced event log — store only the
      // non-derivable halves plus the reconstruction marker, instead of the
      // whole prompt. Legacy wakes (live journal render) keep the full blob.
      final logStart = builtMessage.logStart;
      final logEnd = builtMessage.logEnd;
      final userPayloadContent = (logStart != null && logEnd != null)
          ? encodePromptRecord(
              head: userMessage.substring(0, logStart),
              tail: userMessage.substring(logEnd),
              summaryId: memoryView.activeSummaryId,
              until: memoryView.lastEventPosition,
            )
          : <String, Object?>{'text': userMessage};
      await syncService.upsertEntity(
        AgentDomainEntity.agentMessagePayload(
          id: userPayloadId,
          agentId: agentId,
          createdAt: now,
          vectorClock: null,
          content: userPayloadContent,
        ),
      );
      await syncService.upsertEntity(
        AgentDomainEntity.agentMessage(
          id: TaskAgentWorkflow._uuid.v4(),
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
        journalRepository: this.journalRepository,
        checklistRepository: this.checklistRepository,
        labelsRepository: labelsRepository,
        persistenceLogic: getIt<PersistenceLogic>(),
        timeService: getIt<TimeService>(),
        taskAgentService: taskAgentService,
        projectRepository: this.projectRepository,
        agentRepository: agentRepository,
        syncService: syncService,
        requestingAgentId: agentId,
      );

      final changeSetBuilder = ChangeSetBuilder(
        agentId: agentId,
        taskId: taskId,
        threadId: threadId,
        runKey: runKey,
        domainLogger: domainLogger,
        checklistItemStateResolver: (itemId) async {
          final entity = await journalDb.journalEntityById(itemId);
          if (entity is ChecklistItem) {
            return (
              title: entity.data.title,
              isChecked: entity.data.isChecked,
              isArchived: entity.data.isArchived,
            );
          }
          return null;
        },
        existingChecklistTitlesResolver: () async {
          final entity = await journalDb.journalEntityById(taskId);
          if (entity is! Task) return {};
          final items = await this.checklistRepository.getChecklistItemsForTask(
            task: entity,
          );
          return items
              .map((item) => item.data.title.toLowerCase().trim())
              .toSet();
        },
        labelNameResolver: (labelId) async {
          final label = await journalDb.getLabelDefinitionById(labelId);
          return label?.name;
        },
        existingLabelIdsResolver: () async {
          final entity = await journalDb.journalEntityById(taskId);
          return entity?.meta.labelIds?.toSet() ?? {};
        },
      );

      final retractionService = SuggestionRetractionService(
        syncService: syncService,
        domainLogger: domainLogger,
        onChangeSetRetracted:
            changeSetNotificationService?.syncAfterAgentRetraction,
      );

      final strategy = TaskAgentStrategy(
        executor: executor,
        syncService: syncService,
        agentId: agentId,
        threadId: threadId,
        runKey: runKey,
        taskId: taskId,
        changeSetBuilder: changeSetBuilder,
        retractionService: retractionService,
        resolveTaskMetadata: () =>
            ChangeProposalFilter.resolveTaskMetadata(journalDb, taskId),
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
        // The completed entries that `update_time_entry` may target — the same
        // set rendered in the "Editable Time Entries" prompt section. A
        // referenced entryId outside this set is a hallucinated id.
        resolveEditableTimeEntryIds: () async {
          final timeService = getIt<TimeService>();
          final runningId = timeService.getCurrent()?.meta.id;
          final linked = await journalDb.getLinkedEntities(taskId);
          return linked
              .whereType<JournalEntry>()
              .where((entry) => entry.meta.id != runningId)
              .map((entry) => entry.meta.id)
              .toSet();
        },
        // The id of the timer running for THIS task (mirrors the same-task
        // branch of the "Active Running Timer" prompt section), or null.
        resolveRunningTimerId: () async {
          final timeService = getIt<TimeService>();
          final current = timeService.getCurrent();
          if (current is! JournalEntry) return null;
          return timeService.linkedFrom?.id == taskId ? current.meta.id : null;
        },
      );

      final tools = _buildToolDefinitions();
      final inferenceRepo = CloudInferenceWrapper(
        cloudRepository: this.cloudInferenceRepository,
        geminiThinkingMode: resolvedProfile.thinkingModel?.geminiThinkingMode,
      );

      // Record template + soul provenance and the resolved model on the wake
      // run log entry so that modelIdForThread can return an accurate model
      // even for failed/incomplete wakes that never persist token usage.
      try {
        await agentRepository.updateWakeRunTemplate(
          runKey,
          templateCtx.template.id,
          templateCtx.version.id,
          resolvedModelId: modelId,
          soulId: templateCtx.soulVersion?.agentId,
          soulVersionId: templateCtx.soulVersion?.id,
        );
      } catch (e) {
        _logError('failed to record template provenance', error: e);
        // Non-fatal: the wake can proceed without provenance tracking.
      }

      // 7. Invoke the LLM and execute tool calls via AgentToolExecutor.
      var usage = await conversationRepository.sendMessage(
        conversationId: conversationId,
        message: userMessage,
        model: modelId,
        provider: provider,
        inferenceRepo: inferenceRepo,
        tools: tools,
        temperature: 0.3,
        strategy: strategy,
      );

      // 7b. Forced-report retry — only to bootstrap the FIRST report. Once a
      // report exists, skipping `update_report` is a legitimate "nothing
      // materially changed" outcome, not a contract violation.
      if (lastReport == null && strategy.extractReportContent().isEmpty) {
        final retryUsage = await _forceUpdateReportIfMissing(
          conversationId: conversationId,
          modelId: modelId,
          provider: provider,
          inferenceRepo: inferenceRepo,
          tools: tools,
          strategy: strategy,
        );
        if (retryUsage != null) {
          usage = usage == null ? retryUsage : usage.merge(retryUsage);
        }
      }

      // Persist token usage as a synced entity (non-fatal on failure).
      await _persistTokenUsage(
        usage: usage,
        agentId: agentId,
        runKey: runKey,
        threadId: threadId,
        modelId: modelId,
        templateCtx: templateCtx,
        now: now,
      );

      // Capture the final assistant response from the conversation manager.
      final manager = conversationRepository.getConversation(conversationId);
      final finalContent = _extractFinalAssistantContent(manager);
      strategy.recordFinalResponse(finalContent);

      // 7–11. Persist all wake outputs atomically. Wrapping in a transaction
      // ensures the state revision is only bumped if all outputs (thought,
      // report, observations) are successfully written.
      final reportContent = strategy.extractReportContent();
      final reportTldr = strategy.extractReportTldr();
      final reportOneLiner = strategy.extractReportOneLiner();
      if (reportContent.isEmpty && lastReport == null) {
        // Only the FIRST report is mandatory; afterwards an empty report
        // means "nothing materially changed" and the prior one stands.
        _log(
          'no initial report published despite forced retry',
          subDomain: 'execute',
        );
      }

      final observations = strategy.extractObservations();

      final reportToEmbed =
          await WakeOutputWriter(
            syncService: syncService,
            agentRepository: agentRepository,
          ).persist(
            strategy: strategy,
            reportContent: reportContent,
            reportTldr: reportTldr,
            reportOneLiner: reportOneLiner,
            observations: observations,
            retractionService: retractionService,
            changeSetBuilder: changeSetBuilder,
            ledger: ledger,
            pendingSets: pendingSets,
            state: state,
            taskId: taskId,
            agentId: agentId,
            threadId: threadId,
            runKey: runKey,
            now: now,
          );

      // 9b. Embed the report for vector search (fire-and-forget).
      // Runs after the transaction commits so we never embed rolled-back data.
      final embed = reportToEmbed;
      if (embed != null) {
        unawaited(
          _embedAgentReport(
            reportId: embed.reportId,
            reportContent: embed.reportContent,
            taskId: embed.taskId,
            previousReportId: embed.previousReportId,
          ),
        );
      }

      developer.log(
        'Wake completed for agent $agentId: '
        '${observations.length} observations, '
        '${executor.mutatedEntries.length} mutations, '
        '${changeSetBuilder.items.length} deferred changes',
        name: 'TaskAgentWorkflow',
      );

      return WakeResult(
        success: true,
        mutatedEntries: executor.mutatedEntries,
      );
    } catch (e, s) {
      _logError('wake failed', error: e, stackTrace: s);

      // Update failure count in state.
      try {
        await syncService.upsertEntity(
          state.copyWith(
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
      // 12. Clean up in-memory conversation to prevent resource leaks.
      conversationRepository.deleteConversation(conversationId);
    }
  }
}
