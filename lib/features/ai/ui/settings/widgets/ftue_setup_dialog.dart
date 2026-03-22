import 'package:flutter/material.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';

/// Configuration for FTUE setup preview display
class FtueSetupConfig {
  const FtueSetupConfig({
    required this.providerName,
    required this.modelCount,
    required this.modelDescription,
    required this.categoryName,
  });

  final String providerName;
  final int modelCount;
  final String modelDescription;
  final String categoryName;

  /// Default configuration for Gemini FTUE
  static const gemini = FtueSetupConfig(
    providerName: 'Gemini',
    modelCount: 3,
    modelDescription: 'Flash, Pro, and Nano Banana Pro (image)',
    categoryName: ftueGeminiCategoryName,
  );

  /// Default configuration for OpenAI FTUE
  static const openAi = FtueSetupConfig(
    providerName: 'OpenAI',
    modelCount: 4,
    modelDescription:
        'GPT-5.2 (reasoning), GPT-5 Nano (fast), Audio, and Image',
    categoryName: ftueOpenAiCategoryName,
  );

  /// Default configuration for Mistral FTUE
  static const mistral = FtueSetupConfig(
    providerName: 'Mistral',
    modelCount: 3,
    modelDescription:
        'Magistral Medium (reasoning), Mistral Small (fast), '
        'Voxtral Mini (audio)',
    categoryName: ftueMistralCategoryName,
  );

  /// Default configuration for Alibaba FTUE
  static const alibaba = FtueSetupConfig(
    providerName: 'Alibaba Cloud (Qwen)',
    modelCount: 5,
    modelDescription:
        'Qwen 3.5 Plus (reasoning), Qwen Flash, VL Flash (vision), '
        'Omni Flash (audio), Wan 2.6 (image)',
    categoryName: ftueAlibabaCategoryName,
  );

  /// Get the appropriate config for a provider type.
  ///
  /// Asserts in debug mode if an unsupported provider type is passed.
  /// Falls back to Gemini in release mode for safety.
  static FtueSetupConfig forProviderType(InferenceProviderType type) {
    final config = switch (type) {
      InferenceProviderType.alibaba => alibaba,
      InferenceProviderType.gemini => gemini,
      InferenceProviderType.openAi => openAi,
      InferenceProviderType.mistral => mistral,
      _ => null,
    };

    if (config == null) {
      assert(
        false,
        'FtueSetupConfig.forProviderType: Unsupported provider type: $type. '
        'Add a case for this provider or handle it before calling this method.',
      );
      // Fallback to Gemini in release mode
      return gemini;
    }

    return config;
  }
}

/// Dialog shown after creating a provider to offer FTUE setup.
///
/// Displays a preview of what will be created:
/// - Models (varies by provider)
/// - Category with auto-selection configured
class FtueSetupDialog extends StatelessWidget {
  const FtueSetupDialog({
    required this.config,
    super.key,
  });

  final FtueSetupConfig config;

  /// Shows the FTUE setup dialog and returns true if user confirms setup.
  static Future<bool> show(
    BuildContext context, {
    required String providerName,
    FtueSetupConfig? config,
  }) async {
    final effectiveConfig =
        config ??
        switch (providerName) {
          'Alibaba Cloud (Qwen)' => FtueSetupConfig.alibaba,
          'OpenAI' => FtueSetupConfig.openAi,
          'Mistral' => FtueSetupConfig.mistral,
          _ => FtueSetupConfig.gemini,
        };

    // useRootNavigator ensures dialog survives widget tree rebuilds (e.g., window resize)
    return await showDialog<bool>(
          context: context,
          // ignore: avoid_redundant_argument_values
          useRootNavigator: true,
          builder: (context) => FtueSetupDialog(config: effectiveConfig),
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
            'Get started quickly with ${config.providerName}',
            style: context.textTheme.titleSmall?.copyWith(
              color: context.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "We'll set up models and a test category so you can "
            'start using AI features right away.',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onPrimaryContainer.withValues(
                alpha: 0.8,
              ),
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
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.5,
        ),
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
            title: '${config.modelCount} Models',
            subtitle: config.modelDescription,
          ),
          const SizedBox(height: 8),

          // Category section
          _buildPreviewItem(
            context,
            icon: Icons.folder_outlined,
            title: '1 Category',
            subtitle: config.categoryName,
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
