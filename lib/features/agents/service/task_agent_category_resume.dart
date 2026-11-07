import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/features/agents/service/category_snapshot_setup.dart';
import 'package:lotti/features/agents/service/task_agent_service.dart';
import 'package:lotti/services/domain_logging.dart';

/// Hands back to their category the task agents an earlier build created
/// switched off only because their category named no profile, so they run
/// on the category's profile or the Settings default like every agent the
/// user has not touched.
///
/// Such an agent is dormant with a *disabled* setup of `categorySnapshot`
/// origin — a shape nothing else writes: *Turn off AI* and clearing a model
/// override store a disabled setup of `user` origin, and those stay off.
/// Each one gets [categoryFollowingSetup] through
/// [TaskAgentService.updateAgentInferenceSetup], which wakes a dormant agent
/// whose setup stops being disabled and restores its subscriptions and its
/// automatic-updates preference.
///
/// Idempotent and cheap: afterwards no such setup is left, so later starts
/// list the dormant agents and change nothing. One agent that cannot be
/// handed back is logged and skipped; it never blocks the others or startup.
/// Returns how many agents were handed back.
Future<int> resumeTaskAgentsSwitchedOffForCategory({
  required TaskAgentService taskAgentService,
  required DomainLogger domainLogger,
}) async {
  final dormant = await taskAgentService.agentService.listAgents(
    lifecycle: AgentLifecycle.dormant,
  );
  var resumed = 0;
  for (final agent in dormant) {
    final setup = agent.config.inferenceSetup;
    if (agent.kind != AgentKinds.taskAgent ||
        setup == null ||
        setup.mode != AgentInferenceSetupMode.disabled ||
        setup.origin != AgentInferenceSetupOrigin.categorySnapshot) {
      continue;
    }
    try {
      await taskAgentService.updateAgentInferenceSetup(
        agentId: agent.agentId,
        setup: categoryFollowingSetup(categoryId: setup.originEntityId),
      );
      resumed++;
    } catch (error, stackTrace) {
      domainLogger.error(
        LogDomain.agentRuntime,
        error,
        stackTrace: stackTrace,
        subDomain: 'restore',
        message:
            'Could not hand task agent '
            '${DomainLogger.sanitizeId(agent.agentId)} back to its category',
      );
    }
  }
  if (resumed > 0) {
    domainLogger.log(
      LogDomain.agentRuntime,
      'handed $resumed task agent(s) switched off for a category without a '
      'profile back to their category',
      subDomain: 'restore',
    );
  }
  return resumed;
}
