import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/ui/goal_agent_chat_pane.dart';
import 'package:lotti/features/goals/ui/pages/goal_page_state.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/goal_routes.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:material_ui/material_ui.dart';

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
    final detailPath = goalDetailPath(agentId);
    void back() => beamToNamed(detailPath);
    // Before there is a goal to talk to: the goal pages' shared states — a
    // first load, a failed read with Try again, a link that names no goal.
    final GoalPageStateKind? state;
    // The error first: a Riverpod retry is loading and errored at once. A
    // read that resolved to nothing is a goal that is gone, not a load.
    if (!identityAsync.hasValue) {
      state = identityAsync.hasError
          ? GoalPageStateKind.failed
          : GoalPageStateKind.loading;
    } else if (identity is! AgentIdentityEntity ||
        identity.kind != AgentKinds.goalAgent) {
      state = GoalPageStateKind.notFound;
    } else {
      state = null;
    }
    if (state != null) {
      return GoalPageState(
        kind: state,
        onBack: back,
        onRetry: state == GoalPageStateKind.failed
            ? () => ref.invalidate(agentIdentityProvider(agentId))
            : null,
      );
    }
    final page = Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => beamToNamed(detailPath),
        ),
        // Same rule as the detail page: a user-written goal name is routinely
        // long enough to truncate on one line.
        title: Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.designTokens.typography.styles.subtitle.subtitle2
              .copyWith(color: context.designTokens.colors.text.highEmphasis),
        ),
      ),
      body: SafeArea(
        child: isActiveGoal
            ? Padding(
                padding: EdgeInsets.only(
                  bottom: DesignSystemBottomNavigationBar.occupiedHeight(
                    context,
                  ),
                ),
                child: GoalAgentChatPane(
                  agentId: agentId,
                ),
              )
            // An archived goal has no conversation to continue.
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
