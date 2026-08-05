import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// One row of the "Add" sheet, on the design-system stack.
///
/// The sheet is the task page's second action surface — the first-run card is
/// the other — and for a round of review the two spoke different languages:
/// Title-Case nouns over `bodyLarge` here, verb-led sentence case over
/// `subtitle2` there, teal glyphs on one and monochrome on the other, and a
/// uniform trailing "+" that contradicted the card's behavioural glyph rule
/// one tap after the card taught it. This row is now a [DesignSystemListItem]
/// carrying the card's exact grammar:
///
/// * leading glyph in `interactive.enabled`, the accent every actionable row
///   on the page uses;
/// * a REQUIRED one-line [subtitle] naming what the tap does. Optional at
///   first, which produced two heavy rows clustered at the sheet's foot and
///   the same action rendered at two densities one tap apart — the exact
///   contract war the card settled with its all-or-none rule. Every row
///   explains itself; the list runs a steady two-line cadence.
/// * a trailing `+` for creates-in-place versus `›` for opens-a-surface
///   ([opensSheet]), at `mediumEmphasis` — the same semantic, weight and size
///   as the first-run card's rows.
class CreateMenuListItem extends StatelessWidget {
  const CreateMenuListItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.opensSheet = false,
    this.onHoverChanged,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Whether the tap opens another surface (picker, recorder sheet, file
  /// dialog) rather than creating the entry in place. Drives the trailing
  /// glyph: `›` for a detour, `+` for a direct create.
  final bool opensSheet;

  /// Reports pointer enter/leave to the sheet, which owns the rows' dividers
  /// and fades the pair bracketing the hovered row (`HoverDividerIndex`).
  /// The row cannot do this itself: the hairlines are its siblings, not its
  /// children.
  final ValueChanged<bool>? onHoverChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DesignSystemListItem(
      onTap: onTap,
      onHoverChanged: onHoverChanged,
      title: title,
      titleMaxLines: 2,
      subtitle: subtitle,
      subtitleMaxLines: 2,
      leading: Icon(
        icon,
        // IconSizes.s, the list-row glyph tier — not a borrowed spacing step,
        // which would resize the glyph whenever the gap scale is retuned.
        size: IconSizes.s,
        color: tokens.colors.interactive.enabled,
      ),
      trailingExtra: Icon(
        // Rounded family for both glyphs, at one size and one emphasis, so
        // the plus and the chevron carry equal ink — the behavioural signal
        // must not be faintest exactly where its meaning is rarest.
        opensSheet ? Icons.chevron_right_rounded : Icons.add_rounded,
        size: IconSizes.s,
        color: tokens.colors.text.mediumEmphasis,
      ),
    );
  }
}
