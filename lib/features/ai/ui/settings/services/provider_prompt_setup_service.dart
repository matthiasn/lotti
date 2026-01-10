import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
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
    this.imageModel,
  });

  final AiConfigModel? audioModel;
  final AiConfigModel reasoningModel;
  final AiConfigModel? imageModel;
}

// =============================================================================
// FTUE (First Time User Experience) Setup
// =============================================================================

/// Result of the Gemini FTUE setup process.
class GeminiFtueResult {
  const GeminiFtueResult({
    required this.modelsCreated,
    required this.modelsVerified,
    required this.promptsCreated,
    required this.promptsSkipped,
    required this.categoryCreated,
    this.categoryName,
    this.errors = const [],
  });

  final int modelsCreated;
  final int modelsVerified;
  final int promptsCreated;
  final int promptsSkipped;
  final bool categoryCreated;
  final String? categoryName;
  final List<String> errors;

  int get totalModels => modelsCreated + modelsVerified;
  int get totalPrompts => promptsCreated + promptsSkipped;
}

/// Configuration for a prompt to create during FTUE.
class FtuePromptConfig {
  const FtuePromptConfig({
    required this.template,
    required this.modelVariant,
    required this.promptName,
  });

  final PreconfiguredPrompt template;

  /// Which model to use: 'flash', 'pro', or 'image'
  final String modelVariant;
  final String promptName;
}

/// Extension to add Gemini FTUE functionality to ProviderPromptSetupService.
extension GeminiFtueSetup on ProviderPromptSetupService {
  /// Performs comprehensive FTUE setup for Gemini providers.
  ///
  /// This creates:
  /// 1. Three models (Flash, Pro, Nano Banana Pro) if they don't exist
  /// 2. 18 prompts (Flash and Pro variants for 9 prompt types)
  /// 3. A test category with all prompts enabled and auto-selection configured
  ///
  /// Returns [GeminiFtueResult] with details of what was created.
  Future<GeminiFtueResult?> performGeminiFtueSetup({
    required BuildContext context,
    required WidgetRef ref,
    required AiConfigInferenceProvider provider,
  }) async {
    // Only works with Gemini providers
    if (provider.inferenceProviderType != InferenceProviderType.gemini) {
      return null;
    }

    final repository = ref.read(aiConfigRepositoryProvider);
    final categoryRepository = ref.read(categoryRepositoryProvider);

    // Step 1: Create/verify models
    final modelResult = await _ensureFtueModelsExist(
      repository: repository,
      providerId: provider.id,
    );

    if (modelResult == null) {
      return const GeminiFtueResult(
        modelsCreated: 0,
        modelsVerified: 0,
        promptsCreated: 0,
        promptsSkipped: 0,
        categoryCreated: false,
        errors: ['Failed to find required Gemini model configurations'],
      );
    }

    // Step 2: Create prompts
    final promptResult = await _createFtuePrompts(
      repository: repository,
      flashModel: modelResult.flash,
      proModel: modelResult.pro,
      imageModel: modelResult.image,
    );

    // Step 3: Create category with auto-selection (uses all prompts, not just created)
    final category = await _createFtueCategory(
      categoryRepository: categoryRepository,
      prompts: promptResult.allPrompts,
    );

    return GeminiFtueResult(
      modelsCreated: modelResult.created.length,
      modelsVerified: modelResult.verified.length,
      promptsCreated: promptResult.created.length,
      promptsSkipped: promptResult.skipped,
      categoryCreated: category != null,
      categoryName: category?.name,
    );
  }

