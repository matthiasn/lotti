import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/ui/chat/agent_chat_view.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_chat_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class GoalAgentChatPane extends ConsumerWidget {
  const GoalAgentChatPane({
    required this.agentId,
    this.showHeader = true,
    super.key,
  });

  final String agentId;
  final bool showHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(agentIdentityProvider(agentId)).value;
    final health = ref.watch(goalAgentHealthProvider(agentId)).value;
    final composer = ref.watch(goalChatControllerProvider(agentId));
    final controller = ref.read(goalChatControllerProvider(agentId).notifier);
    final name = identity is AgentIdentityEntity
        ? identity.displayName
        : context.messages.agentsPageTitle;
    final statement = health?.spec?.statement;
    final tokens = context.designTokens;

    return Column(
      children: [
        if (showHeader)
          DecoratedBox(
            decoration: BoxDecoration(
              color: tokens.colors.background.level01,
              border: Border(
                bottom: BorderSide(color: tokens.colors.decorative.level01),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(tokens.spacing.step4),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: tokens.colors.interactive.enabled,
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: tokens.typography.styles.subtitle.subtitle2
                              .copyWith(
                                color: tokens.colors.text.highEmphasis,
                              ),
                        ),
                        if (statement != null)
                          Text(
                            statement,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tokens.typography.styles.others.caption
                                .copyWith(
                                  color: tokens.colors.text.mediumEmphasis,
                                ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: AgentChatView(
            agentId: agentId,
            agentName: name,
            draft: composer.draft,
            isSending: composer.isSending,
            hasFailedTurn: composer.failedMessage != null,
            onDraftChanged: controller.updateDraft,
            onSend: controller.send,
            onRetry: controller.retry,
          ),
        ),
      ],
    );
  }
}
