import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'provider_prompt_setup_service.g.dart';

/// Provider for [ProviderPromptSetupService].
@riverpod
ProviderPromptSetupService providerPromptSetupService(Ref ref) {
  return const ProviderPromptSetupService();
}

/// Configuration for a prompt to be created, including its template and model.
class PromptConfig {
  const PromptConfig({
    required this.template,
    required this.model,
  });

  final PreconfiguredPrompt template;
  final AiConfigModel model;
}

/// Preview information for displaying in the setup dialog.
class PromptPreviewInfo {
  const PromptPreviewInfo({
    required this.icon,
    required this.name,
    required this.modelName,
  });

  final IconData icon;
  final String name;
  final String modelName;
}

/// Service that handles automatic prompt setup after creating inference providers.
///
/// This service supports multiple provider types (Gemini, Ollama, etc.) and:
/// 1. Shows a confirmation dialog asking if they want default prompts
/// 2. Creates prompts with dynamic naming (e.g., "Task Summary - DeepSeek R1 8B")
/// 3. Associates prompts with appropriate models based on provider capabilities
/// 4. Shows a success snackbar with the number of prompts created
class ProviderPromptSetupService {
  const ProviderPromptSetupService();

  /// Provider types that support automatic prompt setup.
  static const Set<InferenceProviderType> supportedProviders = {
    InferenceProviderType.gemini,
    InferenceProviderType.ollama,
  };

  /// Shows a dialog offering to set up default prompts for supported providers.
  ///
  /// Returns true if prompts were created, false otherwise.
  Future<bool> offerPromptSetup({
    required BuildContext context,
    required WidgetRef ref,
    required AiConfigInferenceProvider provider,
  }) async {
    // Only offer for supported provider types
    if (!supportedProviders.contains(provider.inferenceProviderType)) {
      return false;
    }

    final repository = ref.read(aiConfigRepositoryProvider);
    final modelSelection = await _selectModelsForProvider(
      repository: repository,
      provider: provider,
    );

    if (modelSelection == null) {
      return false;
    }

    if (!context.mounted) return false;

    // Get the prompt configs and preview info based on provider type
    final promptConfigs = _getPromptConfigs(
      providerType: provider.inferenceProviderType,
      modelSelection: modelSelection,
    );

    final previewInfos = _getPromptPreviews(
      providerType: provider.inferenceProviderType,
      modelSelection: modelSelection,
    );

    // Show confirmation dialog
    final confirmed = await _showSetupDialog(
      context,
      providerName: _getProviderDisplayName(provider.inferenceProviderType),
      previews: previewInfos,
    );

    if (!confirmed) return false;
    if (!context.mounted) return false;

    // Create the prompts
    final promptsCreated = await _createPrompts(
      repository: repository,
      promptConfigs: promptConfigs,
    );

    if (context.mounted && promptsCreated > 0) {
      _showSuccessSnackbar(context, promptsCreated);
    }

    return promptsCreated > 0;
  }

  /// Gets the display name for a provider type.
  String _getProviderDisplayName(InferenceProviderType type) {
    return switch (type) {
      InferenceProviderType.gemini => 'Gemini',
      InferenceProviderType.ollama => 'Ollama',
      _ => 'AI Provider',
    };
  }

  /// Selects the appropriate models for the provider based on its type.
  Future<_ModelSelection?> _selectModelsForProvider({
    required AiConfigRepository repository,
    required AiConfigInferenceProvider provider,
  }) async {
    final allConfigs = await repository.getConfigsByType(AiConfigType.model);
    final providerModels = allConfigs
        .whereType<AiConfigModel>()
        .where((model) => model.inferenceProviderId == provider.id)
        .toList();

    if (providerModels.isEmpty) {
      return null;
    }

    return switch (provider.inferenceProviderType) {
      InferenceProviderType.gemini => _selectGeminiModels(providerModels),
      InferenceProviderType.ollama => _selectOllamaModels(providerModels),
      _ => null,
    };
  }

  /// Selects Flash and Pro models for Gemini provider.
  _ModelSelection _selectGeminiModels(List<AiConfigModel> models) {
    // Find Flash model (for audio - fast processing)
    final flashModel = models.firstWhere(
      (m) =>
          m.name.toLowerCase().contains('flash') &&
          m.inputModalities.contains(Modality.audio),
      orElse: () => models.first,
    );

    // Find Pro model (for reasoning tasks)
    final proModel = models.firstWhere(
      (m) => m.name.toLowerCase().contains('pro'),
      orElse: () => models.firstWhere(
        (m) => !m.name.toLowerCase().contains('flash'),
        orElse: () => models.first,
      ),
    );

    return _ModelSelection(
      audioModel: flashModel,
      reasoningModel: proModel,
      imageModel: proModel,
    );
  }

  /// Selects DeepSeek R1 8B for text tasks and Gemma 3 12B for image tasks.
  _ModelSelection _selectOllamaModels(List<AiConfigModel> models) {
    // Find DeepSeek R1 8B for reasoning/text tasks
    final reasoningModel = models.firstWhere(
      (m) =>
          m.name.toLowerCase().contains('deepseek') &&
          m.supportsFunctionCalling,
      orElse: () => models.firstWhere(
        (m) => m.supportsFunctionCalling,
        orElse: () => models.first,
      ),
    );

    // Find Gemma 3 12B for image analysis
    final imageModel = models.firstWhereOrNull(
          (m) =>
              m.name.toLowerCase().contains('gemma') &&
              m.name.contains('12') &&
              m.inputModalities.contains(Modality.image),
        ) ??
        models.firstWhereOrNull(
          (m) => m.inputModalities.contains(Modality.image),
        );

    return _ModelSelection(
      audioModel: null, // Ollama models don't support audio
      reasoningModel: reasoningModel,
      imageModel: imageModel,
    );
  }

