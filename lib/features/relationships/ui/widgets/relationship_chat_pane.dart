import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/ui/agent_internals_panel.dart';
import 'package:lotti/features/agents/ui/chat/agent_chat_view.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/state/relationship_chat_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The per-person agent conversation, header and all — the shared
/// [AgentChatView] under an identity header that says who is answering and
/// what they can see (design 2026-09-06 §6, artboard 1e).
///
/// Hosted twice: by `RelationshipChatPage` on phones, where it is the whole
/// route, and by the People detail pane on desktop, where it replaces the
/// person page inside the same column. [onBack] and [showInternalsAction]
/// are what differ between those hosts.
class RelationshipChatPane extends ConsumerWidget {
  const RelationshipChatPane({
    required this.relationshipId,
    this.onBack,
    this.showInternalsAction = false,
    super.key,
  });

  final String relationshipId;

  /// Renders a back affordance in the header when supplied. The phone route
  /// leaves this null: its app bar already has one.
  final VoidCallback? onBack;

  /// Whether the header offers *Agent internals*. The desktop pane does,
  /// because it has the width for a labelled button and no other way in.
  final bool showInternalsAction;

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

    if (!identityAsync.hasValue && !identityAsync.hasError) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!isActive) {
      return Center(child: Text(context.messages.relationshipChatUnavailable));
    }

    final composer = ref.watch(relationshipChatControllerProvider(agentId));
    final controller = ref.read(
      relationshipChatControllerProvider(agentId).notifier,
    );

    return Column(
      children: [
        RelationshipChatHeader(
          agentId: agentId,
          agentName: name,
          onBack: onBack,
          showInternalsAction: showInternalsAction,
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

/// The chat's identity band: sparkle, the agent's name beside what it is,
/// and one line naming the boundary — it reads the check-ins, never the
/// phone number or the email (ADR 0041 §5).
class RelationshipChatHeader extends StatelessWidget {
  const RelationshipChatHeader({
    required this.agentId,
    required this.agentName,
    this.onBack,
    this.showInternalsAction = false,
    super.key,
  });

  final String agentId;
  final String agentName;
  final VoidCallback? onBack;
  final bool showInternalsAction;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    return DecoratedBox(
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
            if (onBack != null) ...[
              IconButton(
                key: const ValueKey('person-chat-back'),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: onBack,
                icon: const Icon(LottiIcons.back),
              ),
              SizedBox(width: tokens.spacing.step2),
            ],
            Container(
              width: tokens.spacing.step8,
              height: tokens.spacing.step8,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tokens.colors.aiCard.accentSoft,
                borderRadius: BorderRadius.circular(tokens.radii.m),
                border: Border.all(color: tokens.colors.aiCard.border),
              ),
              child: Icon(
                LottiIcons.aiSpark,
                size: tokens.spacing.step6,
                color: tokens.colors.aiCard.accent,
              ),
            ),
            SizedBox(width: tokens.spacing.step3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    messages.relationshipChatAgentTitle(agentName),
                    key: const ValueKey('person-chat-title'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                  SizedBox(height: tokens.spacing.step1),
                  Text(
                    messages.relationshipChatAgentSubtitle,
                    key: const ValueKey('person-chat-subtitle'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: tokens.colors.text.lowEmphasis,
                    ),
                  ),
                ],
              ),
            ),
            if (showInternalsAction) ...[
              SizedBox(width: tokens.spacing.step3),
              _InternalsAction(agentId: agentId, agentName: agentName),
            ],
          ],
        ),
      ),
    );
  }
}

/// The way into the agent internals from the chat header.
///
/// Labelled where there is room for a word (the desktop detail pane, which
/// has no other entry point) and a bare icon on a phone, where the label
/// would crowd out the agent's own name. One action either way — a menu for
/// a single item would be a click the user does not owe us.
class _InternalsAction extends StatelessWidget {
  const _InternalsAction({required this.agentId, required this.agentName});

  /// Below this width the header shows the icon alone.
  static const double _labelledFrom = 520;

  final String agentId;
  final String agentName;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    void open() => Navigator.of(context).push(
      AgentInternalsPanel.route(
        context: context,
        agentId: agentId,
        agentName: agentName,
      ),
    );

    final labelled = MediaQuery.sizeOf(context).width >= _labelledFrom;
    return labelled
        ? DesignSystemButton(
            key: const ValueKey('person-chat-internals'),
            label: messages.aiInternalsTitle,
            variant: DesignSystemButtonVariant.secondary,
            leadingIcon: LottiIcons.reasoning,
            onPressed: open,
          )
        : IconButton(
            key: const ValueKey('person-chat-internals'),
            tooltip: messages.aiInternalsTitle,
            onPressed: open,
            icon: const Icon(LottiIcons.reasoning),
          );
  }
}
