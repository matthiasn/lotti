import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/goals/service/goal_spec_revision_service.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';

/// Applies ACCEPTED goal change-set items (the `EventToolDispatcher`
/// shape): the confirmation service persists the decision, then hands the
/// item here. One case today — `propose_goal_revision_v2`, whose acceptance
/// mints a new spec version and moves the head.
///
/// Definitive refusals return `success: false` and `nonRetryable: true`,
/// allowing the confirmation service to retract a proposal whose immutable
/// arguments can never apply instead of leaving a dead retry action. Missing
/// synced dependencies remain retryable until their head/version rows arrive.
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
      case GoalAgentToolNames.legacyProposeGoalRevision:
        return const ToolExecutionResult(
          success: false,
          output: 'Error: this goal revision proposal uses an obsolete format',
          errorMessage: 'Obsolete goal revision proposal',
          nonRetryable: true,
        );
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
        nonRetryable: true,
      );
    }
    final rationaleValue = args['rationale'];
    final rationale = rationaleValue is String ? rationaleValue.trim() : '';
    final sourceThreadId = args['sourceThreadId'];
    final baseVersionIdValue = args['baseVersionId'];
    final baseVersionId = baseVersionIdValue is String
        ? baseVersionIdValue.trim()
        : '';
    if (baseVersionId.isEmpty) {
      return const ToolExecutionResult(
        success: false,
        output: 'Error: the proposal carries no originating goal version',
        errorMessage: 'Missing originating goal version',
        nonRetryable: true,
      );
    }

    final outcome = await _revisionService.reviseFromProposal(
      agentId: agentId,
      baseVersionId: baseVersionId,
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
      GoalSpecRevisionRefused(:final reason, :final retryable) =>
        ToolExecutionResult(
          success: false,
          output: 'Error: $reason',
          errorMessage: reason,
          nonRetryable: !retryable,
        ),
    };
  }
}
