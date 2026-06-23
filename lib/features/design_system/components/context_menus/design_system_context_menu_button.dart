import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// A `⋯`-style trigger that opens a [DesignSystemContextMenu] in a
/// dismiss-on-outside-tap popover (via [MenuAnchor]).
///
/// [DesignSystemContextMenu] is only the menu *surface*; this widget supplies
/// the trigger, the overlay, positioning, and outside-tap / Escape dismissal so
/// the styled menu can be used as a popup — the same role Material's
/// `PopupMenuButton` plays for its own items, but reusing the design-system menu
/// instead of a bespoke one.
///
/// The trigger is a >=48px (WCAG 2.5.5) touch target wrapping a compact glyph.
/// Each item's tap closes the menu before firing its callback.
class DesignSystemContextMenuButton extends StatefulWidget {
  const DesignSystemContextMenuButton({
    required this.items,
    this.icon = Icons.more_horiz_rounded,
    this.tooltip,
    this.iconColor,
    this.semanticsLabel,
    super.key,
  });

  /// The rows to show when the trigger is tapped.
  final List<DesignSystemContextMenuItem> items;

  /// The trigger glyph (defaults to the `⋯` overflow icon).
  final IconData icon;

  /// Tooltip / long-press label for the trigger.
  final String? tooltip;

  /// Trigger glyph color; defaults to the low-emphasis text token.
  final Color? iconColor;

  /// Semantics label for the opened menu container.
  final String? semanticsLabel;

  @override
  State<DesignSystemContextMenuButton> createState() =>
      _DesignSystemContextMenuButtonState();
}

class _DesignSystemContextMenuButtonState
    extends State<DesignSystemContextMenuButton> {
  final MenuController _controller = MenuController();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return MenuAnchor(
      controller: _controller,
      alignmentOffset: Offset(0, tokens.spacing.step2),
      // The panel itself is invisible — DesignSystemContextMenu carries its own
      // surface, border-radius and shadow, so a second background here would
      // double up.
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(0),
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder()),
        side: WidgetStatePropertyAll(BorderSide.none),
      ),
      menuChildren: [
        DesignSystemContextMenu(
          semanticsLabel: widget.semanticsLabel,
          items: [
            for (final item in widget.items)
              DesignSystemContextMenuItem(
                label: item.label,
                icon: item.icon,
                isDestructive: item.isDestructive,
                onTap: () {
                  _controller.close();
                  item.onTap?.call();
                },
              ),
          ],
        ),
      ],
      builder: (context, controller, child) {
        return SizedBox(
          width: tokens.spacing.step9,
          height: tokens.spacing.step9,
          child: IconButton(
            tooltip: widget.tooltip,
            padding: EdgeInsets.zero,
            iconSize: tokens.spacing.step5,
            icon: Icon(
              widget.icon,
              color: widget.iconColor ?? tokens.colors.text.lowEmphasis,
            ),
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
          ),
        );
      },
    );
  }
}
