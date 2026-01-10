import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';

/// Modal shown to users who don't have a Gemini provider configured.
///
/// This modal:
/// - Explains the AI features available with Gemini
/// - Offers to set up Gemini with pre-configured models and prompts
/// - Allows dismissal (persisted so it won't show again)
class GeminiSetupPromptModal extends StatelessWidget {
  const GeminiSetupPromptModal({
    required this.onSetUp,
    required this.onDismiss,
    super.key,
  });

  final VoidCallback onSetUp;
  final VoidCallback onDismiss;

  /// Shows the Gemini setup prompt modal.
  static Future<void> show(
    BuildContext context, {
    required VoidCallback onSetUp,
    required VoidCallback onDismiss,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (context) => GeminiSetupPromptModal(
        onSetUp: onSetUp,
        onDismiss: onDismiss,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: _buildTitle(context),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Would you like to set up Gemini AI?',
              style: context.textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            _buildFeaturesSection(context),
            const SizedBox(height: 12),
            Text(
              'Gemini is the quickest way to get started. '
              'Other providers like Ollama for local inference '
              'can be configured in Settings > AI.',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        LottiTertiaryButton(
          onPressed: onDismiss,
          label: "Don't Show Again",
        ),
        LottiPrimaryButton(
          onPressed: onSetUp,
          icon: Icons.arrow_forward,
          label: 'Set Up Gemini',
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
            'Set Up AI Features?',
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFeatureItem(
            context,
            icon: Icons.mic,
            text: 'Audio transcription',
          ),
          const SizedBox(height: 8),
          _buildFeatureItem(
            context,
            icon: Icons.image,
            text: 'Image analysis',
          ),
          const SizedBox(height: 8),
          _buildFeatureItem(
            context,
            icon: Icons.checklist,
            text: 'Smart checklists',
          ),
          const SizedBox(height: 8),
          _buildFeatureItem(
            context,
            icon: Icons.summarize,
            text: 'Task summaries',
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: context.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(text),
      ],
    );
  }
}
