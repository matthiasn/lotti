import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/modal_card.dart';
import 'package:lotti/widgets/modal/animated_modal_card_item.dart';

/// A modern modal entry type item for creating different entry types
///
/// This widget provides a clean, production-quality design for entry type selection
/// with subtle animations and visual feedback optimized for the create entry flow.
class ModernModalEntryTypeItem extends StatelessWidget {
  const ModernModalEntryTypeItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconColor,
    this.isDisabled = false,
    this.badge,
    super.key,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? iconColor;
  final bool isDisabled;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? context.colorScheme.primary;

    return AnimatedModalCardItem(
      onTap: isDisabled ? null : onTap,
      isDisabled: isDisabled,
      cardBuilder: (context, controller) => ModalCard(
        backgroundColor: context.colorScheme.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.cardPadding,
          vertical: AppTheme.cardPadding * 0.6,
        ),
        onTap: isDisabled ? null : onTap,
        isDisabled: isDisabled,
        animationController: controller,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppTheme.modalIconSpacerWidth,
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: AppTheme.modalIconSpacerWidth,
                height: AppTheme.modalIconSpacerWidth,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      effectiveIconColor.withValues(alpha: 0.25),
                      effectiveIconColor.withValues(alpha: 0.15),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(
                    AppTheme.iconContainerBorderRadius,
                  ),
                  border: Border.all(
                    color: effectiveIconColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: AppTheme.iconSize,
                    color: effectiveIconColor.withValues(alpha: 0.9),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.modalChevronSpacerWidth),

              // Title
              Expanded(
                child: Text(
                  title,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: AppTheme.titleFontSize,
                    color: context.colorScheme.onSurface,
                    letterSpacing: AppTheme.letterSpacingTitle * 0.8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Badge if present
              if (badge != null) ...[
                const SizedBox(width: AppTheme.spacingMedium),
                badge!,
              ],

              // Add chevron
              Icon(
                Icons.add_circle_outline_rounded,
                size: AppTheme.chevronSize,
                color: effectiveIconColor.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
