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
      final payloadId = _uuid.v4();
      // ADR 0020 v2 prompt records: when the read flipped, the `<day_log>`
      // section is a pure function of the synced event log — store the payload
      // WITHOUT the whole section plus the reconstruction marker. The day log
      // is multi-line, so we splice on the section boundaries (not a single
      // line) and re-render it between the tags on reconstruction
      // (`day-log-section` wrap).
      var content = <String, Object?>{'text': userMessage};
      if (memoryView != null && memoryView.useCompactedLog) {
        final sectionStart = userMessage.indexOf(dayLogSectionOpenMarker);
        if (sectionStart >= 0) {
          final closeStart = userMessage.indexOf(
            dayLogSectionCloseMarker,
            sectionStart + dayLogSectionOpenMarker.length,
          );
          if (closeStart > sectionStart) {
            final tailStart = closeStart + dayLogSectionCloseMarker.length;
            content = encodePromptRecord(
              // The whole `<day_log>…</day_log>` section is derivable, so head
              // ends just before it and tail begins just after it.
              head: userMessage.substring(0, sectionStart),
              tail: userMessage.substring(tailStart),
              summaryId: memoryView.activeSummaryId,
              until: memoryView.lastEventPosition,
              wrap: promptRecordWrapDayLogSection,
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
          id: _uuid.v4(),
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
    final payloadId = _uuid.v4();
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
        id: _uuid.v4(),
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
      final payloadId = _uuid.v4();
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
          id: _uuid.v4(),
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
        id: _uuid.v4(),
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

  /// Lazily resolves a deferred capture event's inline content (its transcript)
  /// by capture id — invoked by the compactor only for the post-cutoff tail it
  /// renders, so folded captures never reload their transcript. Returns null
  /// when the capture is missing/not a capture (the event is then dropped).
  Future<Map<String, Object?>?> _resolveCaptureContent(
    String captureId,
  ) async {
    final entity = await agentRepository.getEntity(captureId);
    if (entity is! CaptureEntity) return null;
    return captureInlineContent(entity.transcript);
  }
}
