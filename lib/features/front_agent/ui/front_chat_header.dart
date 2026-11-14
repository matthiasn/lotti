import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/state/front_chat_controller.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';
import 'package:lotti/features/front_agent/ui/front_companion_figure.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for the header's controls.
@visibleForTesting
abstract final class FrontChatHeaderKeys {
  static const Key title = Key('front-chat-title');
  static const Key inbox = Key('front-chat-inbox');
  static const Key drawer = Key('front-chat-drawer');
  static const Key newChat = Key('front-chat-new');
  static const Key companion = Key('front-chat-companion-toggle');
  static const Key figure = Key('front-chat-header-figure');
  static const Key close = Key('front-chat-close');
}

/// The inset of the sheet's top band — her header, and the drawer's top row
/// beside it: with a tap target's height inside both, they come out the
/// same height, so beside each other their hairlines meet.
EdgeInsets frontBandPadding(DsTokens tokens) => EdgeInsets.symmetric(
  horizontal: tokens.spacing.step5,
  vertical: tokens.spacing.step2,
);

/// Whether a new conversation has anything to start: not while the open one
/// is already new and empty (the index has loaded and does not list it),
/// unless the inbox is on, which a new chat leaves. Watches what it reads.
bool frontCanStartConversation(WidgetRef ref) {
  final inboxOnly = ref.watch(frontInboxFilterProvider);
  final activeId = ref.watch(frontActiveConversationProvider).value;
  final index = ref.watch(frontConversationsProvider).value;
  final notBegun =
      index != null && activeId != null && index.byId(activeId) == null;
  return !notBegun || inboxOnly;
}

/// The front chat's header: one row, as a ChatGPT or Claude window has it.
///
/// The drawer's toggle — a dot on it while something waits in the inbox,
/// whose count the drawer's Inbox row says — then her face in a rounded tile (while the companion is switched
/// on; the spark every agent wears while it is off; a tap on it shows her
/// glass card over the thread, in place, and the face slides away while the
/// card is out), her name, a new conversation and the sheet's close.
/// Everything else — the conversations, her voice, her profile, her
/// internals — is the drawer's (`FrontChatDrawer`).
///
/// Beside the list (a desktop window) the drawer is always there and
/// carries its own new-chat row, so the row is her face, her name and the
/// close.
class FrontChatHeader extends ConsumerWidget {
  const FrontChatHeader({
    required this.onClose,
    this.listBeside = false,
    this.drawerFocusNode,
    super.key,
  });

  final VoidCallback onClose;

  /// The drawer sits beside the conversation, so the row leaves out the way
  /// to it and a new conversation.
  final bool listBeside;

  /// The drawer toggle's focus, so closing the drawer can hand focus back to
  /// what opened it.
  final FocusNode? drawerFocusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final inboxOnly = ref.watch(frontInboxFilterProvider);
    final activeId = ref.watch(frontActiveConversationProvider).value;
    // Her stage goes with her figure: with the character off she does not
    // stand up. Never in the inbox, which gathers every conversation.
    final companionOn =
        ref.watch(configFlagProvider(enableCompanionFlag)).value ?? false;
    final faceEnabled = companionOn && !inboxOnly && activeId != null;
    // Read through `.value`: a re-projection keeps the last count.
    final inboxCount =
        ref.watch(
          frontAllChatsThreadProvider.select((t) => t.value?.inboxCount),
        ) ??
        0;
    // Read on the tap: the pane is what keeps the drawer's state alive, and
    // a notifier taken at build could be one already disposed.
    void openDrawer() =>
        ref.read(frontConversationListOpenProvider.notifier).toggle();

    // Under the drawer slid over it the row's end shows through the scrim,
    // beside the drawer's own way back: its actions step aside, keeping
    // their room, so one cross is not read for two.
    final underDrawer =
        !listBeside && ref.watch(frontConversationListOpenProvider);
    Widget aside(Widget action) => Visibility(
      visible: !underDrawer,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: action,
    );

    // Where the user is: over a phone's or a tablet's thread the drawer
    // that lists the conversations is shut, so the row names the open one.
    // Her own name stays for one not begun, for the inbox — every
    // conversation at once — and beside the drawer, which marks the open row.
    final openTitle = listBeside || inboxOnly
        ? null
        : ref
              .watch(frontConversationsProvider)
              .value
              ?.conversations
              .where((c) => c.id == activeId)
              .map((c) => c.title.trim())
              .where((title) => title.isNotEmpty)
              .firstOrNull;