  /// Ensures the three FTUE models exist for the given provider.
  Future<_FtueModelResult?> _ensureFtueModelsExist({
    required AiConfigRepository repository,
    required String providerId,
  }) async {
    final knownModels = getFtueKnownModels();
    if (knownModels == null) {
      return null;
    }

    final allModels = await repository.getConfigsByType(AiConfigType.model);
    final providerModels = allModels
        .whereType<AiConfigModel>()
        .where((m) => m.inferenceProviderId == providerId)
        .toList();

    final created = <AiConfigModel>[];
    final verified = <AiConfigModel>[];
    const uuid = Uuid();

    // Process each model type
    final modelConfigs = [
      (known: knownModels.flash, id: ftueFlashModelId),
      (known: knownModels.pro, id: ftueProModelId),
      (known: knownModels.image, id: ftueImageModelId),
    ];

    AiConfigModel? flashModel;
    AiConfigModel? proModel;
    AiConfigModel? imageModel;

    for (final config in modelConfigs) {
      // Check if model with same providerModelId already exists
      final existing = providerModels.firstWhereOrNull(
        (m) => m.providerModelId == config.id,
      );

      AiConfigModel model;
      if (existing != null) {
        verified.add(existing);
        model = existing;
      } else {
        // Create new model
        model = config.known.toAiConfigModel(
          id: uuid.v4(),
          inferenceProviderId: providerId,
        );
        await repository.saveConfig(model);
        created.add(model);
      }

      // Assign to appropriate variable
      if (config.id == ftueFlashModelId) {
        flashModel = model;
      } else if (config.id == ftueProModelId) {
        proModel = model;
      } else if (config.id == ftueImageModelId) {
        imageModel = model;
      }
    }

    if (flashModel == null || proModel == null || imageModel == null) {
      return null;
    }

    return _FtueModelResult(
      flash: flashModel,
      pro: proModel,
      image: imageModel,
      created: created,
      verified: verified,
    );
  }

  /// Creates all FTUE prompts with idempotency checks.
  /// Returns all prompts that should be in the category (both new and existing).
  Future<_FtuePromptResult> _createFtuePrompts({
    required AiConfigRepository repository,
    required AiConfigModel flashModel,
    required AiConfigModel proModel,
    required AiConfigModel imageModel,
  }) async {
    final created = <AiConfigPrompt>[];
    final allPrompts =
        <AiConfigPrompt>[]; // All prompts for category (new + existing)
    var skipped = 0;
    const uuid = Uuid();

    // Get existing prompts to check for duplicates
    final existingPrompts =
        await repository.getConfigsByType(AiConfigType.prompt);
    final existingPromptsMap = <String, AiConfigPrompt>{};
    for (final p in existingPrompts.whereType<AiConfigPrompt>()) {
      final key = '${p.preconfiguredPromptId}_${p.defaultModelId}';
      existingPromptsMap[key] = p;
    }

    // Define all prompt configurations
    final promptConfigs = _getFtuePromptConfigs();

    for (final config in promptConfigs) {
      final model = switch (config.modelVariant) {
        'flash' => flashModel,
        'pro' => proModel,
        'image' => imageModel,
        _ => flashModel,
      };

      // Check for existing prompt with same preconfiguredPromptId + modelId
      final key = '${config.template.id}_${model.id}';
      final existingPrompt = existingPromptsMap[key];
      if (existingPrompt != null) {
        // Prompt already exists, add it to allPrompts but don't recreate
        allPrompts.add(existingPrompt);
        skipped++;
        continue;
      }

      // Determine useReasoning based on model variant and prompt type
      // Flash with thinking for most tasks, Pro with reasoning, no reasoning for image gen
      final useReasoning = config.modelVariant != 'image' ||
          config.template.aiResponseType != AiResponseType.imageGeneration;

      final prompt = AiConfig.prompt(
        id: uuid.v4(),
        name: config.promptName,
        systemMessage: config.template.systemMessage,
        userMessage: config.template.userMessage,
        defaultModelId: model.id,
        modelIds: [model.id],
        createdAt: DateTime.now(),
        useReasoning: useReasoning,
        requiredInputData: config.template.requiredInputData,
        aiResponseType: config.template.aiResponseType,
        description: config.template.description,
        trackPreconfigured: true,
        preconfiguredPromptId: config.template.id,
        defaultVariables: config.template.defaultVariables,
      );

      await repository.saveConfig(prompt);
      // AiConfig.prompt() creates AiConfigPrompt
      final createdPrompt = prompt as AiConfigPrompt;
      created.add(createdPrompt);
      allPrompts.add(createdPrompt);
    }

    return _FtuePromptResult(
      created: created,
      skipped: skipped,
      allPrompts: allPrompts,
    );
  }

