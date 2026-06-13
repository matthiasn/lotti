import 'package:clock/clock.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_editor.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_parser.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_writer.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';
import 'package:lotti/services/domain_logging.dart';

/// Translates raw day-plan tool calls into [DayAgentPlanWriter] /
/// [DayAgentPlanEditor] operations and wraps the result for the agent loop.
class DayAgentPlanToolDispatcher {
  /// Creates the plan tool dispatcher collaborator.
  DayAgentPlanToolDispatcher({
    required this.writer,
    required this.editor,
    required this.domainLogger,
  });

  /// Persistence-side collaborator for drafting/summarizing.
  final DayAgentPlanWriter writer;

  /// In-place editing collaborator for plan diffs.
  final DayAgentPlanEditor editor;

  /// Structured logger.
  final DomainLogger domainLogger;

  /// Executes a foundation day-plan tool.
  Future<DayAgentDirectToolResult> executeTool({
    required String agentId,
    required String threadId,
    required String runKey,
    required String toolName,
    required Map<String, dynamic> args,
  }) async {
    try {
      final data = switch (toolName) {
        DayAgentToolNames.draftDayPlan => await _draftDayPlanTool(
          agentId,
          args,
        ),
        DayAgentToolNames.summarizeRecentPatterns =>
          await _summarizeRecentPatternsTool(agentId, args),
        DayAgentToolNames.proposePlanDiff => await _proposePlanDiffTool(
          agentId: agentId,
          threadId: threadId,
          runKey: runKey,
          args: args,
        ),
        _ => throw DayAgentCaptureException('unknown tool "$toolName"'),
      };
      return DayAgentDirectToolResult.success(data);
    } on DayAgentCaptureException catch (e) {
      return DayAgentDirectToolResult.failure(e.message);
    } catch (e, s) {
      domainLogger.error(
        LogDomain.agentWorkflow,
        e,
        message: 'day-agent plan tool failed',
        stackTrace: s,
      );
      return DayAgentDirectToolResult.failure(e.toString());
    }
  }

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
    final plan = await writer.persistDraftPlan(
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

  Future<Map<String, Object?>> _summarizeRecentPatternsTool(
    String agentId,
    Map<String, dynamic> args,
  ) async {
    final asOf = optionalDateTimeArg(args['asOf']) ?? clock.now();
    final cards = await writer.summarizeRecentPatterns(
      agentId: agentId,
      asOf: asOf,
      lookbackDays: optionalIntArg(args['lookbackDays']) ?? 7,
    );
    return {
      'cards': [for (final card in cards) card.toJson()],
    };
  }

  Future<Map<String, Object?>> _proposePlanDiffTool({
    required String agentId,
    required String threadId,
    required String runKey,
    required Map<String, dynamic> args,
  }) async {
    final dayId = requiredStringArg(args, 'dayId');
    final changeSet = await editor.proposePlanDiff(
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
