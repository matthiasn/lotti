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
    super.key,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step5),
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
