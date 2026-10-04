part of 'task_agent_workflow.dart';

/// The preparation steps of [TaskAgentExecute.executeImpl]: rendering the
/// wake's sources, persisting its prompts, and wiring the change-set builder
/// and conversation strategy it runs with.
extension _TaskAgentExecuteSetup on TaskAgentWorkflow {
  /// Renders the task's linked entities as this wake's sources, together
  /// with the ids of those outgoing links.
  ///
  /// Rendered once: input capture logs these sources, and the
  /// unchanged-input gate fingerprints them. Sources are null when rendering
  /// failed, which skips both rather than aborting the wake.
  Future<({List<RenderedSource>? sources, Set<String> linkedEntityIds})>
  _renderWakeSources(String taskId) async {
    try {
      final linked = await journalDb.getLinkedEntities(taskId);
      // Image AI analyses (summary, OCR, …) are linked from their image,
      // not from the task, so they need their own bulk lookup. A failure
      // here degrades to rendering without analyses rather than skipping
      // the sources altogether.
      var imageAiResponses = const <String, List<AiResponseEntry>>{};
      try {
        imageAiResponses = await fetchAiResponsesForImages(
          db: journalDb,
          linkedEntities: linked,
        );
      } catch (e) {
        logError('failed to fetch image AI responses for capture', error: e);
      }
      final sources = renderTaskSources(
        linked,
        // A running timer's duration is still ticking; capturing it would
        // mint a new content version every wake (see renderTaskSources).
        runningEntryId: getIt<TimeService>().getCurrent()?.meta.id,
        aiResponsesByEntryId: imageAiResponses,
      );
      return (
        sources: sources,
        linkedEntityIds: {for (final entity in linked) entity.meta.id},
      );
    } catch (e) {
      logError('failed to render wake sources', error: e);
    }
    return (sources: null, linkedEntityIds: const <String>{});
  }

