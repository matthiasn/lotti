import 'package:flutter/services.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_anchor.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Where a turn of the user's stands, as far as what can be done with it.
enum FrontUserMessageStatus {
  /// She answered it, or it failed: its words can be copied.
  settled,

  /// She is working on it: it is hers until it is stopped.
  working,

  /// The user stopped it before she answered: its words can be copied, or
  /// taken back into the box to change and send again.
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
/// its [text]: copied, and — once stopped — edited, which hands the words to
/// [onEdit] for the box.
///
/// On a phone the actions are a long press away, in a menu where the finger
/// is; a long press on a turn she is still working on says it cannot be
/// edited until it is stopped. On a desktop they show as icons under the
/// bubble while the pointer is over it or focus is in it, the row's room
/// kept so nothing shifts; a secondary click opens the same menu there.
class FrontChatUserMessage extends StatefulWidget {
  const FrontChatUserMessage({
    required this.messageId,
    required this.text,
    required this.status,
    required this.onEdit,
    required this.bubble,
    super.key,
  });

  final String messageId;
  final String text;
  final FrontUserMessageStatus status;
  final ValueChanged<String> onEdit;
  final Widget bubble;

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
    );
  }

  void _edit() => widget.onEdit(widget.text);

  /// Opens the menu at [position] — or, while she works on the turn, says
  /// why there is nothing to do with it yet.
  void _open(Offset position) {
    if (widget.status == FrontUserMessageStatus.working) {
      context.showToast(
        tone: DesignSystemToastTone.warning,
        title: context.messages.frontChatMessageBusy,
      );
      return;
    }
    HapticFeedback.mediumImpact();
    _menu.open(position: position);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final desktop = isDesktopLayout(context);
    final id = widget.messageId;
    final showIcons = desktop && (_hovered || _focused);

    final menu = DesignSystemContextMenuAnchor(
      controller: _menu,
      semanticsLabel: messages.frontChatMessageActions,
      items: [
        DesignSystemContextMenuItem(
          key: FrontChatUserMessageKeys.menuCopy(id),
          label: messages.frontChatMessageCopy,
          icon: LottiIcons.copy,
          onTap: _copy,
        ),
        if (_stopped)
          DesignSystemContextMenuItem(
            key: FrontChatUserMessageKeys.menuEdit(id),
            label: messages.frontChatMessageEdit,
            icon: LottiIcons.edit,
            onTap: _edit,
          ),
      ],
      builder: (context, {required toggle, required isOpen}) => Semantics(
        onLongPressHint: messages.frontChatMessageActions,
        onLongPress: () => _open(Offset.zero),
        child: GestureDetector(
          onLongPressStart: (details) => _open(details.localPosition),
          onSecondaryTapUp: (details) => _open(details.localPosition),
          child: widget.bubble,
        ),
      ),
    );

    final row = <Widget>[
      if (_stopped)
        Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step2),
          child: Text(
            messages.frontChatMessageStopped,
            key: FrontChatUserMessageKeys.stopped(id),
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
        ),
      if (desktop)
        // Kept in the tree, so the row keeps its room and the icons stay
        // in the focus order; drawn only while wanted.
        Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (focused) => setState(() => _focused = focused),
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
                if (widget.status != FrontUserMessageStatus.settled)
                  DesignSystemIconAction(
                    key: FrontChatUserMessageKeys.edit(id),
                    icon: LottiIcons.edit,
                    // While she works on it, the tooltip says why not yet.
                    tooltip: _stopped
                        ? messages.frontChatMessageEdit
                        : messages.frontChatMessageBusy,
                    onPressed: _stopped ? _edit : null,
                  ),
              ],
            ),
          ),
        ),
    ];

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          menu,
          if (row.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: row,
            ),
        ],
      ),
    );
  }
}
