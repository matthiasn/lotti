import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/goals/ui/goal_agent_chat_pane.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

class GoalAgentChatPage extends ConsumerWidget {
  const GoalAgentChatPage({required this.agentId, super.key});

  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(agentIdentityProvider(agentId)).value;
    final name = identity is AgentIdentityEntity
        ? identity.displayName
        : context.messages.agentsPageTitle;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => beamToNamed('/agents/details/$agentId'),
        ),
        title: Text(name),
      ),
      body: SafeArea(
        child: GoalAgentChatPane(agentId: agentId, showHeader: false),
      ),
    );
  }
}
