import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_anchor.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// A `⋯`-style trigger that opens a [DesignSystemContextMenu] in a
/// dismiss-on-outside-tap popover.
///
/// The popover, positioning and dismissal come from
/// [DesignSystemContextMenuAnchor]; this widget only supplies the trigger —
/// the same role Material's `PopupMenuButton` plays for its own items, but
/// reusing the design-system menu instead of a bespoke one.
///
/// The trigger is a >=48px (WCAG 2.5.5) touch target wrapping a compact glyph.
class DesignSystemContextMenuButton extends StatelessWidget {
  const DesignSystemContextMenuButton({
    required this.items,
    this.icon = LottiIcons.more,
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
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accessibleLabel =
        tooltip ?? MaterialLocalizations.of(context).showMenuTooltip;
    return DesignSystemContextMenuAnchor(
      items: items,
      semanticsLabel: semanticsLabel,
      builder: (context, {required toggle, required isOpen}) {
        return SizedBox(
          width: tokens.spacing.step9,
          height: tokens.spacing.step9,
          child: Semantics(
            label: accessibleLabel,
            button: true,
            excludeSemantics: true,
            onTap: toggle,
            child: IconButton(
              tooltip: accessibleLabel,
              padding: EdgeInsets.zero,
              iconSize: tokens.spacing.step5,
              icon: Icon(
                icon,
                color: iconColor ?? tokens.colors.text.lowEmphasis,
              ),
              onPressed: toggle,
            ),
          ),
        );
      },
    );
  }
}
