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
    required _KnowledgeContext knowledge,
    String? compactedLog,
  }) {
    // Key order is deliberately STABLE → VOLATILE for prompt-prefix / KV-cache
    // reuse: providers cache the longest identical leading prefix, so anything
    // that varies wake-to-wake must come last. Slow-changing day-stable blocks
    // (standingKnowledge, dayLog, attentionPlanning) precede the per-wake mode
    // blocks, and the genuinely volatile fields (triggerTokens, wall-clock)
    // are trailing so they cannot evict the large stable blocks behind them.
    final payload = <String, Object?>{
      'dayId': dayId,
      'planDate': planDate.toIso8601String(),
      // Durable, compaction-exempt planner knowledge (ADR 0022 Decisions 9–10),
      // two-tier: the always-on `hookIndex` plus the scope-filtered full
      // `statements` for what this wake touches. Global and slow-changing, so
      // it leads the stable prefix.
      if (knowledge.hookIndex.isNotEmpty || knowledge.statements.isNotEmpty)
        'standingKnowledge': knowledge.toJson(),
      // The compacted day log (ADR 0017): capture transcripts and the agent's
      // observations as an append-only event tail behind a summary —
      // byte-stable at its head between folds.
      'dayLog': ?compactedLog,
      // Day-stable attention claims/agreements precede the per-wake mode blocks.
      if (!attentionPlanning.isEmpty)
        'attentionPlanning': _attentionPlanningToJson(attentionPlanning),
      // Mode blocks: present only for the wake that owns them, stable for it.
      if (captureContext != null) 'capture': captureContext.toJson(),
      if (draftingContext != null) 'drafting': draftingContext.toJson(),
      if (refineContext != null) 'refine': refineContext.toJson(),
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
      // Volatile per-wake metadata, kept LAST (before the wall-clock) so a
      // changing trigger set never evicts the large stable blocks above it.
      'triggerTokens': triggerTokens.toList()..sort(),
      // The volatile wall-clock is the trailing key.
      'currentLocalTime': now.toIso8601String(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Loads the planner's durable knowledge and renders the two-tier prompt
  /// blocks (ADR 0022 Decisions 9–10): the always-on hook index plus the
  /// scope-filtered full statements for the scopes this wake actually touches
  /// (`global` always; [touchedScopes] for `category:`/`project:`). Returns
  /// empty blocks (and the caller omits the field) when no knowledge or no
  /// service is configured.
  Future<_KnowledgeContext> _knowledgeContext({
    required AgentIdentityEntity agentIdentity,
    required Set<String> touchedScopes,
    required DateTime now,
  }) async {
    final service = knowledgeService;
    if (service == null) return const _KnowledgeContext.empty();
    try {
      final active = await service.activeFor(agentIdentity.agentId);
      if (active.isEmpty) return const _KnowledgeContext.empty();
      return _KnowledgeContext(
        hookIndex: renderKnowledgeHookIndex(active),
        statements: renderKnowledgeStatements(active, touchedScopes, now: now),
      );
    } catch (e, s) {
      _logError(
        'failed to load durable planner knowledge',
        error: e,
        stackTrace: s,
      );
      return const _KnowledgeContext.empty();
    }
  }

  /// The category/project scopes the current wake actually touches (ADR 0022
  /// Decision 10): the categories of the day's attention claims/agreements and
  /// the categories of the baseline plan blocks being drafted/refined. This is
  /// the wake's real workspace, not the planner identity's static allow-list
  /// (which is empty = "allow all" and would surface nothing).
  Set<String> _touchedScopes({
    required AttentionPlanningInputs attentionPlanning,
    required _DraftingContext? draftingContext,
    required _RefineContext? refineContext,
  }) {
    final scopes = <String>{};
    void addCategory(String? categoryId) {
      if (categoryId != null && categoryId.isNotEmpty) {
        scopes.add(knowledgeCategoryScope(categoryId));
      }
    }

    for (final claim in attentionPlanning.claims) {
      addCategory(claim.categoryId);
    }
    for (final agreement in attentionPlanning.standingAgreements) {
      addCategory(agreement.categoryId);
    }
    final decidedTasks = draftingContext?.decidedTasks;
    if (decidedTasks != null) {
      for (final task in decidedTasks) {
        addCategory(task.categoryId);
      }
    }
    final draftBlocks = draftingContext?.baselinePlan?.data.plannedBlocks;
    if (draftBlocks != null) {
      for (final block in draftBlocks) {
        addCategory(block.categoryId);
      }
    }
    final refineBlocks = refineContext?.baselinePlan?.data.plannedBlocks;
    if (refineBlocks != null) {
      for (final block in refineBlocks) {
        addCategory(block.categoryId);
      }
    }
    return scopes;
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
    required DailyOsPlannerWakeContext wakeContext,
  }) async {
    final service = captureService;
    if (service == null) return null;
    if (wakeContext.captureIds.isEmpty) return null;

    // The IDs are pre-sorted, so under a merged multi-capture token set the
    // same capture wins deterministically. The first capture that loads and
    // belongs to this agent becomes the wake's capture context.
    for (final captureId in wakeContext.captureIds) {
      final capture = await service.getCapture(captureId);
      if (capture == null || capture.agentId != agentIdentity.agentId) {
        continue;
      }

      final corpus = await service.buildTaskCorpusSnapshot(
        allowedCategoryIds: agentIdentity.allowedCategoryIds,
        day: planDate,
      );
      return _CaptureContext(capture: capture, taskCorpus: corpus);
    }
    return null;
  }

  Future<_DraftingContext?> _draftingContext({
    required AgentIdentityEntity agentIdentity,
    required DailyOsPlannerWakeContext wakeContext,
    required _CaptureContext? captureContext,
  }) async {
    final service = planService;
    if (service == null) return null;
    if (!wakeContext.isDraftingWake) return null;

    final baselinePlan = await service.draftPlanForDay(
      agentId: agentIdentity.agentId,
      dayId: wakeContext.dayId,
    );
    final explicitTaskIds = wakeContext.decidedTaskIds;
    final explicitCaptureItemIds = wakeContext.decidedCaptureItemIds.toSet();
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
    required DailyOsPlannerWakeContext wakeContext,
  }) async {
    final service = planService;
    if (service == null) return null;
    if (!wakeContext.isRefineWake) return null;

    final baselinePlan = await service.draftPlanForDay(
      agentId: agentIdentity.agentId,
      dayId: wakeContext.dayId,
    );
    return _RefineContext(baselinePlan: baselinePlan);
  }
}
