import 'package:flutter/services.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_anchor.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/features/design_system/utils/disabled_overlay.dart';
import 'package:lotti/features/front_agent/ui/front_chat_day_label.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/device_datetime.dart';
import 'package:lotti/utils/platform.dart';
import 'package:material_ui/material_ui.dart';

/// Where a turn of the user's stands, as far as what can be done with it.
enum FrontUserMessageStatus {
  /// She answered it, or it failed: its words can be copied, or taken back
  /// into the box to change and send again — the edit, sent, replaces it
  /// and her answer.
  settled,

  /// She is working on it: it is hers until it is stopped.
  working,

  /// The user stopped it before she answered: like [settled], and marked
  /// so.
  stopped,
}

/// Stable keys for a user turn's actions.
@visibleForTesting
abstract final class FrontChatUserMessageKeys {
  static Key copy(String messageId) =>
      Key('front-user-message-copy-$messageId');
  static Key edit(String messageId) =>
      Key('front-user-message-edit-$messageId');
  static Key stopped(String messageId) =>
      Key('front-user-message-stopped-$messageId');
  static Key menuCopy(String messageId) =>
      Key('front-user-message-menu-copy-$messageId');
  static Key menuEdit(String messageId) =>
      Key('front-user-message-menu-edit-$messageId');
}

/// The user's [bubble] in the companion's thread, with what can be done with
/// its [text]: copied, and edited, which hands the words to [onEdit] for the
/// box — any time but while she is working on it.
///
/// On a phone or tablet the actions are a long press away, in a small
/// window under the bubble headed by when it was sent ([sentAt]); a long
/// press on a turn she is still working on says it cannot be edited until
/// it is stopped. On a desktop they show as icons beside the
/// bubble while the pointer is over it or focus is in them, their room kept
/// so nothing shifts — a pencil dimmed while she works, which says the same
/// when clicked; a secondary click opens the same menu where it was made.
class FrontChatUserMessage extends StatefulWidget {
  const FrontChatUserMessage({
    required this.messageId,
    required this.text,
    required this.status,
    required this.onEdit,
    required this.bubble,
    required this.sentAt,
    this.onStop,
    super.key,
  });

  final String messageId;
  final String text;
  final FrontUserMessageStatus status;
  final ValueChanged<String> onEdit;
  final Widget bubble;

  /// When the turn was sent: the heading of its window of actions.
  final DateTime sentAt;

  /// Stops the turn she is working on — offered on the warning that it
  /// cannot be edited yet, so the way forward is one tap away.
  final VoidCallback? onStop;

  @override
  State<FrontChatUserMessage> createState() => _FrontChatUserMessageState();
}

class _FrontChatUserMessageState extends State<FrontChatUserMessage> {
  final _menu = MenuController();
  bool _hovered = false;
  bool _focused = false;

  bool get _stopped => widget.status == FrontUserMessageStatus.stopped;

  Future<void> _copy() async {
    final messages = context.messages;
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    context.showToast(
      tone: DesignSystemToastTone.success,
      title: messages.frontChatMessageCopied,
      replaceCurrent: true,
    );
  }

  void _edit() => widget.onEdit(widget.text);

  /// Says the turn cannot be edited until it is stopped.
  void _warnBusy() {
    final messages = context.messages;
    context.showToast(
      tone: DesignSystemToastTone.warning,
      title: messages.frontChatMessageBusy,
      description: messages.frontChatMessageBusyHint,
      action: switch (widget.onStop) {
        final stop? => ToastAction(
          label: messages.chatInputStopTooltip,
          onPressed: stop,
        ),
        null => null,
      },
      replaceCurrent: true,
    );
  }

