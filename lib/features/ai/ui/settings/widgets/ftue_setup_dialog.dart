import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';

/// Dialog shown after creating a Gemini provider to offer FTUE setup.
///
/// Displays a preview of what will be created:
/// - 3 models (Flash, Pro, Nano Banana Pro)
/// - 18 prompts (Flash and Pro variants for 9 prompt types)
/// - 1 category (Test Category Gemini Enabled)
class FtueSetupDialog extends StatelessWidget {
  const FtueSetupDialog({
    required this.providerName,
    super.key,
  });

  final String providerName;

  /// Shows the FTUE setup dialog and returns true if user confirms setup.
  static Future<bool> show(BuildContext context,
      {required String providerName}) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => FtueSetupDialog(providerName: providerName),
        ) ??
        false;
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
            _buildInfoSection(context),
            const SizedBox(height: 16),
            _buildPreviewSection(context),
          ],
        ),
      ),
      actions: [
        LottiTertiaryButton(
          onPressed: () => Navigator.of(context).pop(false),
          label: 'No Thanks',
        ),
        LottiPrimaryButton(
          onPressed: () => Navigator.of(context).pop(true),
          label: 'Set Up',
          icon: Icons.auto_awesome,
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
            color: context.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.auto_awesome,
            color: context.colorScheme.primary,
            size: 24,
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

  Widget _buildInfoSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Get started quickly with $providerName',
            style: context.textTheme.titleSmall?.copyWith(
              color: context.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "We'll set up models, prompts, and a test category so you can "
            'start using AI features right away.',
            style: context.textTheme.bodySmall?.copyWith(
              color:
                  context.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What will be created:',
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // Models section
          _buildPreviewItem(
            context,
            icon: Icons.memory,
            title: '3 Models',
            subtitle: 'Flash, Pro, and Nano Banana Pro (image)',
          ),
          const SizedBox(height: 8),

          // Prompts section
          _buildPreviewItem(
            context,
            icon: Icons.chat_bubble_outline,
            title: '18 Prompts',
            subtitle: 'Flash & Pro variants for 9 prompt types',
          ),
          const SizedBox(height: 8),

          // Category section
          _buildPreviewItem(
            context,
            icon: Icons.folder_outlined,
            title: '1 Category',
            subtitle: 'Test Category Gemini Enabled',
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: context.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: context.colorScheme.primary,
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                subtitle,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
