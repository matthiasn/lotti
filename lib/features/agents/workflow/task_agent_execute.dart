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
    final preparationTimer = Stopwatch()..start();
    final conversationTimer = Stopwatch();
    final persistenceTimer = Stopwatch();

    logInfo(
      'wake start: agent=${DomainLogger.sanitizeId(agentId)}, '
      'triggers=${triggerTokens.length}',
      subDomain: 'execute',
    );

    // 1. Load current state + both memory types. The wake acts on the
    // log-reconciled state (PR 4 B6), so a watermark/slot the cache lost to LWW
    // self-heals before the agent decides anything.
    final state = await syncService.reconciledAgentState(agentId);
    if (state == null) {
      logInfo('no agent state found — aborting wake', subDomain: 'execute');
      return const WakeResult(success: false, error: 'No agent state found');
    }

    final taskId = state.slots.activeTaskId;
    if (taskId == null) {
      logInfo('no active task ID — aborting wake', subDomain: 'execute');
      return const WakeResult(success: false, error: 'No active task ID');
    }

    logInfo(
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
    final (:sources, :linkedEntityIds) = await _renderWakeSources(taskId);

    var captureSucceeded = false;
    final renderedSources = sources;
    if (inputCaptureService != null && renderedSources != null) {
      captureSucceeded = await memory.capture(
        agentId: agentId,
        sources: renderedSources,
        at: now,
        threadId: threadId,
        runKey: runKey,
      );
    }

    // 2. Resolve the agent's template and active version. (Resolved before
    // compaction so the summarizer can use the wake's own model.)
    final templateCtx = await resolveAgentTemplateContext(
      templateService: templateService,
      soulDocumentService: soulDocumentService,
      agentId: agentId,
      onTrace: (message) => logInfo(message, subDomain: 'resolve'),
    );
    if (templateCtx == null) {
      logInfo('no template assigned — aborting wake', subDomain: 'execute');
      return const WakeResult(
        success: false,
        error: 'No template assigned to agent',
      );
    }

    logInfo(
      'template=${DomainLogger.sanitizeId(templateCtx.template.id)}, '
      'version=${DomainLogger.sanitizeId(templateCtx.version.id)}, '
      'model=${templateCtx.version.modelId ?? templateCtx.template.modelId}',
      subDomain: 'execute',
    );

    // 3. Resolve inference profile (or legacy modelId) → provider.
    final profileResolver = ProfileResolver(
      aiConfigRepository: this.aiConfigRepository,
      domainLogger: domainLogger,
    );
    final resolvedSetup = await profileResolver.resolveDetailed(
      agentConfig: agentIdentity.config,
      template: templateCtx.template,
      version: templateCtx.version,
    );
    final resolvedProfile = resolvedSetup.profile;
    if (resolvedProfile == null) {
      if (agentIdentity.config.inferenceSetup != null) {
        logInfo(
          'typed inference setup is ${resolvedSetup.status.name} — aborting wake',
          subDomain: 'execute',
        );
        return WakeResult(
          success: false,
          error: 'Inference setup is ${resolvedSetup.status.name}',
        );
      }
      final modelId =
          templateCtx.version.modelId ?? templateCtx.template.modelId;
      logInfo(
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

    // 3a. Unchanged-input gate: an automatic wake whose inputs match the last
    // completed wake's would show the model the same task again, so it ends
    // here, before compaction, prompt assembly and inference. The completed
    // run keeps the report fresh and carries the fingerprint forward.
    if (renderedSources != null) {
      final skipped = await _recordInputFingerprint(
        agentId: agentId,
        taskId: taskId,
        runKey: runKey,
        sources: renderedSources,
        linkedEntityIds: linkedEntityIds,
        templateCtx: templateCtx,
        modelId: modelId,
      );
      if (skipped) return const WakeResult(success: true);
    }
    final runSnapshot = InferenceRunSnapshot(
      runKey: runKey,
      threadId: threadId,
      setupSource: resolvedSetup.source,
      setupOrigin: resolvedSetup.setupOrigin,
      profileId:
          agentIdentity.config.inferenceSetup?.baseProfileId ??
          agentIdentity.config.profileId,
      executor: InferenceRouteSnapshot.fromResolvedProfile(resolvedProfile),
    );

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
      logInfo(
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
    final journalObservations = await recallAgentObservations(
      agentRepository,
      agentId,
      limit: taskObservationLookback,
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
      categoryKnowledge,
      pullRequestsContext,
    ) = await (
      // Compacted wakes get the task STATE as compact markdown (the log is
      // event material supplied separately); legacy wakes keep the full JSON
      // header with the inline log entries.
      useCompactedLog
          ? this.aiInputRepository.buildTaskStateMarkdown(taskId)
          : this.aiInputRepository.buildTaskDetailsJson(id: taskId),
      this.aiInputRepository.buildProjectContextJsonForTask(taskId),
      _buildLinkedTasksContextJson(taskId),
      this.aiInputRepository.buildCategoryKnowledge(taskId),
      _buildPullRequestsContext(taskId),
    ).wait;

    if (taskDetails == null) {
      logInfo(
        'task not found in journal — aborting wake',
        subDomain: 'execute',
      );
      return const WakeResult(success: false, error: 'Task not found');
    }
    final taskAttentionContext = await _maintainAndLoadAttentionClaims(
      agentId: agentId,
      taskId: taskId,
    );

    // 5. Assemble conversation context (the ledger was fetched before
    // compaction, which consumes its resolved entries as decision events).
    final pendingSets = ledger.pendingSets;

    // The report's prose is withheld from the model, so a status change the
    // user made since it was written (IN PROGRESS → DONE) is computed here
    // rather than left for the model to notice.
    final statusTransition = TaskAgentReportPolicy.statusTransitionSinceReport(
      task: taskAttentionContext.task?.data,
      reportCreatedAt: lastReport?.createdAt,
    );
    if (statusTransition != null) {
      logInfo(
        'status changed since last report: '
        '${statusTransition.from} → ${statusTransition.to}',
        subDomain: 'execute',
      );
    }

    final systemPrompt = _buildSystemPrompt(templateCtx, modelId: modelId);
    final builtMessage = await _buildUserMessage(
      agentId: agentId,
      hasReport: lastReport != null,
      journalObservations: journalObservations,
      taskDetails: taskDetails,
      projectContextJson: projectContextJson,
      linkedTasksJson: linkedTasksJson,
      categoryKnowledge: categoryKnowledge,
      pullRequestsContext: pullRequestsContext,
      triggerTokens: triggerTokens,
      taskId: taskId,
      ledger: ledger,
      attentionClaims: taskAttentionContext.claims,
      task: taskAttentionContext.task,
      timeService: getIt<TimeService>(),
      // Only attach the compacted log when we're actually using it (the inline
      // log was dropped); otherwise the full inline log already carries it.
      compactedTaskLog: useCompactedLog ? compactedTaskLog : null,
      statusTransition: statusTransition,
    );
    final userMessage = builtMessage.text;

    // 6. Create conversation and run with strategy.
    final conversationId = conversationRepository.createConversation(
      systemMessage: systemPrompt,
      maxTurns: agentIdentity.config.maxTurnsPerWake,
    );

    // 6a. Persist the prompts for inspectability before sending to the LLM.
    await _persistWakePrompts(
      agentId: agentId,
      threadId: threadId,
      runKey: runKey,
      now: now,
      systemPrompt: systemPrompt,
      builtMessage: builtMessage,
      memoryView: memoryView,
    );

    // Visible to the failure path below: incremental flushes commit as they
    // go, so a wake that dies later still has suggestions on disk that need
    // finalizing.
    ChangeSetBuilder? flushedChangeSets;

    try {
      final executor = AgentToolExecutor(
        syncService: syncService,
        allowedCategoryIds: agentIdentity.allowedCategoryIds,
        runKey: runKey,
        agentId: agentId,
        threadId: threadId,
        domainLogger: domainLogger,
      );

      final changeSetBuilder = _buildChangeSetBuilder(
        agentId: agentId,
        taskId: taskId,
        threadId: threadId,
        runKey: runKey,
      );

      flushedChangeSets = changeSetBuilder;

      final retractionService = SuggestionRetractionService(
        syncService: syncService,
        domainLogger: domainLogger,
        onChangeSetRetracted:
            changeSetNotificationService?.syncAfterAgentRetraction,
      );

      // Only compute the gating facts when the flag is on: each is a real
      // query, and a wake that will advertise everything anyway should not pay
      // for the answers.
      final wakeFacts = narrowToolSurface
          ? await _resolveWakeFacts(
              taskId: taskId,
              ledger: ledger,
              attentionClaims: taskAttentionContext.claims,
            )
          : TaskAgentWakeFacts.permissive;
      final tools = _contextBuilder.buildToolDefinitions(facts: wakeFacts);

      final strategy = _buildStrategy(
        tools: tools,
        executor: executor,
        agentId: agentId,
        threadId: threadId,
        runKey: runKey,
        taskId: taskId,
        changeSetBuilder: changeSetBuilder,
        ledger: ledger,
        retractionService: retractionService,
      );

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
        logError('failed to record template provenance', error: e);
        // Non-fatal: the wake can proceed without provenance tracking.
      }

      // Resolve consumption owner ids only when a recorder is wired, so the
      // wake path (and its DB reads) is untouched when tracking is off.
      final recordConsumption = getIt.isRegistered<AiInteractionCapture>();
      final consumptionCategoryId = recordConsumption
          ? (await journalDb.journalEntityById(taskId))?.categoryId
          : null;

      // 7. Invoke the LLM and execute tool calls via AgentToolExecutor.
      final inferenceTemperature =
          TaskAgentEvidenceSynthesis.usesCompactScaffold(modelId) ? 0.0 : 0.3;
      preparationTimer.stop();
      conversationTimer.start();
      var usage = await conversationRepository.sendMessage(
        conversationId: conversationId,
        message: userMessage,
        model: modelId,
        provider: provider,
        inferenceRepo: inferenceRepo,
        tools: tools,
        temperature: inferenceTemperature,
        strategy: strategy,
        consumptionAgentId: recordConsumption ? agentId : null,
        consumptionTaskId: recordConsumption ? taskId : null,
        consumptionCategoryId: consumptionCategoryId,
        consumptionWakeRunKey: recordConsumption ? runKey : null,
        consumptionThreadId: recordConsumption ? threadId : null,
        rethrowInferenceErrors: true,
      );

      // 7b. First reports and material mutations require publication. Label
      // and language housekeeping alone preserve an existing report; a status
      // change since the last report never does.
      final reportMissing = strategy.extractReportContent().isEmpty;
      final reportWasRequired = TaskAgentReportPolicy.requiresReport(
        hasExistingReport: lastReport != null,
        taskStatusChanged: statusTransition != null,
        successfulToolNames: strategy.extractSuccessfulMutations().map(
          (mutation) => mutation.toolName,
        ),
      );
      if (reportMissing && reportWasRequired) {
        final retryUsage = await _forceUpdateReportIfMissing(
          conversationId: conversationId,
          modelId: modelId,
          provider: provider,
          inferenceRepo: inferenceRepo,
          tools: tools,
          strategy: strategy,
          consumptionAgentId: recordConsumption ? agentId : null,
          consumptionTaskId: recordConsumption ? taskId : null,
          consumptionCategoryId: consumptionCategoryId,
          consumptionWakeRunKey: recordConsumption ? runKey : null,
          consumptionThreadId: recordConsumption ? threadId : null,
          temperature: inferenceTemperature,
        );
        if (retryUsage != null) {
          usage = usage == null ? retryUsage : usage.merge(retryUsage);
        }
      }

      final (
        report: effectiveReport,
        editorUsage: reportEditorUsage,
        outcome: reportFinalizerOutcome,
      ) = await _finalizeReport(
        strategy: strategy,
        provider: provider,
        modelId: modelId,
        inferenceRepo: inferenceRepo,
        task: taskAttentionContext.task,
        reportWasRequired: reportWasRequired,
        templateCtx: templateCtx,
        recordConsumption: recordConsumption,
        consumptionCategoryId: consumptionCategoryId,
        agentId: agentId,
        taskId: taskId,
        runKey: runKey,
        threadId: threadId,
      );

      conversationTimer.stop();
      persistenceTimer.start();

      // Persist token usage as a synced entity (non-fatal on failure).
      await persistWakeTokenUsage(
        syncService: syncService,
        usage: usage,
        agentId: agentId,
        runKey: runKey,
        threadId: threadId,
        modelId: modelId,
        templateCtx: templateCtx,
        now: now,
        logError: logError,
      );
      await persistWakeTokenUsage(
        syncService: syncService,
        usage: reportEditorUsage,
        agentId: agentId,
        runKey: runKey,
        threadId: threadId,
        modelId: meliousQwen35122BA10BModelId,
        templateCtx: templateCtx,
        now: now,
        logError: logError,
      );

      // Capture the final assistant response from the conversation manager.
      final manager = conversationRepository.getConversation(conversationId);
      final finalContent = manager?.finalAssistantContent;
      strategy.recordFinalResponse(finalContent);

      // 7–11. Persist all wake outputs atomically. Wrapping in a transaction
      // ensures the state revision is only bumped if all outputs (thought,
      // report, observations) are successfully written.
      final reportContent = TaskAgentReportPolicy.withoutPublicationNoise(
        effectiveReport?.content ?? strategy.extractReportContent(),
      );
      final draftTldr = effectiveReport?.tldr ?? strategy.extractReportTldr();
      final reportTldr = draftTldr == null
          ? null
          : TaskAgentReportPolicy.withoutPublicationNoise(draftTldr);
      final reportOneLiner =
          effectiveReport?.oneLiner ?? strategy.extractReportOneLiner();
      if (reportContent.isEmpty && reportWasRequired) {
        // Initial wakes and material mutations require a current report.
        // An empty report is valid only when an existing projection remains
        // authoritative because the wake applied no material change.
        logInfo(
          'no required report published despite forced retry',
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
            reportProvenance: _reportProvenance(
              runSnapshot,
              reportFinalizerOutcome,
            ),
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

      domainLogger.log(
        LogDomain.agentWorkflow,
        'Wake completed for agent $agentId: '
        '${observations.length} observations, '
        '${executor.mutatedEntries.length} mutations, '
        '${changeSetBuilder.items.length} deferred changes',
        subDomain: 'TaskAgentWorkflow',
      );

      return WakeResult(
        success: true,
        mutatedEntries: executor.mutatedEntries,
      );
    } catch (e, s) {
      logError('wake failed', error: e, stackTrace: s);

      // Suggestions flushed mid-wake are already committed and stay visible;
      // `WakeOutputWriter` never ran, so nothing else will raise their inbox
      // alert. Consolidation is deliberately NOT attempted here: it retires
      // the pre-wake sets, and the staged retractions that would have to land
      // first die with this wake. The surplus card is folded by the next
      // wake's end-of-wake build instead.
      // `raiseInboxAlert` swallows its own failures — it must never mask the
      // error that actually killed the wake.
      await flushedChangeSets?.raiseInboxAlert(
        syncService,
        unconsolidatedSets: pendingSets,
      );

      // Update failure count in state, over the row as it is now rather than
      // the wake-start snapshot (ADR 0068).
      try {
        await syncService.updateAgentState(
          agentId,
          (current) => current.copyWith(
            updatedAt: now,
            consecutiveFailureCount: current.consecutiveFailureCount + 1,
          ),
        );
      } catch (stateError, s) {
        logError(
          'failed to update failure count',
          error: stateError,
          stackTrace: s,
        );
      }

      return WakeResult.failed(kind: 'Task agent', error: e);
    } finally {
      preparationTimer.stop();
      conversationTimer.stop();
      persistenceTimer.stop();
      logInfo(
        'wake stages: agent=${DomainLogger.sanitizeId(agentId)} '
        'run=${DomainLogger.sanitizeId(runKey)} '
        'preparationMs=${preparationTimer.elapsedMilliseconds} '
        'modelToolsMs=${conversationTimer.elapsedMilliseconds} '
        'persistenceMs=${persistenceTimer.elapsedMilliseconds}',
        subDomain: 'timings',
      );
      // 12. Clean up in-memory conversation to prevent resource leaks.
      conversationRepository.deleteConversation(conversationId);
    }
  }

  /// The facts that decide which tools this wake advertises.
  ///
  /// Each is a question the app can answer itself. `hasNewerContentThanReport`
  /// is deliberately left permissive: a note that arrived saying nothing new is
  /// still newer than the report, and materiality is not something timestamps
  /// can judge, so gating `update_report` on it would withhold the tool from
  /// wakes that genuinely need it.
  Future<TaskAgentWakeFacts> _resolveWakeFacts({
    required String taskId,
    required ProposalLedger ledger,
    required List<AttentionRequestEntity> attentionClaims,
  }) async {
    final entity = await journalDb.journalEntityById(taskId);
    final task = entity is Task ? entity : null;

    // A timer running for this task is linked from it like any other entry,
    // so its text is editable too; one belonging to another task is not.
    final linked = await journalDb.getLinkedEntities(taskId);
    final hasTimeRecords = linked.whereType<JournalEntry>().isNotEmpty;

    final labelDefinitions = await journalDb.getAllLabelDefinitions();

    return TaskAgentWakeFacts(
      // A null `checklistIds` and an empty one both mean "no checklists"
      // everywhere else in the app, and a task that never had one carries null
      // — so only an unresolvable task stays permissive here. Coalescing the
      // null to `true` would leave the gate dead for the common case.
      hasChecklistItems:
          task == null || (task.data.checklistIds?.isNotEmpty ?? false),
      hasTimeRecords: hasTimeRecords,
      hasLabelDefinitions: labelDefinitions.isNotEmpty,
      hasOpenProposals: ledger.open.isNotEmpty,
      hasActiveAttentionClaims: attentionClaims.isNotEmpty,
    );
  }

  /// Fingerprints this wake's inputs (see [taskWakeInputFingerprint]) and
  /// records the fingerprint on the run, returning whether the wake should
  /// be skipped as unchanged. [linkedEntityIds] are the task's outgoing
  /// links; the incoming ones are looked up here.
  ///
  /// Only automatic subscription wakes are skipped. Manual, creation,
  /// scheduled and transcript wakes always run — someone or something asked
  /// for them — but still record their fingerprint, so a no-op edit right
  /// after an "Update now" is recognised. Any failure means "changed": the
  /// gate never costs a wake that should have run.
  Future<bool> _recordInputFingerprint({
    required String agentId,
    required String taskId,
    required String runKey,
    required List<RenderedSource> sources,
    required Set<String> linkedEntityIds,
    required AgentTemplateContext templateCtx,
    required String modelId,
  }) async {
    try {
      final taskState = await this.aiInputRepository.buildTaskStateMarkdown(
        taskId,
        includeTimeSpent: false,
      );
      if (taskState == null) return false;
      final fingerprint = taskWakeInputFingerprint(
        taskState: taskState,
        sources: sources,
        linkedEntityIds: {
          ...linkedEntityIds,
          for (final entity in await journalDb.getLinkedToEntities(taskId))
            entity.id,
        },
        categoryKnowledge: await this.aiInputRepository.buildCategoryKnowledge(
          taskId,
        ),
        templateVersionId: templateCtx.version.id,
        soulVersionId: templateCtx.soulVersion?.id,
        modelId: modelId,
      );
      final run = await agentRepository.getWakeRunByRunKey(runKey);
      final previous = await agentRepository
          .getLatestCompletedWakeInputFingerprint(agentId);
      await agentRepository.updateWakeRunInputFingerprint(runKey, fingerprint);
      final skip =
          run?.reason == WakeReason.subscription.name &&
          previous == fingerprint;
      if (skip) {
        logInfo(
          'inputs unchanged since the last completed wake — skipping',
          subDomain: 'execute',
        );
      }
      return skip;
    } catch (e) {
      logError('failed to fingerprint wake inputs', error: e);
      return false;
    }
  }
}
