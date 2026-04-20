import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

/// A clean list item widget for the Entry Actions menu following Nano Banana Pro styling.
///
/// This widget provides a minimal, unified design with:
/// - Icon with customizable color (supports special colors for starred, private, flagged)
/// - Text label with optional destructive styling
/// - Optional subtitle for additional context
/// - No trailing icon (unlike CreateMenuListItem which has a + icon)
/// - Designed to be used in a list with dividers between items
class ActionMenuListItem extends StatelessWidget {
  const ActionMenuListItem({
    required this.title,
    required this.onTap,
    this.icon,
    this.leading,
    this.subtitle,
    this.iconColor,
    this.isDestructive = false,
    this.isDisabled = false,
    super.key,
  }) : assert(
         icon != null || leading != null,
         'Either icon or leading must be provided',
       );

  final IconData? icon;

  /// Optional custom leading widget. Replaces [icon] when provided — used
  /// for items that need a non-Material leading visual (e.g. a country flag).
  final Widget? leading;
  final String title;
  final VoidCallback onTap;
  final String? subtitle;
  final Color? iconColor;
  final bool isDestructive;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    // Determine colors based on state
    final baseColor = isDisabled
        ? context.colorScheme.onSurface.withValues(
            alpha: AppTheme.alphaDisabled,
          )
        : isDestructive
        ? context.colorScheme.error
        : context.colorScheme.onSurface;

    final effectiveIconColor = isDisabled
        ? context.colorScheme.onSurface.withValues(
            alpha: AppTheme.alphaDisabled,
          )
        : isDestructive
        ? context.colorScheme.error
        : iconColor ?? context.colorScheme.onSurface;

    final subtitleColor = isDisabled
        ? context.colorScheme.onSurface.withValues(
            alpha: AppTheme.alphaDisabled,
          )
        : context.colorScheme.onSurfaceVariant;

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
              // Leading icon - clean, no container. A custom [leading] widget
              // takes precedence when provided (e.g. a country flag whose
              // natural 4:3 aspect wouldn't fit a square icon footprint).
              leading ??
                  Icon(
                    icon,
                    size: AppTheme.listItemIconSize,
                    color: effectiveIconColor,
                  ),
              const SizedBox(width: AppTheme.modalChevronSpacerWidth),

              // Title and optional subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: context.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: baseColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: subtitleColor,
                          fontSize: AppTheme.subtitleFontSize,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
