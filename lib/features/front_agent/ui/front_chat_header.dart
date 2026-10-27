import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/ui/agent_internals_panel.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/state/companion_look_controller.dart';
import 'package:lotti/features/companion/ui/companion_view.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for the header's controls.
@visibleForTesting
abstract final class FrontChatHeaderKeys {
  static const Key title = Key('front-chat-title');
  static const Key figure = Key('front-chat-figure');
  static const Key inbox = Key('front-chat-inbox');
  static const Key internals = Key('front-chat-internals');
  static const Key close = Key('front-chat-close');
}

/// The front chat's identity band, one row: her face when the companion is
/// switched on, a spark tile when it is not; her name; the inbox chip while
/// something waits on the user; the way into her internals, where what the
/// thread has cost is accounted (decision 8 made the routing model hers and
/// cheap); and the sheet's close. What she does is said by the empty
/// thread's invitation and the composer's hint, not repeated up here.
class FrontChatHeader extends ConsumerWidget {
  const FrontChatHeader({required this.onClose, super.key});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final companionOn =
        ref.watch(configFlagProvider(enableCompanionFlag)).value ?? false;
    // Read through `.value`: a re-projection keeps the last count.
    final inboxCount =
        ref.watch(frontChatThreadProvider.select((t) => t.value?.inboxCount)) ??
        0;
    final inboxOnly = ref.watch(frontInboxFilterProvider);
    // How many doors wait on the user, and the filter to just those turns.
    // Absent while nothing waits and the filter is off.
    final inbox = inboxCount == 0 && !inboxOnly
        ? null
        : DesignSystemChip(
            key: FrontChatHeaderKeys.inbox,
            label: messages.frontChatInboxChip(inboxCount),
            leadingIcon: LottiIcons.inbox,
            size: DesignSystemChipSize.compactPillTouch,
            outlined: !inboxOnly,
            selected: inboxOnly,
            onPressed: ref.read(frontInboxFilterProvider.notifier).toggle,
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level01,
        border: Border(
          bottom: BorderSide(color: tokens.colors.decorative.level01),
        ),
      ),
      child: Padding(
        // The side gutter the bubbles below keep, so the title and the
        // thread share a left edge.
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step5,
          vertical: tokens.spacing.step3,
        ),
        child: Row(
          children: [
            _Figure(companionOn: companionOn),
            SizedBox(width: tokens.spacing.step3),
            Expanded(
              child: Text(
                messages.frontChatTitle,
                key: FrontChatHeaderKeys.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
            ),
            if (inbox != null) ...[
              SizedBox(width: tokens.spacing.step2),
              inbox,
            ],
            SizedBox(width: tokens.spacing.step2),
            DesignSystemIconAction(
              key: FrontChatHeaderKeys.internals,
              tooltip: messages.aiInternalsTitle,
              onPressed: () => AgentInternalsPanel.show(
                context: context,
                agentId: frontAgentId,
                agentName: messages.frontChatTitle,
              ),
              icon: LottiIcons.reasoning,
            ),
            DesignSystemIconAction(
              key: FrontChatHeaderKeys.close,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: onClose,
              icon: LottiIcons.close,
            ),
          ],
        ),
      ),
    );
  }
}

/// Her bust in the session's outfit, or the spark tile every agent chat
/// header wears when the companion character is switched off.
class _Figure extends ConsumerWidget {
  const _Figure({required this.companionOn});

  final bool companionOn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    return ExcludeSemantics(
      child: Container(
        key: FrontChatHeaderKeys.figure,
        width: ControlSizes.avatar,
        height: ControlSizes.avatar,
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tokens.colors.aiCard.accentSoft,
          borderRadius: BorderRadius.circular(tokens.radii.m),
          border: Border.all(color: tokens.colors.aiCard.border),
        ),
        child: companionOn
            ? CompanionView(
                look: ref.watch(companionLookProvider),
                framing: CompanionFraming.bust,
              )
            : Icon(
                LottiIcons.aiSpark,
                size: IconSizes.l,
                color: tokens.colors.aiCard.accent,
              ),
      ),
    );
  }
}
