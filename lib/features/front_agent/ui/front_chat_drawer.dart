import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/ui/agent_internals_panel.dart';
import 'package:lotti/features/ai/state/ai_runtime_settings_controller.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/consumption_summary_pill.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/state/front_chat_controller.dart';
import 'package:lotti/features/front_agent/state/front_conversation_cost.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';
import 'package:lotti/features/front_agent/ui/front_chat_header.dart';
import 'package:lotti/features/front_agent/ui/front_conversation_list.dart';
import 'package:lotti/features/front_agent/ui/front_profile_choice.dart';
import 'package:lotti/features/front_agent/ui/front_voice_switch.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for the drawer's controls.
@visibleForTesting
abstract final class FrontChatDrawerKeys {
  static const Key search = Key('front-chat-drawer-search');
  static const Key close = Key('front-chat-drawer-close');
  static const Key newChat = Key('front-chat-drawer-new');
  static const Key profile = Key('front-chat-drawer-profile');
  static const Key internals = Key('front-chat-drawer-internals');
}

/// Her drawer: everything about the chat that is not the conversation.
///
/// A top row as tall as her header — the search, and on a phone the way
/// back to the conversation — then a new conversation, then the
/// conversations themselves ([FrontConversationList]: the inbox, the
/// categories, the dated history), then her settings
/// ([FrontChatDrawerFooter]). On a phone it slides over the thread; on a
/// desktop window it sits [beside] it, always open, holding the same things
/// in the same order.
class FrontChatDrawer extends ConsumerStatefulWidget {
  const FrontChatDrawer({
    this.beside = false,
    this.keyboardUp = false,
    super.key,
  });

  /// Always open beside the conversation: there is nothing to close.
  final bool beside;

  /// Whether the on-screen keyboard is up. Passed in rather than read here:
  /// the dialog she opens in pads by the keyboard and removes the inset from
  /// everything inside it, so only her surface, above the dialog, sees it.
  final bool keyboardUp;

  @override
  ConsumerState<FrontChatDrawer> createState() => _FrontChatDrawerState();
}

class _FrontChatDrawerState extends ConsumerState<FrontChatDrawer> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    void close() =>
        ref.read(frontConversationListOpenProvider.notifier).close();
    final canStart = frontCanStartConversation(ref);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: tokens.colors.decorative.level01),
            ),
          ),
          child: Padding(
            padding: frontBandPadding(tokens),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: TapTargets.minimum,
              ),
              child: Row(
                spacing: tokens.spacing.step2,
                children: [
                  Expanded(
                    child: DesignSystemSearch(
                      key: FrontChatDrawerKeys.search,
                      hintText: messages.frontChatSearchChats,
                      size: DesignSystemSearchSize.small,
                      onChanged: (value) => setState(() => _query = value),
                      onClear: () => setState(() => _query = ''),
                    ),
                  ),
                  if (!widget.beside)
                    DesignSystemIconAction(
                      key: FrontChatDrawerKeys.close,
                      tooltip: messages.frontChatDrawerClose,
                      // Back to the conversation: the cross is her
                      // surface's own close, in the header beside this.
                      icon: LottiIcons.chevronLeft,
                      onPressed: close,
                    ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
            left: tokens.spacing.step5,
            top: tokens.spacing.step3,
            right: tokens.spacing.step5,
          ),
          // The drawer's one action, so the accent.
          child: DesignSystemListItem(
            key: FrontChatDrawerKeys.newChat,
            titleContent: Text(
              messages.queryNewChat,
              style: frontDrawerLabelStyle(context).copyWith(
                color: tokens.colors.interactive.enabled,
                fontWeight: tokens.typography.weight.semiBold,
              ),
            ),
            size: frontDrawerRowSize(context),
            borderRadius: BorderRadius.circular(tokens.radii.s),
            hoverBackgroundColor: tokens.colors.surface.enabled,
            leading: Icon(
              LottiIcons.editNote,
              size: IconSizes.s,
              color: tokens.colors.interactive.enabled,
            ),
            onTap: !canStart
                ? null
                : () {
                    ref
                        .read(frontChatControllerProvider.notifier)
                        .startConversation();
                    close();
                  },
          ),
        ),
        Expanded(
          child: FrontConversationList(query: _query, beside: widget.beside),
        ),
        // While the keyboard is up the search is what is being used: her
        // settings step aside, so a short or landscape screen keeps room
        // for what it finds.
        if (!widget.keyboardUp) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step5),
            child: const DesignSystemDivider(),
          ),
          const FrontChatDrawerFooter(),
        ],
      ],
    );
  }
}

