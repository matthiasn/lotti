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
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.description,
    this.selectionIndicator,
    super.key,
  });

  /// Title of the option
  final String title;

  /// Optional description text
  final String? description;

  /// Icon to display
  final IconData icon;

  /// Whether this option is currently selected
  final bool isSelected;

  /// Callback when option is tapped
  final VoidCallback onTap;

  /// Custom selection indicator widget (defaults to checkmark or circle based on context)
  final Widget? selectionIndicator;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? context.colorScheme.primaryContainer.withValues(alpha: 0.15)
            : context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? context.colorScheme.primary.withValues(alpha: 0.6)
              : context.colorScheme.outline.withValues(alpha: 0.1),
          width: 2,
        ),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: context.colorScheme.primary.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon container
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.colorScheme.primary.withValues(alpha: 0.15)
                        : context.colorScheme.surfaceContainerHigh.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? context.colorScheme.primary.withValues(alpha: 0.3)
                          : Colors.transparent,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected
                        ? context.colorScheme.primary
                        : context.colorScheme.onSurface.withValues(alpha: 0.8),
                    size: 24,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? context.colorScheme.primary
                              : context.colorScheme.onSurface,
                          height: 1.3,
                        ),
                      ),
                      if (description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          description!,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Selection indicator
                if (selectionIndicator != null)
                  selectionIndicator!
                else
                  _DefaultSelectionIndicator(isSelected: isSelected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Default selection indicator (checkmark when selected, empty circle when not)
class _DefaultSelectionIndicator extends StatelessWidget {
  const _DefaultSelectionIndicator({
    required this.isSelected,
  });

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    if (isSelected) {
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: context.colorScheme.primary,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: context.colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.check_rounded,
          color: context.colorScheme.onPrimary,
          size: 16,
        ),
      );
    } else {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          border: Border.all(
            color: context.colorScheme.outline.withValues(alpha: 0.3),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
      );
    }
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
