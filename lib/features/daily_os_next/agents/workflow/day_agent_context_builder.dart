part of 'day_agent_workflow.dart';

/// Pure context-assembly helpers of [DayAgentWorkflow]: user-message
/// construction and the capture/drafting/refine context builders.
extension DayAgentContextBuilder on DayAgentWorkflow {
  String _buildUserMessage({
    required String dayId,
    required DateTime planDate,
    required DateTime now,
    required Set<String> triggerTokens,
    required List<AgentMessageEntity> observations,
    required Map<String, AgentMessagePayloadEntity> observationPayloads,
    required _CaptureContext? captureContext,
    required _DraftingContext? draftingContext,
    required _RefineContext? refineContext,
    required AttentionPlanningInputs attentionPlanning,
    String? compactedLog,
  }) {
    final payload = <String, Object?>{
      'dayId': dayId,
      'planDate': planDate.toIso8601String(),
      // The compacted day log (ADR 0017): capture transcripts and the
      // agent's observations as an append-only event tail behind a summary.
      // Placed before the per-wake volatile fields so the JSON-encoded
      // prefix stays byte-stable across wakes; when present it supersedes
      // the separate recentObservations listing below.
      'dayLog': ?compactedLog,
      'triggerTokens': triggerTokens.toList()..sort(),
      if (captureContext != null) 'capture': captureContext.toJson(),
      if (draftingContext != null) 'drafting': draftingContext.toJson(),
      if (refineContext != null) 'refine': refineContext.toJson(),
      if (!attentionPlanning.isEmpty)
        'attentionPlanning': _attentionPlanningToJson(attentionPlanning),
      if (compactedLog == null)
        'recentObservations': [
          for (final observation in observations)
            {
              'createdAt': observation.createdAt.toIso8601String(),
              'text': DayAgentWorkflow._extractPayloadText(
                observationPayloads[observation.contentEntryId],
              ),
            },
        ],
      // Keep the volatile wall-clock last so the rest of the payload stays a
      // stable prefix across wakes, maximizing prompt prefix / KV-cache reuse.
      'currentLocalTime': now.toIso8601String(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<AttentionPlanningInputs> _attentionPlanningContext(
    DateTime planDate,
  ) async {
    try {
      final start = DateTime(planDate.year, planDate.month, planDate.day);
      return await agentRepository.getAttentionPlanningInputsForWindow(
        start: start,
        // Use day + 1 (not Duration(days: 1)) so the window stays at local
        // midnight across DST transitions, where a day may be 23 or 25 hours.
        end: DateTime(start.year, start.month, start.day + 1),
      );
    } catch (e, s) {
      _logError(
        'failed to load attention planning context',
        error: e,
        stackTrace: s,
      );
      return const AttentionPlanningInputs.empty();
    }
  }

  Map<String, Object?> _attentionPlanningToJson(
    AttentionPlanningInputs inputs,
  ) {
    return {
      'claims': [
        for (final claim in inputs.claims)
          {
            'id': claim.id,
            'agentId': claim.agentId,
            'kind': claim.kind.name,
            'title': claim.title,
            'categoryId': claim.categoryId,
            'requestedMinutes': claim.requestedMinutes,
            'impact': claim.impact,
            'urgency': claim.urgency,
            'energyFit': claim.energyFit.name,
            'scopeKind': claim.scopeKind.name,
            'earliestStart': claim.earliestStart?.toIso8601String(),
            'latestEnd': claim.latestEnd?.toIso8601String(),
            'deadline': claim.deadline?.toIso8601String(),
            'nextReviewAt': claim.nextReviewAt?.toIso8601String(),
            'targetId': claim.targetId,
            'targetKind': claim.targetKind,
            'rationale': claim.rationale,
            'evidenceRefs': [
              for (final ref in claim.evidenceRefs)
                {
                  'kind': ref.kind.name,
                  'id': ref.id,
                  'label': ref.label,
                },
            ],
          },
      ],
      'standingAgreements': [
        for (final agreement in inputs.standingAgreements)
          {
            'id': agreement.id,
            'agentId': agreement.agentId,
            'title': agreement.title,
            'scope': agreement.scope.name,
            'cadence': agreement.cadence.name,
            'status': agreement.status.name,
            'enforcement': agreement.enforcement.name,
            'approvalMode': agreement.approvalMode.name,
            'categoryId': agreement.categoryId,
            'targetId': agreement.targetId,
            'targetKind': agreement.targetKind,
            'minCount': agreement.minCount,
            'maxCount': agreement.maxCount,
            'minMinutes': agreement.minMinutes,
            'maxMinutes': agreement.maxMinutes,
            'preferredSessionMinutes': agreement.preferredSessionMinutes,
            'priority': agreement.priority,
            'canPreempt': agreement.canPreempt,
            'activeFrom': agreement.activeFrom?.toIso8601String(),
            'activeUntil': agreement.activeUntil?.toIso8601String(),
            'rationale': agreement.rationale,
          },
      ],
    };
  }

  Future<_CaptureContext?> _captureContext({
    required AgentIdentityEntity agentIdentity,
    required DateTime planDate,
    required Set<String> triggerTokens,
  }) async {
    final service = captureService;
    if (service == null) return null;

    final captureId = captureIdFromTriggerTokens(triggerTokens);
    if (captureId == null) return null;

    final capture = await service.getCapture(captureId);
    if (capture == null || capture.agentId != agentIdentity.agentId) {
      return null;
    }

    final corpus = await service.buildTaskCorpusSnapshot(
      allowedCategoryIds: agentIdentity.allowedCategoryIds,
      day: planDate,
    );
    return _CaptureContext(capture: capture, taskCorpus: corpus);
  }

  Future<_DraftingContext?> _draftingContext({
    required AgentIdentityEntity agentIdentity,
    required String dayId,
    required Set<String> triggerTokens,
    required _CaptureContext? captureContext,
  }) async {
    final service = planService;
    if (service == null) return null;
    if (draftingDayIdFromTriggerTokens(triggerTokens) != dayId) return null;

    final baselinePlan = await service.draftPlanForDay(
      agentId: agentIdentity.agentId,
      dayId: dayId,
    );
    final explicitTaskIds = decidedTaskIdsFromTriggerTokens(triggerTokens);
    final explicitCaptureItemIds = decidedCaptureItemIdsFromTriggerTokens(
      triggerTokens,
    ).toSet();
    final parsedItems = await _parsedItemsForCapture(captureContext);
    final decidedTasks = await service.hydrateDecidedTasks(
      allowedCategoryIds: agentIdentity.allowedCategoryIds,
      explicitTaskIds: explicitTaskIds,
      parsedItems: parsedItems,
    );
    final decidedCaptureItems = [
      for (final item in parsedItems)
        if (explicitCaptureItemIds.contains(item.id)) item,
    ];
    return _DraftingContext(
      baselinePlan: baselinePlan,
      decidedTasks: decidedTasks,
      decidedCaptureItems: decidedCaptureItems,
    );
  }

  Future<List<ParsedItemEntity>> _parsedItemsForCapture(
    _CaptureContext? captureContext,
  ) async {
    final capture = captureContext?.capture;
    final service = captureService;
    if (capture == null || service == null) return const [];
    final entities = await service.parsedItemsForCapture(capture.id);
    return entities.whereType<ParsedItemEntity>().toList();
  }

  Future<_RefineContext?> _refineContext({
    required AgentIdentityEntity agentIdentity,
    required String dayId,
    required Set<String> triggerTokens,
  }) async {
    final service = planService;
    if (service == null) return null;
    if (refineDayIdFromTriggerTokens(triggerTokens) != dayId) return null;

    final baselinePlan = await service.draftPlanForDay(
      agentId: agentIdentity.agentId,
      dayId: dayId,
    );
    return _RefineContext(baselinePlan: baselinePlan);
  }
}