  /// Opens the menu — under the bubble, or at [position] — or, while she
  /// works on the turn, says why there is nothing to do with it yet.
  void _open([Offset? position]) {
    // Felt either way: the press was taken, whatever it can do.
    HapticFeedback.mediumImpact();
    if (widget.status == FrontUserMessageStatus.working) {
      _warnBusy();
      return;
    }
    _menu.open(position: position);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    // A pointer to hover with: a desktop's, never a touch screen's, however
    // wide.
    final desktop = !isMobile && isDesktopLayout(context);
    final id = widget.messageId;
    final showIcons = desktop && (_hovered || _focused);

    final menu = DesignSystemContextMenuAnchor(
      controller: _menu,
      semanticsLabel: messages.frontChatMessageActions,
      header: messages.frontChatMessageSentAt(
        frontChatDayLabel(
          context,
          widget.sentAt,
          Localizations.localeOf(context).toLanguageTag(),
        ),
        deviceClockLabel(context, widget.sentAt),
      ),
      // A small window raised off the thread, which sits on the menu's own
      // base level, its edge drawn where it meets the bubbles.
      surfaceColor: dsCardSurface(context),
      outlined: true,
      // As wide as its longest line, not a full menu's width.
      fitContent: true,
      items: [
        DesignSystemContextMenuItem(
          key: FrontChatUserMessageKeys.menuCopy(id),
          label: messages.frontChatMessageCopy,
          icon: LottiIcons.copy,
          onTap: _copy,
        ),
        DesignSystemContextMenuItem(
          key: FrontChatUserMessageKeys.menuEdit(id),
          label: messages.frontChatMessageEdit,
          icon: LottiIcons.edit,
          onTap: _edit,
        ),
      ],
      builder: (context, {required toggle, required isOpen}) => Semantics(
        onLongPressHint: messages.frontChatMessageActions,
        onLongPress: _open,
        child: GestureDetector(
          // Under the bubble, clear of the words it acts on.
          onLongPress: _open,
          onSecondaryTapUp: (details) => _open(details.localPosition),
          // The caption rides with the bubble, so the menu opens below both.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              widget.bubble,
              if (_stopped)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spacing.step2,
                    vertical: tokens.spacing.step1,
                  ),
                  // Led by Stop's own mark: what was pressed, and what it did.
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: tokens.spacing.step1,
                    children: [
                      Icon(
                        LottiIconsFilled.square,
                        size: IconSizes.xs,
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                      Text(
                        messages.frontChatMessageStopped,
                        key: FrontChatUserMessageKeys.stopped(id),
                        style: tokens.typography.styles.others.caption.copyWith(
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
    );

    final working = widget.status == FrontUserMessageStatus.working;
    final icons = desktop
        // Kept in the tree, so the bubble keeps its place and the icons stay
        // in the focus order; drawn only while wanted.
        ? Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onFocusChange: (focused) => setState(() => _focused = focused),
            // Hidden icons take no taps — a touch screen at desktop width
            // never hovers to show them first.
            child: IgnorePointer(
              ignoring: !showIcons,
              child: AnimatedOpacity(
                opacity: showIcons ? 1 : 0,
                duration: MotionDurations.short3,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DesignSystemIconAction(
                      key: FrontChatUserMessageKeys.copy(id),
                      icon: LottiIcons.copy,
                      tooltip: messages.frontChatMessageCopy,
                      onPressed: _copy,
                    ),
                    DesignSystemIconAction(
                      key: FrontChatUserMessageKeys.edit(id),
                      icon: LottiIcons.edit,
                      // While she works on it: dimmed, and a click says why
                      // not yet — what a long press says on a phone.
                      tooltip: working
                          ? messages.frontChatMessageBusyHint
                          : messages.frontChatMessageEdit,
                      // The disabled ink and dimming, though still live:
                      // a click says why not yet.
                      tone: working ? tokens.colors.text.lowEmphasis : null,
                      onPressed: working ? _warnBusy : _edit,
                    ).withDisabledOpacity(
                      enabled: !working,
                      disabledOpacity: tokens.colors.text.lowEmphasis.a,
                    ),
                  ],
                ),
              ),
            ),
          )
        : null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (icons == null)
            menu
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              // Level with the bubble's top, whatever caption is under it.
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                icons,
                Flexible(child: menu),
              ],
            ),
        ],
      ),
    );
  }
}
