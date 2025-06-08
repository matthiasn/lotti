import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/ai_config_by_type_controller.dart';
import 'package:lotti/themes/theme.dart';

/// Model family classifications for robust icon selection
enum ModelFamily {
  gpt,
  claude,
  gemini,
  opus,
  sonnet,
  haiku,
  generic,
}

/// Maps model families to their representative icons
const Map<ModelFamily, IconData> _modelFamilyIcons = {
  ModelFamily.gpt: Icons.psychology,
  ModelFamily.claude: Icons.auto_awesome,
  ModelFamily.gemini: Icons.diamond,
  ModelFamily.opus: Icons.workspace_premium,
  ModelFamily.sonnet: Icons.edit_note,
  ModelFamily.haiku: Icons.flash_on,
  ModelFamily.generic: Icons.smart_toy,
};

/// Maps common model patterns to their families for robust classification
const Map<String, ModelFamily> _modelPatterns = {
  'gpt': ModelFamily.gpt,
  'claude': ModelFamily.claude,
  'gemini': ModelFamily.gemini,
  'opus': ModelFamily.opus,
  'sonnet': ModelFamily.sonnet,
  'haiku': ModelFamily.haiku,
};

/// A reusable card component for AI configurations (providers, models, prompts)
/// with polished design matching the model selection modal
class AiConfigCard extends ConsumerWidget {
  const AiConfigCard({
    required this.config,
    required this.onTap,
    this.showCapabilities = false,
    this.isCompact = false,
    super.key,
  });

  final AiConfig config;
  final VoidCallback onTap;
  final bool showCapabilities;
  final bool isCompact;

