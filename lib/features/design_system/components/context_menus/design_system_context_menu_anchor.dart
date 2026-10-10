import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Builds the trigger for a [DesignSystemContextMenuAnchor].
///
/// [toggle] opens the menu when closed and closes it when open; [isOpen]
/// reflects the current state so the trigger can render a pressed look.
typedef DesignSystemContextMenuTriggerBuilder =
    Widget Function(
      BuildContext context, {
      required VoidCallback toggle,
      required bool isOpen,
    });

/// Opens a [DesignSystemContextMenu] in a dismiss-on-outside-tap popover
/// (via [MenuAnchor]) beneath a caller-supplied trigger.
///
/// [DesignSystemContextMenu] is only the menu *surface*; this widget supplies
/// the overlay, positioning and outside-tap / Escape dismissal so the styled
/// menu can be used as a popup under any trigger — an icon button, a logo, a
/// text chip. `DesignSystemContextMenuButton` is the ready-made `⋯` trigger
/// on top of it.
///
/// Each enabled item's tap closes the menu before firing its callback; an
/// item without a callback renders disabled and leaves the menu open.
///
/// The trigger's `toggle` opens the menu beneath the trigger. A surface that
/// opens it where the pointer is — a right-click or a long press on an
/// image — passes its own [controller] and calls `open(position:)` on it
/// with the offset within the trigger.
class DesignSystemContextMenuAnchor extends StatefulWidget {
  const DesignSystemContextMenuAnchor({
    required this.items,
    required this.builder,
    this.controller,
    this.header,
    this.semanticsLabel,
    this.size = DesignSystemContextMenuSize.medium,
    super.key,
  });

  /// The rows to show when the trigger is tapped.
  final List<DesignSystemContextMenuItem> items;

  /// Builds the always-visible trigger.
  final DesignSystemContextMenuTriggerBuilder builder;

  /// The menu's controller, for a caller that opens the menu itself — at a
  /// pointer position — besides the trigger's toggle. The anchor owns one of
  /// its own when none is given.
  final MenuController? controller;

  /// Optional quiet heading rendered above the rows.
  final String? header;

  /// Semantics label for the opened menu container.
  final String? semanticsLabel;

  /// Row height variant of the menu surface.
  final DesignSystemContextMenuSize size;

  @override
  State<DesignSystemContextMenuAnchor> createState() =>
      _DesignSystemContextMenuAnchorState();
}

class _DesignSystemContextMenuAnchorState
    extends State<DesignSystemContextMenuAnchor> {
  late MenuController _controller = widget.controller ?? MenuController();

  @override
  void didUpdateWidget(DesignSystemContextMenuAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _controller = widget.controller ?? MenuController();
    }
  }

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
          header: widget.header,
          size: widget.size,
          items: [
            for (final item in widget.items)
              DesignSystemContextMenuItem(
                key: item.key,
                label: item.label,
                icon: item.icon,
                iconColor: item.iconColor,
                isDestructive: item.isDestructive,
                isSelected: item.isSelected,
                // A null callback is a disabled row and must stay one; only
                // a real callback gets the close-then-fire wrapper.
                onTap: item.onTap == null
                    ? null
                    : () {
                        _controller.close();
                        item.onTap!();
                      },
              ),
          ],
        ),
      ],
      builder: (context, controller, child) {
        void toggle() {
          if (controller.isOpen) {
            controller.close();
          } else {
            controller.open();
          }
        }

        return widget.builder(
          context,
          toggle: toggle,
          isOpen: controller.isOpen,
        );
      },
    );
  }
}
