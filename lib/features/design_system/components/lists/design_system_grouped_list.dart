import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// A rounded, bordered container for grouping design-system list-item rows.
///
/// Applies the standard design-system background, border, and corner radius.
/// Wrap a [Column] of list items inside this widget to get the grouped visual
/// style used on settings, categories, and labels pages.
class DesignSystemGroupedList extends StatelessWidget {
  const DesignSystemGroupedList({
    required this.children,
    this.padding,
    super.key,
  });

  final List<Widget> children;

  /// Outer padding around the grouped card. Defaults to the standard
  /// `spacing.step5` horizontal inset; hosts that already lay the card on
  /// a padded grid (e.g. the settings content column) pass
  /// [EdgeInsets.zero].
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Padding(
      padding:
          padding ?? EdgeInsets.symmetric(horizontal: tokens.spacing.step5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.background.level02,
          borderRadius: BorderRadius.circular(tokens.radii.m),
          border: Border.all(color: tokens.colors.decorative.level01),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(tokens.radii.m),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }
}
