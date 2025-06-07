import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/ai_config_by_type_controller.dart';
import 'package:lotti/themes/theme.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Material(
        elevation: 0,
        borderRadius: BorderRadius.circular(14),
        color: context.colorScheme.surface,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: context.colorScheme.primary.withValues(alpha: 0.1),
          highlightColor: context.colorScheme.primary.withValues(alpha: 0.05),
          child: Container(
            padding: EdgeInsets.all(isCompact ? 10 : 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: context.colorScheme.outline.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Icon with premium container
                Container(
                  width: isCompact ? 28 : 32,
                  height: isCompact ? 28 : 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        context.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.7),
                        context.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getConfigIcon(),
                    size: isCompact ? 16 : 18,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),

                SizedBox(width: isCompact ? 8 : 10),

                // Config info with enhanced typography
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Config name
                      Text(
                        config.name,
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                          fontSize: isCompact ? 14 : 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Provider info for models
                      if (config is AiConfigModel) ...[
                        const SizedBox(height: 2),
                        _CompactProviderName(
                          providerId: (config as AiConfigModel).inferenceProviderId,
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
                                .withValues(alpha: 0.7),
                            fontSize: isCompact ? 10 : 11,
                            height: 1.3,
                            letterSpacing: -0.1,
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
                  color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
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
      final modelName = model.name.toLowerCase();
      if (modelName.contains('gpt')) return Icons.psychology;
      if (modelName.contains('claude')) return Icons.auto_awesome;
      if (modelName.contains('gemini')) return Icons.diamond;
      if (modelName.contains('opus')) return Icons.workspace_premium;
      if (modelName.contains('sonnet')) return Icons.edit_note;
      if (modelName.contains('haiku')) return Icons.flash_on;
      return Icons.smart_toy;
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
            color: context.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            providerName,
            style: context.textTheme.bodySmall?.copyWith(
              color:
                  context.colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
              fontSize: isCompact ? 9 : 10,
              letterSpacing: -0.1,
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
    final capabilities = <Widget>[];

    // Text support (always present)
    capabilities.add(_buildCapabilityIcon(
      context,
      Icons.text_fields,
      'Text',
      true,
    ));

    // Vision support
    final hasVision = model.inputModalities.contains(Modality.image);
    capabilities.add(_buildCapabilityIcon(
      context,
      Icons.visibility,
      'Vision',
      hasVision,
    ));

    // Audio support
    final hasAudio = model.inputModalities.contains(Modality.audio);
    capabilities.add(_buildCapabilityIcon(
      context,
      Icons.hearing,
      'Audio',
      hasAudio,
    ));

    // Reasoning support
    final hasReasoning = model.isReasoningModel;
    if (hasReasoning) {
      capabilities.add(_buildCapabilityIcon(
        context,
        Icons.psychology,
        'Reasoning',
        true,
      ));
    }

    return Wrap(
      spacing: isCompact ? 4 : 6,
      children: capabilities,
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
