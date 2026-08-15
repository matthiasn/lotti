import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/goals/ui/pages/create_goal_agent_page.dart';
import 'package:lotti/features/goals/ui/pages/goal_agent_chat_page.dart';
import 'package:lotti/features/goals/ui/pages/goal_agent_detail_page.dart';
import 'package:lotti/features/goals/ui/pages/unified_goals_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The unified Goals tab (flag: `enable_unified_goals`): goals at the top
/// level with their habits inside.
///
/// Hosts the same detail, chat and wizard pages as [`AgentsLocation`] under
/// `/goals/...` paths, so the tab's primary actions work — and Back returns
/// here — even when the independent `enable_agents_page` flag is off (a
/// route under a disabled tab is normalized to `/tasks` by `NavService`).
/// Anything malformed renders the plain list, mirroring the agents tab.
class GoalsLocation extends BeamLocation<BeamState> {
  GoalsLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
    '/goals',
    '/goals/create',
    '/goals/details/:agentId',
    '/goals/details/:agentId/edit',
    '/goals/details/:agentId/chat',
  ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) {
    final agentId = state.pathParameters['agentId'];
    final messages = context.messages;
    return [
      BeamPage(
        key: const ValueKey('goals'),
        title: messages.navTabTitleGoals,
        child: const UnifiedGoalsPage(),
      ),
      if (state.uri.path == '/goals/create')
        BeamPage(
          key: const ValueKey('goals-create'),
          title: messages.agentsCreateGoal,
          child: const CreateGoalAgentPage(),
        ),
      if (agentId != null)
        BeamPage(
          key: ValueKey('goals-details-$agentId'),
          title: messages.navTabTitleGoals,
          child: GoalAgentDetailPage(agentId: agentId),
        ),
      if (agentId != null && state.uri.path.endsWith('/chat'))
        BeamPage(
          key: ValueKey('goals-details-$agentId-chat'),
          title: messages.goalChatPageTitle,
          child: GoalAgentChatPage(agentId: agentId),
        ),
      if (agentId != null && state.uri.path.endsWith('/edit'))
        BeamPage(
          key: ValueKey('goals-details-$agentId-edit'),
          title: messages.goalFormEditTitle,
          child: CreateGoalAgentPage(agentId: agentId),
        ),
    ];
  }
}
