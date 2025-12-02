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

part 'gemini_prompt_setup_service.g.dart';

/// Provider for [GeminiPromptSetupService].
@riverpod
GeminiPromptSetupService geminiPromptSetupService(Ref ref) {
  return const GeminiPromptSetupService();
}

/// Service that handles automatic prompt setup after creating a Gemini provider.
///
/// When a user adds Gemini for the first time, this service:
/// 1. Shows a confirmation dialog asking if they want default prompts
/// 2. Creates prompts with dynamic naming (e.g., "Audio Transcript - Gemini Flash")
/// 3. Associates prompts with appropriate models (Flash for audio, Pro for others)
/// 4. Shows a success snackbar with the number of prompts created
class GeminiPromptSetupService {
  const GeminiPromptSetupService();

  /// Shows a dialog offering to set up default prompts for Gemini.
  ///
  /// Returns true if prompts were created, false otherwise.
  Future<bool> offerPromptSetup({
    required BuildContext context,
    required WidgetRef ref,
    required AiConfigInferenceProvider provider,
  }) async {
    // Only offer for Gemini provider
    if (provider.inferenceProviderType != InferenceProviderType.gemini) {
      return false;
    }

    // Fetch models first to determine what will be shown in the dialog
    final repository = ref.read(aiConfigRepositoryProvider);
    final modelSelection = await _selectModelsForProvider(
      repository: repository,
      provider: provider,
    );

    // If no models available, skip the dialog
    if (modelSelection == null) {
      return false;
    }

    if (!context.mounted) return false;

    // Show confirmation dialog with actual model names
    final confirmed = await _showSetupDialog(
      context,
      flashModelName: modelSelection.flashModel.name,
      proModelName: modelSelection.proModel.name,
    );
    if (!confirmed) return false;

    if (!context.mounted) return false;

    // Create the prompts
    final promptsCreated = await _createDefaultPromptsWithModels(
      repository: repository,
      flashModel: modelSelection.flashModel,
      proModel: modelSelection.proModel,
    );

    if (context.mounted && promptsCreated > 0) {
      _showSuccessSnackbar(context, promptsCreated);
    }

    return promptsCreated > 0;
  }

  /// Selects the appropriate Flash and Pro models for the provider.
  /// Returns null if no models are available.
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

    // Find Flash model (for audio - fast processing)
    final flashModel = providerModels.firstWhere(
      (m) =>
          m.name.toLowerCase().contains('flash') &&
          m.inputModalities.contains(Modality.audio),
      orElse: () => providerModels.first,
    );

    // Find Pro model (for reasoning tasks - image analysis, checklist, summary)
    // Prioritize models with "pro" in the name, fall back to others excluding flash
    final proModel = providerModels.firstWhere(
      (m) => m.name.toLowerCase().contains('pro'),
      orElse: () => providerModels.firstWhere(
        (m) => !m.name.toLowerCase().contains('flash'),
        orElse: () => providerModels.first,
      ),
    );

    return _ModelSelection(flashModel: flashModel, proModel: proModel);
  }

  /// Shows the confirmation dialog for setting up prompts.
  Future<bool> _showSetupDialog(
    BuildContext context, {
    required String flashModelName,
    required String proModelName,
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
                          'Get started quickly',
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
                        _buildPromptPreview(
                          context,
                          Icons.mic,
                          'Audio Transcript',
                          flashModelName,
                        ),
                        const SizedBox(height: 8),
                        _buildPromptPreview(
                          context,
                          Icons.image,
                          'Image Analysis',
                          proModelName,
                        ),
                        const SizedBox(height: 8),
                        _buildPromptPreview(
                          context,
                          Icons.checklist,
                          'Checklist Updates',
                          proModelName,
                        ),
                        const SizedBox(height: 8),
                        _buildPromptPreview(
                          context,
                          Icons.summarize,
                          'Task Summary',
                          proModelName,
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

  /// Creates the default prompts using the pre-selected models.
  Future<int> _createDefaultPromptsWithModels({
    required AiConfigRepository repository,
    required AiConfigModel flashModel,
    required AiConfigModel proModel,
  }) async {
    var promptsCreated = 0;
    const uuid = Uuid();

    // Define prompts to create with their configurations
    final promptConfigs = [
      (
        template: audioTranscriptionPrompt,
        model: flashModel,
      ),
      (
        template: imageAnalysisInTaskContextPrompt,
        model: proModel,
      ),
      (
        template: checklistUpdatesPrompt,
        model: proModel,
      ),
      (
        template: taskSummaryPrompt,
        model: proModel,
      ),
    ];

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
    required this.flashModel,
    required this.proModel,
  });

  final AiConfigModel flashModel;
  final AiConfigModel proModel;
}
