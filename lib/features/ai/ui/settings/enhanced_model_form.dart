import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/modality_extensions.dart';
import 'package:lotti/features/ai/state/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/inference_model_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/widgets/modality_selection_modal.dart';
import 'package:lotti/features/ai/ui/settings/widgets/provider_selection_modal.dart';
import 'package:lotti/features/ai/ui/widgets/enhanced_form_field.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Enhanced model form with modern Series A startup styling
///
/// Features:
/// - Professional card-based layout with proper spacing
/// - Smooth animations and micro-interactions
/// - Enhanced visual hierarchy and typography
/// - Formz validation integration with friendly error messages
/// - Modern modality selection with chip-based interface
/// - Accessible design with proper contrast and labels
/// - Professional toggles and selection modals
class EnhancedInferenceModelForm extends ConsumerStatefulWidget {
  const EnhancedInferenceModelForm({
    this.config,
    super.key,
  });

  final AiConfig? config;

  @override
  ConsumerState<EnhancedInferenceModelForm> createState() =>
      _EnhancedInferenceModelFormState();
}

class _EnhancedInferenceModelFormState
    extends ConsumerState<EnhancedInferenceModelForm> {
  void _showInferenceProviderModal() {
    final formController = ref.read(
      inferenceModelFormControllerProvider(configId: widget.config?.id)
          .notifier,
    );
    final formState = ref
        .watch(
            inferenceModelFormControllerProvider(configId: widget.config?.id))
        .valueOrNull;

    ProviderSelectionModal.show(
      context: context,
      onProviderSelected: formController.inferenceProviderIdChanged,
      selectedProviderId: formState?.inferenceProviderId ?? '',
    );
  }

  void _showModalitySelectionModal({
    required String title,
    required List<Modality> selectedModalities,
    required void Function(List<Modality>) onSave,
  }) {
    ModalitySelectionModal.show(
      context: context,
      title: title,
      selectedModalities: selectedModalities,
      onSave: onSave,
    );
  }

  @override
  Widget build(BuildContext context) {
    final configId = widget.config?.id;
    final formState = ref
        .watch(inferenceModelFormControllerProvider(configId: configId))
        .valueOrNull;
    final formController = ref.read(
      inferenceModelFormControllerProvider(configId: configId).notifier,
    );

    if (formState == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section
            Text(
              'Configure an AI model to make it available for use in prompts',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.4,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // Basic Configuration Section
            _FormSection(
              title: 'Basic Configuration',
              icon: Icons.tune_rounded,
              children: [
                // Display Name
                EnhancedFormField(
                  controller: formController.nameController,
                  labelText: 'Display Name',
                  formzField: formState.name,
                  onChanged: formController.nameChanged,
                  prefixIcon: const Icon(Icons.label_outline),
                  isRequired: true,
                  helperText: 'A friendly name to identify this model',
                ),
                const SizedBox(height: 24),

                // Provider Model ID
                EnhancedFormField(
                  controller: formController.providerModelIdController,
                  labelText: 'Provider Model ID',
                  formzField: formState.providerModelId,
                  onChanged: formController.providerModelIdChanged,
                  prefixIcon: const Icon(Icons.fingerprint_outlined),
                  isRequired: true,
                  helperText:
                      'The exact model identifier used by the provider (e.g., gpt-4o, claude-3-5-sonnet)',
                ),
                const SizedBox(height: 24),

                // Provider Selection
                _ProviderSelectionCard(
                  inferenceProviderId: formState.inferenceProviderId,
                  onTap: _showInferenceProviderModal,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Model Capabilities Section
            _FormSection(
              title: 'Model Capabilities',
              icon: Icons.psychology_outlined,
              children: [
                // Input Modalities
                _ModalitySelectionCard(
                  title: 'Input Modalities',
                  subtitle: 'Types of content this model can process',
                  icon: Icons.input_rounded,
                  modalities: formState.inputModalities,
                  onTap: () => _showModalitySelectionModal(
                    title: context.messages.aiConfigInputModalitiesTitle,
                    selectedModalities: formState.inputModalities,
                    onSave: formController.inputModalitiesChanged,
                  ),
                ),
                const SizedBox(height: 16),

                // Output Modalities
                _ModalitySelectionCard(
                  title: 'Output Modalities',
                  subtitle: 'Types of content this model can generate',
                  icon: Icons.output_rounded,
                  modalities: formState.outputModalities,
                  onTap: () => _showModalitySelectionModal(
                    title: context.messages.aiConfigOutputModalitiesTitle,
                    selectedModalities: formState.outputModalities,
                    onSave: formController.outputModalitiesChanged,
                  ),
                ),
                const SizedBox(height: 24),

                // Reasoning Capability Toggle
                _ReasoningCapabilityCard(
                  value: formState.isReasoningModel,
                  onChanged: formController.isReasoningModelChanged,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Additional Details Section
            _FormSection(
              title: 'Additional Details',
              icon: Icons.description_outlined,
              children: [
                // Description/Comment
                EnhancedFormField(
                  controller: formController.descriptionController,
                  labelText: 'Description',
                  onChanged: formController.descriptionChanged,
                  maxLines: null,
                  minLines: 3,
                  helperText: 'Optional notes about this model configuration',
                ),

                const SizedBox(height: 24),

                // Max Completion Tokens
                EnhancedFormField(
                  controller: formController.maxCompletionTokensController,
                  labelText: 'Max Completion Tokens',
                  onChanged: formController.maxCompletionTokensChanged,
                  keyboardType: TextInputType.number,
                  helperText:
                      'Optional limit for response length (leave empty for unlimited)',
                ),
              ],
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

/// Modality selection card widget
class _ModalitySelectionCard extends StatelessWidget {
  const _ModalitySelectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.modalities,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Modality> modalities;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerLow.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.colorScheme.outline.withValues(alpha: 0.15),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: context.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: context.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ],
            ),
            if (modalities.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: modalities.map((modality) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: context.colorScheme.primaryContainer
                          .withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      modality.displayName(context),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Reasoning capability toggle card
class _ReasoningCapabilityCard extends StatelessWidget {
  const _ReasoningCapabilityCard({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerLow.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.psychology_outlined,
              size: 20,
              color: context.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reasoning Capability',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Model can perform step-by-step reasoning',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: context.colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

/// Section widget for organizing form fields with modern styling
class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerLow.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colorScheme.outline.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: context.colorScheme.shadow.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: context.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: context.colorScheme.onSurface.withValues(alpha: 0.8),
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Section content
          ...children,
        ],
      ),
    );
  }
}

/// Provider selection card that shows selected provider name
class _ProviderSelectionCard extends ConsumerWidget {
  const _ProviderSelectionCard({
    required this.inferenceProviderId,
    required this.onTap,
  });

  final String inferenceProviderId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the selected provider
    final providerAsync = inferenceProviderId.isNotEmpty
        ? ref.watch(aiConfigByIdProvider(inferenceProviderId))
        : const AsyncData<AiConfig?>(null);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerLow.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.colorScheme.outline.withValues(alpha: 0.15),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.cloud_outlined,
                    size: 20,
                    color: context.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inference Provider',
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Choose the provider that hosts this model',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: context.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Selected provider display
            switch (providerAsync) {
              AsyncData(value: final provider) when provider != null =>
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: context.colorScheme.primaryContainer
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: context.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 20,
                        color: context.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          provider.name,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              _ => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: context.colorScheme.errorContainer
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: context.colorScheme.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_rounded,
                        size: 20,
                        color: context.colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No provider selected',
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: context.colorScheme.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            },
          ],
        ),
      ),
    );
  }
}
