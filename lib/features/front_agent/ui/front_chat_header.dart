import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/ui/agent_internals_panel.dart';
import 'package:lotti/features/ai/state/ai_runtime_settings_controller.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/state/front_chat_controller.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';
import 'package:lotti/features/front_agent/ui/front_chat_hero.dart';
import 'package:lotti/features/front_agent/ui/front_conversation_actions.dart';
import 'package:lotti/features/front_agent/ui/front_profile_choice.dart';
import 'package:lotti/features/front_agent/ui/front_voice_controls.dart';
import 'package:lotti/features/front_agent/ui/front_voice_switch.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for the header's controls.
@visibleForTesting
abstract final class FrontChatHeaderKeys {
  static const Key title = Key('front-chat-title');
  static const Key name = Key('front-chat-name');
  static const Key archived = Key('front-chat-archived');
  static const Key inbox = Key('front-chat-inbox');
  static const Key chats = Key('front-chat-chats');
  static const Key back = Key('front-chat-back');
  static const Key more = Key('front-chat-more');
  static const Key newChat = Key('front-chat-new');
  static const Key internals = Key('front-chat-internals');
  static const Key profile = Key('front-chat-profile');
  static const Key stage = Key('front-chat-open-stage');
  static const Key close = Key('front-chat-close');
}

