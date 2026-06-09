part of 'day_agent_plan_service.dart';

/// Tool-call dispatch handlers of [DayAgentPlanService]; each translates
/// raw tool arguments into the corresponding service call and wraps the
/// result for the agent loop.
mixin _DayAgentPlanToolDispatcher on _DayAgentPlanServiceBase {
  @override
  Future<Map<String, Object?>> _draftDayPlanTool(
    String agentId,
    Map<String, dynamic> args,
  ) async {
    final dayId = _requiredString(args, 'dayId');
    final planDate =
        _optionalDateTime(args['dayDate']) ?? _dateFromDayId(dayId);
    if (planDate == null) {
      throw const DayAgentCaptureException(
        'dayDate must be a valid ISO-8601 date-time',
      );
    }
    final plan = await persistDraftPlan(
      agentId: agentId,
      dayId: dayId,
      planDate: planDate,
      captureId: _optionalString(args['captureId']),
      decidedTaskIds: _stringList(args['decidedTaskIds']),
      rawBlocks: _objectList(args['blocks'], 'blocks'),
      rawEnergyBands: _objectList(args['energyBands'], 'energyBands'),
      capacityMinutes: _optionalInt(args['capacityMinutes']) ?? 480,
      dayLabel: _optionalString(args['dayLabel']),
    );
    return _planJson(plan);
  }

  @override
  Future<Map<String, Object?>> _summarizeRecentPatternsTool(
    String agentId,
    Map<String, dynamic> args,
  ) async {
    final asOf = _optionalDateTime(args['asOf']) ?? clock.now();
    final cards = await summarizeRecentPatterns(
      agentId: agentId,
      asOf: asOf,
      lookbackDays: _optionalInt(args['lookbackDays']) ?? 7,
    );
    return {
      'cards': [for (final card in cards) card.toJson()],
    };
  }

  @override
  Future<Map<String, Object?>> _proposePlanDiffTool({
    required String agentId,
    required String threadId,
    required String runKey,
    required Map<String, dynamic> args,
  }) async {
    final dayId = _requiredString(args, 'dayId');
    final changeSet = await proposePlanDiff(
      agentId: agentId,
      threadId: threadId,
      runKey: runKey,
      dayId: dayId,
      rawChanges: _objectList(args['changes'], 'changes'),
      baselinePlanId: _optionalString(args['baselinePlanId']),
      captureId: _optionalString(args['captureId']),
    );
    return {
      'changeSetId': changeSet.id,
      'items': [
        for (var i = 0; i < changeSet.items.length; i++)
          <String, Object?>{
            'index': i,
            'toolName': changeSet.items[i].toolName,
            'summary': changeSet.items[i].humanSummary,
            'reason': changeSet.items[i].args['reason'],
          },
      ],
    };
  }

  @override
  Future<Map<String, Object?>> _acceptPlanDiffTool({
    required String agentId,
    required Map<String, dynamic> args,
  }) async {
    final changeSet = await acceptPlanDiff(
      agentId: agentId,
      changeSetId: _requiredString(args, 'changeSetId'),
      itemIndices: _optionalIntList(args['itemIndices']),
    );
    return _resolutionSummary(changeSet);
  }

  @override
  Future<Map<String, Object?>> _revertPlanDiffTool({
    required String agentId,
    required Map<String, dynamic> args,
  }) async {
    final changeSet = await revertPlanDiff(
      agentId: agentId,
      changeSetId: _requiredString(args, 'changeSetId'),
      itemIndices: _optionalIntList(args['itemIndices']),
    );
    return _resolutionSummary(changeSet);
  }

  @override
  Future<Map<String, Object?>> _commitDayTool({
    required String agentId,
    required Map<String, dynamic> args,
  }) async {
    final committedPlan = await commitDay(
      agentId: agentId,
      dayId: _requiredString(args, 'dayId'),
    );
    final status = committedPlan.data.status;
    final committedAt = status is DayPlanStatusCommitted
        ? status.committedAt
        : null;
    return <String, Object?>{
      'planId': committedPlan.id,
      'dayId': committedPlan.dayId,
      'status': 'committed',
      'committedAt': committedAt?.toIso8601String(),
      'blockCount': committedPlan.data.plannedBlocks.length,
    };
  }

  @override
  Future<Map<String, Object?>> _uncommitDayTool({
    required String agentId,
    required Map<String, dynamic> args,
  }) async {
    final plan = await uncommitDay(
      agentId: agentId,
      dayId: _requiredString(args, 'dayId'),
    );
    return <String, Object?>{
      'planId': plan.id,
      'dayId': plan.dayId,
      'status': 'draft',
      'blockCount': plan.data.plannedBlocks.length,
    };
  }
}
