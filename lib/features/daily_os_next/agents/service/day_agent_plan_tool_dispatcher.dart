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
    final dayId = requiredStringArg(args, 'dayId');
    final planDate =
        optionalDateTimeArg(args['dayDate']) ?? dateFromDayId(dayId);
    if (planDate == null) {
      throw const DayAgentCaptureException(
        'dayDate must be a valid ISO-8601 date-time',
      );
    }
    final plan = await persistDraftPlan(
      agentId: agentId,
      dayId: dayId,
      planDate: planDate,
      captureId: optionalStringArg(args['captureId']),
      decidedTaskIds: stringListArg(args['decidedTaskIds']),
      rawBlocks: objectListArg(args['blocks'], 'blocks'),
      rawEnergyBands: objectListArg(args['energyBands'], 'energyBands'),
      capacityMinutes: optionalIntArg(args['capacityMinutes']) ?? 480,
      dayLabel: optionalStringArg(args['dayLabel']),
    );
    return planJson(plan);
  }

  @override
  Future<Map<String, Object?>> _summarizeRecentPatternsTool(
    String agentId,
    Map<String, dynamic> args,
  ) async {
    final asOf = optionalDateTimeArg(args['asOf']) ?? clock.now();
    final cards = await summarizeRecentPatterns(
      agentId: agentId,
      asOf: asOf,
      lookbackDays: optionalIntArg(args['lookbackDays']) ?? 7,
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
    final dayId = requiredStringArg(args, 'dayId');
    final changeSet = await proposePlanDiff(
      agentId: agentId,
      threadId: threadId,
      runKey: runKey,
      dayId: dayId,
      rawChanges: objectListArg(args['changes'], 'changes'),
      baselinePlanId: optionalStringArg(args['baselinePlanId']),
      captureId: optionalStringArg(args['captureId']),
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
}
