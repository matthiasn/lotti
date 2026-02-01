import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

/// Chip showing the day's label/intent.
class DayLabelChip extends StatelessWidget {
  const DayLabelChip({
    required this.label,
    super.key,
  });

  final String label;

  // Maximum width to prevent overflow on smaller screens
  static const double maxWidth = 120;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingMedium,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: context.colorScheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: context.textTheme.labelMedium?.copyWith(
            color: context.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }
}
