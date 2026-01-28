import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/services/ai_setup_prompt_service.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';

/// Modal shown to users who don't have any AI provider configured.
///
/// This modal:
/// - Explains the AI features available
/// - Offers a choice between Gemini, OpenAI, and Mistral
/// - Allows dismissal (persisted so it won't show again)
class AiProviderSelectionModal extends StatefulWidget {
  const AiProviderSelectionModal({
    required this.onProviderSelected,
    required this.onDismiss,
    super.key,
  });

  final void Function(InferenceProviderType) onProviderSelected;
  final VoidCallback onDismiss;

  /// Shows the AI provider selection modal.
  ///
  /// Callbacks are invoked after the dialog is fully closed to avoid
  /// Hero animation conflicts during navigation.
  static Future<void> show(
    BuildContext context, {
    required void Function(InferenceProviderType) onProviderSelected,
    required VoidCallback onDismiss,
  }) async {
    final result = await showDialog<InferenceProviderType?>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => AiProviderSelectionModal(
        onProviderSelected: (type) => Navigator.of(dialogContext).pop(type),
        onDismiss: () => Navigator.of(dialogContext).pop(),
      ),
    );

    // Use post-frame callback to invoke callbacks after dialog animation completes
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (result != null) {
        onProviderSelected(result);
      } else {
        onDismiss();
      }
    });
  }

  @override
  State<AiProviderSelectionModal> createState() =>
      _AiProviderSelectionModalState();
}

class _AiProviderSelectionModalState extends State<AiProviderSelectionModal> {
  AiProviderOption? _selectedProvider;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: _buildTitle(context),
      content: SingleChildScrollView(
        child: RadioGroup<AiProviderOption>(
          groupValue: _selectedProvider,
          onChanged: (value) => setState(() => _selectedProvider = value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose your AI provider to get started:',
                style: context.textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              _buildProviderOption(
                context,
                option: AiProviderOption.gemini,
                icon: Icons.auto_awesome,
                color: ftueGeminiColor,
              ),
              const SizedBox(height: 12),
              _buildProviderOption(
                context,
                option: AiProviderOption.openAi,
                icon: Icons.psychology,
                color: ftueOpenAiColor,
              ),
              const SizedBox(height: 12),
              _buildProviderOption(
                context,
                option: AiProviderOption.mistral,
                icon: Icons.air,
                color: ftueMistralColor,
              ),
              const SizedBox(height: 16),
              Text(
                'You can configure additional providers later in Settings > AI.',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        LottiTertiaryButton(
          onPressed: widget.onDismiss,
          label: "Don't Show Again",
        ),
        LottiPrimaryButton(
          onPressed: _selectedProvider != null
              ? () => widget
                  .onProviderSelected(_selectedProvider!.inferenceProviderType)
              : null,
          icon: Icons.arrow_forward,
          label: 'Continue',
        ),
      ],
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.auto_awesome,
            color: context.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Set Up AI Features',
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProviderOption(
    BuildContext context, {
    required AiProviderOption option,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedProvider == option;

    return GestureDetector(
      onTap: () => setState(() => _selectedProvider = option),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : context.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? color
                : context.colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.displayName,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    option.description,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Radio<AiProviderOption>(
              value: option,
              activeColor: color,
            ),
          ],
        ),
      ),
    );
  }
}
