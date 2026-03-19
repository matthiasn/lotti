import 'package:flutter/material.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/projects/ui/widgets/project_status_attributes.dart';
import 'package:lotti/widgets/cards/modern_status_chip.dart';

/// Maps [ProjectStatus] to a colored [ModernStatusChip].
///
/// Uses brightness-aware colors that adapt to light/dark theme,
/// following the same pattern as `TaskStatus.colorForBrightness`.
class ProjectStatusChip extends StatelessWidget {
  const ProjectStatusChip({
    required this.status,
    super.key,
  });

  final ProjectStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = projectStatusAttributes(context, status);
    return ModernStatusChip(
      label: label,
      color: color,
      icon: icon,
    );
  }
}
