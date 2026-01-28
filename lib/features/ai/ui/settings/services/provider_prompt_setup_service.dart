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
    InferenceProviderType.openAi,
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
      InferenceProviderType.openAi => 'OpenAI',
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
    this.categoryUpdated = false,
    this.categoryName,
    this.errors = const [],
  });

  final int modelsCreated;
  final int modelsVerified;
  final int promptsCreated;
  final int promptsSkipped;
  final bool categoryCreated;
  final bool categoryUpdated;
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

    // Step 3: Create or update category with auto-selection (uses all prompts)
    final (category, categoryWasCreated) = await _createOrUpdateFtueCategory(
      categoryRepository: categoryRepository,
      prompts: promptResult.allPrompts,
      flashModelId: modelResult.flash.id,
      proModelId: modelResult.pro.id,
      imageModelId: modelResult.image.id,
    );

    return GeminiFtueResult(
      modelsCreated: modelResult.created.length,
      modelsVerified: modelResult.verified.length,
      promptsCreated: promptResult.created.length,
      promptsSkipped: promptResult.skipped,
      categoryCreated: categoryWasCreated,
      categoryUpdated: !categoryWasCreated && category != null,
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

      // Enable reasoning/thinking for all models
      // All Gemini 3 models support thinking mode, including Nano Banana Pro for image generation
      const useReasoning = true;

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

  /// Gets all prompt configurations for FTUE.
  ///
  /// Model assignments:
  /// - Gemini Pro: Cover Art, Coding, Image Prompts, Checklists (complex reasoning)
  /// - Gemini Flash: All other text prompts (fast processing)
  /// - Nano Banana Pro: Image generation (cover art output)
  List<FtuePromptConfig> _getFtuePromptConfigs() {
    return const [
      // Audio Transcription -> Flash (fast processing)
      FtuePromptConfig(
        template: audioTranscriptionPrompt,
        modelVariant: 'flash',
        promptName: 'Audio Transcription Gemini Flash',
      ),

      // Audio Transcription with Task Context -> Flash (fast processing)
      FtuePromptConfig(
        template: audioTranscriptionWithTaskContextPrompt,
        modelVariant: 'flash',
        promptName: 'Audio Transcription (Task Context) Gemini Flash',
      ),

      // Task Summary -> Flash (fast processing)
      FtuePromptConfig(
        template: taskSummaryPrompt,
        modelVariant: 'flash',
        promptName: 'Task Summary Gemini Flash',
      ),

      // Checklist Updates -> Pro (complex reasoning needed)
      FtuePromptConfig(
        template: checklistUpdatesPrompt,
        modelVariant: 'pro',
        promptName: 'Checklist Gemini Pro',
      ),

      // Image Analysis -> Flash (fast processing)
      FtuePromptConfig(
        template: imageAnalysisPrompt,
        modelVariant: 'flash',
        promptName: 'Image Analysis Gemini Flash',
      ),

      // Image Analysis in Task Context -> Flash (fast processing)
      FtuePromptConfig(
        template: imageAnalysisInTaskContextPrompt,
        modelVariant: 'flash',
        promptName: 'Image Analysis (Task Context) Gemini Flash',
      ),

      // Generate Coding Prompt -> Pro (complex reasoning needed)
      FtuePromptConfig(
        template: promptGenerationPrompt,
        modelVariant: 'pro',
        promptName: 'Coding Prompt Gemini Pro',
      ),

      // Generate Image Prompt -> Pro (complex reasoning needed)
      FtuePromptConfig(
        template: imagePromptGenerationPrompt,
        modelVariant: 'pro',
        promptName: 'Image Prompt Gemini Pro',
      ),

      // Cover Art Generation -> Nano Banana Pro (image generation model)
      FtuePromptConfig(
        template: coverArtGenerationPrompt,
        modelVariant: 'image', // Uses Nano Banana Pro for image generation
        promptName: 'Cover Art Nano Banana Pro',
      ),
    ];
  }

  /// Creates or updates the FTUE test category with all prompts enabled and auto-selection.
  ///
  /// If the category already exists, it will be updated with the new prompts.
  /// Returns a tuple of (category, wasCreated) where wasCreated is true if
  /// a new category was created, false if an existing one was updated.
  Future<(CategoryDefinition?, bool)> _createOrUpdateFtueCategory({
    required CategoryRepository categoryRepository,
    required List<AiConfigPrompt> prompts,
    required String flashModelId,
    required String proModelId,
    required String imageModelId,
  }) async {
    const categoryName = ftueGeminiCategoryName;

    // Build allowedPromptIds from all created prompts
    final allowedPromptIds = prompts.map((p) => p.id).toList();

    // Build automaticPrompts map with auto-selection logic
    final automaticPrompts = _buildFtueAutomaticPrompts(
      prompts,
      flashModelId: flashModelId,
      proModelId: proModelId,
      imageModelId: imageModelId,
    );

    // Check if category already exists
    final allCategories = await categoryRepository.getAllCategories();
    final existingCategory = allCategories
        .where((c) => c.name == categoryName && c.deletedAt == null)
        .firstOrNull;

    if (existingCategory != null) {
      // Update existing category with new prompts
      final updatedCategory = existingCategory.copyWith(
        allowedPromptIds: allowedPromptIds,
        automaticPrompts: automaticPrompts,
      );

      await categoryRepository.updateCategory(updatedCategory);
      return (updatedCategory, false); // false = was updated, not created
    }

    // Create new category
    final category = await categoryRepository.createCategory(
      name: categoryName,
      color: ftueGeminiCategoryColor,
    );

    // Update with prompts configuration
    final updatedCategory = category.copyWith(
      allowedPromptIds: allowedPromptIds,
      automaticPrompts: automaticPrompts,
    );

    await categoryRepository.updateCategory(updatedCategory);

    return (updatedCategory, true); // true = was created
  }

  /// Builds the automaticPrompts map with FTUE auto-selection logic.
  ///
  /// Uses stable identifiers (preconfiguredPromptId + modelId) for matching
  /// instead of fragile name-based matching.
  ///
  /// Auto-selection rules:
  /// - Checklist, Coding Prompt, Image Prompt: Pro model (complex reasoning)
  /// - Image Generation: Nano Banana Pro (image model with reasoning enabled)
  /// - Everything else: Flash (fast processing)
  Map<AiResponseType, List<String>> _buildFtueAutomaticPrompts(
    List<AiConfigPrompt> prompts, {
    required String flashModelId,
    required String proModelId,
    required String imageModelId,
  }) {
    final map = <AiResponseType, List<String>>{};

    // Helper to find prompt by preconfiguredPromptId + modelId
    // This is more stable than name-based matching
    String? findPromptId(String preconfiguredId, String modelId) {
      return prompts
          .firstWhereOrNull(
            (p) =>
                p.preconfiguredPromptId == preconfiguredId &&
                p.defaultModelId == modelId,
          )
          ?.id;
    }

    // Audio Transcription -> Flash (fast processing)
    final audioFlash = findPromptId('audio_transcription', flashModelId);
    if (audioFlash != null) {
      map[AiResponseType.audioTranscription] = [audioFlash];
    }

    // Image Analysis (task context) -> Flash (fast processing)
    final imageFlash =
        findPromptId('image_analysis_task_context', flashModelId);
    if (imageFlash != null) {
      map[AiResponseType.imageAnalysis] = [imageFlash];
    }

    // Task Summary -> Flash (fast processing)
    final summaryFlash = findPromptId('task_summary', flashModelId);
    if (summaryFlash != null) {
      map[AiResponseType.taskSummary] = [summaryFlash];
    }

    // Checklist Updates -> Pro (complex reasoning needed)
    final checklistPro = findPromptId('checklist_updates', proModelId);
    if (checklistPro != null) {
      map[AiResponseType.checklistUpdates] = [checklistPro];
    }

    // Prompt Generation -> Pro (complex reasoning needed for code prompts)
    final promptGenPro = findPromptId('prompt_generation', proModelId);
    if (promptGenPro != null) {
      map[AiResponseType.promptGeneration] = [promptGenPro];
    }

    // Image Prompt Generation -> Pro (complex reasoning needed)
    final imagePromptPro = findPromptId('image_prompt_generation', proModelId);
    if (imagePromptPro != null) {
      map[AiResponseType.imagePromptGeneration] = [imagePromptPro];
    }

    // Image Generation -> Nano Banana Pro (image model with reasoning enabled)
    final imageGenImage = findPromptId('cover_art_generation', imageModelId);
    if (imageGenImage != null) {
      map[AiResponseType.imageGeneration] = [imageGenImage];
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

// =============================================================================
// OpenAI FTUE (First Time User Experience) Setup
// =============================================================================

/// Result of the OpenAI FTUE setup process.
class OpenAiFtueResult {
  const OpenAiFtueResult({
    required this.modelsCreated,
    required this.modelsVerified,
    required this.promptsCreated,
    required this.promptsSkipped,
    required this.categoryCreated,
    this.categoryUpdated = false,
    this.categoryName,
    this.errors = const [],
  });

  final int modelsCreated;
  final int modelsVerified;
  final int promptsCreated;
  final int promptsSkipped;
  final bool categoryCreated;
  final bool categoryUpdated;
  final String? categoryName;
  final List<String> errors;

  int get totalModels => modelsCreated + modelsVerified;
  int get totalPrompts => promptsCreated + promptsSkipped;
}

/// Extension to add OpenAI FTUE functionality to ProviderPromptSetupService.
extension OpenAiFtueSetup on ProviderPromptSetupService {
  /// Performs comprehensive FTUE setup for OpenAI providers.
  ///
  /// This creates:
  /// 1. Four models (Flash/GPT-5 Nano, Reasoning/GPT-5.2, Audio/GPT-4o Transcribe, Image/GPT Image 1.5)
  /// 2. 9 prompts with appropriate model assignments
  /// 3. A test category with all prompts enabled and auto-selection configured
  ///
  /// Returns [OpenAiFtueResult] with details of what was created.
  Future<OpenAiFtueResult?> performOpenAiFtueSetup({
    required BuildContext context,
    required WidgetRef ref,
    required AiConfigInferenceProvider provider,
  }) async {
    // Only works with OpenAI providers
    if (provider.inferenceProviderType != InferenceProviderType.openAi) {
      return null;
    }

    final repository = ref.read(aiConfigRepositoryProvider);
    final categoryRepository = ref.read(categoryRepositoryProvider);

    // Step 1: Create/verify models
    final modelResult = await _ensureOpenAiFtueModelsExist(
      repository: repository,
      providerId: provider.id,
    );

    if (modelResult == null) {
      return const OpenAiFtueResult(
        modelsCreated: 0,
        modelsVerified: 0,
        promptsCreated: 0,
        promptsSkipped: 0,
        categoryCreated: false,
        errors: ['Failed to find required OpenAI model configurations'],
      );
    }

    // Step 2: Create prompts
    final promptResult = await _createOpenAiFtuePrompts(
      repository: repository,
      flashModel: modelResult.flash,
      reasoningModel: modelResult.reasoning,
      audioModel: modelResult.audio,
      imageModel: modelResult.image,
    );

    // Step 3: Create or update category with auto-selection
    final (category, categoryWasCreated) =
        await _createOrUpdateOpenAiFtueCategory(
      categoryRepository: categoryRepository,
      prompts: promptResult.allPrompts,
      flashModelId: modelResult.flash.id,
      reasoningModelId: modelResult.reasoning.id,
      audioModelId: modelResult.audio.id,
      imageModelId: modelResult.image.id,
    );

    return OpenAiFtueResult(
      modelsCreated: modelResult.created.length,
      modelsVerified: modelResult.verified.length,
      promptsCreated: promptResult.created.length,
      promptsSkipped: promptResult.skipped,
      categoryCreated: categoryWasCreated,
      categoryUpdated: !categoryWasCreated && category != null,
      categoryName: category?.name,
    );
  }

  /// Ensures the four FTUE models exist for the given OpenAI provider.
  Future<_OpenAiFtueModelResult?> _ensureOpenAiFtueModelsExist({
    required AiConfigRepository repository,
    required String providerId,
  }) async {
    final knownModels = getOpenAiFtueKnownModels();
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
      (known: knownModels.flash, id: ftueOpenAiFlashModelId),
      (known: knownModels.reasoning, id: ftueOpenAiReasoningModelId),
      (known: knownModels.audio, id: ftueOpenAiAudioModelId),
      (known: knownModels.image, id: ftueOpenAiImageModelId),
    ];

    AiConfigModel? flashModel;
    AiConfigModel? reasoningModel;
    AiConfigModel? audioModel;
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
      if (config.id == ftueOpenAiFlashModelId) {
        flashModel = model;
      } else if (config.id == ftueOpenAiReasoningModelId) {
        reasoningModel = model;
      } else if (config.id == ftueOpenAiAudioModelId) {
        audioModel = model;
      } else if (config.id == ftueOpenAiImageModelId) {
        imageModel = model;
      }
    }

    if (flashModel == null ||
        reasoningModel == null ||
        audioModel == null ||
        imageModel == null) {
      return null;
    }

    return _OpenAiFtueModelResult(
      flash: flashModel,
      reasoning: reasoningModel,
      audio: audioModel,
      image: imageModel,
      created: created,
      verified: verified,
    );
  }

  /// Creates all FTUE prompts for OpenAI with idempotency checks.
  Future<_FtuePromptResult> _createOpenAiFtuePrompts({
    required AiConfigRepository repository,
    required AiConfigModel flashModel,
    required AiConfigModel reasoningModel,
    required AiConfigModel audioModel,
    required AiConfigModel imageModel,
  }) async {
    final created = <AiConfigPrompt>[];
    final allPrompts = <AiConfigPrompt>[];
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

    // Define all prompt configurations for OpenAI
    final promptConfigs = _getOpenAiFtuePromptConfigs();

    for (final config in promptConfigs) {
      final model = switch (config.modelVariant) {
        'flash' => flashModel,
        'reasoning' => reasoningModel,
        'audio' => audioModel,
        'image' => imageModel,
        _ => flashModel,
      };

      // Check for existing prompt with same preconfiguredPromptId + modelId
      final key = '${config.template.id}_${model.id}';
      final existingPrompt = existingPromptsMap[key];
      if (existingPrompt != null) {
        allPrompts.add(existingPrompt);
        skipped++;
        continue;
      }

      // OpenAI GPT-5 models (GPT-5.2, GPT-5 Nano) support reasoning mode
      final useReasoning =
          config.modelVariant == 'reasoning' || config.modelVariant == 'flash';

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

  /// Gets all prompt configurations for OpenAI FTUE.
  ///
  /// Model assignments:
  /// - GPT-5.2 (Reasoning): Checklists, Coding Prompt, Image Prompt (complex reasoning)
  /// - GPT-5 Nano (Flash): Task Summary, Image Analysis (fast processing)
  /// - GPT-4o Transcribe: Audio transcription tasks
  /// - GPT Image 1.5: Image generation (cover art output)
  List<FtuePromptConfig> _getOpenAiFtuePromptConfigs() {
    return const [
      // Audio Transcription -> Audio model (dedicated transcription)
      FtuePromptConfig(
        template: audioTranscriptionPrompt,
        modelVariant: 'audio',
        promptName: 'Audio Transcription OpenAI',
      ),

      // Audio Transcription with Task Context -> Audio model
      FtuePromptConfig(
        template: audioTranscriptionWithTaskContextPrompt,
        modelVariant: 'audio',
        promptName: 'Audio Transcription (Task Context) OpenAI',
      ),

      // Task Summary -> Flash (fast processing)
      FtuePromptConfig(
        template: taskSummaryPrompt,
        modelVariant: 'flash',
        promptName: 'Task Summary OpenAI GPT-5 Nano',
      ),

      // Checklist Updates -> Reasoning (complex reasoning needed)
      FtuePromptConfig(
        template: checklistUpdatesPrompt,
        modelVariant: 'reasoning',
        promptName: 'Checklist OpenAI GPT-5.2',
      ),

      // Image Analysis -> Flash (fast processing)
      FtuePromptConfig(
        template: imageAnalysisPrompt,
        modelVariant: 'flash',
        promptName: 'Image Analysis OpenAI GPT-5 Nano',
      ),

      // Image Analysis in Task Context -> Flash (fast processing)
      FtuePromptConfig(
        template: imageAnalysisInTaskContextPrompt,
        modelVariant: 'flash',
        promptName: 'Image Analysis (Task Context) OpenAI GPT-5 Nano',
      ),

      // Generate Coding Prompt -> Reasoning (complex reasoning needed)
      FtuePromptConfig(
        template: promptGenerationPrompt,
        modelVariant: 'reasoning',
        promptName: 'Coding Prompt OpenAI GPT-5.2',
      ),

      // Generate Image Prompt -> Reasoning (complex reasoning needed)
      FtuePromptConfig(
        template: imagePromptGenerationPrompt,
        modelVariant: 'reasoning',
        promptName: 'Image Prompt OpenAI GPT-5.2',
      ),

      // Cover Art Generation -> Image model (image generation)
      FtuePromptConfig(
        template: coverArtGenerationPrompt,
        modelVariant: 'image',
        promptName: 'Cover Art OpenAI GPT Image 1.5',
      ),
    ];
  }

  /// Creates or updates the FTUE test category for OpenAI.
  Future<(CategoryDefinition?, bool)> _createOrUpdateOpenAiFtueCategory({
    required CategoryRepository categoryRepository,
    required List<AiConfigPrompt> prompts,
    required String flashModelId,
    required String reasoningModelId,
    required String audioModelId,
    required String imageModelId,
  }) async {
    const categoryName = ftueOpenAiCategoryName;

    // Build allowedPromptIds from all created prompts
    final allowedPromptIds = prompts.map((p) => p.id).toList();

    // Build automaticPrompts map with auto-selection logic
    final automaticPrompts = _buildOpenAiFtueAutomaticPrompts(
      prompts,
      flashModelId: flashModelId,
      reasoningModelId: reasoningModelId,
      audioModelId: audioModelId,
      imageModelId: imageModelId,
    );

    // Check if category already exists
    final allCategories = await categoryRepository.getAllCategories();
    final existingCategory = allCategories
        .where((c) => c.name == categoryName && c.deletedAt == null)
        .firstOrNull;

    if (existingCategory != null) {
      // Update existing category with new prompts
      final updatedCategory = existingCategory.copyWith(
        allowedPromptIds: allowedPromptIds,
        automaticPrompts: automaticPrompts,
      );

      await categoryRepository.updateCategory(updatedCategory);
      return (updatedCategory, false);
    }

    // Create new category
    final category = await categoryRepository.createCategory(
      name: categoryName,
      color: ftueOpenAiCategoryColor,
    );

    // Update with prompts configuration
    final updatedCategory = category.copyWith(
      allowedPromptIds: allowedPromptIds,
      automaticPrompts: automaticPrompts,
    );

    await categoryRepository.updateCategory(updatedCategory);

    return (updatedCategory, true);
  }

  /// Builds the automaticPrompts map for OpenAI FTUE auto-selection.
  Map<AiResponseType, List<String>> _buildOpenAiFtueAutomaticPrompts(
    List<AiConfigPrompt> prompts, {
    required String flashModelId,
    required String reasoningModelId,
    required String audioModelId,
    required String imageModelId,
  }) {
    final map = <AiResponseType, List<String>>{};

    String? findPromptId(String preconfiguredId, String modelId) {
      return prompts
          .firstWhereOrNull(
            (p) =>
                p.preconfiguredPromptId == preconfiguredId &&
                p.defaultModelId == modelId,
          )
          ?.id;
    }

    // Audio Transcription -> Audio model
    final audioTranscript = findPromptId('audio_transcription', audioModelId);
    if (audioTranscript != null) {
      map[AiResponseType.audioTranscription] = [audioTranscript];
    }

    // Image Analysis (task context) -> Flash (fast processing)
    final imageAnalysis =
        findPromptId('image_analysis_task_context', flashModelId);
    if (imageAnalysis != null) {
      map[AiResponseType.imageAnalysis] = [imageAnalysis];
    }

    // Task Summary -> Flash (fast processing)
    final taskSummary = findPromptId('task_summary', flashModelId);
    if (taskSummary != null) {
      map[AiResponseType.taskSummary] = [taskSummary];
    }

    // Checklist Updates -> Reasoning (complex reasoning needed)
    final checklist = findPromptId('checklist_updates', reasoningModelId);
    if (checklist != null) {
      map[AiResponseType.checklistUpdates] = [checklist];
    }

    // Prompt Generation -> Reasoning (complex reasoning needed)
    final promptGen = findPromptId('prompt_generation', reasoningModelId);
    if (promptGen != null) {
      map[AiResponseType.promptGeneration] = [promptGen];
    }

    // Image Prompt Generation -> Reasoning (complex reasoning needed)
    final imagePrompt =
        findPromptId('image_prompt_generation', reasoningModelId);
    if (imagePrompt != null) {
      map[AiResponseType.imagePromptGeneration] = [imagePrompt];
    }

    // Image Generation -> Image model
    final imageGen = findPromptId('cover_art_generation', imageModelId);
    if (imageGen != null) {
      map[AiResponseType.imageGeneration] = [imageGen];
    }

    return map;
  }
}

/// Internal result class for OpenAI model creation.
class _OpenAiFtueModelResult {
  const _OpenAiFtueModelResult({
    required this.flash,
    required this.reasoning,
    required this.audio,
    required this.image,
    required this.created,
    required this.verified,
  });

  final AiConfigModel flash;
  final AiConfigModel reasoning;
  final AiConfigModel audio;
  final AiConfigModel image;
  final List<AiConfigModel> created;
  final List<AiConfigModel> verified;
}

// =============================================================================
// Mistral FTUE (First Time User Experience) Setup
// =============================================================================

/// Result of the Mistral FTUE setup process.
class MistralFtueResult {
  const MistralFtueResult({
    required this.modelsCreated,
    required this.modelsVerified,
    required this.promptsCreated,
    required this.promptsSkipped,
    required this.categoryCreated,
    this.categoryUpdated = false,
    this.categoryName,
    this.errors = const [],
  });

  final int modelsCreated;
  final int modelsVerified;
  final int promptsCreated;
  final int promptsSkipped;
  final bool categoryCreated;
  final bool categoryUpdated;
  final String? categoryName;
  final List<String> errors;

  int get totalModels => modelsCreated + modelsVerified;
  int get totalPrompts => promptsCreated + promptsSkipped;
}

/// Extension to add Mistral FTUE functionality to ProviderPromptSetupService.
extension MistralFtueSetup on ProviderPromptSetupService {
  /// Performs comprehensive FTUE setup for Mistral providers.
  ///
  /// This creates:
  /// 1. Three models (Fast/Mistral Small, Reasoning/Magistral Medium, Audio/Voxtral Small)
  /// 2. 8 prompts with appropriate model assignments (no image generation)
  /// 3. A test category with all prompts enabled and auto-selection configured
  ///
  /// Returns [MistralFtueResult] with details of what was created.
  Future<MistralFtueResult?> performMistralFtueSetup({
    required BuildContext context,
    required WidgetRef ref,
    required AiConfigInferenceProvider provider,
  }) async {
    // Only works with Mistral providers
    if (provider.inferenceProviderType != InferenceProviderType.mistral) {
      return null;
    }

    final repository = ref.read(aiConfigRepositoryProvider);
    final categoryRepository = ref.read(categoryRepositoryProvider);

    // Step 1: Create/verify models
    final modelResult = await _ensureMistralFtueModelsExist(
      repository: repository,
      providerId: provider.id,
    );

    if (modelResult == null) {
      return const MistralFtueResult(
        modelsCreated: 0,
        modelsVerified: 0,
        promptsCreated: 0,
        promptsSkipped: 0,
        categoryCreated: false,
        errors: ['Failed to find required Mistral model configurations'],
      );
    }

    // Step 2: Create prompts
    final promptResult = await _createMistralFtuePrompts(
      repository: repository,
      flashModel: modelResult.flash,
      reasoningModel: modelResult.reasoning,
      audioModel: modelResult.audio,
    );

    // Step 3: Create or update category with auto-selection
    final (category, categoryWasCreated) =
        await _createOrUpdateMistralFtueCategory(
      categoryRepository: categoryRepository,
      prompts: promptResult.allPrompts,
      flashModelId: modelResult.flash.id,
      reasoningModelId: modelResult.reasoning.id,
      audioModelId: modelResult.audio.id,
    );

    return MistralFtueResult(
      modelsCreated: modelResult.created.length,
      modelsVerified: modelResult.verified.length,
      promptsCreated: promptResult.created.length,
      promptsSkipped: promptResult.skipped,
      categoryCreated: categoryWasCreated,
      categoryUpdated: !categoryWasCreated && category != null,
      categoryName: category?.name,
    );
  }

  /// Ensures the three FTUE models exist for the given Mistral provider.
  Future<_MistralFtueModelResult?> _ensureMistralFtueModelsExist({
    required AiConfigRepository repository,
    required String providerId,
  }) async {
    final knownModels = getMistralFtueKnownModels();
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
      (known: knownModels.flash, id: ftueMistralFlashModelId),
      (known: knownModels.reasoning, id: ftueMistralReasoningModelId),
      (known: knownModels.audio, id: ftueMistralAudioModelId),
    ];

    AiConfigModel? flashModel;
    AiConfigModel? reasoningModel;
    AiConfigModel? audioModel;

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
      switch (config.id) {
        case ftueMistralFlashModelId:
          flashModel = model;
        case ftueMistralReasoningModelId:
          reasoningModel = model;
        case ftueMistralAudioModelId:
          audioModel = model;
      }
    }

    if (flashModel == null || reasoningModel == null || audioModel == null) {
      return null;
    }

    return _MistralFtueModelResult(
      flash: flashModel,
      reasoning: reasoningModel,
      audio: audioModel,
      created: created,
      verified: verified,
    );
  }

  /// Creates all FTUE prompts for Mistral with idempotency checks.
  Future<_FtuePromptResult> _createMistralFtuePrompts({
    required AiConfigRepository repository,
    required AiConfigModel flashModel,
    required AiConfigModel reasoningModel,
    required AiConfigModel audioModel,
  }) async {
    final created = <AiConfigPrompt>[];
    final allPrompts = <AiConfigPrompt>[];
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

    // Define all prompt configurations for Mistral
    final promptConfigs = _getMistralFtuePromptConfigs();

    for (final config in promptConfigs) {
      final model = switch (config.modelVariant) {
        'flash' => flashModel,
        'reasoning' => reasoningModel,
        'audio' => audioModel,
        _ => flashModel,
      };

      // Check for existing prompt with same preconfiguredPromptId + modelId
      final key = '${config.template.id}_${model.id}';
      final existingPrompt = existingPromptsMap[key];
      if (existingPrompt != null) {
        allPrompts.add(existingPrompt);
        skipped++;
        continue;
      }

      // Magistral reasoning model supports reasoning mode
      final useReasoning = config.modelVariant == 'reasoning';

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

  /// Gets all prompt configurations for Mistral FTUE.
  ///
  /// Model assignments:
  /// - Magistral Medium (Reasoning): Checklists, Coding Prompt, Image Prompt (complex reasoning)
  /// - Mistral Small (Flash): Task Summary, Image Analysis (fast processing)
  /// - Voxtral Small (Audio): Audio transcription tasks
  /// Note: No image generation model available for Mistral
  List<FtuePromptConfig> _getMistralFtuePromptConfigs() {
    return const [
      // Audio Transcription -> Audio model (dedicated transcription)
      FtuePromptConfig(
        template: audioTranscriptionPrompt,
        modelVariant: 'audio',
        promptName: 'Audio Transcription Mistral Voxtral',
      ),

      // Audio Transcription with Task Context -> Audio model
      FtuePromptConfig(
        template: audioTranscriptionWithTaskContextPrompt,
        modelVariant: 'audio',
        promptName: 'Audio Transcription (Task Context) Mistral Voxtral',
      ),

      // Task Summary -> Flash (fast processing)
      FtuePromptConfig(
        template: taskSummaryPrompt,
        modelVariant: 'flash',
        promptName: 'Task Summary Mistral Small',
      ),

      // Checklist Updates -> Reasoning (complex reasoning needed)
      FtuePromptConfig(
        template: checklistUpdatesPrompt,
        modelVariant: 'reasoning',
        promptName: 'Checklist Mistral Magistral',
      ),

      // Image Analysis -> Flash (fast processing with vision)
      FtuePromptConfig(
        template: imageAnalysisPrompt,
        modelVariant: 'flash',
        promptName: 'Image Analysis Mistral Small',
      ),

      // Image Analysis in Task Context -> Flash (fast processing)
      FtuePromptConfig(
        template: imageAnalysisInTaskContextPrompt,
        modelVariant: 'flash',
        promptName: 'Image Analysis (Task Context) Mistral Small',
      ),

      // Generate Coding Prompt -> Reasoning (complex reasoning needed)
      FtuePromptConfig(
        template: promptGenerationPrompt,
        modelVariant: 'reasoning',
        promptName: 'Coding Prompt Mistral Magistral',
      ),

      // Generate Image Prompt -> Reasoning (complex reasoning needed)
      FtuePromptConfig(
        template: imagePromptGenerationPrompt,
        modelVariant: 'reasoning',
        promptName: 'Image Prompt Mistral Magistral',
      ),

      // Note: No cover art generation - Mistral has no image generation model
    ];
  }

  /// Creates or updates the FTUE test category for Mistral.
  Future<(CategoryDefinition?, bool)> _createOrUpdateMistralFtueCategory({
    required CategoryRepository categoryRepository,
    required List<AiConfigPrompt> prompts,
    required String flashModelId,
    required String reasoningModelId,
    required String audioModelId,
  }) async {
    const categoryName = ftueMistralCategoryName;

    // Build allowedPromptIds from all created prompts
    final allowedPromptIds = prompts.map((p) => p.id).toList();

    // Build automaticPrompts map with auto-selection logic
    final automaticPrompts = _buildMistralFtueAutomaticPrompts(
      prompts,
      flashModelId: flashModelId,
      reasoningModelId: reasoningModelId,
      audioModelId: audioModelId,
    );

    // Check if category already exists
    final allCategories = await categoryRepository.getAllCategories();
    final existingCategory = allCategories
        .where((c) => c.name == categoryName && c.deletedAt == null)
        .firstOrNull;

    if (existingCategory != null) {
      // Update existing category with new prompts
      final updatedCategory = existingCategory.copyWith(
        allowedPromptIds: allowedPromptIds,
        automaticPrompts: automaticPrompts,
      );

      await categoryRepository.updateCategory(updatedCategory);
      return (updatedCategory, false);
    }

    // Create new category
    final category = await categoryRepository.createCategory(
      name: categoryName,
      color: ftueMistralCategoryColor,
    );

    // Update with prompts configuration
    final updatedCategory = category.copyWith(
      allowedPromptIds: allowedPromptIds,
      automaticPrompts: automaticPrompts,
    );

    await categoryRepository.updateCategory(updatedCategory);

    return (updatedCategory, true);
  }

  /// Builds the automaticPrompts map for Mistral FTUE auto-selection.
  Map<AiResponseType, List<String>> _buildMistralFtueAutomaticPrompts(
    List<AiConfigPrompt> prompts, {
    required String flashModelId,
    required String reasoningModelId,
    required String audioModelId,
  }) {
    final map = <AiResponseType, List<String>>{};

    String? findPromptId(String preconfiguredId, String modelId) {
      return prompts
          .firstWhereOrNull(
            (p) =>
                p.preconfiguredPromptId == preconfiguredId &&
                p.defaultModelId == modelId,
          )
          ?.id;
    }

    // Audio Transcription -> Audio model (Voxtral)
    final audioTranscript = findPromptId('audio_transcription', audioModelId);
    if (audioTranscript != null) {
      map[AiResponseType.audioTranscription] = [audioTranscript];
    }

    // Image Analysis (task context) -> Flash (Mistral Small with vision)
    final imageAnalysis =
        findPromptId('image_analysis_task_context', flashModelId);
    if (imageAnalysis != null) {
      map[AiResponseType.imageAnalysis] = [imageAnalysis];
    }

    // Task Summary -> Flash (fast processing)
    final taskSummary = findPromptId('task_summary', flashModelId);
    if (taskSummary != null) {
      map[AiResponseType.taskSummary] = [taskSummary];
    }

    // Checklist Updates -> Reasoning (Magistral)
    final checklist = findPromptId('checklist_updates', reasoningModelId);
    if (checklist != null) {
      map[AiResponseType.checklistUpdates] = [checklist];
    }

    // Prompt Generation -> Reasoning (Magistral)
    final promptGen = findPromptId('prompt_generation', reasoningModelId);
    if (promptGen != null) {
      map[AiResponseType.promptGeneration] = [promptGen];
    }

    // Image Prompt Generation -> Reasoning (Magistral)
    final imagePrompt =
        findPromptId('image_prompt_generation', reasoningModelId);
    if (imagePrompt != null) {
      map[AiResponseType.imagePromptGeneration] = [imagePrompt];
    }

    // Note: No image generation - Mistral has no image generation model

    return map;
  }
}

/// Internal result class for Mistral model creation.
class _MistralFtueModelResult {
  const _MistralFtueModelResult({
    required this.flash,
    required this.reasoning,
    required this.audio,
    required this.created,
    required this.verified,
  });

  final AiConfigModel flash;
  final AiConfigModel reasoning;
  final AiConfigModel audio;
  final List<AiConfigModel> created;
  final List<AiConfigModel> verified;
}