/// The front chat's one-row header, in two modes.
///
/// On a conversation it says who you are talking to and about what: her
/// face (while the companion is switched on; the spark every agent wears
/// while it is off), her name, and under it the open conversation's title.
/// Then her voice: the way to have her say her latest answer again, the
/// switch that mutes her, and her full-screen stage; then one overflow for
/// the rest (her AI profile, which is also her voice, once she exists; her
/// internals, where what the thread has cost is accounted; the open
/// conversation's own actions) and the sheet's close.
///
/// Where the list is a page over the conversation, the row opens with the
/// way to it — a menu glyph named "Chats" by its tooltip, in the slot the
/// list's back arrow takes, so both pages share one leading rail and the
/// title keeps its room — with the inbox count after it, and a new conversation
/// joins the overflow, as do the stage and the switch that mutes her (a
/// checked row), so the row fits a 360 dp phone. Beside
/// the list, the list carries those.
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
            style: tokens.typography.styles.subtitle.subtitle1.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
        ),
        close,
      ];
    } else {
      // Her profile can be chosen once she exists: her first turn creates
      // her, and the choice is written onto her.
      final identity = ref.watch(agentIdentityProvider(frontAgentId)).value;
      // Watched, not read on the tap: the picker opens at once with what is
      // current, and the catalog is never left loading with no listener.
      final profiles = ref.watch(agentSetupOptionsProvider).value?.profiles;
      final defaultProfileId = ref
          .watch(defaultInferenceProfileControllerProvider)
          .value;
      // Read through `.value`: a re-projection keeps the last count.
      final inboxCount =
          ref.watch(
            frontAllChatsThreadProvider.select((t) => t.value?.inboxCount),
          ) ??
          0;
      // Her voice and her stage go with her figure: with the character off
      // she neither stands up nor speaks. Never in the inbox, which gathers
      // every conversation.
      final companionOn =
          ref.watch(configFlagProvider(enableCompanionFlag)).value ?? false;
      final voiceId = companionOn && !inboxOnly ? activeId : null;
      final openList = ref
          .read(frontConversationListOpenProvider.notifier)
          .toggle;
      final startConversation = notBegun && !inboxOnly
          ? null
          : ref.read(frontChatControllerProvider.notifier).startConversation;
      // Where the row has to fit a phone, the switch that mutes her is a
      // checked row of the overflow instead.
      final voiceItem = !listBeside && voiceId != null
          ? frontVoiceMenuItem(context, ref)
          : null;
      row = [
        if (!listBeside) ...[
          // The glyph alone, named by its tooltip: a word here would cost
          // the conversation's title the room it needs on a phone.
          DesignSystemIconAction(
            key: FrontChatHeaderKeys.chats,
            tooltip: messages.queryChats,
            icon: LottiIcons.menu,
            onPressed: openList,
          ),
          // After the glyph, never over it: the two read as one thing, and a
          // tap on the count opens the list as well.
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
          SizedBox(width: tokens.spacing.step3),
        ],
        const FrontCompanionFigure(size: ControlSizes.avatarCompact),
        SizedBox(width: tokens.spacing.step3),
        Expanded(
          child: _Identity(name: messages.frontChatTitle),
        ),
        if (voiceId != null) ...[
          FrontVoiceButton(conversationId: voiceId),
          if (listBeside) ...[
            SizedBox(width: tokens.spacing.step2),
            const FrontVoiceSwitch(),
            SizedBox(width: tokens.spacing.step2),
            DesignSystemIconAction(
              key: FrontChatHeaderKeys.stage,
              tooltip: messages.aiCardCompanionOpenFullScreen,
              icon: LottiIcons.expandFull,
              onPressed: () => openFrontStage(context, voiceId).ignore(),
            ),
          ],
        ],
        // A new conversation and the stage when the row has no room for
        // them, then her profile and internals, then the open
        // conversation's own ways out — the same menu its row in the list
        // has — so the destructive one is last.
        FrontMenuButton(
          key: FrontChatHeaderKeys.more,
          iconColor: tokens.colors.text.mediumEmphasis,
          items: [
            if (!listBeside)
              DesignSystemContextMenuItem(
                key: FrontChatHeaderKeys.newChat,
                label: messages.queryNewChat,
                icon: LottiIcons.editNote,
                onTap: startConversation,
              ),
            if (!listBeside && voiceId != null)
              DesignSystemContextMenuItem(
                key: FrontChatHeaderKeys.stage,
                label: messages.aiCardCompanionOpenFullScreen,
                icon: LottiIcons.expandFull,
                onTap: () => openFrontStage(context, voiceId).ignore(),
              ),
            ?voiceItem,
            if (identity is AgentIdentityEntity && profiles != null)
              DesignSystemContextMenuItem(
                key: FrontChatHeaderKeys.profile,
                label: messages.frontChatProfileMenuItem,
                icon: LottiIcons.aiModel,
                startsGroup: !listBeside,
                onTap: () => FrontProfileChoice.choose(
                  context,
                  ref,
                  identity,
                  profiles: profiles,
                  defaultProfileId: defaultProfileId,
                ).ignore(),
              ),
            DesignSystemContextMenuItem(
              key: FrontChatHeaderKeys.internals,
              label: messages.aiInternalsTitle,
              icon: LottiIcons.reasoning,
              startsGroup:
                  !listBeside &&
                  !(identity is AgentIdentityEntity && profiles != null),
              onTap: () => AgentInternalsPanel.show(
                context: context,
                agentId: frontAgentId,
                agentName: messages.frontChatTitle,
              ),
            ),
            // This conversation's ways out after it, so Delete is last.
            if (conversation != null && !inboxOnly)
              ...FrontConversationActions(
                context,
                ref,
              ).menuItems(conversation, startsGroup: true),
          ],
        ),
        close,
      ];
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level01,
        border: Border(
          bottom: BorderSide(color: tokens.colors.decorative.level01),
        ),
      ),
      child: Padding(
        // The side gutter the bubbles and the list keep: the header's
        // leading and trailing controls sit on the same edges as the
        // content below them.
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step5,
          vertical: tokens.spacing.step3,
        ),
        child: Row(children: row),
      ),
    );
  }
}

/// Who the conversation is with, and what it is about: her name over the
/// open conversation's title — the inbox's name while that view is on — and
/// her name alone for a conversation not begun. An archived conversation
/// says so before its title, as its row does in the list.
class _Identity extends ConsumerWidget {
  const _Identity({required this.name});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final open = frontOpenConversation(ref, context.messages);
    final subtitle = open.title == name ? null : open.title;
    final nameText = Text(
      name,
      key: subtitle == null
          ? FrontChatHeaderKeys.title
          : FrontChatHeaderKeys.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: tokens.typography.styles.subtitle.subtitle1.copyWith(
        color: tokens.colors.text.highEmphasis,
      ),
    );
    if (subtitle == null) return nameText;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        nameText,
        Row(
          children: [
            if (open.archived) ...[
              Icon(
                LottiIcons.archive,
                key: FrontChatHeaderKeys.archived,
                size: IconSizes.xs,
                color: tokens.colors.text.mediumEmphasis,
              ),
              SizedBox(width: tokens.spacing.step2),
            ],
            Flexible(
              child: Tooltip(
                message: subtitle,
                child: Text(
                  subtitle,
                  key: FrontChatHeaderKeys.title,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
