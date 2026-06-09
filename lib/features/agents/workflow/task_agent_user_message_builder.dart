part of 'task_agent_workflow.dart';

/// System-prompt and user-message assembly of [TaskAgentWorkflow].

extension TaskAgentUserMessageBuilder on TaskAgentWorkflow {
  /// Builds the user message for a wake cycle. [taskDetails] is the compact
  /// markdown task state when the read-flip succeeds, or the full JSON header
  /// (inline log included) for fallback prompts. [hasReport] gates the
  /// first-wake report bootstrap section; the prior report's prose is never
  /// injected.
  ///
  /// Returns the full text plus the offsets of the embedded (derivable) log
  /// block, so the persisted prompt record can store only the non-derivable
  /// halves (ADR 0020 v2 prompt records).
  Future<({String text, int? logStart, int? logEnd})> _buildUserMessage({
    required String agentId,
    required bool hasReport,
    required List<AgentMessageEntity> journalObservations,
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
  }) async {
    final buffer = StringBuffer();

    // Ordering is by volatility, least-volatile first, so provider prefix
    // caches survive consecutive wakes. The stable header is label / correction
    // context (rare-change, user-gated) then the compacted task log
    // (append-only between folds), which ends the prefix. Everything that
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
      _logError(
        'failed to build label/correction context',
        error: e,
        stackTrace: s,
      );
      // Non-fatal: continue without context.
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
    // reports (their oneLiner / tldr / createdAt), which change out-of-band
    // with this task's wakes (ADR 0027). They live here in the volatile tail —
    // never in the stable prefix — so a neighbor's republish cannot void this
    // task's warm log/prefix cache. Placed ahead of the ticking task-state so
    // they remain cacheable within the tail on wakes where no neighbor changed.
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

    final activeTimerSection = _buildActiveTimerSection(timeService, taskId);
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

    // Proposal ledger. In compacted mode only the OPEN proposals render here
    // — they are current state (fingerprints for `retract_suggestions`,
    // same-wake dedup) — while resolved verdicts live in the `## Task Log`
    // as decision-tagged events that fold into summaries. Legacy mode keeps
    // the full status-sorted view including resolved history.
    if (!ledger.isEmpty) {
      buffer.writeln(
        _formatProposalLedger(ledger, includeResolved: !useCompactedLog),
      );
    }

    final attentionSection = _formatTaskAttentionRequests(
      attentionClaims,
      agentId: agentId,
    );
    if (attentionSection.isNotEmpty) {
      buffer.write(attentionSection);
    }

    if (journalObservations.isNotEmpty) {
      // Cap to most recent 20 to prevent unbounded context growth.
      // journalObservations is ordered newest-first from the DB query.
      final boundedObservations = journalObservations.length > 20
          ? journalObservations.sublist(0, 20)
          : journalObservations;

      // Batch-resolve all observation payloads in parallel to avoid N+1
      // queries. Used for both the critical section and the journal listing.
      final allPayloads = await _resolveObservationPayloads(
        boundedObservations,
      );

      // Inject prior critical observations first so the agent addresses
      // grievances and excellence notes before routine work.
      TaskAgentWorkflow._writePriorCriticalObservations(
        buffer,
        boundedObservations,
        allPayloads,
      );

      // With compaction on, observations live in the `## Task Log` event tail
      // (interleaved as observation-tagged lines, folded into summaries by
      // the same watermarks) — a separate journal section would duplicate
      // them.
      if (!useCompactedLog) {
        buffer.writeln('## Agent Journal');
        // Reverse so the LLM sees them in chronological order.
        final recentObs = boundedObservations.reversed.toList();

        for (var i = 0; i < recentObs.length; i++) {
          final payload = recentObs[i].contentEntryId != null
              ? allPayloads[recentObs[i].contentEntryId]
              : null;
          final text = TaskAgentWorkflow._extractPayloadText(payload);
          buffer.writeln(
            '- [${recentObs[i].createdAt.toIso8601String()}] $text',
          );
        }
        buffer.writeln();
      }
    }

    // The prior report's PROSE is deliberately NOT injected: the report is a
    // projection of the task log, not agent memory. Re-reading its own stale
    // conclusions as ground truth creates a feedback loop (a wrong "learning"
    // re-published verbatim every wake), and everything report-worthy is
    // already in the log, the observations, and the task state.
    if (!hasReport) {
      buffer
        ..writeln(
          '## First Wake — No prior report exists. '
          'Produce an initial report.',
        )
        ..writeln();
    }

    if (triggerTokens.isNotEmpty) {
      buffer
        ..writeln('## Changed Since Last Wake')
        ..writeln(
          'The following entity IDs changed: ${triggerTokens.join(", ")}',
        )
        ..writeln();
    }

    final openProposalGuard = _formatOpenProposalGuard(ledger);
    if (openProposalGuard.isNotEmpty) {
      buffer.write(openProposalGuard);
    }

    buffer.writeln(
      'Analyze the current state, maintain any attention requests, and call '
      'tools if needed. If the report '
      'would materially change, call `update_report` with the full updated '
      'report; otherwise finish with a brief plain-text note. '
      'Add observations if warranted.',
    );

    return (text: buffer.toString(), logStart: logStart, logEnd: logEnd);
  }
}
