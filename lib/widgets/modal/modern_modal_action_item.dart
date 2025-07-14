import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/modal_card.dart';
import 'package:lotti/widgets/cards/modern_icon_container.dart';
import 'package:lotti/widgets/modal/animated_modal_card_item.dart';

/// A modern modal action item with gradient styling and polished animations
///
/// This widget provides a high-budget, production-quality design for modal action items
/// with gradient backgrounds, smooth animations, and proper visual feedback.
class ModernModalActionItem extends StatefulWidget {
  const ModernModalActionItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.iconColor,
    this.isDestructive = false,
    this.isDisabled = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? subtitle;
  final Widget? trailing;
  final Color? iconColor;
  final bool isDestructive;
  final bool isDisabled;

  @override
  State<ModernModalActionItem> createState() => _ModernModalActionItemState();
}

class _ModernModalActionItemState extends State<ModernModalActionItem> {
  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = widget.isDestructive
        ? context.colorScheme.error
        : widget.iconColor ?? context.colorScheme.primary;

    final effectiveTextColor = widget.isDestructive
        ? context.colorScheme.error
        : context.colorScheme.onSurface;

    final effectiveSubtitleColor = widget.isDestructive
        ? context.colorScheme.error.withValues(alpha: 0.8)
        : context.colorScheme.onSurfaceVariant;

    return AnimatedModalCardItem(
      onTap: widget.onTap,
      isDisabled: widget.isDisabled,
      cardBuilder: (context, controller) => ModalCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.cardPadding,
          vertical: AppTheme.cardSpacing,
        ),
        backgroundColor: context.colorScheme.surfaceContainerHighest,
        child: Row(
          children: [
            // Icon with gradient container
            ModernIconContainer(
              icon: widget.icon,
              iconColor: effectiveIconColor,
              gradient: widget.isDestructive
                  ? LinearGradient(
                      colors: [
                        context.colorScheme.errorContainer
                            .withValues(alpha: 0.3),
                        context.colorScheme.errorContainer
                            .withValues(alpha: 0.2),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              borderColor: widget.isDestructive
                  ? context.colorScheme.error
                      .withValues(alpha: AppTheme.alphaDestructive)
                  : null,
            ),
            const SizedBox(width: AppTheme.spacingLarge),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    widget.title,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: AppTheme.titleFontSize,
                      color: effectiveTextColor,
                      letterSpacing: AppTheme.letterSpacingTitle,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Subtitle
                  if (widget.subtitle != null &&
                      widget.subtitle!.isNotEmpty) ...[
                    const SizedBox(
                        height: AppTheme.spacingBetweenTitleAndSubtitle),
                    Text(
                      widget.subtitle!,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: effectiveSubtitleColor,
                        fontSize: AppTheme.subtitleFontSize,
                        height: AppTheme.lineHeightSubtitle,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
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
    );
  }
}
