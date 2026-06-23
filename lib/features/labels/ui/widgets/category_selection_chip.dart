import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// A removable, category-tinted pill that shows a selected category on the
/// label editor surfaces (the label details page and the label editor sheet).
///
/// Renders [name] inside a [DsPill] tinted with the category's own [color] —
/// so each category keeps its colour identity — followed by a tappable ✕ that
/// calls [onRemove]. The ✕ carries [removeTooltip] as its hover / long-press
/// affordance.
class CategorySelectionChip extends StatelessWidget {
  const CategorySelectionChip({
    required this.name,
    required this.color,
    required this.onRemove,
    required this.removeTooltip,
    super.key,
  });

  /// The category's display name, shown as the pill label.
  final String name;

  /// The category's accent colour. Drives the pill tint, the label colour and
  /// the ✕ glyph colour.
  final Color color;

  /// Called when the user taps the ✕ to drop this category from the selection.
  final VoidCallback onRemove;

  /// Tooltip shown on the ✕ remove affordance.
  final String removeTooltip;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DsPill(
      variant: DsPillVariant.tinted,
      color: color,
      label: name,
      trailing: Tooltip(
        message: removeTooltip,
        child: InkWell(
          onTap: onRemove,
          customBorder: const CircleBorder(),
          child: Icon(
            Icons.close_rounded,
            size: tokens.spacing.step5,
            color: color,
          ),
        ),
      ),
    );
  }
}