  /// Determines the model family from a model configuration
  ///
  /// This method provides a more robust way to classify models than string matching.
  /// It first checks the provider model ID (which tends to be more standardized),
  /// then falls back to the display name if needed.
  static ModelFamily _getModelFamily(AiConfigModel model) {
    // Check provider model ID first (more standardized)
    final providerModelId = model.providerModelId.toLowerCase();
    for (final entry in _modelPatterns.entries) {
      if (providerModelId.contains(entry.key)) {
        return entry.value;
      }
    }

    // Fall back to display name
    final displayName = model.name.toLowerCase();
    for (final entry in _modelPatterns.entries) {
      if (displayName.contains(entry.key)) {
        return entry.value;
      }
    }

    return ModelFamily.generic;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.colorScheme.surfaceContainer,
            context.colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colorScheme.primaryContainer.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: context.colorScheme.shadow.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: context.colorScheme.primary.withValues(alpha: 0.1),
          highlightColor: context.colorScheme.primary.withValues(alpha: 0.05),
          child: Container(
            padding: EdgeInsets.all(isCompact ? 12 : 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                // Icon with premium container
                Container(
                  width: isCompact ? 36 : 40,
                  height: isCompact ? 36 : 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        context.colorScheme.primaryContainer
                            .withValues(alpha: 0.3),
                        context.colorScheme.primaryContainer
                            .withValues(alpha: 0.2),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          context.colorScheme.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Icon(
                    _getConfigIcon(),
                    size: isCompact ? 18 : 20,
                    color: context.colorScheme.primary.withValues(alpha: 0.9),
                  ),
                ),

                SizedBox(width: isCompact ? 10 : 12),

                // Config info with enhanced typography
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Config name
                      Text(
                        config.name,
                        style: context.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                          fontSize: isCompact ? 15 : 16,
                          color: context.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Provider info for models
                      if (config is AiConfigModel) ...[
                        const SizedBox(height: 2),
                        _CompactProviderName(
                          providerId:
                              (config as AiConfigModel).inferenceProviderId,
                          isCompact: isCompact,
                        ),
                      ],

                      // Description
                      if (config.description != null &&
                          config.description!.isNotEmpty) ...[
                        SizedBox(height: isCompact ? 2 : 4),
                        Text(
                          config.description!,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.8),
                            fontSize: isCompact ? 11 : 12,
                            height: 1.4,
                            letterSpacing: 0,
                          ),
                          maxLines: isCompact ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      // Capabilities for models
                      if (showCapabilities && config is AiConfigModel) ...[
                        const SizedBox(height: 6),
                        _CapabilityIndicators(
                          model: config as AiConfigModel,
                          isCompact: isCompact,
                        ),
                      ],
                    ],
                  ),
                ),

                // Chevron
                Icon(
                  Icons.chevron_right,
                  size: isCompact ? 18 : 20,
                  color: context.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getConfigIcon() {
    if (config is AiConfigInferenceProvider) {
      final provider = config as AiConfigInferenceProvider;
      switch (provider.inferenceProviderType) {
        case InferenceProviderType.anthropic:
          return Icons.auto_awesome;
        case InferenceProviderType.openAi:
          return Icons.psychology;
        case InferenceProviderType.gemini:
          return Icons.diamond;
        case InferenceProviderType.openRouter:
          return Icons.hub;
        case InferenceProviderType.ollama:
          return Icons.computer;
        case InferenceProviderType.genericOpenAi:
          return Icons.cloud;
        case InferenceProviderType.nebiusAiStudio:
          return Icons.rocket_launch;
      }
    } else if (config is AiConfigModel) {
      final model = config as AiConfigModel;
      final family = _getModelFamily(model);
      return _modelFamilyIcons[family] ?? Icons.smart_toy;
    } else if (config is AiConfigPrompt) {
      final prompt = config as AiConfigPrompt;
      // Return icon based on the primary input data type
      if (prompt.requiredInputData.contains(InputDataType.images)) {
        return Icons.image;
      } else if (prompt.requiredInputData.contains(InputDataType.audioFiles)) {
        return Icons.audiotrack;
      } else {
        return Icons.text_snippet;
      }
    }
    return Icons.settings;
  }
}

class _CompactProviderName extends ConsumerWidget {
  const _CompactProviderName({
    required this.providerId,
    this.isCompact = false,
  });

  final String providerId;
  final bool isCompact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providerAsync = ref.watch(aiConfigByIdProvider(providerId));

    return providerAsync.when(
      data: (provider) {
        final providerName = provider?.name ?? 'Unknown';
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 5 : 6,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                context.colorScheme.primaryContainer.withValues(alpha: 0.25),
                context.colorScheme.primaryContainer.withValues(alpha: 0.15),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: context.colorScheme.primary.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          child: Text(
            providerName,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.primary.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
              fontSize: isCompact ? 10 : 11,
              letterSpacing: 0.1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
      loading: () => Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 5 : 6,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          'Loading...',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            fontSize: isCompact ? 9 : 10,
          ),
        ),
      ),
      error: (_, __) => Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 5 : 6,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: context.colorScheme.errorContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          'Error',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.error.withValues(alpha: 0.8),
            fontSize: isCompact ? 9 : 10,
          ),
        ),
      ),
    );
  }
}

class _CapabilityIndicators extends StatelessWidget {
  const _CapabilityIndicators({
    required this.model,
    this.isCompact = false,
  });

  final AiConfigModel model;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: isCompact ? 4 : 6,
      children: [
        // Text support (always present)
        _buildCapabilityIcon(
          context,
          Icons.text_fields,
          'Text',
          true,
        ),
        // Vision support
        _buildCapabilityIcon(
          context,
          Icons.visibility,
          'Vision',
          model.inputModalities.contains(Modality.image),
        ),
        // Audio support
        _buildCapabilityIcon(
          context,
          Icons.hearing,
          'Audio',
          model.inputModalities.contains(Modality.audio),
        ),
        // Reasoning support (if applicable)
        if (model.isReasoningModel)
          _buildCapabilityIcon(
            context,
            Icons.psychology,
            'Reasoning',
            true,
          ),
      ],
    );
  }

  Widget _buildCapabilityIcon(
    BuildContext context,
    IconData icon,
    String tooltip,
    bool isSupported,
  ) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: isCompact ? 20 : 24,
        height: isCompact ? 20 : 24,
        decoration: BoxDecoration(
          color: isSupported
              ? context.colorScheme.primaryContainer.withValues(alpha: 0.7)
              : context.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          icon,
          size: isCompact ? 12 : 14,
          color: isSupported
              ? context.colorScheme.primary
              : context.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
