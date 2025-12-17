import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/index.dart';
import 'package:lotti/widgets/cards/modal_card.dart';
import 'package:lotti/widgets/modal/animated_modal_card_item.dart';

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
    this.isDefault = false,
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
  final bool isDefault;

  @override
  State<ModernModalPromptItem> createState() => _ModernModalPromptItemState();
}

class _ModernModalPromptItemState extends State<ModernModalPromptItem> {
  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = widget.iconColor ?? context.colorScheme.primary;
    const goldColor = Color(0xFFD4AF37);

    final cardContent = Row(
      children: [
        // Icon with gradient container
        ModernIconContainer(
          icon: widget.icon,
          iconColor: effectiveIconColor,
          gradient: widget.isDefault
              ? LinearGradient(
                  colors: [
                    goldColor.withValues(alpha: 0.45),
                    goldColor.withValues(alpha: 0.35),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : widget.isSelected
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
                      style: context.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: AppTheme.titleFontSize,
                        color: context.colorScheme.onSurface,
                        letterSpacing: AppTheme.letterSpacingTitle,
                      ),
                      maxLines: 2,
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
                maxLines: 4,
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
    );

    return AnimatedModalCardItem(
      onTap: widget.onTap,
      isDisabled: widget.isDisabled,
      cardBuilder: (context, controller) => ModalCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.cardPadding,
          vertical: AppTheme.cardPadding / 2,
        ),
        backgroundColor: widget.isDefault
            ? goldColor.withValues(alpha: 0.18)
            : context.colorScheme.surfaceContainerHighest,
        borderColor: widget.isDefault
            ? goldColor.withValues(alpha: 0.85)
            : context.colorScheme.outline.withValues(alpha: 0.15),
        onTap: widget.onTap,
        isDisabled: widget.isDisabled,
        animationController: controller,
        child: cardContent,
      ),
    );
  }
}
