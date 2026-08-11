import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/goals/ui/goal_agent_chat_pane.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

class GoalAgentChatPage extends ConsumerWidget {
  const GoalAgentChatPage({required this.agentId, super.key});

  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identityAsync = ref.watch(agentIdentityProvider(agentId));
    final identity = identityAsync.value;
    final isActiveGoal =
        identity is AgentIdentityEntity &&
        identity.kind == AgentKinds.goalAgent &&
        identity.lifecycle == AgentLifecycle.active;
    final name = isActiveGoal
        ? identity.displayName
        : context.messages.agentsPageTitle;
    final detailPath = '/agents/details/$agentId';
    final page = Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => beamToNamed(detailPath),
        ),
        title: Text(name),
      ),
      body: SafeArea(
        child: !identityAsync.hasValue && !identityAsync.hasError
            ? const Center(child: CircularProgressIndicator())
            : isActiveGoal
            ? Padding(
                padding: EdgeInsets.only(
                  bottom: DesignSystemBottomNavigationBar.occupiedHeight(
                    context,
                  ),
                ),
                child: GoalAgentChatPane(
                  agentId: agentId,
                  showHeader: false,
                ),
              )
            : Center(child: Text(context.messages.goalDetailHealthUnavailable)),
      ),
    );
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => beamToNamed(detailPath),
        );
      },
      child: page,
    );
  }
}
