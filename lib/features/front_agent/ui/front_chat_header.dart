import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/ui/agent_internals_panel.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/state/front_chat_controller.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';
import 'package:lotti/features/front_agent/ui/front_chat_hero.dart';
import 'package:lotti/features/front_agent/ui/front_conversation_actions.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for the header's controls.
@visibleForTesting
abstract final class FrontChatHeaderKeys {
  static const Key title = Key('front-chat-title');
  static const Key inbox = Key('front-chat-inbox');
  static const Key chats = Key('front-chat-chats');
  static const Key back = Key('front-chat-back');
  static const Key more = Key('front-chat-more');
  static const Key newChat = Key('front-chat-new');
  static const Key internals = Key('front-chat-internals');
  static const Key close = Key('front-chat-close');
}

/// The front chat's one-row header, in two modes.
///
/// On a conversation the row opens with the way to the list of
/// conversations — in the slot the list's back arrow takes, so both pages
/// share one leading rail — then her face while the companion is switched
/// on (with it off there is no stand-in tile), then the title, the open
/// conversation's or her name for one not begun, taking the row's width.
/// After it come the inbox
/// chip while something waits on the user in any conversation, a new
/// conversation, one overflow for the rest (her internals, where what the
/// thread has cost is accounted), and the sheet's close.
///
/// On the list the row is a page header: back to the conversation, "Chats",
/// close — nothing that would duplicate the list's own new-chat row.
class FrontChatHeader extends ConsumerWidget {
  const FrontChatHeader({
    required this.onClose,
    this.listBeside = false,
    super.key,
  });

  final VoidCallback onClose;

  /// The list sits beside the conversation, carrying the way to it, a new
  /// conversation and the inbox, so the control row leaves them out.
  final bool listBeside;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final listOpen =
        !listBeside && ref.watch(frontConversationListOpenProvider);
    final inboxOnly = ref.watch(frontInboxFilterProvider);
    // The title rides the control row once the hero has scrolled away —
    // and always in the inbox, which has no hero of its own.
    final inLine = ref.watch(frontHeroScrolledProvider) || inboxOnly;
    final open = frontOpenConversation(ref, messages);
    // Watched in both modes: the conversation is still there behind the list,
    // and its title must not blink out when the list closes.
    final activeId = ref.watch(frontActiveConversationProvider).value;
    final index = ref.watch(frontConversationsProvider).value;
    final conversation = index?.byId(activeId);
    // Known to be new and empty: the index has loaded and does not list it.
    final notBegun = index != null && activeId != null && conversation == null;
    final close = DesignSystemIconAction(
      key: FrontChatHeaderKeys.close,
      tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
      onPressed: onClose,
      icon: LottiIcons.close,
    );
    final titleStyle = tokens.typography.styles.subtitle.subtitle1;

    final List<Widget> row;
    if (listOpen) {
      row = [
        DesignSystemIconAction(
          key: FrontChatHeaderKeys.back,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: ref.read(frontConversationListOpenProvider.notifier).close,
          icon: LottiIcons.back,
        ),
        SizedBox(width: tokens.spacing.step2),
        Expanded(
          child: Text(
            messages.queryChats,
            key: FrontChatHeaderKeys.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: titleStyle.copyWith(color: tokens.colors.text.highEmphasis),
          ),
        ),
        close,
      ];
    } else {
      // Read through `.value`: a re-projection keeps the last count.
      final inboxCount =
          ref.watch(
            frontAllChatsThreadProvider.select((t) => t.value?.inboxCount),
          ) ??
          0;
      final openList = ref
          .read(frontConversationListOpenProvider.notifier)
          .toggle;
      row = [
        // Beside the list these live in it: the way to it, a new
        // conversation, the inbox.
        if (!listBeside) ...[
          // The way to the list sits where the list's own back arrow does,
          // so the two pages share one leading rail.
          // While something waits on the user in any conversation, its count
          // on the way to the list — where the inbox is — rather than a chip
          // taking the title's width.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Said in a word as well as the glyph: three lines alone do
              // not tell anyone that their other chats live there. Its
              // glyph on the thread's own edge.
              DesignSystemButton(
                key: FrontChatHeaderKeys.chats,
                label: messages.queryChats,
                variant: DesignSystemButtonVariant.quiet,
                leadingIcon: LottiIcons.menu,
                alignsLabelToLeadingEdge: true,
                onPressed: openList,
              ),
              // After the word, never over it: "Chats ②" reads as one
              // thing, and a tap on the count opens the list as well.
              if (inboxCount > 0)
                GestureDetector(
                  onTap: openList,
                  child: DesignSystemBadge.number(
                    key: FrontChatHeaderKeys.inbox,
                    value: '$inboxCount',
                    // The tone query chat marks "waiting on you" with.
                    tone: DesignSystemBadgeTone.warning,
                    semanticLabel: messages.frontChatInboxChip(inboxCount),
                  ),
                ),
            ],
          ),
          // A step before the next control, so the count reads as the
          // word's, never the pencil's.
          SizedBox(width: tokens.spacing.step3),
          // Beside the list, as ChatGPT groups them: the ways to another
          // conversation lead, so the pencil never reads as "rename this".
          DesignSystemIconAction(
            key: FrontChatHeaderKeys.newChat,
            tooltip: messages.queryNewChat,
            // Nothing to start while the open one is new and empty already.
            onPressed: notBegun && !inboxOnly
                ? null
                : ref
                      .read(frontChatControllerProvider.notifier)
                      .startConversation,
            icon: LottiIcons.editNote,
          ),
        ],
        // She and the title lead the thread from its hero; once that has
        // scrolled away, they ride here in a line.
        Expanded(
          child: AnimatedOpacity(
            opacity: inLine ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: inLine
                ? Row(
                    children: [
                      SizedBox(width: tokens.spacing.step3),
                      const FrontCompanionFigure(
                        size: ControlSizes.avatarCompact,
                      ),
                      SizedBox(width: tokens.spacing.step3),
                      Expanded(
                        child: Tooltip(
                          message: open.title,
                          child: Text(
                            open.title,
                            key: FrontChatHeaderKeys.title,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                            style: tokens.typography.styles.subtitle.subtitle2
                                .copyWith(
                                  color: tokens.colors.text.highEmphasis,
                                ),
                          ),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ),
        // Her internals, then the open conversation's own ways out — the
        // same menu its row in the list has — so the destructive one is last.
        DesignSystemContextMenuButton(
          key: FrontChatHeaderKeys.more,
          iconColor: tokens.colors.text.mediumEmphasis,
          items: [
            DesignSystemContextMenuItem(
              key: FrontChatHeaderKeys.internals,
              label: messages.aiInternalsTitle,
              icon: LottiIcons.reasoning,
              onTap: () => AgentInternalsPanel.show(
                context: context,
                agentId: frontAgentId,
                agentName: messages.frontChatTitle,
              ),
            ),
            // This conversation's ways out after it, so Delete is last.
            if (conversation != null && !inboxOnly)
              ...FrontConversationActions(context, ref).menuItems(conversation),
          ],
        ),
        close,
      ];
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level01,
        // A rule under the controls only once the hero has gone, or on the
        // list: over her, the thread's own day divider is the only line.
        border: listOpen || inLine
            ? Border(
                bottom: BorderSide(color: tokens.colors.decorative.level01),
              )
            : null,
      ),
      child: Padding(
        // The side gutter the bubbles and the list keep: the header's
        // leading and trailing controls sit on the same edges as the
        // content below them.
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step5,
          vertical: tokens.spacing.step3,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: row),
          ],
        ),
      ),
    );
  }
}
