import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/state/prompt_form_controller.dart';
import 'package:lotti/features/ai/ui/settings/preconfigured_prompt_selection_modal.dart';
import 'package:lotti/features/ai/ui/settings/prompt_form_select_model.dart';
import 'package:lotti/features/ai/ui/settings/prompt_input_type_selection.dart';
import 'package:lotti/features/ai/ui/settings/prompt_response_type_selection.dart';
import 'package:lotti/features/ai/ui/widgets/enhanced_form_field.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Enhanced prompt form with modern Series A startup styling
///
/// Features:
/// - Professional card-based layout with proper spacing
/// - Smooth animations and micro-interactions
/// - Enhanced visual hierarchy and typography
/// - Formz validation integration with friendly error messages
/// - Modern model selection and configuration options
/// - Accessible design with proper contrast and labels
/// - Professional toggles and selection interfaces
class EnhancedPromptForm extends ConsumerStatefulWidget {
  const EnhancedPromptForm({
    this.configId,
    super.key,
  });

  final String? configId;

  @override
  ConsumerState<EnhancedPromptForm> createState() => _EnhancedPromptFormState();
}

class _EnhancedPromptFormState extends ConsumerState<EnhancedPromptForm> {
  @override
  Widget build(BuildContext context) {
    final configId = widget.configId;
    final formState =
        ref.watch(promptFormControllerProvider(configId: configId)).valueOrNull;
    final formController = ref.read(
      promptFormControllerProvider(configId: configId).notifier,
    );

    if (formState == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header section - removed redundant title
            Text(
              'Create custom prompts that can be used with your AI models to generate specific types of responses',
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.4,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),

            // Quick Start Section (only for new prompts)
            if (configId == null) ...[
              _FormSection(
                title: 'Quick Start',
                icon: Icons.rocket_launch_outlined,
                children: [
                  _PreconfiguredPromptButton(
                    onPressed: () async {
                      final selectedPrompt =
                          await showPreconfiguredPromptSelectionModal(context);
                      if (selectedPrompt != null) {
                        formController
                            .populateFromPreconfiguredPrompt(selectedPrompt);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

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
                  helperText: 'A descriptive name for this prompt template',
                ),
                const SizedBox(height: 24),

                // Model Selection
                _ModelSelectionCard(configId: configId),
              ],
            ),

            const SizedBox(height: 24),

            // Prompt Configuration Section
            _FormSection(
              title: 'Prompt Configuration',
              icon: Icons.edit_note_rounded,
              children: [
                // User Message
                EnhancedFormField(
                  controller: formController.userMessageController,
                  labelText: 'User Message',
                  formzField: formState.userMessage,
                  onChanged: formController.userMessageChanged,
                  maxLines: null,
                  minLines: 3,
                  isRequired: true,
                  helperText:
                      'The main prompt text. Use {{variables}} for dynamic content.',
                ),
                const SizedBox(height: 24),

                // System Message
                EnhancedFormField(
                  controller: formController.systemMessageController,
                  labelText: 'System Message',
                  onChanged: formController.systemMessageChanged,
                  maxLines: null,
                  minLines: 3,
                  helperText:
                      "Instructions that define the AI's behavior and response style",
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Configuration Options Section
            _FormSection(
              title: 'Configuration Options',
              icon: Icons.settings_outlined,
              children: [
                // Input Type Selection
                _SelectionRow(
                  title: 'Required Input Data',
                  subtitle: 'Type of data this prompt expects',
                  icon: Icons.input_rounded,
                  child: PromptInputTypeSelection(configId: configId),
                ),
                const SizedBox(height: 16),

                // Response Type Selection
                _SelectionRow(
                  title: 'AI Response Type',
                  subtitle: 'Format of the expected response',
                  icon: Icons.output_rounded,
                  child: PromptResponseTypeSelection(configId: configId),
                ),
                const SizedBox(height: 24),

                // Use Reasoning Toggle
                _ReasoningToggleCard(
                  value: formState.useReasoning,
                  onChanged: formController.useReasoningChanged,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Additional Details Section
            _FormSection(
              title: 'Additional Details',
              icon: Icons.description_outlined,
              children: [
                // Description
                EnhancedFormField(
                  controller: formController.descriptionController,
                  labelText: 'Description',
                  onChanged: formController.descriptionChanged,
                  maxLines: null,
                  minLines: 3,
                  prefixIcon: const Icon(Icons.notes_outlined),
                  helperText:
                      "Optional notes about this prompt's purpose and usage",
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

/// Preconfigured prompt selection button
class _PreconfiguredPromptButton extends StatelessWidget {
  const _PreconfiguredPromptButton({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.colorScheme.primaryContainer.withValues(alpha: 0.3),
            context.colorScheme.primaryContainer.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: context.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.messages.promptUsePreconfiguredButton,
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: context.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose from ready-made prompt templates',
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: context.colorScheme.primary,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Model selection card wrapper
class _ModelSelectionCard extends StatelessWidget {
  const _ModelSelectionCard({
    required this.configId,
  });

  final String? configId;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:
            context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colorScheme.outline.withValues(alpha: 0.12),
        ),
      ),
      child: PromptFormSelectModel(configId: configId),
    );
  }
}

/// Selection row for dropdowns
class _SelectionRow extends StatelessWidget {
  const _SelectionRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:
            context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colorScheme.outline.withValues(alpha: 0.12),
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
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Reasoning toggle card
class _ReasoningToggleCard extends StatelessWidget {
  const _ReasoningToggleCard({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:
            context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colorScheme.outline.withValues(alpha: 0.12),
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
                  context.messages.aiConfigUseReasoningFieldLabel,
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.messages.aiConfigUseReasoningDescription,
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
        color: context.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colorScheme.outline.withValues(alpha: 0.08),
        ),
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
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.colorScheme.onSurface,
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
