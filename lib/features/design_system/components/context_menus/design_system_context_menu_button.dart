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
    this.header,
    this.size = DesignSystemContextMenuSize.medium,
    this.fitContent = false,
    this.surfaceColor,
    this.outlined = false,
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

  /// Optional quiet heading above the rows — what the rows act on, such as
  /// the model a briefing would be written with.
  final String? header;

  /// Row height variant of the menu surface.
  final DesignSystemContextMenuSize size;

  /// Sizes the menu to its widest row
  /// ([DesignSystemContextMenuAnchor.fitContent]).
  final bool fitContent;

  /// The menu's surface ([DesignSystemContextMenu.surfaceColor]).
  final Color? surfaceColor;

  /// A hairline around the menu ([DesignSystemContextMenu.outlined]).
  final bool outlined;

  /// The square the trigger occupies, so a row can reserve its slot.
  static double extent(DsTokens tokens) => tokens.spacing.step9;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accessibleLabel =
        tooltip ?? MaterialLocalizations.of(context).showMenuTooltip;
    return DesignSystemContextMenuAnchor(
      items: items,
      semanticsLabel: semanticsLabel,
      header: header,
      size: size,
      fitContent: fitContent,
      surfaceColor: surfaceColor,
      outlined: outlined,
      builder: (context, {required toggle, required isOpen}) {
        return SizedBox(
          width: extent(tokens),
          height: extent(tokens),
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
