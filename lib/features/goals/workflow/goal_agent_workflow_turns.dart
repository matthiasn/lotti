part of 'goal_agent_workflow.dart';

/// The turn helpers of [GoalAgentWorkflow]: forcing the ad, report and reply turns, reconciling check-ins, and the user-voice and compaction inputs they read. A private extension because they use the workflow's private deps and are driven by execute.
extension _GoalAgentWorkflowTurns on GoalAgentWorkflow {
  Future<String?> _previousVisibleAssistantText(
    String agentId, {
    required DateTime before,
  }) async {
    final actions =
        (await _repository.getMessagesByKindAndToolName(
              agentId,
              AgentMessageKind.action,
              AgentConversationToolNames.replyToUser,
              limit: 12,
            ))
            .where(
              (message) =>
                  message.deletedAt == null &&
                  !message.createdAt.isAfter(before) &&
                  message.metadata.toolName ==
                      AgentConversationToolNames.replyToUser &&
                  message.contentEntryId != null,
            )
            .toList()
          ..sort((a, b) {
            final byTime = b.createdAt.compareTo(a.createdAt);
            return byTime != 0 ? byTime : b.id.compareTo(a.id);
          });
    for (final action in actions) {
      final payload = await _repository.getEntity(action.contentEntryId!);
      final text =
          payload is AgentMessagePayloadEntity && payload.agentId == agentId
          ? payload.content['text']
          : null;
      if (text is String && text.trim().isNotEmpty) return text.trim();
    }
    return null;
  }

  Future<InferenceUsage?> _forceAd({
    required GoalWakeFacts facts,
    required String conversationId,
    required ({
      String modelId,
      AiConfigInferenceProvider provider,
      GeminiThinkingMode? geminiThinkingMode,
    })
    resolved,
    required CloudInferenceWrapper inferenceRepo,
    required List<ChatCompletionTool> tools,
    required GoalAgentStrategy strategy,
    required String? agentId,
    required String? runKey,
    required String? threadId,
    required bool userRequestedAd,
  }) async {
    try {
      return await _conversationRepository.sendMessage(
        conversationId: conversationId,
        message: userRequestedAd
            ? 'The user explicitly requested a NEW banner ad. Dismissal '
                  'cooldown does not block this user-initiated replacement. '
                  'Call create_goal_ad now; do not refuse or merely promise '
                  'that a banner will appear.'
            : 'The goal is ${facts.trackStatus.name} with no active banner '
                  'and no cooldown — an ad is REQUIRED (policy). Call '
                  'create_goal_ad now (or rerun_goal_ad if the FACTS offered '
                  'a reusable one).',
        model: resolved.modelId,
        provider: resolved.provider,
        inferenceRepo: inferenceRepo,
        tools: [
          for (final tool in tools)
            if (tool.function.name == GoalAgentToolNames.createGoalAd ||
                (!userRequestedAd &&
                    tool.function.name == GoalAgentToolNames.rerunGoalAd))
              tool,
        ],
        toolChoice: userRequestedAd
            ? forcedToolChoiceFor(
                modelId: resolved.modelId,
                toolName: GoalAgentToolNames.createGoalAd,
              )
            : null,
        temperature: 0,
        strategy: strategy,
        consumptionAgentId: agentId,
        consumptionWakeRunKey: runKey,
        consumptionThreadId: threadId,
        rethrowInferenceErrors: true,
      );
    } catch (error) {
      _domainLogger.error(
        LogDomain.agentWorkflow,
        error,
        subDomain: 'goalPhaseB',
        message: 'forced goal ad retry failed',
      );
      return null;
    }
  }

