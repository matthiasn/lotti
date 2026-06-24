import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/ui/settings/widgets/provider_chip_constants.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';

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

        return DesignSystemChip(
          label: provider.name,
          selected: isSelected,
          onPressed: onTap,
          // The provider's colour identity rides a gradient avatar dot; the
          // chip's selected / idle surface comes from the design system.
          avatar: DecoratedBox(
            decoration: BoxDecoration(
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
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
