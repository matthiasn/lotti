part of 'relationship_agent_workflow.dart';

/// Private helpers of [RelationshipAgentWorkflow] that hold no state of their own; kept beside the class as an extension so the library stays readable.
extension _RelationshipAgentWorkflowInternals on RelationshipAgentWorkflow {
  /// Near-duplicate dedupe key over the copy (the goal `briefDigest`).
  String _briefDigest(NudgeBrief brief) => const Uuid().v5(
    Namespace.url.value,
    'lotti://relationship-ad/${brief.headline.toLowerCase().trim()}/'
    '${brief.tagline?.toLowerCase().trim() ?? ''}',
  );

  bool _dismissedToday(List<RelationshipNudgeEntity> nudges, DateTime now) {
    for (final nudge in nudges) {
      final dismissedAt = nudge.dismissedForDayAt ?? nudge.dismissedAt;
      if (dismissedAt == null) continue;
      final local = dismissedAt.toLocal();
      if (local.year == now.year &&
          local.month == now.month &&
          local.day == now.day) {
        return true;
      }
    }
    return false;
  }

  Future<InferenceUsage?> _forceInstruction({
    required String conversationId,
    required RelationshipModelResolution resolved,
    required CloudInferenceWrapper inferenceRepo,
    required List<ChatCompletionTool> tools,
    required RelationshipAgentStrategy strategy,
    required bool recordConsumption,
    required String agentId,
    required String runKey,
    required String threadId,
    required String instruction,
  }) async {
    try {
      return await _conversationRepository.sendMessage(
        conversationId: conversationId,
        message: instruction,
        model: resolved.modelId,
        provider: resolved.provider,
        inferenceRepo: inferenceRepo,
        tools: tools,
        temperature: 0,
        strategy: strategy,
        consumptionAgentId: recordConsumption ? agentId : null,
        consumptionWakeRunKey: recordConsumption ? runKey : null,
        consumptionThreadId: recordConsumption ? threadId : null,
        rethrowInferenceErrors: true,
      );
    } catch (error, stackTrace) {
      // The retry is best-effort: the primary pass already succeeded and
      // its outputs must persist regardless.
      logError(
        'pinned relationship retry failed',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  Future<void> _persistFactsMessage({
    required String agentId,
    required String threadId,
    required String runKey,
    required String text,
    required DateTime now,
  }) async {
    final payloadId = RelationshipAgentWorkflow._uuid.v4();
    await _syncService.upsertEntity(
      AgentDomainEntity.agentMessagePayload(
        id: payloadId,
        agentId: agentId,
        createdAt: now,
        vectorClock: null,
        content: <String, Object?>{'text': text},
      ),
    );
    await _syncService.upsertEntity(
      AgentDomainEntity.agentMessage(
        id: RelationshipAgentWorkflow._uuid.v4(),
        agentId: agentId,
        threadId: threadId,
        kind: AgentMessageKind.system,
        createdAt: now,
        vectorClock: null,
        contentEntryId: payloadId,
        metadata: AgentMessageMetadata(runKey: runKey),
      ),
    );
  }
}

/// Wake bookkeeping: stamping the outcome and re-arming a consumed escalation.
extension _RelationshipWakeBookkeeping on RelationshipAgentWorkflow {
  /// Stamps the wake's outcome on the agent's state row
  /// ([relationshipWakeOutcome]) — what the person page's agent card reads
  /// to show *failed* with the reason and the fix, the maintenance pass
  /// reads as backed off, and the internals' Stats tab reads as the last
  /// wake. Stamped with the instant the wake ENDS, read here rather than
  /// taken from the wake's start: a short failure that began after a long
  /// success began must not outrank it. A transform of the row as it is now
  /// (ADR 0068). Contained: a state write that fails is logged and never
  /// changes the wake's own verdict. No state row (the agent is
  /// mid-creation) means nothing to stamp.
  Future<void> _stampWakeOutcome({
    required String agentId,
    required bool succeeded,
  }) async {
    try {
      await _syncService.updateAgentState(
        agentId,
        (current) => relationshipWakeOutcome(
          current,
          now: clock.now(),
          succeeded: succeeded,
        ),
      );
    } catch (error, stackTrace) {
      logError(
        'failed to stamp the wake outcome on the agent state',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Re-arms a consumed escalation after a failure that committed nothing.
  ///
  /// Transient failures retry at `now.toUtc()` — a strictly LATER instant than the
  /// consumed record's, so this rides the resolver's supported
  /// reschedule-beats-consume path (the goal precedent). Rebuilding the
  /// record from the derivation instead would write a pending twin at the
  /// consumed record's own deadline, and consumption is terminal at an
  /// equal instant: any peer's consumed echo would kill the retry.
  /// The ORIGINAL trigger tokens are forwarded verbatim — the baseline
  /// token carries the pre-transition cadence status, which a re-derivation
  /// after Phase A's register write can no longer reconstruct.
  /// Configuration failures back off from one hour to at most one day.
  /// Maintenance can bring the pending retry forward once routing is fixed.
  /// Contained: neither a failed retry-count read nor a failed re-arm masks
  /// the original error.
  Future<void> _rearmEscalation(
    String agentId,
    String escalationWorkspaceKey,
    Set<String> triggerTokens,
    DateTime now, {
    bool configurationFailure = false,
  }) async {
    var failures = 0;
    if (configurationFailure) {
      try {
        failures =
            (await _repository.getAgentState(
              agentId,
            ))?.consecutiveFailureCount ??
            0;
      } catch (error, stackTrace) {
        // A broken counter read must not discard the durable episode.
        // Preserve the retry using the base delay when its streak is unknown.
        logError(
          'failed to read relationship retry count',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    final delay = configurationFailure
        ? Duration(hours: (1 << failures.clamp(0, 5)).clamp(1, 24))
        : Duration.zero;
    await rearmConsumedEscalation(
      syncService: _syncService,
      agentId: agentId,
      workspaceKey: escalationWorkspaceKey,
      triggerTokens: triggerTokens,
      scheduledAt: now.add(delay),
      updatedAt: now,
      logError: logError,
    );
  }
}