/// Her settings, at the drawer's foot: whether she answers aloud (with the
/// way to have her say her latest answer again), her AI profile with the
/// one in use, and her internals with what the open conversation has cost.
/// The same calls the header's overflow made, in rows that say their value.
class FrontChatDrawerFooter extends ConsumerWidget {
  const FrontChatDrawerFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final size = frontDrawerRowSize(context);
    final rounded = BorderRadius.circular(tokens.radii.s);
    final inboxOnly = ref.watch(frontInboxFilterProvider);
    final activeId = ref.watch(frontActiveConversationProvider).value;
    // Her profile can be chosen once she exists: her first turn creates
    // her, and the choice is written onto her.
    final identity = ref.watch(agentIdentityProvider(frontAgentId)).value;
    // Watched, not read on the tap: the picker opens at once with what is
    // current, and the catalog is never left loading with no listener.
    final profiles = ref.watch(agentSetupOptionsProvider).value?.profiles;
    final defaultProfileId = ref
        .watch(defaultInferenceProfileControllerProvider)
        .value;
    final cost = ref.watch(frontConversationCostProvider);
    final quiet = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );

    Widget value(String text) => ConstrainedBox(
      // A long profile name gives way to the row's label.
      constraints: BoxConstraints(maxWidth: tokens.spacing.step12),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: quiet,
      ),
    );

    // Settings, quieter than the conversations over them, and in one
    // style on every layout.
    Widget label(String text) => Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: frontDrawerLabelStyle(
        context,
      ).copyWith(color: tokens.colors.text.mediumEmphasis),
    );

    Widget icon(IconData glyph) => Icon(
      glyph,
      size: IconSizes.s,
      color: tokens.colors.text.mediumEmphasis,
    );

    String? profileName() {
      if (identity is! AgentIdentityEntity || profiles == null) return null;
      final own = FrontProfileChoice.ownProfileId(identity.config);
      String? nameOf(String? id) =>
          profiles.where((p) => p.id == id).firstOrNull?.name;
      return nameOf(own) ?? nameOf(defaultProfileId);
    }

    final profile = profileName();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        tokens.spacing.step2,
        tokens.spacing.step5,
        tokens.spacing.step4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Her voice is the open conversation's: none in the inbox.
          FrontVoiceSwitch(conversationId: inboxOnly ? null : activeId),
          const FrontVoiceSpeedRow(),
          if (identity is AgentIdentityEntity && profiles != null)
            DesignSystemListItem(
              key: FrontChatDrawerKeys.profile,
              titleContent: label(messages.frontChatProfileMenuItem),
              size: size,
              borderRadius: rounded,
              hoverBackgroundColor: tokens.colors.surface.enabled,
              leading: icon(LottiIcons.aiModel),
              trailing: profile == null ? null : value(profile),
              onTap: () => FrontProfileChoice.choose(
                context,
                ref,
                identity,
                profiles: profiles,
                defaultProfileId: defaultProfileId,
              ).ignore(),
            ),
          DesignSystemListItem(
            key: FrontChatDrawerKeys.internals,
            titleContent: label(messages.aiInternalsTitle),
            size: size,
            borderRadius: rounded,
            hoverBackgroundColor: tokens.colors.surface.enabled,
            leading: icon(LottiIcons.reasoning),
            // What the open conversation has cost, once it has cost anything;
            // nothing in the inbox, which is no one conversation.
            trailing: cost == null || cost.callCount == 0
                ? null
                : value(consumptionSummaryLabel(context, cost)),
            onTap: () => AgentInternalsPanel.show(
              context: context,
              agentId: frontAgentId,
              agentName: messages.frontChatTitle,
            ),
          ),
        ],
      ),
    );
  }
}
