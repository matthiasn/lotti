import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/settings/widgets/provider_chip_constants.dart';

/// A styled filter chip for AI inference providers with color-coded visual identity
///
/// Features:
/// - Provider-specific colors with gradient avatars
/// - Consistent styling using shared constants
/// - Dark/light theme support
/// - Optional selection state
class ProviderFilterChip extends ConsumerWidget {
  const ProviderFilterChip({
    required this.providerId,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String providerId;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providerAsync = ref.watch(aiConfigByIdProvider(providerId));

    return providerAsync.when(
      data: (provider) {
        if (provider == null) return const SizedBox.shrink();
        if (provider is! AiConfigInferenceProvider) {
          return const SizedBox.shrink();
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final providerColor = ProviderChipConstants.getProviderColor(
          provider.inferenceProviderType,
          isDark: isDark,
        );

        final backgroundColor = isSelected
            ? providerColor.withValues(
                alpha: isDark
                    ? ProviderChipConstants.selectedAlphaDark
                    : ProviderChipConstants.selectedAlphaLight,
              )
            : providerColor.withValues(
                alpha: isDark
                    ? ProviderChipConstants.unselectedAlphaDark
                    : ProviderChipConstants.unselectedAlphaLight,
              );

        final borderColor = isSelected
            ? providerColor.withValues(
                alpha: ProviderChipConstants.selectedBorderAlpha)
            : providerColor.withValues(
                alpha: ProviderChipConstants.unselectedBorderAlpha);

        final textColor = isDark ? Colors.white : Colors.black;

        return FilterChip(
          selected: isSelected,
          onSelected: (_) => onTap(),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                Icon(
                  Icons.check,
                  size: 14,
                  color: textColor,
                ),
                const SizedBox(width: 4),
              ],
              Text(provider.name),
            ],
          ),
          avatar: Container(
            width: ProviderChipConstants.avatarSize,
            height: ProviderChipConstants.avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  providerColor,
                  providerColor.withValues(
                    alpha: ProviderChipConstants.avatarGradientAlpha,
                  ),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: providerColor.withValues(
                    alpha: ProviderChipConstants.avatarShadowAlpha,
                  ),
                  blurRadius: ProviderChipConstants.avatarShadowBlurRadius,
                  offset: ProviderChipConstants.avatarShadowOffset,
                ),
              ],
            ),
          ),
          checkmarkColor: textColor,
          backgroundColor: backgroundColor,
          selectedColor: backgroundColor,
          side: BorderSide(
            color: borderColor,
            width: ProviderChipConstants.chipBorderWidth,
          ),
          labelStyle: TextStyle(
            fontSize: ProviderChipConstants.chipFontSize,
            fontWeight: ProviderChipConstants.chipFontWeight,
            letterSpacing: ProviderChipConstants.chipLetterSpacing,
            color: textColor,
          ),
          showCheckmark: false,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(ProviderChipConstants.chipBorderRadius),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
