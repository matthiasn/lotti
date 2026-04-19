import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';

/// Flat, list-matching surface for cards rendered on the task detail page.
///
/// Matches the `task_browse_list_item` treatment: solid
/// `background.level02`, `radii.l` (16px), `decorative.level01` border,
/// no drop shadow, no gradient. Replaces `ModernBaseCard` on the detail
/// page so it visually aligns with the task list.
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
    final tokens = context.designTokens;
    final radius = BorderRadius.circular(tokens.radii.l);
    final effectivePadding = padding ?? EdgeInsets.all(tokens.spacing.step5);

    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: TaskShowcasePalette.surface(context),
        borderRadius: radius,
        border: Border.all(color: TaskShowcasePalette.border(context)),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        child: onTap == null
            ? Padding(padding: effectivePadding, child: child)
            : InkWell(
                onTap: onTap,
                borderRadius: radius,
                child: Padding(padding: effectivePadding, child: child),
              ),
      ),
    );

    if (margin == null) return decorated;
    return Padding(padding: margin!, child: decorated);
  }
}
