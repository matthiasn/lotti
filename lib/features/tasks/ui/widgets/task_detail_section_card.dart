import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';

/// Flat, list-matching surface for cards rendered on the task detail page.
///
/// Thin alias over [DesignSystemSectionCard], which owns the treatment (solid
/// `background.level02`, `radii.l` (16px), `decorative.level01` border, no drop
/// shadow, no gradient) so the logbook detail page can share the same surface
/// without depending on the tasks feature.
class TaskDetailSectionCard extends StatelessWidget {
  const TaskDetailSectionCard({
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    return DesignSystemSectionCard(
      onTap: onTap,
      padding: padding,
      margin: margin,
      child: child,
    );
  }
}
