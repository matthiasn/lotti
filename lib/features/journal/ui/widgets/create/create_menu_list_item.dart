import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

/// A clean list item widget for the FAB addition menu following Nano Banana Pro styling.
///
/// This widget provides a minimal, unified design with:
/// - White icon (no container/gradient background)
/// - White text label
/// - White plus (+) icon aligned to the right
/// - Designed to be used in a list with dividers between items
class CreateMenuListItem extends StatelessWidget {
  const CreateMenuListItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDisabled = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final itemColor = isDisabled
        ? context.colorScheme.onSurface
            .withValues(alpha: AppTheme.alphaDisabled)
        : context.colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.cardPadding,
            vertical: AppTheme.spacingMedium,
          ),
          child: Row(
            children: [
              // Leading icon - clean, no container
              Icon(
                icon,
                size: AppTheme.listItemIconSize,
                color: itemColor,
              ),
              const SizedBox(width: AppTheme.modalChevronSpacerWidth),

              // Title text
              Expanded(
                child: Text(
                  title,
                  style: context.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: itemColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Trailing plus icon
              Icon(
                Icons.add,
                size: AppTheme.iconSize,
                color: itemColor.withValues(alpha: AppTheme.alphaIconTrailing),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