  /// Compacts every check-in whose transcript has arrived but which has no
  /// summary yet.
  ///
  /// Idempotent by construction: the summary id is derived from
  /// `(agentId, entryId)`, so an entry already summarised is skipped and a
  /// retried compaction overwrites rather than appends. Individually
  /// contained — one unreadable recording must not cost the wake the rest of
  /// what the user said.
  Future<List<GoalCheckInSummary>> _reconcileCheckIns({
    required String agentId,
    required String goalStatement,
    required String model,
    required AiConfigInferenceProvider provider,
    required bool compactMissing,
  }) async {
    final compactor = _checkInCompactor;
    final reader = _checkInSourceReader;
    if (compactor == null || reader == null) return const [];

    final List<GoalCheckInSource> sources;
    _GoalCheckInCompactionState state;
    try {
      // ONE read of each side per wake. Reading the summaries again to render
      // user voice doubled an already-unbounded scan, which is exactly what
      // ADR 0057's bounded-read invariant forbids.
      state = await _checkInCompactionState(agentId);
      sources = await reader(agentId);
    } on Object {
      return const [];
    }

    var stored = state.summaries;
    final byEntryId = {
      for (final summary in stored) summary.sourceEntryId: summary,
    };
    final live = {for (final source in sources) source.entryId: source};

    if (compactMissing) {
      var compacted = false;
      for (final source in sources) {
        final existing = byEntryId[source.entryId];
        // Recompact when the words changed. A transcript is not final when it
        // first lands — it can be re-transcribed with a better model or edited —
        // and without this the first summary stood forever while the agent
        // coached from words that no longer existed. A summary predating the
        // digest has none, so it is refreshed once and then carries one.
        final digest = goalCheckInSourceDigest(source.text);
        if (existing != null && existing.sourceDigest == digest) continue;
        if (state.failuresByEntryId[source.entryId]?.blocks(
              digest,
              clock.now(),
            ) ??
            false) {
          continue;
        }
        await compactor.compact(
          agentId: agentId,
          entryId: source.entryId,
          recordedAt: source.recordedAt,
          transcript: source.text,
          goalStatement: goalStatement,
          model: model,
          provider: provider,
        );
        compacted = true;
      }
      if (compacted) {
        try {
          state = await _checkInCompactionState(agentId);
          stored = state.summaries;
        } on Object {
          return const [];
        }
      }
    }

    if (live.isEmpty && stored.isEmpty) return const [];
    // Only summaries whose source is still linked and live. A deleted or
    // unlinked check-in leaves its summary behind, and without this the agent
    // kept quoting words the user had removed — the timeline already hides
    // them, and the agent's view must not disagree with what the user sees.
    return [
      for (final summary in stored)
        if (live.containsKey(summary.sourceEntryId)) summary,
    ];
  }

  Future<List<Map<String, Object?>>> _userVoiceEntries({
    required String agentId,
    required List<GoalCheckInSummary> summaries,
    required String goalStatement,
    required String model,
    required AiConfigInferenceProvider provider,
    required bool allowInference,
    required DateTime reference,
  }) async {
    final digestService = _checkInDigestService;
    if (digestService == null || summaries.isEmpty) {
      return goalUserVoiceEntries(summaries);
    }
    try {
      final context = await HierarchicalCheckInCompaction(
        digestWriter: digestService.forWake(
          agentId: agentId,
          goalStatement: goalStatement,
          model: model,
          provider: provider,
          allowInference: allowInference,
        ),
      ).build(summaries, reference: reference);
      return context.entries;
    } catch (error, stackTrace) {
      _domainLogger.error(
        LogDomain.agentWorkflow,
        error,
        subDomain: 'goalCheckInDigest',
        message: 'hierarchical user voice failed; falling back to the tail',
        stackTrace: stackTrace,
      );
      return goalUserVoiceEntries(summaries);
    }
  }

  /// The compacted check-ins and retry failures stored for this goal.
  ///
  /// Summaries are read whole and then token-bounded by
  /// `goalUserVoiceEntries`; failure markers stay keyed by source entry so
  /// reconciliation can apply their durable retry backoff.
  Future<_GoalCheckInCompactionState> _checkInCompactionState(
    String agentId,
  ) async {
    final messages = await _repository.getEntitiesByAgentIdAndSubtype(
      agentId,
      type: AgentEntityTypes.agentMessage,
      subtype: AgentMessageKind.action.name,
    );
    final summaries = <GoalCheckInSummary>[];
    final failuresByEntryId = <String, GoalCheckInCompactionFailure>{};
    for (final message in messages.whereType<AgentMessageEntity>()) {
      final payloadId = message.contentEntryId;
      if (payloadId == null) continue;
      final payload = await _repository.getEntity(payloadId);
      if (payload is! AgentMessagePayloadEntity) continue;
      if (message.metadata.toolName == goalCheckInSummaryToolName) {
        final summary = GoalCheckInSummary.fromContent(
          message.id,
          payload.content,
        );
        if (summary != null) summaries.add(summary);
      } else if (message.metadata.toolName ==
          goalCheckInCompactionFailureToolName) {
        final failure = GoalCheckInCompactionFailure.fromContent(
          payload.content,
        );
        if (failure != null) {
          failuresByEntryId[failure.sourceEntryId] = failure;
        }
      }
    }
    return (
      summaries: summaries,
      failuresByEntryId: failuresByEntryId,
    );
  }

