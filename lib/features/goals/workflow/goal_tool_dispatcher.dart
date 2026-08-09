import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/goals/service/goal_spec_revision_service.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';

/// Applies ACCEPTED goal change-set items (the `EventToolDispatcher`
/// shape): the confirmation service persists the decision, then hands the
/// item here. One case today — `propose_goal_revision`, whose acceptance
/// mints a new spec version and moves the head.
///
/// Refusals return `success: false` so the proposal stays unresolved
/// instead of half-applying (the accept-after-delete posture).
class GoalToolDispatcher {
  GoalToolDispatcher({required this._revisionService});

  final GoalSpecRevisionService _revisionService;

  Future<ToolExecutionResult> dispatch(
    String toolName,
    Map<String, dynamic> args,
    String agentId,
  ) async {
    switch (toolName) {
      case GoalAgentToolNames.proposeGoalRevision:
        return _handleProposeGoalRevision(args, agentId);
      default:
        return ToolExecutionResult(
          success: false,
          output: 'Unknown tool: $toolName',
          errorMessage: 'Tool $toolName is not registered for the Goal Agent',
        );
    }
  }

  Future<ToolExecutionResult> _handleProposeGoalRevision(
    Map<String, dynamic> args,
    String agentId,
  ) async {
    final changes = args['changes'];
    if (changes is! Map<String, dynamic> || changes.isEmpty) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: the proposal carries no changes object',
        errorMessage: 'Missing changes',
      );
    }
    final rationaleValue = args['rationale'];
    final rationale = rationaleValue is String ? rationaleValue.trim() : '';
    final sourceThreadId = args['sourceThreadId'];

    final outcome = await _revisionService.reviseFromProposal(
      agentId: agentId,
      changes: changes,
      rationale: rationale,
      sourceThreadId: sourceThreadId is String ? sourceThreadId : null,
    );
    return switch (outcome) {
      GoalSpecRevisionMinted(:final version, :final changeSummaries) =>
        ToolExecutionResult(
          success: true,
          output:
              'Goal revised to v${version.version}: '
              '${changeSummaries.join(', ')}',
          mutatedEntityId: version.id,
        ),
      GoalSpecRevisionRefused(:final reason) => ToolExecutionResult(
        success: false,
        output: 'Error: $reason',
        errorMessage: reason,
      ),
    };
  }
}