    final row = <Widget>[
      if (!listBeside) ...[
        // Something waits: a quiet dot on the glyph, never a count in the
        // header — the drawer's Inbox row says how many.
        Stack(
          clipBehavior: Clip.none,
          children: [
            DesignSystemIconAction(
              key: FrontChatHeaderKeys.drawer,
              focusNode: drawerFocusNode,
              tooltip: messages.queryChats,
              icon: LottiIcons.menu,
              onPressed: openDrawer,
            ),
            if (inboxCount > 0)
              PositionedDirectional(
                top: tokens.spacing.step3,
                end: tokens.spacing.step3,
                // A picture on the glyph: the tap is the glyph's.
                child: IgnorePointer(
                  child: DesignSystemBadge.dot(
                    key: FrontChatHeaderKeys.inbox,
                    // The tone query chat marks "waiting on you" with.
                    tone: DesignSystemBadgeTone.warning,
                    semanticLabel: messages.frontChatInboxChip(inboxCount),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(width: tokens.spacing.step3),
      ],
      _CompanionFace(enabled: faceEnabled),
      Expanded(
        child: Text(
          openTitle ?? messages.frontChatTitle,
          key: FrontChatHeaderKeys.title,
          // A conversation's title is longer than her name: a step smaller
          // and on up to two lines, which the band's height already holds.
          maxLines: openTitle == null ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          style:
              (openTitle == null
                      ? tokens.typography.styles.subtitle.subtitle1
                      : tokens.typography.styles.subtitle.subtitle2)
                  .copyWith(color: tokens.colors.text.highEmphasis),
        ),
      ),
      if (!listBeside)
        aside(
          DesignSystemIconAction(
            key: FrontChatHeaderKeys.newChat,
            tooltip: messages.queryNewChat,
            icon: LottiIcons.editNote,
            // Already in a new, empty one: nothing to start.
            onPressed: frontCanStartConversation(ref)
                ? ref
                      .read(frontChatControllerProvider.notifier)
                      .startConversation
                : null,
          ),
        ),
      aside(
        DesignSystemIconAction(
          key: FrontChatHeaderKeys.close,
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: onClose,
          icon: LottiIcons.close,
        ),
      ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level01,
        border: Border(
          bottom: BorderSide(color: tokens.colors.decorative.level01),
        ),
      ),
      child: Padding(
        // The side gutter the bubbles and the drawer keep, so the row's
        // leading and trailing controls sit on the content's edges.
        padding: frontBandPadding(tokens),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: TapTargets.minimum),
          // Over a thread on its own the row keeps the thread's measure, so
          // on a wide panel its controls sit on the column they act on.
          child: listBeside
              ? Row(children: row)
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: kProseMeasureWidth,
                    ),
                    child: Row(children: row),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Her face at the head of the conversation, a rounded tile: a tap floats
/// her glass card over the thread ([frontCompanionCardShownProvider]), in
/// place — never a page of its own — and the face slides away while the card
/// is out, since she is already on screen; Hide in the card's menu brings
/// the face back.
/// Only her face, never a control, while she cannot float: with the
/// character off, or in the inbox.
class _CompanionFace extends ConsumerWidget {
  const _CompanionFace({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final shown = enabled && ref.watch(frontCompanionCardShownProvider);
    final label = context.messages.frontChatCompanionShow;
    const face = FrontCompanionFigure(
      key: FrontChatHeaderKeys.figure,
      size: ControlSizes.avatarCompact,
    );
    // Fades as it narrows, so her name and title slide into its room.
    return AnimatedSwitcher(
      duration: MotionDurations.short4,
      switchInCurve: MotionCurves.standard,
      switchOutCurve: MotionCurves.standard,
      transitionBuilder: (child, animation) => SizeTransition(
        axis: Axis.horizontal,
        alignment: AlignmentDirectional.centerStart,
        sizeFactor: animation,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: shown
          ? const SizedBox.shrink()
          : Padding(
              padding: EdgeInsetsDirectional.only(end: tokens.spacing.step3),
              child: !enabled
                  ? face
                  : Semantics(
                      key: FrontChatHeaderKeys.companion,
                      container: true,
                      button: true,
                      label: label,
                      onTap: ref
                          .read(frontCompanionCardShownProvider.notifier)
                          .toggle,
                      child: ExcludeSemantics(
                        child: Tooltip(
                          message: label,
                          // Focusable, and Enter or Space shows her too.
                          child: InkWell(
                            borderRadius: BorderRadius.circular(
                              tokens.radii.m,
                            ),
                            onTap: ref
                                .read(frontCompanionCardShownProvider.notifier)
                                .toggle,
                            child: face,
                          ),
                        ),
                      ),
                    ),
            ),
    );
  }
}
