import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/index.dart';
import 'package:lotti/widgets/modal/animated_modal_item.dart';

/// A modern modal prompt item designed for AI prompts and similar content
///
/// This widget provides an enhanced design for items with descriptions,
/// perfect for AI prompt selection and similar use cases requiring
/// more detailed information display.
class ModernModalPromptItem extends StatefulWidget {
  const ModernModalPromptItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    this.badge,
    this.trailing,
    this.iconColor,
    this.isSelected = false,
    this.isDisabled = false,
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
  final Widget? badge;
  final Widget? trailing;
  final Color? iconColor;
  final bool isSelected;
  final bool isDisabled;

  @override
  State<ModernModalPromptItem> createState() => _ModernModalPromptItemState();
}

class _ModernModalPromptItemState extends State<ModernModalPromptItem> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveIconColor = widget.iconColor ?? context.colorScheme.primary;

    return AnimatedModalItem(
      onTap: widget.onTap,
      isDisabled: widget.isDisabled,
      child: ModernBaseCard(
        onTap: widget.isDisabled ? null : widget.onTap,
        padding: EdgeInsets.zero,
        backgroundColor: widget.isSelected && !isDark
            ? context.colorScheme.primaryContainer.withValues(alpha: 0.1)
            : null,
        borderColor: widget.isSelected
            ? context.colorScheme.primary.withValues(alpha: 0.5)
            : null,
        gradient: widget.isSelected && isDark
            ? LinearGradient(
                colors: [
                  context.colorScheme.primaryContainer.withValues(alpha: 0.2),
                  context.colorScheme.primaryContainer.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        child: AnimatedOpacity(
          opacity: widget.isDisabled ? 0.5 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.cardPadding,
              vertical: AppTheme.cardPadding / 2,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon with gradient container
                ModernIconContainer(
                  icon: widget.icon,
                  iconColor: effectiveIconColor,
                  gradient: widget.isSelected
                      ? LinearGradient(
                          colors: [
                            context.colorScheme.primary.withValues(alpha: 0.3),
                            context.colorScheme.primary.withValues(alpha: 0.2),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                ),
                const SizedBox(width: AppTheme.spacingLarge),

                // Title and description column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row with badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.title,
                              style: context.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: AppTheme.titleFontSize,
                                color: context.colorScheme.onSurface,
                                letterSpacing: AppTheme.letterSpacingTitle,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.badge != null) ...[
                            const SizedBox(width: AppTheme.spacingSmall),
                            widget.badge!,
                          ],
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacingXSmall),
                      // Description
                      Text(
                        widget.description,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.85),
                          fontSize: AppTheme.subtitleFontSize,
                          height: AppTheme.lineHeightSubtitle,
                          letterSpacing: AppTheme.letterSpacingSubtitle,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Trailing widget
                if (widget.trailing != null) ...[
                  const SizedBox(width: AppTheme.spacingMedium),
                  widget.trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
