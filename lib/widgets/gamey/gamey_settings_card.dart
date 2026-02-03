import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/settings/ui/widgets/animated_settings_cards.dart';
import 'package:lotti/features/theming/state/theming_controller.dart';
import 'package:lotti/themes/gamey/gamey_theme.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/gamey/gamey_card.dart';
import 'package:lotti/widgets/gamey/gamey_icon_badge.dart';

/// A gamified settings card with vibrant gradients and animations.
///
/// Used for settings navigation items with playful tap feedback.
class GameySettingsCard extends StatelessWidget {
  const GameySettingsCard({
    required this.title,
    this.subtitle,
    this.icon,
    this.iconGradient,
    this.onTap,
    this.trailing,
    this.accentColor,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Gradient? iconGradient;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? accentColor;

  /// Unified gamey gradient for all cards
  static const Gradient _gameyGradient = LinearGradient(
    colors: [GameyColors.gameyAccent, GameyColors.gameyAccentLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    // Always use unified gamey accent for consistent look
    const effectiveAccent = GameyColors.gameyAccent;

    return GameySubtleCard(
      accentColor: effectiveAccent,
      onTap: onTap,
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingLarge,
        vertical: AppTheme.cardSpacing / 2,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.cardPadding,
        vertical: AppTheme.cardPaddingCompact,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            GameyIconBadge(
              icon: icon!,
              gradient: _gameyGradient,
              size: 48,
              iconSize: 24,
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
          if (trailing == null && onTap != null)
            Icon(
              Icons.chevron_right,
              color: effectiveAccent.withValues(alpha: 0.6),
            ),
        ],
      ),
    );
  }
}

/// A gamified settings section with grouped cards
class GameySettingsSection extends StatelessWidget {
  const GameySettingsSection({
    required this.title,
    required this.children,
    this.accentColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    super.key,
  });

  final String title;
  final List<Widget> children;
  final Color? accentColor;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: accentColor ?? GameyColors.primaryPurple,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
          ...children.map(
            (child) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// A gamified toggle switch card with unified bubbly styling
class GameyToggleCard extends StatelessWidget {
  const GameyToggleCard({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.accentColor,
    super.key,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? subtitle;
  final IconData? icon;
  final Color? accentColor;

  /// Unified gamey gradient for all cards
  static const Gradient _gameyGradient = LinearGradient(
    colors: [GameyColors.gameyAccent, GameyColors.gameyAccentLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    // Always use unified gamey accent for consistent look
    const effectiveAccent = GameyColors.gameyAccent;

    return GameySubtleCard(
      accentColor: value ? effectiveAccent : Colors.grey,
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingLarge,
        vertical: AppTheme.cardSpacing / 2,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.cardPadding,
        vertical: AppTheme.cardPaddingCompact,
      ),
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          if (icon != null) ...[
            GameyIconBadge(
              icon: icon!,
              gradient: value
                  ? _gameyGradient
                  : LinearGradient(
                      colors: [Colors.grey.shade400, Colors.grey.shade500],
                    ),
              size: 48,
              iconSize: 24,
              showGlow: value,
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                        ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: effectiveAccent.withValues(alpha: 0.5),
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return effectiveAccent;
              }
              return null;
            }),
          ),
        ],
      ),
    );
  }
}

/// A gamified list tile for simple settings items
class GameyListTile extends StatelessWidget {
  const GameyListTile({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.accentColor,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accentColor ?? context.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: effectiveAccent.withValues(alpha: 0.1),
        highlightColor: effectiveAccent.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

/// An adaptive settings card that automatically uses gamey styling when
/// the gamey theme is active, otherwise uses the standard animated card.
///
/// This eliminates duplicated theme-detection logic across settings pages.
class AdaptiveSettingsCard extends ConsumerWidget {
  const AdaptiveSettingsCard({
    required this.title,
    required this.icon,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.showChevron = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showChevron;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themingState = ref.watch(themingControllerProvider);
    final brightness = Theme.of(context).brightness;
    final useGamey = themingState.isGameyThemeForBrightness(brightness);

    if (useGamey) {
      return GameySettingsCard(
        title: title,
        subtitle: subtitle,
        icon: icon,
        onTap: onTap,
        trailing: trailing,
      );
    }

    return AnimatedModernSettingsCardWithIcon(
      title: title,
      subtitle: subtitle,
      icon: icon,
      onTap: onTap,
      trailing: trailing,
      showChevron: showChevron,
    );
  }
}
