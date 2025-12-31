import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_provider_extensions.dart';
import 'package:lotti/features/ai/model/inference_provider_form_state.dart';
import 'package:lotti/features/ai/state/settings/inference_provider_form_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/selection/selection_modal_base.dart';

/// High-quality provider type selection modal with Series A startup design standards
///
/// Features:
/// - Wolt modal sheet with persistent title section
/// - Premium card-based design with proper contrast
/// - Smooth animations and micro-interactions
/// - Modern glassmorphic styling
/// - Accessible design with semantic labels
/// - Professional typography hierarchy
class ProviderTypeSelectionModal extends ConsumerWidget {
  const ProviderTypeSelectionModal({
    required this.configId,
    super.key,
  });

  final String? configId;

  /// Shows the provider type selection modal using SelectionModalBase
  static void show({
    required BuildContext context,
    required String? configId,
  }) {
    SelectionModalBase.show(
      context: context,
      title: context.messages.aiConfigSelectProviderTypeModalTitle,
      child: ProviderTypeSelectionModal(configId: configId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref
        .watch(
          inferenceProviderFormControllerProvider(configId: configId),
        )
        .value;
    final formController = ref.read(
      inferenceProviderFormControllerProvider(configId: configId).notifier,
    );

    if (formState == null) {
      return const _LoadingState();
    }

    return _ProviderTypeContent(
      formState: formState,
      formController: formController,
    );
  }
}

/// Main content widget for provider type selection
class _ProviderTypeContent extends StatelessWidget {
  const _ProviderTypeContent({
    required this.formState,
    required this.formController,
  });

  final InferenceProviderFormState formState;
  final InferenceProviderFormController formController;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: InferenceProviderType.values.map((type) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: _ProviderTypeCard(
              type: type,
              isSelected: formState.inferenceProviderType == type,
              onTap: () {
                formController.inferenceProviderTypeChanged(type);
                Navigator.of(context).pop();
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Individual provider type card with premium styling
class _ProviderTypeCard extends StatelessWidget {
  const _ProviderTypeCard({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  final InferenceProviderType type;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? context.colorScheme.primaryContainer.withValues(alpha: 0.15)
            : context.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? context.colorScheme.primary.withValues(alpha: 0.6)
              : context.colorScheme.outline.withValues(alpha: 0.1),
          width: 2, // Keep consistent border width to prevent breathing
        ),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: context.colorScheme.primary.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Provider icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.colorScheme.primary.withValues(alpha: 0.15)
                        : context.colorScheme.surfaceContainerHigh
                            .withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? context.colorScheme.primary.withValues(alpha: 0.3)
                          : Colors.transparent,
                    ),
                  ),
                  child: Icon(
                    type.icon,
                    color: isSelected
                        ? context.colorScheme.primary
                        : context.colorScheme.onSurface.withValues(alpha: 0.8),
                    size: 24,
                  ),
                ),

                const SizedBox(width: 16),

                // Provider info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.displayName(context),
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? context.colorScheme.primary
                              : context.colorScheme.onSurface,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        type.description(context),
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                // Selection indicator
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: context.colorScheme.primary,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: context.colorScheme.primary
                              .withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: context.colorScheme.onPrimary,
                      size: 16,
                    ),
                  )
                else
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color:
                            context.colorScheme.outline.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Loading state widget
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: context.colorScheme.primary,
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading providers...',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
