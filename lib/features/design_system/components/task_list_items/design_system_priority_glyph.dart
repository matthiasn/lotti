import 'package:flutter_svg/flutter_svg.dart';
import 'package:lotti/features/design_system/components/task_list_items/design_system_task_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// The one priority mark: a badge for P0 and one to three bars for P1–P3.
/// The task row, the task header and the priority filter all draw it, so a
/// priority looks the same wherever it is read.
class DesignSystemPriorityGlyph extends StatelessWidget {
  const DesignSystemPriorityGlyph({
    required this.priority,
    this.size = IconSizes.s,
    super.key,
  });

  final DesignSystemTaskPriority priority;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.designTokens.colors;
    final asset = switch (priority) {
      DesignSystemTaskPriority.p0 =>
        'assets/design_system/task_priority_p0.svg',
      DesignSystemTaskPriority.p1 =>
        'assets/design_system/task_priority_high.svg',
      DesignSystemTaskPriority.p2 =>
        'assets/design_system/task_priority_medium.svg',
      DesignSystemTaskPriority.p3 =>
        'assets/design_system/task_priority_low.svg',
    };

    // The assets bake the dark theme's hues, so the glyph is always tinted.
    // Only urgency earns colour, and only upwards: Medium and Low read from
    // their bar count at neutral ink. Medium, the default every new task
    // wears, takes high emphasis — the asset's per-bar alpha already dims its
    // upper bars, and over medium ink the glyph looked switched off.
    final color = switch (priority) {
      DesignSystemTaskPriority.p0 => colors.alert.error.defaultColor,
      DesignSystemTaskPriority.p1 => colors.alert.warning.defaultColor,
      DesignSystemTaskPriority.p2 => colors.text.highEmphasis,
      DesignSystemTaskPriority.p3 => colors.text.mediumEmphasis,
    };

    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
