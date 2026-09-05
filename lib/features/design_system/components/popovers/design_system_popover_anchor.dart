import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_anchor.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Opens arbitrary content in a dismiss-on-outside-tap popover beneath a
/// caller-supplied trigger, on the context menu's floating surface.
///
/// `DesignSystemContextMenuAnchor` is the same overlay for a list of menu
/// rows; this one hosts a widget instead — a settings panel, a picker — so a
/// desktop control can open in place what a phone opens as a sheet. The
/// content decides when it is done: nothing inside closes the popover, only
/// an outside tap or the trigger itself.
class DesignSystemPopoverAnchor extends StatefulWidget {
  const DesignSystemPopoverAnchor({
    required this.builder,
    required this.child,
    this.width = DesignSystemContextMenu.defaultWidth,
    this.semanticsLabel,
    super.key,
  });

  /// Builds the always-visible trigger.
  final DesignSystemContextMenuTriggerBuilder builder;

  /// The popover's content. It is built each time the popover opens, so it
  /// always starts from the caller's current state.
  final Widget child;

  /// Width of the floating surface.
  final double width;

  /// Semantics label for the opened popover container.
  final String? semanticsLabel;

  @override
  State<DesignSystemPopoverAnchor> createState() =>
      _DesignSystemPopoverAnchorState();
}

class _DesignSystemPopoverAnchorState extends State<DesignSystemPopoverAnchor> {
  final MenuController _controller = MenuController();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return MenuAnchor(
      controller: _controller,
      alignmentOffset: Offset(0, tokens.spacing.step2),
      // The panel itself is invisible — the surface below carries the
      // background, radius and shadow, so a second background here would
      // double up.
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(0),
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder()),
        side: WidgetStatePropertyAll(BorderSide.none),
      ),
      menuChildren: [
        DesignSystemPopoverSurface(
          width: widget.width,
          semanticsLabel: widget.semanticsLabel,
          child: widget.child,
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

/// The floating surface a [DesignSystemPopoverAnchor] opens: the context
/// menu's background, radius and shadow around [child].
class DesignSystemPopoverSurface extends StatelessWidget {
  const DesignSystemPopoverSurface({
    required this.child,
    this.width = DesignSystemContextMenu.defaultWidth,
    this.semanticsLabel,
    super.key,
  });

  final Widget child;
  final double width;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Semantics(
      container: true,
      label: semanticsLabel,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: tokens.colors.background.level01,
            borderRadius: BorderRadius.circular(tokens.radii.s),
            boxShadow: DsShadows.floatingSurface,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radii.s),
            child: Material(color: Colors.transparent, child: child),
          ),
        ),
      ),
    );
  }
}