  Future<void> _persistUserMessage({
    required String agentId,
    required String threadId,
    required String runKey,
    required String text,
    required DateTime now,
  }) async {
    // Full-blob persistence (the event-agent argument): a FACTS block is
    // entirely non-derivable context, so a v2 prompt record would point
    // at an empty derivation.
    final payloadId = GoalAgentWorkflow._uuid.v4();
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
        id: GoalAgentWorkflow._uuid.v4(),
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

  Future<InferenceUsage?> _forceReport({
    required String conversationId,
    required ({
      String modelId,
      AiConfigInferenceProvider provider,
      GeminiThinkingMode? geminiThinkingMode,
    })
    resolved,
    required CloudInferenceWrapper inferenceRepo,
    required List<ChatCompletionTool> tools,
    required GoalAgentStrategy strategy,
    required String? agentId,
    required String? runKey,
    required String? threadId,
    required String instruction,
  }) async {
    try {
      return await _conversationRepository.sendMessage(
        conversationId: conversationId,
        message: instruction,
        model: resolved.modelId,
        provider: resolved.provider,
        inferenceRepo: inferenceRepo,
        tools: [
          for (final tool in tools)
            if (tool.function.name == GoalAgentToolNames.updateGoalReport) tool,
        ],
        toolChoice: forcedToolChoiceFor(
          modelId: resolved.modelId,
          toolName: GoalAgentToolNames.updateGoalReport,
        ),
        temperature: 0,
        strategy: strategy,
        consumptionAgentId: agentId,
        consumptionWakeRunKey: runKey,
        consumptionThreadId: threadId,
        rethrowInferenceErrors: true,
      );
    } catch (error) {
      _domainLogger.error(
        LogDomain.agentWorkflow,
        error,
        subDomain: 'goalPhaseB',
        message: 'forced goal report retry failed',
      );
      return null;
    }
  }

  Future<InferenceUsage?> _forceReply({
    required String conversationId,
    required ({
      String modelId,
      AiConfigInferenceProvider provider,
      GeminiThinkingMode? geminiThinkingMode,
    })
    resolved,
    required CloudInferenceWrapper inferenceRepo,
    required List<ChatCompletionTool> tools,
    required GoalAgentStrategy strategy,
    required String? agentId,
    required String? runKey,
    required String? threadId,
    required bool bannerCreated,
  }) async {
    try {
      return await _conversationRepository.sendMessage(
        conversationId: conversationId,
        message: bannerCreated
            ? 'A banner was created in this wake. Call reply_to_user now with '
                  'a brief goal-focused confirmation. Do not mention cooldown.'
            : 'The user is waiting for an answer. Call reply_to_user now with '
                  'a brief response focused only on this goal and its FACTS.',
        model: resolved.modelId,
        provider: resolved.provider,
        inferenceRepo: inferenceRepo,
        tools: [
          for (final tool in tools)
            if (tool.function.name == GoalAgentToolNames.replyToUser) tool,
        ],
        toolChoice: const ChatCompletionToolChoiceOption.tool(
          ChatCompletionNamedToolChoice(
            type: ChatCompletionNamedToolChoiceType.function,
            function: ChatCompletionFunctionCallOption(
              name: GoalAgentToolNames.replyToUser,
            ),
          ),
        ),
        temperature: 0,
        strategy: strategy,
        consumptionAgentId: agentId,
        consumptionWakeRunKey: runKey,
        consumptionThreadId: threadId,
        rethrowInferenceErrors: true,
      );
    } catch (error, stackTrace) {
      logError(
        'forced interactive reply failed',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
