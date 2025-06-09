import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

/// Reusable selection option widget for modal selections
///
/// This widget provides a consistent design for selection options across
/// different modal types (single selection, multi-selection, etc.)
///
/// Features:
/// - Consistent styling with 16px border radius
/// - 2px borders to prevent breathing effects
/// - Proper shadows and visual feedback
/// - Support for icons, titles, descriptions
/// - Customizable selection indicators
class SelectionOption extends StatelessWidget {
  const SelectionOption({
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.description,
    this.icon,
    this.selectionIndicator,
    super.key,
  });

  /// Title of the option
  final String title;

  /// Optional description text
  final String? description;

  /// Icon to display
  final IconData? icon;

  /// Whether this option is currently selected
  final bool isSelected;

  /// Callback when option is tapped
  final VoidCallback onTap;

  /// Custom selection indicator widget (defaults to checkmark or circle based on context)
  final Widget? selectionIndicator;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? context.colorScheme.primaryContainer : null,
            border: Border.all(
              color: isSelected
                  ? context.colorScheme.primary
                  : context.colorScheme.outline.withValues(alpha: 0.3),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: context.colorScheme.primary.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 24,
                    color: isSelected
                        ? context.colorScheme.primary
                        : context.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: context.textTheme.bodyLarge?.copyWith(
                          color: isSelected
                              ? context.colorScheme.primary
                              : context.colorScheme.onSurface,
                          fontWeight: isSelected ? FontWeight.w600 : null,
                        ),
                      ),
                      if (description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          description!,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (selectionIndicator != null) ...[
                  const SizedBox(width: 16),
                  selectionIndicator!,
                ] else ...[
                  const SizedBox(width: 16),
                  Icon(
                    Icons.check_rounded,
                    color: isSelected
                        ? context.colorScheme.primary
                        : Colors.transparent,
                    size: 24,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Radio button style selection indicator for single-selection scenarios
class RadioSelectionIndicator extends StatelessWidget {
  const RadioSelectionIndicator({
    required this.isSelected,
    super.key,
  });

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected
              ? context.colorScheme.primary
              : context.colorScheme.outline.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: isSelected
          ? Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.colorScheme.primary,
                ),
              ),
            )
          : null,
    );
  }
}
