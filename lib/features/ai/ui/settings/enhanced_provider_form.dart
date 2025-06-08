import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_provider_extensions.dart';
import 'package:lotti/features/ai/state/inference_provider_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/widgets/provider_type_selection_modal.dart';
import 'package:lotti/features/ai/ui/widgets/enhanced_form_field.dart';
import 'package:lotti/themes/theme.dart';

/// Enhanced inference provider form with modern Series A startup styling
///
/// Features:
/// - Professional card-based layout with proper spacing
/// - Smooth animations and micro-interactions
/// - Enhanced visual hierarchy and typography
/// - Formz validation integration with friendly error messages
/// - Accessible design with proper contrast and labels
/// - Modern selection modals with improved UX
class EnhancedInferenceProviderForm extends ConsumerStatefulWidget {
  const EnhancedInferenceProviderForm({
    this.config,
    super.key,
  });

  final AiConfig? config;

  @override
  ConsumerState<EnhancedInferenceProviderForm> createState() =>
      _EnhancedInferenceProviderFormState();
}

class _EnhancedInferenceProviderFormState
    extends ConsumerState<EnhancedInferenceProviderForm> {
  bool _showApiKey = false;

  void _showProviderTypeModal() {
    ProviderTypeSelectionModal.show(
      context: context,
      configId: widget.config?.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final configId = widget.config?.id;
    final formState = ref
        .watch(inferenceProviderFormControllerProvider(configId: configId))
        .valueOrNull;
    final formController = ref.read(
      inferenceProviderFormControllerProvider(configId: configId).notifier,
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
            // Header section - removed redundant title
            Text(
              'Configure your AI inference provider to start making requests',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.4,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // Form section
            _FormSection(
              title: 'Provider Configuration',
              icon: Icons.settings_outlined,
              children: [
                // Provider Type Selection
                EnhancedSelectionField(
                  labelText: 'Provider Type',
                  value: formState.inferenceProviderType.displayName(context),
                  onTap: _showProviderTypeModal,
                  prefixIcon: Icon(formState.inferenceProviderType.icon),
                  isRequired: true,
                  helperText:
                      'Choose the AI service provider for this configuration',
                ),
                const SizedBox(height: 24),

                // Display Name
                EnhancedFormField(
                  controller: formController.nameController,
                  labelText: 'Display Name',
                  formzField: formState.name,
                  onChanged: formController.nameChanged,
                  prefixIcon: const Icon(Icons.label_outline),
                  isRequired: true,
                  helperText: 'A friendly name to identify this provider',
                ),
                const SizedBox(height: 24),

                // Base URL
                EnhancedFormField(
                  controller: formController.baseUrlController,
                  labelText: 'Base URL',
                  formzField: formState.baseUrl,
                  onChanged: formController.baseUrlChanged,
                  keyboardType: TextInputType.url,
                  prefixIcon: const Icon(Icons.link_outlined),
                  helperText: 'The API endpoint URL for this provider',
                ),
              ],
            ),

            const SizedBox(height: 32),

            _FormSection(
              title: 'Authentication',
              icon: Icons.security_outlined,
              children: [
                // API Key
                EnhancedFormField(
                  controller: formController.apiKeyController,
                  labelText: 'API Key',
                  formzField: formState.apiKey,
                  onChanged: formController.apiKeyChanged,
                  obscureText: !_showApiKey,
                  prefixIcon: const Icon(Icons.key_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showApiKey
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () => setState(() {
                      _showApiKey = !_showApiKey;
                    }),
                    tooltip: _showApiKey ? 'Hide API Key' : 'Show API Key',
                  ),
                  isRequired: true,
                  helperText:
                      'Your API key for authenticating with this provider',
                ),
              ],
            ),

            const SizedBox(height: 32),

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
                  helperText:
                      'Optional notes about this provider configuration',
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
