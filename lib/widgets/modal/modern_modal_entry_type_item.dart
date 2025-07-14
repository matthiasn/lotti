import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/modal_card.dart';
import 'package:lotti/widgets/modal/animated_modal_item_with_icon.dart';

/// A modern modal entry type item for creating different entry types
///
/// This widget provides a clean, production-quality design for entry type selection
/// with subtle animations and visual feedback optimized for the create entry flow.
/// It now uses AnimatedModalItemWithIcon to eliminate code duplication.
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

    return AnimatedModalItemWithIcon(
      onTap: isDisabled ? null : onTap,
      isDisabled: isDisabled,
      iconBuilder: (context, iconAnimation, {required bool isPressed}) {
        return Positioned.fill(
          child: IgnorePointer(
            child: Row(
              children: [
                const SizedBox(width: AppTheme.cardPadding),
                // Animated icon container
                Transform.scale(
                  scale: iconAnimation.value,
                  child: Container(
                    width: AppTheme.modalIconSpacerWidth,
                    height: AppTheme.modalIconSpacerWidth,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isPressed
                            ? [
                                effectiveIconColor.withValues(alpha: 0.4),
                                effectiveIconColor.withValues(alpha: 0.3),
                              ]
                            : [
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
                        color: effectiveIconColor.withValues(
                            alpha: isPressed ? 0.3 : 0.2),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        size: AppTheme.iconSize,
                        color: effectiveIconColor.withValues(
                          alpha: isPressed ? 1.0 : 0.9,
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                // Subtle chevron with animation
                AnimatedOpacity(
                  opacity: isPressed ? 1.0 : 0.4,
                  duration: const Duration(milliseconds: 100),
                  child: Icon(
                    Icons.add_circle_outline_rounded,
                    size: AppTheme.chevronSize,
                    color: effectiveIconColor,
                  ),
                ),
                const SizedBox(width: AppTheme.cardPadding),
              ],
            ),
          ),
        );
      },
      child: ModalCard(
        backgroundColor: context.colorScheme.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.cardPadding,
          vertical: AppTheme.cardPadding * 0.6,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppTheme.modalIconSpacerWidth,
          ),
          child: Row(
            children: [
              // Spacer for icon
              const SizedBox(width: AppTheme.modalIconSpacerWidth),
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

              // Spacer for chevron
              const SizedBox(width: AppTheme.chevronSize),
              const SizedBox(width: AppTheme.spacingSmall),
            ],
          ),
        ),
      ),
    );
  }
}
