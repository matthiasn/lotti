import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list_corners.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// A rounded, bordered container for grouping design-system list-item rows.
///
/// Applies the standard design-system background, border, and corner radius.
/// Wrap a [Column] of list items inside this widget to get the grouped visual
/// style used on settings, categories, and labels pages. The first and last
/// child are wrapped in a [DesignSystemGroupedListCorners] scope so edge rows
/// can round their own decorations to the group's corners instead of painting
/// square outlines into the clip.
class DesignSystemGroupedList extends StatelessWidget {
  const DesignSystemGroupedList({
    required this.children,
    this.padding,
    this.filled = true,
    super.key,
  });

  final List<Widget> children;

  /// Outer padding around the grouped card. Defaults to the standard
  /// `spacing.step5` horizontal inset; hosts that already lay the card on
  /// a padded grid (e.g. the settings content column) pass
  /// [EdgeInsets.zero].
  final EdgeInsetsGeometry? padding;

  /// Whether to paint the standard grouped-list fill. Set to `false` when the
  /// host surface should continue through the outline unchanged.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cornerRadius = Radius.circular(tokens.radii.m);

    return Padding(
      padding:
          padding ?? EdgeInsets.symmetric(horizontal: tokens.spacing.step5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: filled ? tokens.colors.background.level02 : null,
          borderRadius: BorderRadius.circular(tokens.radii.m),
          border: Border.all(color: tokens.colors.decorative.level01),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(tokens.radii.m),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (index, child) in children.indexed)
                if (index == 0 || index == children.length - 1)
                  DesignSystemGroupedListCorners(
                    borderRadius: BorderRadius.vertical(
                      top: index == 0 ? cornerRadius : Radius.zero,
                      bottom: index == children.length - 1
                          ? cornerRadius
                          : Radius.zero,
                    ),
                    child: child,
                  )
                else
                  child,
            ],
          ),
        ),
      ),
    );
  }
}
