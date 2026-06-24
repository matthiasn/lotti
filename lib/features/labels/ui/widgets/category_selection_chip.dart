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

  /// The category's accent colour. Drives the pill tint; the label and ✕ use a
  /// contrast-clamped variant of it (see [_legibleAccent]).
  final Color color;

  /// Called when the user taps the ✕ to drop this category from the selection.
  final VoidCallback onRemove;

  /// Tooltip shown on the ✕ remove affordance.
  final String removeTooltip;

  /// The accent colour with its lightness pinned into a band that always
  /// contrasts against the 18%-tinted background (which is close to the theme
  /// surface): darker in light theme, lighter in dark theme. This keeps the
  /// category hue on the label / ✕ while staying legible even for very light
  /// categories like `#F9F871`, where the raw accent would wash out.
  Color _legibleAccent(BuildContext context) {
    final hsl = HSLColor.fromColor(color);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lightness = isDark
        ? hsl.lightness.clamp(0.62, 1.0)
        : hsl.lightness.clamp(0.0, 0.42);
    return hsl.withLightness(lightness).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = _legibleAccent(context);
    return DsPill(
      variant: DsPillVariant.tinted,
      color: color,
      label: name,
      labelColor: accent,
      trailing: Tooltip(
        message: removeTooltip,
        child: InkWell(
          onTap: onRemove,
          customBorder: const CircleBorder(),
          child: Icon(
            Icons.close_rounded,
            size: tokens.spacing.step5,
            color: accent,
          ),
        ),
      ),
    );
  }
}
