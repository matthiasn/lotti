import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/knowledge/agent_knowledge_providers.dart';
import 'package:lotti/features/agents/ui/knowledge/agent_knowledge_panel.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// What the goal's agent has learned about the user and the goal
/// (`remember_goal_fact`, ADR 0057 decision 1): the shared "What I've
/// learned" panel, where proposals are confirmed and any fact edited or
/// forgotten.
///
/// Takes no room until the agent has learned something — a goal page is
/// long, and an empty panel would be one more card saying nothing. A first
/// read that fails is the exception: the panel shows why, with a retry, so
/// the facts are never silently out of reach. It owns the gap above it, so
/// rendering nothing leaves no hole in the page.
class GoalKnowledgeSection extends ConsumerWidget {
  const GoalKnowledgeSection({required this.agentId, super.key});

  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `.value`: a re-read after a confirm or a synced edit keeps the panel
    // on screen rather than flashing it away.
    final async = ref.watch(agentKnowledgeProvider(agentId));
    final view = async.value;
    final failed = view == null && async.hasError;
    if (!failed && (view == null || view.isEmpty)) {
      return const SizedBox.shrink();
    }
    return Padding(
      key: const ValueKey('goal-knowledge-section'),
      padding: EdgeInsets.only(
        top: context.designTokens.spacing.cardItemSpacing,
      ),
      child: AgentKnowledgePanel(agentId: agentId),
    );
  }
}