  /// Persists the wake's prompts for inspectability before the LLM call.
  ///
  /// The system prompt is content-addressed: one payload per DISTINCT prompt
  /// text (it only changes when the template/soul/scaffold change, so storage
  /// does not grow per wake), referenced from each wake by a `system` message
  /// with a `contentEntryId` so the conversation view can expand it. In the
  /// actual LLM request the system prompt is always messages[0] — this row is
  /// audit/inspection only.
  ///
  /// Both writes are non-fatal: a failed audit row never aborts the wake.
  Future<void> _persistWakePrompts({
    required String agentId,
    required String threadId,
    required String runKey,
    required DateTime now,
    required String systemPrompt,
    required ({String text, int? logStart, int? logEnd}) builtMessage,
    required WakeMemoryView memoryView,
  }) async {
    final userMessage = builtMessage.text;
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
      logError('failed to persist system prompt', error: e);
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
      logError('failed to persist user message', error: e);
      // Non-fatal: continue with execution even if audit fails.
    }
  }

  /// The builder that collects this wake's deferred change proposals,
  /// resolving the base state of checklist items, labels and the task
  /// from the journal.
  ChangeSetBuilder _buildChangeSetBuilder({
    required String agentId,
    required String taskId,
    required String threadId,
    required String runKey,
  }) {
    return ChangeSetBuilder(
      agentId: agentId,
      taskId: taskId,
      threadId: threadId,
      runKey: runKey,
      domainLogger: domainLogger,
      approvedChecklistItemResolver: journalChecklistItemResolver(journalDb),
      checklistItemBaseResolver: journalChecklistItemResolver(journalDb),
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
  }

  /// The conversation strategy for this wake, with the task's tool
  /// dispatcher and the journal lookups its proposal validation needs.
  TaskAgentStrategy _buildStrategy({
    required List<ChatCompletionTool> tools,
    required AgentToolExecutor executor,
    required String agentId,
    required String threadId,
    required String runKey,
    required String taskId,
    required ChangeSetBuilder changeSetBuilder,
    required ProposalLedger ledger,
    required SuggestionRetractionService retractionService,
  }) {
    final pendingSets = ledger.pendingSets;
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

    return TaskAgentStrategy(
      // Withhold `update_report` from the opening turn so the wake does the
      // work before it reports on it. Null when the flag is off, which
      // leaves one fixed tool list for the conversation as before.
      stagedToolExposure: narrowToolSurface
          ? TaskAgentStagedToolExposure(allTools: tools)
          : null,
      executor: executor,
      syncService: syncService,
      agentId: agentId,
      threadId: threadId,
      runKey: runKey,
      taskId: taskId,
      changeSetBuilder: changeSetBuilder,
      // Surface proposals at each turn boundary instead of making the user
      // wait out the report turn, its forced retry and any report-editor
      // pass. `pendingSets` is the pre-wake snapshot: an incremental flush
      // dedups against it but never writes to it — consolidation waits for
      // the end-of-wake build, which runs after staged retractions land.
      //
      // Wrapped in a transaction because a flush is retried on the next
      // turn boundary: a superseded running-timer match writes a
      // `ChangeDecisionEntity` before the change set itself, so a failure
      // in between would otherwise leave that decision behind and the retry
      // would mint a second one for the same match. The end-of-wake build
      // gets its atomicity from `WakeOutputWriter`'s own transaction —
      // `runInTransaction` nests, so both paths are covered exactly once.
      flushChangeSet: () async {
        await syncService.runInTransaction(
          () => changeSetBuilder.build(
            syncService,
            existingPendingSets: pendingSets,
            rejectedFingerprints: ledger.rejectedFingerprints,
            rejectedDisplayKeys: ledger.rejectedDisplayKeys,
            incremental: true,
          ),
        );
        // Writing the change set is not enough to show it: the suggestion
        // providers re-query only when `agentUpdateStreamProvider` emits,
        // and `AgentSyncService` does not notify on upsert. Without this the
        // flush is invisible until `_notifyWakeCompletion` fires after the
        // whole wake returns — which is the wait this feature exists to
        // remove.
        //
        // `notifyUiOnly` rather than `notify`: the latter also feeds
        // `localUpdateStream`, which drives wake orchestration and would let
        // a wake re-trigger itself.
        if (getIt.isRegistered<UpdateNotifications>()) {
          getIt<UpdateNotifications>().notifyUiOnly({
            agentId,
            taskId,
            agentNotification,
          });
        }
      },
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
      // The entries that `update_time_entry` may target — those rendered in
      // the "Editable Time Entries" prompt section plus the running timer
      // of the "Active Running Timer" one, which is linked from this task
      // like any other. A referenced entryId outside this set is a
      // hallucinated id.
      resolveEditableTimeEntryIds: () async {
        final linked = await journalDb.getLinkedEntities(taskId);
        return linked
            .whereType<JournalEntry>()
            .map((entry) => entry.meta.id)
            .toSet();
      },
      // The id of the timer running for THIS task (mirrors the same-task
      // branch of the "Active Running Timer" prompt section), or null. Only
      // its text may be proposed while it runs.
      resolveRunningTimerId: () async {
        final timeService = getIt<TimeService>();
        final current = timeService.getCurrent();
        if (current is! JournalEntry) return null;
        return timeService.linkedFrom?.id == taskId ? current.meta.id : null;
      },
      // The fields an `update_time_entry` proposal records as its base.
      resolveTimeEntryFields: (entryId) async {
        final entity = await journalDb.journalEntityById(entryId);
        return entity is JournalEntry ? timeEntryFields(entity) : null;
      },
      // A `link_task` target must be a live task; anything else is a
      // hallucinated id. Returns the title for the proposal summary.
      resolveLinkableTaskTitle: (targetTaskId) async {
        final entity = await journalDb.journalEntityById(targetTaskId);
        if (entity is! Task || entity.meta.deletedAt != null) return null;
        return entity.data.title;
      },
      // Canonical triples of every live link touching this task, so an
      // already-existing relationship is suppressed instead of re-proposed.
      resolveExistingTaskRelations: () async {
        final links = await journalDb.linksForEntryIdsBidirectional({
          taskId,
        });
        return {
          for (final link in links)
            if (link.deletedAt == null && link.hidden != true)
              TaskAgentChangeHandlers.canonicalRelationTripleOfLink(link),
        };
      },
    );
  }
}
