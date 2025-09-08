import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
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
    super.key,
  });

  final AiConfig config;
  final VoidCallback onTap;
  final bool showCapabilities;

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
      duration: const Duration(milliseconds: AppTheme.animationDuration),
      curve: AppTheme.animationCurve,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? context.colorScheme.surface
            : null,
        gradient: Theme.of(context).brightness == Brightness.light
            ? null
            : LinearGradient(
                colors: [
                  Color.lerp(
                    context.colorScheme.surfaceContainer,
                    context.colorScheme.surfaceContainerHigh,
                    0.3,
                  )!,
                  Color.lerp(
                    context.colorScheme.surface,
                    context.colorScheme.surfaceContainerLow,
                    0.5,
                  )!,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.light
              ? context.colorScheme.outline
                  .withValues(alpha: AppTheme.alphaOutline)
              : context.colorScheme.primaryContainer
                  .withValues(alpha: AppTheme.alphaPrimaryContainer),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.light
                ? context.colorScheme.shadow
                    .withValues(alpha: AppTheme.alphaShadowLight)
                : context.colorScheme.shadow
                    .withValues(alpha: AppTheme.alphaShadowDark),
            blurRadius: Theme.of(context).brightness == Brightness.light
                ? AppTheme.cardElevationLight
                : AppTheme.cardElevationDark,
            offset: AppTheme.shadowOffset,
          ),
        ],
      ),
      child: Material(
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
          splashColor: context.colorScheme.primary
              .withValues(alpha: AppTheme.alphaPrimary),
          highlightColor: context.colorScheme.primary
              .withValues(alpha: AppTheme.alphaPrimaryHighlight),
          child: Container(
            padding: const EdgeInsets.all(AppTheme.cardPadding),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
            ),
            child: Row(
              children: [
                // Icon with premium container
                Container(
                  width: AppTheme.iconContainerSize,
                  height: AppTheme.iconContainerSize,
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
                    borderRadius: BorderRadius.circular(
                        AppTheme.iconContainerBorderRadius),
                    border: Border.all(
                      color: context.colorScheme.primary
                          .withValues(alpha: AppTheme.alphaPrimaryBorder),
                    ),
                  ),
                  child: Icon(
                    _getConfigIcon(),
                    size: AppTheme.iconSize,
                    color: context.colorScheme.primary
                        .withValues(alpha: AppTheme.alphaPrimaryIcon),
                  ),
                ),

                const SizedBox(width: AppTheme.spacingLarge),

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
                          letterSpacing: AppTheme.letterSpacingTitle,
                          fontSize: AppTheme.titleFontSize,
                          color: context.colorScheme.onSurface,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Provider info for models
                      if (config is AiConfigModel) ...[
                        const SizedBox(
                            height:
                                AppTheme.spacingBetweenTitleAndSubtitleCompact),
                        _CompactProviderName(
                          providerId:
                              (config as AiConfigModel).inferenceProviderId,
                        ),
                      ],

                      // Description
                      if (config.description != null &&
                          config.description!.isNotEmpty) ...[
                        const SizedBox(
                            height: AppTheme.spacingBetweenTitleAndSubtitle),
                        Text(
                          config.description!,
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant
                                .withValues(
                                    alpha: AppTheme.alphaSurfaceVariant),
                            fontSize: AppTheme.subtitleFontSize,
                            height: AppTheme.lineHeightSubtitle,
                            letterSpacing: AppTheme.letterSpacingSubtitle,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      // Capabilities for models
                      if (showCapabilities && config is AiConfigModel) ...[
                        const SizedBox(height: AppTheme.spacingBetweenElements),
                        _CapabilityIndicators(
                          model: config as AiConfigModel,
                        ),
                      ],
                    ],
                  ),
                ),

                // Chevron
                Icon(
                  Icons.chevron_right,
                  size: AppTheme.chevronSize,
                  color: context.colorScheme.onSurfaceVariant
                      .withValues(alpha: AppTheme.alphaSurfaceVariantChevron),
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
        case InferenceProviderType.whisper:
          return Icons.mic;
        case InferenceProviderType.gemma:
          return Icons.auto_awesome;
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
  });

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providerAsync = ref.watch(aiConfigByIdProvider(providerId));

    return providerAsync.when(
      data: (provider) {
        final providerName = provider?.name ?? context.messages.commonUnknown;
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.statusIndicatorPaddingHorizontal,
            vertical: AppTheme.statusIndicatorPaddingVertical,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                context.colorScheme.primaryContainer
                    .withValues(alpha: AppTheme.alphaPrimaryContainerLight),
                context.colorScheme.primaryContainer
                    .withValues(alpha: AppTheme.alphaPrimaryContainerDark),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius:
                BorderRadius.circular(AppTheme.statusIndicatorBorderRadius),
            border: Border.all(
              color: context.colorScheme.primary
                  .withValues(alpha: AppTheme.alphaStatusIndicatorBorder),
              width: AppTheme.statusIndicatorBorderWidth,
            ),
          ),
          child: Text(
            providerName,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.primary
                  .withValues(alpha: AppTheme.alphaPrimaryIcon),
              fontWeight: FontWeight.w600,
              fontSize: AppTheme.statusIndicatorFontSize,
              letterSpacing: AppTheme.letterSpacingTitle,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.statusIndicatorPaddingHorizontal,
          vertical: AppTheme.statusIndicatorPaddingVertical,
        ),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerHighest
              .withValues(alpha: AppTheme.alphaSurfaceContainerHighest),
          borderRadius:
              BorderRadius.circular(AppTheme.statusIndicatorBorderRadiusSmall),
        ),
        child: Text(
          context.messages.commonLoading,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant
                .withValues(alpha: AppTheme.alphaSurfaceVariantDim),
            fontSize: AppTheme.statusIndicatorFontSizeCompact,
          ),
        ),
      ),
      error: (_, __) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.statusIndicatorPaddingHorizontal,
          vertical: AppTheme.statusIndicatorPaddingVertical,
        ),
        decoration: BoxDecoration(
          color: context.colorScheme.errorContainer
              .withValues(alpha: AppTheme.alphaErrorContainer),
          borderRadius:
              BorderRadius.circular(AppTheme.statusIndicatorBorderRadiusSmall),
        ),
        child: Text(
          context.messages.commonError,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.error
                .withValues(alpha: AppTheme.alphaErrorText),
            fontSize: AppTheme.statusIndicatorFontSizeCompact,
          ),
        ),
      ),
    );
  }
}

class _CapabilityIndicators extends StatelessWidget {
  const _CapabilityIndicators({
    required this.model,
  });

  final AiConfigModel model;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppTheme.spacingBetweenElements,
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
        // Function calling support (if applicable)
        if (model.supportsFunctionCalling)
          _buildCapabilityIcon(
            context,
            Icons.functions_rounded,
            'Function Calling',
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
        width: AppTheme.statusIndicatorSize,
        height: AppTheme.statusIndicatorSize,
        decoration: BoxDecoration(
          color: isSupported
              ? context.colorScheme.primaryContainer
                  .withValues(alpha: AppTheme.alphaPrimaryContainerActive)
              : context.colorScheme.surfaceContainerHighest
                  .withValues(alpha: AppTheme.alphaSurfaceContainerHighest),
          borderRadius:
              BorderRadius.circular(AppTheme.statusIndicatorBorderRadiusTiny),
        ),
        child: Icon(
          icon,
          size: AppTheme.statusIndicatorIconSize,
          color: isSupported
              ? context.colorScheme.primary
              : context.colorScheme.onSurfaceVariant
                  .withValues(alpha: AppTheme.alphaSurfaceVariantDim),
        ),
      ),
    );
  }
}