  /// Gets all prompt configurations for FTUE (9 types × 2 variants = 18 prompts).
  List<FtuePromptConfig> _getFtuePromptConfigs() {
    return const [
      // Audio Transcription
      FtuePromptConfig(
        template: audioTranscriptionPrompt,
        modelVariant: 'flash',
        promptName: 'Audio Transcription Gemini Flash',
      ),
      FtuePromptConfig(
        template: audioTranscriptionPrompt,
        modelVariant: 'pro',
        promptName: 'Audio Transcription Gemini Pro',
      ),

      // Audio Transcription with Task Context
      FtuePromptConfig(
        template: audioTranscriptionWithTaskContextPrompt,
        modelVariant: 'flash',
        promptName: 'Audio Transcription (Task Context) Gemini Flash',
      ),
      FtuePromptConfig(
        template: audioTranscriptionWithTaskContextPrompt,
        modelVariant: 'pro',
        promptName: 'Audio Transcription (Task Context) Gemini Pro',
      ),

      // Task Summary
      FtuePromptConfig(
        template: taskSummaryPrompt,
        modelVariant: 'flash',
        promptName: 'Task Summary Gemini Flash',
      ),
      FtuePromptConfig(
        template: taskSummaryPrompt,
        modelVariant: 'pro',
        promptName: 'Task Summary Gemini Pro',
      ),

      // Checklist Updates
      FtuePromptConfig(
        template: checklistUpdatesPrompt,
        modelVariant: 'flash',
        promptName: 'Checklist Gemini Flash',
      ),
      FtuePromptConfig(
        template: checklistUpdatesPrompt,
        modelVariant: 'pro',
        promptName: 'Checklist Gemini Pro',
      ),

      // Image Analysis
      FtuePromptConfig(
        template: imageAnalysisPrompt,
        modelVariant: 'flash',
        promptName: 'Image Analysis Gemini Flash',
      ),
      FtuePromptConfig(
        template: imageAnalysisPrompt,
        modelVariant: 'pro',
        promptName: 'Image Analysis Gemini Pro',
      ),

      // Image Analysis in Task Context
      FtuePromptConfig(
        template: imageAnalysisInTaskContextPrompt,
        modelVariant: 'flash',
        promptName: 'Image Analysis (Task Context) Gemini Flash',
      ),
      FtuePromptConfig(
        template: imageAnalysisInTaskContextPrompt,
        modelVariant: 'pro',
        promptName: 'Image Analysis (Task Context) Gemini Pro',
      ),

      // Generate Coding Prompt
      FtuePromptConfig(
        template: promptGenerationPrompt,
        modelVariant: 'flash',
        promptName: 'Coding Prompt Gemini Flash',
      ),
      FtuePromptConfig(
        template: promptGenerationPrompt,
        modelVariant: 'pro',
        promptName: 'Coding Prompt Gemini Pro',
      ),

      // Generate Image Prompt
      FtuePromptConfig(
        template: imagePromptGenerationPrompt,
        modelVariant: 'flash',
        promptName: 'Image Prompt Gemini Flash',
      ),
      FtuePromptConfig(
        template: imagePromptGenerationPrompt,
        modelVariant: 'pro',
        promptName: 'Image Prompt Gemini Pro',
      ),

      // Cover Art Generation (uses image model for Pro variant)
      FtuePromptConfig(
        template: coverArtGenerationPrompt,
        modelVariant: 'flash',
        promptName: 'Cover Art Gemini Flash',
      ),
      FtuePromptConfig(
        template: coverArtGenerationPrompt,
        modelVariant: 'image', // Uses Nano Banana Pro
        promptName: 'Cover Art Gemini Pro',
      ),
    ];
  }

