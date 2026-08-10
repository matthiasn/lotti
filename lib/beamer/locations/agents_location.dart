import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/goals/ui/pages/agents_page.dart';
import 'package:lotti/features/goals/ui/pages/create_goal_agent_page.dart';
import 'package:lotti/features/goals/ui/pages/goal_agent_detail_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The flag-gated Agents tab (`enable_agents_page`): the overview of
/// running goal agents, the per-agent detail, and goal creation.
class AgentsLocation extends BeamLocation<BeamState> {
  AgentsLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
    '/agents',
    '/agents/create',
    '/agents/details/:agentId',
  ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    final agentId = state.pathParameters['agentId'];
    final messages = context.messages;
    return [
      BeamPage(
        key: const ValueKey('agents'),
        title: messages.agentsPageTitle,
        child: const AgentsPage(),
      ),
      if (state.uri.path == '/agents/create')
        BeamPage(
          key: const ValueKey('agents-create'),
          title: messages.agentsCreateGoal,
          child: const CreateGoalAgentPage(),
        ),
      if (agentId != null)
        BeamPage(
          key: ValueKey('agents-details-$agentId'),
          title: messages.agentsPageTitle,
          child: GoalAgentDetailPage(agentId: agentId),
        ),
    ];
  }
}
