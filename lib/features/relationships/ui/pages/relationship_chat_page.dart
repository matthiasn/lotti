import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/ui/chat/agent_chat_view.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/state/relationship_chat_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:material_ui/material_ui.dart';

/// The relationship agent's conversation — the shared [AgentChatView] on
/// the kind-agnostic chat projection, wired to the durable
/// `RelationshipChatService` turn (plan v2 phase 5 item 4; the goal chat
/// page shape).
class RelationshipChatPage extends ConsumerWidget {
  const RelationshipChatPage({required this.relationshipId, super.key});

  final String relationshipId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentId = relationshipAgentIdFor(relationshipId);
    final identityAsync = ref.watch(agentIdentityProvider(agentId));
    final identity = identityAsync.value;
    final isActive =
        identity is AgentIdentityEntity &&
        identity.kind == AgentKinds.relationshipAgent &&
        identity.lifecycle == AgentLifecycle.active;
    final name = isActive
        ? identity.displayName
        : context.messages.relationshipChatTooltip;
    final detailPath = '/people/$relationshipId';
    final composer = ref.watch(relationshipChatControllerProvider(agentId));
    final controller = ref.read(
      relationshipChatControllerProvider(agentId).notifier,
    );
    final page = Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => beamToNamed(detailPath)),
        title: Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.designTokens.typography.styles.subtitle.subtitle2
              .copyWith(color: context.designTokens.colors.text.highEmphasis),
        ),
      ),
      body: SafeArea(
        child: !identityAsync.hasValue && !identityAsync.hasError
            ? const Center(child: CircularProgressIndicator())
            : isActive
            ? Padding(
                padding: EdgeInsets.only(
                  bottom: DesignSystemBottomNavigationBar.occupiedHeight(
                    context,
                  ),
                ),
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
              )
            : Center(
                child: Text(context.messages.relationshipChatUnavailable),
              ),
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
