part of 'day_agent_workflow.dart';

/// Write-only persistence helpers of [DayAgentWorkflow]: messages,
/// thoughts, observations, and token usage.
extension DayAgentPersistence on DayAgentWorkflow {
  Future<void> _persistUserMessage({
    required String agentId,
    required String threadId,
    required String runKey,
    required String userMessage,
    required DateTime now,
    WakeMemoryView? memoryView,
  }) async {
    try {
      final payloadId = DayAgentWorkflow._uuid.v4();
      // ADR 0020 v2 prompt records: when the read flipped, the `dayLog`
      // JSON field is a pure function of the synced event log — store the
      // payload WITHOUT that line plus the reconstruction marker. The line
      // is re-encoded on reconstruction (`json-day-log-line` wrap).
      var content = <String, Object?>{'text': userMessage};
      if (memoryView != null && memoryView.useCompactedLog) {
        final anchor = userMessage.indexOf(DayAgentWorkflow._dayLogLineAnchor);
        if (anchor >= 0) {
          final lineStart = anchor + 1;
          final lineEnd = userMessage.indexOf('\n', lineStart);
          if (lineEnd > lineStart) {
            content = encodePromptRecord(
              head: userMessage.substring(0, lineStart),
              tail: userMessage.substring(lineEnd + 1),
              summaryId: memoryView.activeSummaryId,
              until: memoryView.lastEventPosition,
              wrap: promptRecordWrapDayLogJsonLine,
            );
          }
        }
      }
      await syncService.upsertEntity(
        AgentDomainEntity.agentMessagePayload(
          id: payloadId,
          agentId: agentId,
          createdAt: now,
          vectorClock: null,
          content: content,
        ),
      );
      await syncService.upsertEntity(
        AgentDomainEntity.agentMessage(
          id: DayAgentWorkflow._uuid.v4(),
          agentId: agentId,
          threadId: threadId,
          kind: AgentMessageKind.user,
          createdAt: now,
          vectorClock: null,
          contentEntryId: payloadId,
          metadata: AgentMessageMetadata(runKey: runKey),
        ),
      );
    } catch (e, s) {
      _logError(
        'failed to persist day-agent user message',
        error: e,
        stackTrace: s,
      );
    }
  }

  Future<void> _persistThought({
    required String agentId,
    required String threadId,
    required String runKey,
    required String? thoughtText,
    required DateTime now,
  }) async {
    if (thoughtText == null || thoughtText.trim().isEmpty) return;
    final payloadId = DayAgentWorkflow._uuid.v4();
    await syncService.upsertEntity(
      AgentDomainEntity.agentMessagePayload(
        id: payloadId,
        agentId: agentId,
        createdAt: now,
        vectorClock: null,
        content: <String, Object?>{'text': thoughtText.trim()},
      ),
    );
    await syncService.upsertEntity(
      AgentDomainEntity.agentMessage(
        id: DayAgentWorkflow._uuid.v4(),
        agentId: agentId,
        threadId: threadId,
        kind: AgentMessageKind.thought,
        createdAt: now,
        vectorClock: null,
        contentEntryId: payloadId,
        metadata: AgentMessageMetadata(runKey: runKey),
      ),
    );
  }

  Future<void> _persistObservations({
    required String agentId,
    required String threadId,
    required String runKey,
    required List<ObservationRecord> observations,
    required DateTime now,
  }) async {
    for (final observation in observations) {
      final payloadId = DayAgentWorkflow._uuid.v4();
      await syncService.upsertEntity(
        AgentDomainEntity.agentMessagePayload(
          id: payloadId,
          agentId: agentId,
          createdAt: now,
          vectorClock: null,
          content: <String, Object?>{
            'text': observation.text,
            'priority': observation.priority.name,
            'category': observation.category.name,
          },
        ),
      );
      await syncService.upsertEntity(
        AgentDomainEntity.agentMessage(
          id: DayAgentWorkflow._uuid.v4(),
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
  }

  Future<void> _persistTokenUsage({
    required InferenceUsage? usage,
    required String agentId,
    required String runKey,
    required String threadId,
    required String modelId,
    required _TemplateContext? templateCtx,
    required DateTime now,
  }) async {
    if (usage == null || !usage.hasData) return;

    await syncService.upsertEntity(
      AgentDomainEntity.wakeTokenUsage(
        id: DayAgentWorkflow._uuid.v4(),
        agentId: agentId,
        runKey: runKey,
        threadId: threadId,
        modelId: modelId,
        templateId: templateCtx?.template.id,
        templateVersionId: templateCtx?.version.id,
        soulDocumentId: templateCtx?.soulVersion?.agentId,
        soulDocumentVersionId: templateCtx?.soulVersion?.id,
        createdAt: now,
        vectorClock: null,
        inputTokens: usage.inputTokens,
        outputTokens: usage.outputTokens,
        thoughtsTokens: usage.thoughtsTokens,
        cachedInputTokens: usage.cachedInputTokens,
      ),
    );
  }

  Future<Map<String, AgentMessagePayloadEntity>> _resolveObservationPayloads(
    List<AgentMessageEntity> observations,
  ) async {
    final payloadIds = observations
        .map((observation) => observation.contentEntryId)
        .whereType<String>()
        .toSet();
    if (payloadIds.isEmpty) return const <String, AgentMessagePayloadEntity>{};

    final entitiesById = await agentRepository.getEntitiesByIds(payloadIds);
    return {
      for (final entry in entitiesById.entries)
        if (entry.value is AgentMessagePayloadEntity)
          entry.key: entry.value as AgentMessagePayloadEntity,
    };
  }
}