  /// Creates the FTUE test category with all prompts enabled and auto-selection.
  Future<CategoryDefinition?> _createFtueCategory({
    required CategoryRepository categoryRepository,
    required List<AiConfigPrompt> prompts,
  }) async {
    const categoryName = 'Test Category Gemini Enabled';

    // Build allowedPromptIds from all created prompts
    final allowedPromptIds = prompts.map((p) => p.id).toList();

    // Build automaticPrompts map with auto-selection logic
    final automaticPrompts = _buildFtueAutomaticPrompts(prompts);

    try {
      // Create the category
      final category = await categoryRepository.createCategory(
        name: categoryName,
        color: '#4285F4', // Google Blue
      );

      // Update with prompts configuration
      final updatedCategory = category.copyWith(
        allowedPromptIds: allowedPromptIds,
        automaticPrompts: automaticPrompts,
      );

      await categoryRepository.updateCategory(updatedCategory);

      return updatedCategory;
    } catch (e) {
      // Category might already exist
      return null;
    }
  }

  /// Builds the automaticPrompts map with FTUE auto-selection logic.
  ///
  /// Auto-selection rules:
  /// - Checklist, Coding Prompt: Pro model
  /// - Image Generation: Nano Banana Pro (image model)
  /// - Everything else: Flash with thinking
  Map<AiResponseType, List<String>> _buildFtueAutomaticPrompts(
    List<AiConfigPrompt> prompts,
  ) {
    final map = <AiResponseType, List<String>>{};

    // Helper to find prompt by name suffix and response type
    String? findPromptId(String nameSuffix, AiResponseType type) {
      return prompts
          .firstWhereOrNull(
            (p) => p.name.endsWith(nameSuffix) && p.aiResponseType == type,
          )
          ?.id;
    }

    // Audio Transcription -> Flash
    final audioFlash = findPromptId(
      'Gemini Flash',
      AiResponseType.audioTranscription,
    );
    if (audioFlash != null) {
      map[AiResponseType.audioTranscription] = [audioFlash];
    }

    // Image Analysis -> Flash
    final imageFlash = findPromptId(
      'Gemini Flash',
      AiResponseType.imageAnalysis,
    );
    if (imageFlash != null) {
      map[AiResponseType.imageAnalysis] = [imageFlash];
    }

    // Task Summary -> Flash
    final summaryFlash = findPromptId(
      'Gemini Flash',
      AiResponseType.taskSummary,
    );
    if (summaryFlash != null) {
      map[AiResponseType.taskSummary] = [summaryFlash];
    }

    // Checklist Updates -> Pro (needs stronger reasoning)
    final checklistPro = findPromptId(
      'Gemini Pro',
      AiResponseType.checklistUpdates,
    );
    if (checklistPro != null) {
      map[AiResponseType.checklistUpdates] = [checklistPro];
    }

    // Prompt Generation -> Pro (code prompts need stronger reasoning)
    final promptGenPro = findPromptId(
      'Gemini Pro',
      AiResponseType.promptGeneration,
    );
    if (promptGenPro != null) {
      map[AiResponseType.promptGeneration] = [promptGenPro];
    }

    // Image Prompt Generation -> Flash
    final imagePromptFlash = findPromptId(
      'Gemini Flash',
      AiResponseType.imagePromptGeneration,
    );
    if (imagePromptFlash != null) {
      map[AiResponseType.imagePromptGeneration] = [imagePromptFlash];
    }

    // Image Generation -> Pro (uses Nano Banana Pro image model)
    final imageGenPro = findPromptId(
      'Gemini Pro',
      AiResponseType.imageGeneration,
    );
    if (imageGenPro != null) {
      map[AiResponseType.imageGeneration] = [imageGenPro];
    }

    return map;
  }
}

/// Internal result class for model creation.
class _FtueModelResult {
  const _FtueModelResult({
    required this.flash,
    required this.pro,
    required this.image,
    required this.created,
    required this.verified,
  });

  final AiConfigModel flash;
  final AiConfigModel pro;
  final AiConfigModel image;
  final List<AiConfigModel> created;
  final List<AiConfigModel> verified;
}

/// Internal result class for prompt creation.
class _FtuePromptResult {
  const _FtuePromptResult({
    required this.created,
    required this.skipped,
    required this.allPrompts,
  });

  /// Newly created prompts in this run.
  final List<AiConfigPrompt> created;

  /// Number of prompts that already existed and were skipped.
  final int skipped;

  /// All prompts that should be in the category (created + existing).
  final List<AiConfigPrompt> allPrompts;
}
