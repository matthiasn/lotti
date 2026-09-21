import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/ui/agent_internals_panel.dart';
import 'package:lotti/features/agents/ui/chat/agent_chat_view.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/model/relationship_agent_identity.dart';
import 'package:lotti/features/relationships/state/relationship_chat_controller.dart';
import 'package:lotti/features/relationships/state/relationships_providers.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_suggestions_band.dart';
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
    this.onClose,
    this.showInternalsAction = false,
    super.key,
  });

  final String relationshipId;

  /// Renders a back affordance in the header — the phone route, where the
  /// chat is the whole screen.
  final VoidCallback? onBack;

  /// Renders a close affordance on the header's trailing edge — the desktop
  /// sidebar, where the person page stays beside the chat.
  final VoidCallback? onClose;

  /// Whether the header offers *Agent internals*. The desktop pane does,
  /// because it has the width for a labelled button and no other way in.
  final bool showInternalsAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentId = relationshipAgentIdFor(relationshipId);
    final agent = usableRelationshipAgent(
      ref.watch(agentIdentityProvider(agentId)).value,
    );
    final name = agent?.displayName ?? context.messages.relationshipChatTooltip;

    // The header renders in every state, because on the phone route it holds
    // the only way back — a chat whose agent is still resolving, or turns out
    // not to exist, must not be a screen the user is stuck on. Only the body
    // below it varies. Its internals action needs a resolved agent, so it
    // appears with one.
    return Column(
      children: [
        RelationshipChatHeader(
          agentId: agentId,
          agentName: name,
          onBack: onBack,
          onClose: onClose,
          showInternalsAction: showInternalsAction && agent != null,
        ),
        Expanded(
          child: _body(context, ref, agentId: agentId, name: name),
        ),
      ],
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref, {
    required String agentId,
    required String name,
  }) {
    final identityAsync = ref.watch(agentIdentityProvider(agentId));
    final agent = usableRelationshipAgent(identityAsync.value);

    if (!identityAsync.hasValue && !identityAsync.hasError) {
      return const Center(child: CircularProgressIndicator());
    }
    if (agent == null) {
      return Center(child: Text(context.messages.relationshipChatUnavailable));
    }

    final composer = ref.watch(relationshipChatControllerProvider(agentId));
    final controller = ref.read(
      relationshipChatControllerProvider(agentId).notifier,
    );
    final messages = context.messages;
    // The one-line input has the least room: it uses the name the user calls
    // the person by, when there is one.
    final nickname = ref
        .watch(
          relationshipDetailControllerProvider(
            relationshipId,
          ).select((detail) => detail.value?.relationship.data.nickname),
        )
        ?.trim();
    // The agent is named after the person it watches, but the one answering
    // here is the briefing agent: its replies are signed as the agent, and
    // the empty state and the input talk to it *about* the person.
    return AgentChatView(
      agentId: agentId,
      agentName: messages.relationshipChatAgentName,
      emptyMessage: messages.relationshipChatEmpty(name),
      composerHint: messages.relationshipChatPlaceholder(
        nickname == null || nickname.isEmpty ? name : nickname,
      ),
      draft: composer.draft,
      isSending: composer.isSending,
      hasFailedTurn: composer.failedMessage != null,
      onDraftChanged: controller.updateDraft,
      onSend: controller.send,
      onRetry: controller.retry,
      attachmentBuilder: (context, message) {
        if (message.role != AgentChatRole.agent || message.runKey == null) {
          return null;
        }
        return Consumer(
          builder: (context, ref, child) {
            final detail = ref
                .watch(
                  relationshipDetailControllerProvider(
                    relationshipId,
                  ),
                )
                .value;
            return RelationshipSuggestionsBand(
              key: ValueKey(
                'relationship-chat-proposals-${message.id}',
              ),
              relationshipId: relationshipId,
              checkIns: detail?.checkIns ?? const [],
              runKey: message.runKey,
              showHistory: true,
            );
          },
        );
      },
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
    this.onClose,
    this.showInternalsAction = false,
    super.key,
  });

  final String agentId;
  final String agentName;
  final VoidCallback? onBack;
  final VoidCallback? onClose;
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
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
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
                  size: IconSizes.l,
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
                      style: tokens.typography.styles.subtitle.subtitle2
                          .copyWith(
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
                _InternalsAction(
                  agentId: agentId,
                  agentName: agentName,
                  headerWidth: constraints.maxWidth,
                ),
              ],
              if (onClose != null) ...[
                SizedBox(width: tokens.spacing.step2),
                IconButton(
                  key: const ValueKey('person-chat-close'),
                  tooltip: MaterialLocalizations.of(
                    context,
                  ).closeButtonTooltip,
                  onPressed: onClose,
                  icon: const Icon(LottiIcons.close),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The way into the agent internals from the chat header.
///
/// Labelled where there is room for a word and a bare icon where there is
/// not, at [kPageHeaderFoldWidth] — the same width at which every other page
/// header folds its tools off the title line. The measure is the HEADER's,
/// taken from [headerWidth], not the window's: in the desktop split the chat
/// sits in a pane the sidebar and the resizable people list have already
/// eaten into, so a window-wide reading would label the button while the
/// header itself was phone-narrow.
///
/// One action either way — a menu for a single item would be a click the
/// user does not owe us.
class _InternalsAction extends StatelessWidget {
  const _InternalsAction({
    required this.agentId,
    required this.agentName,
    required this.headerWidth,
  });

  final String agentId;
  final String agentName;

  /// The width the header itself was laid out in.
  final double headerWidth;

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

    return headerWidth >= kPageHeaderFoldWidth
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