  /// Gets the prompt configurations based on provider type.
  List<PromptConfig> _getPromptConfigs({
    required InferenceProviderType providerType,
    required _ModelSelection modelSelection,
  }) {
    return switch (providerType) {
      InferenceProviderType.gemini => [
          if (modelSelection.audioModel != null)
            PromptConfig(
              template: audioTranscriptionPrompt,
              model: modelSelection.audioModel!,
            ),
          if (modelSelection.imageModel != null)
            PromptConfig(
              template: imageAnalysisInTaskContextPrompt,
              model: modelSelection.imageModel!,
            ),
          PromptConfig(
            template: checklistUpdatesPrompt,
            model: modelSelection.reasoningModel,
          ),
          PromptConfig(
            template: taskSummaryPrompt,
            model: modelSelection.reasoningModel,
          ),
        ],
      InferenceProviderType.ollama => [
          if (modelSelection.imageModel != null)
            PromptConfig(
              template: imageAnalysisInTaskContextPrompt,
              model: modelSelection.imageModel!,
            ),
          PromptConfig(
            template: checklistUpdatesPrompt,
            model: modelSelection.reasoningModel,
          ),
          PromptConfig(
            template: taskSummaryPrompt,
            model: modelSelection.reasoningModel,
          ),
        ],
      _ => [],
    };
  }

  /// Gets preview information for the setup dialog.
  List<PromptPreviewInfo> _getPromptPreviews({
    required InferenceProviderType providerType,
    required _ModelSelection modelSelection,
  }) {
    return switch (providerType) {
      InferenceProviderType.gemini => [
          if (modelSelection.audioModel != null)
            PromptPreviewInfo(
              icon: Icons.mic,
              name: 'Audio Transcript',
              modelName: modelSelection.audioModel!.name,
            ),
          if (modelSelection.imageModel != null)
            PromptPreviewInfo(
              icon: Icons.image,
              name: 'Image Analysis',
              modelName: modelSelection.imageModel!.name,
            ),
          PromptPreviewInfo(
            icon: Icons.checklist,
            name: 'Checklist Updates',
            modelName: modelSelection.reasoningModel.name,
          ),
          PromptPreviewInfo(
            icon: Icons.summarize,
            name: 'Task Summary',
            modelName: modelSelection.reasoningModel.name,
          ),
        ],
      InferenceProviderType.ollama => [
          if (modelSelection.imageModel != null)
            PromptPreviewInfo(
              icon: Icons.image,
              name: 'Image Analysis',
              modelName: modelSelection.imageModel!.name,
            ),
          PromptPreviewInfo(
            icon: Icons.checklist,
            name: 'Checklist Updates',
            modelName: modelSelection.reasoningModel.name,
          ),
          PromptPreviewInfo(
            icon: Icons.summarize,
            name: 'Task Summary',
            modelName: modelSelection.reasoningModel.name,
          ),
        ],
      _ => [],
    };
  }

  /// Shows the confirmation dialog for setting up prompts.
  Future<bool> _showSetupDialog(
    BuildContext context, {
    required String providerName,
    required List<PromptPreviewInfo> previews,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
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
                    'Set Up Default Prompts?',
                    style: context.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info message
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.colorScheme.primaryContainer
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            context.colorScheme.primary.withValues(alpha: 0.2),
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
                          "We'll create ready-to-use prompts for common AI tasks, "
                          'so you can start using AI features right away.',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colorScheme.onPrimaryContainer
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Prompts that will be created
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            context.colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Prompts to create:',
                          style: context.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...previews.map(
                          (preview) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildPromptPreview(
                              context,
                              preview.icon,
                              preview.name,
                              preview.modelName,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                label: 'Set Up Prompts',
                icon: Icons.auto_awesome,
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildPromptPreview(
    BuildContext context,
    IconData icon,
    String name,
    String modelHint,
  ) {
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
                name,
                style: context.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Uses $modelHint',
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

  /// Creates the prompts using the provided configurations.
  Future<int> _createPrompts({
    required AiConfigRepository repository,
    required List<PromptConfig> promptConfigs,
  }) async {
    var promptsCreated = 0;
    const uuid = Uuid();

    for (final config in promptConfigs) {
      final prompt = AiConfig.prompt(
        id: uuid.v4(),
        name: '${config.template.name} - ${config.model.name}',
        systemMessage: config.template.systemMessage,
        userMessage: config.template.userMessage,
        defaultModelId: config.model.id,
        modelIds: [config.model.id],
        createdAt: DateTime.now(),
        useReasoning: config.template.useReasoning,
        requiredInputData: config.template.requiredInputData,
        aiResponseType: config.template.aiResponseType,
        description: config.template.description,
        trackPreconfigured: true,
        preconfiguredPromptId: config.template.id,
        defaultVariables: config.template.defaultVariables,
      );

      await repository.saveConfig(prompt);
      promptsCreated++;
    }

    return promptsCreated;
  }

  /// Shows a success snackbar after prompts are created.
  void _showSuccessSnackbar(BuildContext context, int promptsCreated) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: context.colorScheme.inversePrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        duration: const Duration(seconds: 5),
        dismissDirection: DismissDirection.down,
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: context.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.check_circle,
                color: context.colorScheme.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$promptsCreated ${promptsCreated == 1 ? 'prompt' : 'prompts'} created successfully!',
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Internal class to hold the selected models for prompt creation.
class _ModelSelection {
  const _ModelSelection({
    required this.audioModel,
    required this.reasoningModel,
    required this.imageModel,
  });

  final AiConfigModel? audioModel;
  final AiConfigModel reasoningModel;
  final AiConfigModel? imageModel;
}
